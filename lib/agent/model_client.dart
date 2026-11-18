import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// One request to the Messages API, kept as raw JSON so the inspector shows
/// exactly what is sent.
class ModelRequest {
  ModelRequest(this.body);
  final Map<String, dynamic> body;

  List<Map<String, dynamic>> get messages =>
      (body['messages'] as List).cast<Map<String, dynamic>>();
}

class ModelReply {
  ModelReply(this.body, {this.fromRecording = false, this.requestMatched});
  final Map<String, dynamic> body;
  final bool fromRecording;

  /// In replay: whether today's request is identical to the recorded one.
  final bool? requestMatched;

  List<Map<String, dynamic>> get content =>
      (body['content'] as List? ?? const []).cast<Map<String, dynamic>>();
  String get stopReason => body['stop_reason'] as String? ?? 'end_turn';
  int get inputTokens =>
      (body['usage'] as Map?)?['input_tokens'] as int? ?? 0;
  int get outputTokens =>
      (body['usage'] as Map?)?['output_tokens'] as int? ?? 0;
  int get cacheReadTokens =>
      (body['usage'] as Map?)?['cache_read_input_tokens'] as int? ?? 0;
  String get text => content
      .where((b) => b['type'] == 'text')
      .map((b) => b['text'] as String)
      .join('\n')
      .trim();
  List<Map<String, dynamic>> get toolUses =>
      content.where((b) => b['type'] == 'tool_use').toList();
}

class ModelException implements Exception {
  ModelException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The model is one swappable part of the harness: one round trip per call.
abstract interface class ModelClient {
  Future<ModelReply> send(ModelRequest request);
  Future<int> countTokens(ModelRequest request);
}

/// Live calls to Claude over plain HTTP. There is no official Dart SDK, and
/// raw HTTP keeps the inspector honest: what you see is what is sent.
class AnthropicClient implements ModelClient {
  AnthropicClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  static final _base = Uri.parse('https://api.anthropic.com/v1/messages');

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'x-api-key': AppConfig.apiKey,
        'anthropic-version': '2026-10-21',
        // Server-side fallback if the model declines a request (refusal).
        'anthropic-beta': 'server-side-fallback-2026-07-01',
      };

  void _requireKey() {
    if (!AppConfig.hasKey) {
      throw ModelException(
          'No API key. Add ANTHROPIC_API_KEY to .env, or switch to Replay.');
    }
  }

  @override
  Future<ModelReply> send(ModelRequest request) async {
    _requireKey();
    final body = await _post(_base, _headers, request.body);
    return ModelReply(body);
  }

  /// POST with up to two retries for rate limits, overload, server errors
  /// and network failures.
  Future<Map<String, dynamic>> _post(
      Uri url, Map<String, String> headers, Map<String, dynamic> payload) async {
    const retryable = {408, 409, 429, 500, 502, 503, 504, 529};
    for (var attempt = 0;; attempt++) {
      try {
        final res = await _http
            .post(url, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 90));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        }
        if (retryable.contains(res.statusCode) && attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 800 * (attempt + 1)));
          continue;
        }
        String detail;
        try {
          final err = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          detail = '${(err['error'] as Map?)?['message'] ?? res.body}';
        } catch (_) {
          detail = 'unexpected response (not JSON). Is the network behind a login page?';
        }
        throw ModelException('Claude API ${res.statusCode}: $detail');
      } on ModelException {
        rethrow;
      } catch (e) {
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 800 * (attempt + 1)));
          continue;
        }
        throw ModelException('Network error: $e');
      }
    }
  }

  @override
  Future<int> countTokens(ModelRequest request) async {
    _requireKey();
    final body = Map<String, dynamic>.from(request.body)
      ..remove('max_tokens')
      ..remove('fallbacks')
      ..remove('output_config');
    final json = await _post(Uri.parse('$_base/count_tokens'),
        {..._headers}..remove('anthropic-beta'), body);
    return json['input_tokens'] as int;
  }
}

/// One recorded round trip.
class Exchange {
  Exchange(this.kind, this.request, this.response);
  final String kind; // 'messages' or 'count_tokens'
  final Map<String, dynamic> request;
  final Map<String, dynamic> response;

  Map<String, dynamic> toJson() =>
      {'kind': kind, 'request': request, 'response': response};
  factory Exchange.fromJson(Map<String, dynamic> j) => Exchange(
      j['kind'] as String,
      (j['request'] as Map).cast<String, dynamic>(),
      (j['response'] as Map).cast<String, dynamic>());
}

/// Wraps the live client and keeps every exchange so a good run can be saved.
class RecordingClient implements ModelClient {
  RecordingClient(this.inner);
  final ModelClient inner;
  final List<Exchange> captured = [];

  @override
  Future<ModelReply> send(ModelRequest request) async {
    final reply = await inner.send(request);
    captured.add(Exchange('messages', request.body, reply.body));
    return reply;
  }

  @override
  Future<int> countTokens(ModelRequest request) async {
    final n = await inner.countTokens(request);
    captured.add(Exchange('count_tokens', request.body, {'input_tokens': n}));
    return n;
  }
}

/// Plays back a saved run, one exchange per call, in order.
class ReplayClient implements ModelClient {
  ReplayClient(this.exchanges);
  final List<Exchange> exchanges;
  int _next = 0;

  Exchange _take(String kind) {
    while (_next < exchanges.length && exchanges[_next].kind != kind) {
      _next++;
    }
    if (_next >= exchanges.length) {
      throw ModelException(
          'The recording has no more ${kind == 'messages' ? 'model replies' : 'token counts'}. Run live and save again.');
    }
    return exchanges[_next++];
  }

  @override
  Future<ModelReply> send(ModelRequest request) async {
    final e = _take('messages');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return ModelReply(e.response,
        fromRecording: true,
        requestMatched: canonicalJson(e.request) == canonicalJson(request.body));
  }

  @override
  Future<int> countTokens(ModelRequest request) async =>
      _take('count_tokens').response['input_tokens'] as int;
}

/// JSON with sorted keys, so equal requests compare equal.
String canonicalJson(Object? value) {
  Object? sort(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: sort(v[k])};
    }
    if (v is List) return v.map(sort).toList();
    return v;
  }

  return jsonEncode(sort(value));
}
