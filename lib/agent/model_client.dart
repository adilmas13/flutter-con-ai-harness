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
  ModelReply(this.body);
  final Map<String, dynamic> body;

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
          'No API key. Add ANTHROPIC_API_KEY to .env.');
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
