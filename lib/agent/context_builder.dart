import '../config.dart';
import '../data/schedule.dart';
import 'conversation.dart';
import 'harness.dart';
import 'model_client.dart';
import 'tools.dart';

enum SectionKind { instructions, memory, summary, conversation, toolResults }

/// A labelled part of a request, for the inspector.
class RequestSection {
  RequestSection(this.kind, this.label, this.text, {this.dropped = false})
      : tokens = estimateTokens(text);
  final SectionKind kind;
  final String label;
  final String text;
  final int tokens;
  final bool dropped;
}

class BuiltRequest {
  BuiltRequest(this.request, this.sections);
  final ModelRequest request;
  final List<RequestSection> sections;
}

/// Builds each request from app state: the "context = f(state)" idea.
class ContextBuilder {
  ContextBuilder(this.schedule);
  final Schedule schedule;

  String rules(HarnessConfig c) {
    final lines = <String>[
      'You are Day Planner, an assistant that plans the user’s day at flutterCon India 2026.',
      if (c.has(HarnessPiece.tools)) ...[
        'Only recommend sessions returned by the tools. Never invent sessions.',
        'Whenever you recommend sessions, call showPlan with their ids.',
      ],
      if (c.has(HarnessPiece.memory))
        'When the user states a lasting preference, save it with savePreference, one call per preference.',
      if (c.has(HarnessPiece.appState))
        'The user’s saved plan for today is available through getItinerary.',
      'Keep replies short: two or three sentences.',
    ];
    return lines.join('\n');
  }

  String eventFacts() =>
      'Today is Saturday 21 November 2026, at ${schedule.venue}.\n'
      'Rooms: Ballroom 1, Ballroom 2, Ballroom 3, Junior Ballroom, Roundtables.';

  BuiltRequest build(
    Conversation conv,
    HarnessConfig config, {
    required bool calendarTools,
  }) {
    final sections = <RequestSection>[];
    final system = <Map<String, dynamic>>[];

    if (config.has(HarnessPiece.contextBuilder)) {
      final r = rules(config), f = eventFacts();
      system.add({'type': 'text', 'text': r});
      system.add({'type': 'text', 'text': f});
      sections
        ..add(RequestSection(SectionKind.instructions, 'System rules', r))
        ..add(RequestSection(SectionKind.instructions, 'Event facts', f));
      if (config.has(HarnessPiece.memory) && conv.memorySnapshot.isNotEmpty) {
        final m =
            'Saved preferences:\n${conv.memorySnapshot.map((e) => '- $e').join('\n')}';
        system.add({'type': 'text', 'text': m});
        sections.add(RequestSection(SectionKind.memory,
            'Memory · ${conv.memorySnapshot.length} facts', m));
      }
    }

    // Which messages are sent.
    final all = conv.messages;
    final start = config.has(HarnessPiece.history) ? conv.keptFrom : conv.turnStart;
    final sent = all.sublist(start).map(_copy).toList();

    // After shrinking, kept turns lose their thinking blocks: those blocks were
    // produced against a history that no longer exists.
    if (conv.keptFrom > 0) {
      final cutoff = conv.turnStart - start;
      for (var i = 0; i < sent.length && i < cutoff; i++) {
        final c = sent[i]['content'];
        if (sent[i]['role'] == 'assistant' && c is List) {
          sent[i] = {
            'role': 'assistant',
            'content': c
                .cast<Map<String, dynamic>>()
                .where((b) => b['type'] != 'thinking' && b['type'] != 'redacted_thinking')
                .toList(),
          };
        }
      }
    }

    // Dropped history, shown struck through in the inspector.
    if (config.has(HarnessPiece.history) && conv.keptFrom > 0) {
      final droppedText = _render(all.sublist(0, conv.keptFrom));
      sections.add(RequestSection(SectionKind.conversation,
          '${conv.shrunkTurns} older turns', droppedText,
          dropped: true));
    }
    if (config.has(HarnessPiece.history) && conv.summary != null) {
      final s = 'Summary of the earlier conversation:\n${conv.summary}';
      // Summary goes in front of the first kept user message, as text.
      final first = sent.first;
      final content = first['content'] is String
          ? [
              {'type': 'text', 'text': first['content']}
            ]
          : List<Map<String, dynamic>>.from(first['content'] as List);
      sent[0] = {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': s},
          ...content
        ]
      };
      sections.add(RequestSection(
          SectionKind.summary, 'Summary of ${conv.shrunkTurns} turns', conv.summary!));
    }

