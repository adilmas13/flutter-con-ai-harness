import '../config.dart';
import '../data/schedule.dart';
import 'agent_state.dart';
import 'checks.dart';
import 'context_builder.dart';
import 'conversation.dart';
import 'harness.dart';
import 'model_client.dart';
import 'tools.dart';

class CancelledRun implements Exception {}

enum TraceKind { model, summary, tool, failed, wait, limit }

class TraceEvent {
  const TraceEvent(this.kind, this.label, this.startMs, this.durMs, [this.note]);
  final TraceKind kind;
  final String label;
  final int startMs;
  final int durMs;
  final String? note;

  TraceEvent finish(int endMs, {TraceKind? kind, String? note}) =>
      TraceEvent(kind ?? this.kind, label, startMs, endMs - startMs, note ?? this.note);
}

/// Everything the loop reports back to the app.
abstract interface class LoopHost implements ToolHost {
  List<String> get memoryFacts;

  /// Completes when the presenter presses Cancel.
  Future<void> get cancelled;
  void setState(AgentState state);
  void showRequest(BuiltRequest request, {int? exactTokens});
  int addTrace(TraceEvent event);
  void updateTrace(int index, TraceEvent event);
  void assistantText(String text);
  void appText(String text);
  void budgetError(int tokens);
  void errorText(String text);
  int toolStarted(String name, Map<String, dynamic> args);
  void toolFinished(int handle, ToolOutcome outcome);
  Future<bool> requestApproval(String tool, Map<String, dynamic> args);
  Future<bool> confirmMemory(String fact);
  void saveMemory(String fact);
}

/// The agent loop: ask the model, run what it asks for, feed results back.
/// Every harness piece is a branch you can switch on or off.
class AgentLoop {
  AgentLoop({
    required this.client,
    required this.builder,
    required this.host,
    required this.config,
    required this.conv,
    required this.calendarTools,
  });

  final ModelClient client;
  final ContextBuilder builder;
  final LoopHost host;
  final HarnessConfig config;
  final Conversation conv;
  final bool calendarTools;

  final _clock = Stopwatch();
  int get _now => _clock.elapsedMilliseconds;
  Schedule get _schedule => builder.schedule;

  BuiltRequest _build() => builder.build(conv, config, calendarTools: calendarTools);

  Future<TurnRecord> run(String text) async {
    _clock.start();
    final rec = TurnRecord()
      ..hadEarlierTurns = conv.userTurns > 0
      ..newConversation = conv.isNew && conv.userTurns == 0
      ..memoryAvailable = host.memoryFacts.isNotEmpty;

    // Keep user/assistant alternation if a previous turn ended early.
    if (conv.messages.isNotEmpty && conv.messages.last['role'] == 'user') {
      conv.messages.add({
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': '(No reply.)'}
        ]
      });
    }
    conv.addUserText(text);

