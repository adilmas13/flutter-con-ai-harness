import 'dart:convert';

import 'package:day_planner/agent/model_client.dart';

typedef Responder = Map<String, dynamic> Function(ModelRequest request);

/// A scripted model: each call returns the next reply in the queue.
class FakeModelClient implements ModelClient {
  FakeModelClient(this.replies, {this.tokens});

  final List<Responder> replies;

  /// Token count for the budget check; defaults to a rough estimate.
  final int Function(ModelRequest request)? tokens;

  final List<ModelRequest> requests = [];
  final List<ModelRequest> counted = [];

  @override
  Future<ModelReply> send(ModelRequest request) async {
    requests.add(request);
    if (replies.isEmpty) throw StateError('No more scripted replies');
    return ModelReply(replies.removeAt(0)(request));
  }

  @override
  Future<int> countTokens(ModelRequest request) async {
    counted.add(request);
    return tokens?.call(request) ?? (jsonEncode(request.body).length ~/ 4);
  }
}

int _ids = 0;

Map<String, dynamic> usage([int input = 500]) =>
    {'input_tokens': input, 'output_tokens': 40};

Responder text(String t) => (_) => {
      'content': [
        {'type': 'thinking', 'thinking': '', 'signature': 'sig-${_ids++}'},
        {'type': 'text', 'text': t},
      ],
      'stop_reason': 'end_turn',
      'usage': usage(),
    };

Responder toolUse(String name, Map<String, dynamic> input) => (_) => {
      'content': [
        {'type': 'thinking', 'thinking': '', 'signature': 'sig-${_ids++}'},
        {'type': 'tool_use', 'id': 'toolu_${_ids++}', 'name': name, 'input': input},
      ],
      'stop_reason': 'tool_use',
      'usage': usage(),
    };

/// Repeats the same responder forever (for runaway loops).
List<Responder> forever(Responder r, int n) => List.filled(n, r, growable: true);