    // Label what is being sent.
    final relTurnStart = conv.turnStart - start;
    final history = sent.take(relTurnStart.clamp(0, sent.length)).toList();
    final current = sent.skip(relTurnStart.clamp(0, sent.length)).toList();
    final historyText = _render(history, includeToolResults: false);
    if (historyText.isNotEmpty) {
      final turns = history.where(Conversation.isUserText).length;
      sections.add(RequestSection(SectionKind.conversation,
          'History · $turns ${turns == 1 ? 'turn' : 'turns'}', historyText));
    }
    if (current.isNotEmpty) {
      sections.add(RequestSection(
          SectionKind.conversation, 'User message', _userText(current.first)));
      final thisTurn = _render(current.skip(1).toList(), includeToolResults: false);
      if (thisTurn.isNotEmpty) {
        sections.add(RequestSection(
            SectionKind.conversation, 'This turn so far', thisTurn));
      }
    }
    final results = _toolResults(sent);
    if (results.isNotEmpty) {
      sections.add(RequestSection(SectionKind.toolResults,
          'Tool results · ${results.length}', results.join('\n\n')));
    }

    final tools = toolsFor(config, calendarTools: calendarTools);
    if (tools.isNotEmpty) {
      sections.insert(
          sections.indexWhere((s) => s.kind != SectionKind.instructions).clamp(0, sections.length),
          RequestSection(SectionKind.instructions, 'Tool definitions · ${tools.length}',
              tools.map((t) => '${t.name}: ${t.description}\n${t.schema}').join('\n\n')));
    }
    final body = <String, dynamic>{
      'model': AppConfig.model,
      'max_tokens': 8000,
      'output_config': {'effort': AppConfig.effort},
      'fallbacks': 'default',
      if (system.isNotEmpty) 'system': system,
      if (tools.isNotEmpty) 'tools': tools.map((t) => t.toJson()).toList(),
      if (tools.isNotEmpty)
        'tool_choice': {'type': 'auto', 'disable_parallel_tool_use': true},
      'messages': sent,
    };
    return BuiltRequest(ModelRequest(body), sections);
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> m) =>
      {'role': m['role'], 'content': m['content']};

  static String _userText(Map<String, dynamic> m) {
    final c = m['content'];
    if (c is String) return c;
    return (c as List)
        .cast<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'])
        .join('\n');
  }

  static List<String> _toolResults(List<Map<String, dynamic>> msgs) => [
        for (final m in msgs)
          if (m['content'] is List)
            for (final b in (m['content'] as List).cast<Map>())
              if (b['type'] == 'tool_result') '${b['content']}'
      ];

  static String _render(List<Map<String, dynamic>> msgs,
      {bool includeToolResults = true}) {
    final out = <String>[];
    for (final m in msgs) {
      final c = m['content'];
      if (c is String) {
        out.add('${m['role']}: $c');
        continue;
      }
      for (final b in (c as List).cast<Map>()) {
        switch (b['type']) {
          case 'text':
            out.add('${m['role']}: ${b['text']}');
          case 'tool_use':
            out.add('${m['role']} asks: ${b['name']}(${b['input']})');
          case 'tool_result' when includeToolResults:
            out.add('tool result: ${b['content']}');
        }
      }
    }
    return out.join('\n');
  }
}
