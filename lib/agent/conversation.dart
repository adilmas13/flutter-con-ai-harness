import 'dart:convert';

/// The messages exactly as they go to the API, plus what the harness has
/// done to them (summarised or removed turns).
class Conversation {
  Conversation({List<String>? memorySnapshot, this.isNew = true})
      : memorySnapshot = List.unmodifiable(memorySnapshot ?? const []);

  /// Everything ever said in this conversation, in API shape. Append-only:
  /// Claude's thinking blocks are only valid if earlier turns never change.
  final List<Map<String, dynamic>> messages = [];

  /// Memory is read once when the conversation starts, so the system prompt
  /// stays identical for every request in it.
  final List<String> memorySnapshot;

  /// True when this conversation started without history from another one.
  final bool isNew;

  /// Index of the first message still sent after shrinking.
  int keptFrom = 0;

  /// Compaction summary standing in for messages[0, keptFrom).
  String? summary;

  /// How many turns were removed or summarised.
  int shrunkTurns = 0;

  /// Index where the current user turn starts.
  int turnStart = 0;

  /// Turns seeded before the demo starts (level 4's long chat).
  int seededTurns = 0;

  int get userTurns => messages.where(isUserText).length;

  static bool isUserText(Map<String, dynamic> m) =>
      m['role'] == 'user' &&
      (m['content'] is String ||
          (m['content'] as List).any((b) => (b as Map)['type'] == 'text'));

  void addUserText(String text) {
    turnStart = messages.length;
    messages.add({'role': 'user', 'content': text});
  }

  /// Start indexes of each user text turn.
  List<int> get turnStarts => [
        for (var i = 0; i < messages.length; i++)
          if (isUserText(messages[i])) i
      ];

  /// All user-written text, including turns that are no longer sent.
  Iterable<String> get userTexts sync* {
    for (final m in messages.where(isUserText)) {
      final c = m['content'];
      if (c is String) {
        yield c;
      } else {
        for (final b in (c as List).cast<Map>()) {
          if (b['type'] == 'text') yield b['text'] as String;
        }
      }
    }
  }
}

/// Rough token estimate for labelling request sections. The total shown in
/// the inspector comes from the API itself.
int estimateTokens(Object? value) {
  final s = value is String ? value : jsonEncode(value);
  return (s.length / 4).ceil();
}