    try {
      var built = _build();

      // Context budget: the window is checked before anything is sent.
      if (built.sections.fold(0, (a, s) => a + (s.dropped ? 0 : s.tokens)) >
          AppConfig.contextBudget * 0.6) {
        host.setState(const CheckingBudget());
        var tokens = await _guard(client.countTokens(built.request));
        host.showRequest(built, exactTokens: tokens);
        if (tokens > AppConfig.contextBudget) {
          rec.wasOverBudget = true;
          if (!config.has(HarnessPiece.contextBudget)) {
            rec.blocked = true;
            host.budgetError(tokens);
            host.setState(Blocked(tokens));
            return rec;
          }
          await _shrink();
          built = _build();
          tokens = await _guard(client.countTokens(built.request));
          host.showRequest(built, exactTokens: tokens);
          if (tokens > AppConfig.contextBudget) {
            rec.blocked = true;
            host.budgetError(tokens);
            host.setState(Blocked(tokens));
            return rec;
          }
        }
      }

      rec.memoryIncluded =
          built.sections.any((s) => s.kind == SectionKind.memory);
      rec.requestIncludedEarlierTurns = config.has(HarnessPiece.history) &&
          (conv.keptFrom < conv.turnStart || conv.summary != null);

      final tools = toolsFor(config, calendarTools: calendarTools);
      var steps = 0;
      while (true) {
        final limit = config.has(HarnessPiece.stepLimit)
            ? AppConfig.stepLimit
            : AppConfig.safetyCap;
        if (steps >= limit) {
          final byLimit = config.has(HarnessPiece.stepLimit);
          rec.stoppedByLimit = byLimit;
          rec.stoppedBySafetyCap = !byLimit;
          host.addTrace(TraceEvent(TraceKind.limit,
              byLimit ? 'Step limit' : 'Safety cap', _now, 20,
              byLimit
                  ? 'Stopped: $limit of $limit model calls used'
                  : 'Stopped by the demo’s safety cap, not by the harness'));
          final msg = byLimit
              ? 'I stopped after $limit steps without settling on an answer. Which topic matters most to you?'
              : 'Stopped after $limit model calls by the demo’s safety cap. Nothing in this harness limits the loop.';
          conv.messages.add({
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': msg}
            ]
          });
          host.appText(msg);
          host.setState(Stopped(byLimit ? 'step limit' : 'safety cap'));
          return rec;
        }

        built = _build();
        host.showRequest(built);
        host.setState(Thinking(steps + 1));
        final t0 = _now;
        final ti = host.addTrace(TraceEvent(TraceKind.model, 'Model call', t0, 0));
        final reply = await _guard(client.send(built.request));
        steps++;
        rec.modelCalls = steps;
        host.updateTrace(
            ti,
            TraceEvent(TraceKind.model, 'Model call', t0, _now - t0,
                '${reply.inputTokens} in · ${reply.outputTokens} out'
                '${reply.requestMatched == false ? ' · request differs from recording' : ''}'));
        host.showRequest(built, exactTokens: reply.inputTokens);

        conv.messages.add({'role': 'assistant', 'content': reply.content});

        if (reply.stopReason == 'refusal') {
          host.errorText('Claude declined this request.');
          host.setState(const Failed('refusal'));
          return rec;
        }
        if (reply.text.isNotEmpty) {
          host.assistantText(reply.text);
          rec.replyTexts.add(reply.text);
          rec.timesInText +=
              RegExp(r'\b([01]\d|2[0-3]):[0-5]\d\b').allMatches(reply.text).length;
        }
        final uses = reply.toolUses;
        if (uses.isEmpty || tools.isEmpty) {
          host.setState(const Done());
          return rec;
        }

        rec.ranTools = true;
        final results = <Map<String, dynamic>>[];
        for (final use in uses) {
          results.add(await _runTool(use, tools, rec));
        }
        conv.messages.add({'role': 'user', 'content': results});
      }
    } on CancelledRun {
      _closeTurn('(Cancelled.)');
      host.appText('Cancelled.');
      host.setState(const Stopped('cancelled'));
      return rec;
    } on ModelException catch (e) {
      _closeTurn('(No reply.)');
      host.errorText(e.message);
      host.setState(Failed(e.message));
      return rec;
    } catch (e) {
      // Network errors, timeouts, a captive-portal page instead of JSON:
      // never leave the app stuck in a busy state.
      _closeTurn('(No reply.)');
      final msg = 'The request failed: $e';
      host.errorText(msg);
      host.setState(Failed(msg));
      return rec;
    }
  }

  /// Races a model call against Cancel.
  Future<T> _guard<T>(Future<T> call) => Future.any([
        call,
        host.cancelled.then<T>((_) => throw CancelledRun()),
      ]);

  /// Keeps user/assistant alternation when a turn ends early.
  void _closeTurn(String text) {
    if (conv.messages.isNotEmpty && conv.messages.last['role'] == 'user') {
      conv.messages.add({
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': text}
        ]
      });
    }
  }

  Future<Map<String, dynamic>> _runTool(Map<String, dynamic> use,
      List<ToolSpec> tools, TurnRecord rec) async {
    final name = use['name'] as String;
    final args = (use['input'] as Map? ?? const {}).cast<String, dynamic>();
    final spec = tools.where((t) => t.name == name).firstOrNull;
    host.setState(CallingTool(name));
    final handle = host.toolStarted(name, args);
    final t0 = _now;
    final ti = host.addTrace(TraceEvent(TraceKind.tool, name, t0, 0));

    ToolOutcome outcome;
    final problem = spec == null
        ? null
        : (config.has(HarnessPiece.validation)
            ? spec.validate?.call(args, _schedule)
            : null);

    if (spec == null) {
      outcome = ToolOutcome(ToolStatus.notAvailable,
          'Error: no tool named $name is available to the planner.',
          'Rejected: the planner doesn’t have this tool');
    } else if (problem != null) {
      outcome = ToolOutcome(ToolStatus.rejected, 'Invalid arguments: $problem',
          'Rejected: $problem');
    } else {
      outcome = await _execute(spec, args, rec, ti, t0);
    }

    if (spec == showPlan && outcome.status == ToolStatus.ok) {
      final ids = (args['sessionIds'] as List? ?? const []).map((e) => '$e');
      rec.showedPlan = true;
      for (final id in ids) {
        (_schedule.byId(id) == null ? rec.planUnknownIds : rec.planIds).add(id);
      }
    }

    host.toolFinished(handle, outcome);
    host.updateTrace(
        ti,
        TraceEvent(
            outcome.isError ? TraceKind.failed : TraceKind.tool,
            name,
            t0,
            _now - t0,
            outcome.isError ? outcome.summary : null));
    return {
      'type': 'tool_result',
      'tool_use_id': use['id'],
      'content': outcome.content,
      if (outcome.isError) 'is_error': true,
    };
  }

  Future<ToolOutcome> _execute(ToolSpec spec, Map<String, dynamic> args,
      TurnRecord rec, int traceIndex, int t0) async {
    // Memory: the model proposes, the user confirms.
    if (spec == savePreference) {
      final fact = '${args['text']}'.trim();
      host.setState(AwaitingConfirmation(fact));
      final w = host.addTrace(TraceEvent(TraceKind.wait, 'savePreference', _now, 0));
      final ok = await host.confirmMemory(fact);
      host.updateTrace(w,
          TraceEvent(TraceKind.wait, 'savePreference', t0, _now - t0,
              ok ? 'Confirmed by the user' : 'Declined by the user'));
      if (!ok) {
        return const ToolOutcome(
            ToolStatus.declined, 'The user chose not to save this.', 'Not saved');
      }
      host.saveMemory(fact);
      return ToolOutcome(ToolStatus.ok, 'Saved.', 'Saved “$fact”');
    }

    // Approval: anything that writes waits for the user.
    var approved = false;
    if (spec.writes && config.has(HarnessPiece.approval)) {
      host.setState(AwaitingApproval(spec.name));
      final w0 = _now;
      final w = host.addTrace(TraceEvent(TraceKind.wait, spec.name, w0, 0));
      approved = await host.requestApproval(spec.name, args);
      host.updateTrace(w,
          TraceEvent(TraceKind.wait, spec.name, w0, _now - w0,
              approved ? 'Approved by the user' : 'Declined by the user'));
      if (!approved) {
        rec.writes.add((tool: spec.name, approved: false));
        return const ToolOutcome(
            ToolStatus.declined, 'The user declined this action.', 'Declined by you');
      }
    }
    if (spec.writes) rec.writes.add((tool: spec.name, approved: approved));

    host.setState(CallingTool(spec.name));
    try {
      final out = await spec.run(args, host);
      if (spec == exportContacts) rec.exportsExecuted++;
      return out;
    } on TransientToolError catch (e) {
      // Retry: one more attempt with the same, already-approved request.
      if (config.has(HarnessPiece.retry)) {
        final f0 = _now;
        host.addTrace(TraceEvent(TraceKind.failed, spec.name, t0, f0 - t0,
            '${e.message} Retrying once.'));
        try {
          final out = await spec.run(args, host);
          return ToolOutcome(out.status, out.content, '${out.summary} · retried once');
        } on TransientToolError catch (e2) {
          return ToolOutcome(ToolStatus.failed, 'Error: ${e2.message}',
              'Failed again: ${e2.message}');
        }
      }
      return ToolOutcome(ToolStatus.failed, 'Error: ${e.message}',
          'Failed: ${e.message}');
    }
  }

  /// Context budget: make the conversation fit by summarising or removing
  /// older turns. Keeps the last three turns and the current one.
  Future<void> _shrink() async {
    final starts = conv.turnStarts;
    if (starts.length < 2) return;
    final keepTurns = 4; // three earlier turns + the current one
    final cut = starts.length > keepTurns ? starts[starts.length - keepTurns] : starts[1];
    final turnsGone = starts.where((s) => s < cut).length;

    if (config.shrink == ShrinkStrategy.summarise) {
      host.setState(const Shrinking('Summarising old turns'));
      final transcript = ContextBuilderTranscript.render(conv.messages.sublist(0, cut));
      final req = ModelRequest({
        'model': AppConfig.model,
        'max_tokens': 1000,
        'output_config': {'effort': 'low'},
        'system':
            'You summarise conversations for an assistant that will continue them. '
                'Write at most 50 words. Focus on the sessions discussed.',
        'messages': [
          {'role': 'user', 'content': 'Summarise this conversation:\n\n$transcript'}
        ],
      });
      final t0 = _now;
      final ti = host.addTrace(TraceEvent(TraceKind.summary, 'Summarise old turns', t0, 0));
      final reply = await _guard(client.send(req));
      host.updateTrace(ti,
          TraceEvent(TraceKind.summary, 'Summarise old turns', t0, _now - t0,
              '$turnsGone turns became ${reply.outputTokens} tokens'));
      conv.summary = reply.text;
    } else {
      host.setState(const Shrinking('Removing old turns'));
      host.addTrace(TraceEvent(TraceKind.summary, 'Remove old turns', _now, 5,
          '$turnsGone turns removed'));
    }
    conv.keptFrom = cut;
    conv.shrunkTurns = turnsGone;
  }
}

/// Plain-text rendering used as input to the summariser.
class ContextBuilderTranscript {
  static String render(List<Map<String, dynamic>> msgs) {
    final out = StringBuffer();
    for (final m in msgs) {
      final c = m['content'];
      if (c is String) {
        out.writeln('${m['role']}: $c');
        continue;
      }
      for (final b in (c as List).cast<Map>()) {
        switch (b['type']) {
          case 'text':
            out.writeln('${m['role']}: ${b['text']}');
          case 'tool_use':
            out.writeln('assistant searched: ${b['input']}');
          case 'tool_result':
            final s = '${b['content']}';
            out.writeln('results: ${s.length > 400 ? '${s.substring(0, 400)}…' : s}');
        }
      }
    }
    return out.toString();
  }
}
