@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:day_planner/agent/agent_loop.dart';
import 'package:day_planner/agent/levels.dart';
import 'package:day_planner/agent/model_client.dart';
import 'package:day_planner/agent/recordings.dart';
import 'package:day_planner/config.dart';
import 'package:day_planner/data/schedule.dart';
import 'package:day_planner/stores/app_store.dart';
import 'package:day_planner/stores/chat_items.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Runs every experiment live, the same way the app does, and writes each
/// run to build/live_runs/ for review. Nothing is saved to the recordings
/// until a run is approved (`just promote`).
///
/// `just run-live` runs all; `just run-live L3/vague` runs matching ones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = AppConfig.hasKey ? false : 'No ANTHROPIC_API_KEY in .env';
  const only = String.fromEnvironment('ONLY');
  late Schedule schedule;
  late String pasteText;

  setUpAll(() async {
    HttpOverrides.global = null;
    schedule = await Schedule.load();
    pasteText = await rootBundle.loadString('assets/schedule_paste.txt');
    Directory('build/live_runs').createSync(recursive: true);
  });

  for (var li = 0; li < levels.length; li++) {
    final level = levels[li];
    for (var ei = 0; ei < level.experiments.length; ei++) {
      final exp = level.experiments[ei];
      final sides = exp.baseline ? [Side.without] : Side.values;
      for (final side in sides) {
        final sideKey = exp.baseline ? 'baseline' : (side == Side.without ? 'without' : 'with');
        final name = 'L${level.number}/${exp.id}/$sideKey';
        if (only.isNotEmpty && !name.contains(only)) continue;

        test(name, () async {
          final captures = <RecordingClient>[];
          final store = AppStore(schedule, RecordingStore(),
              scheduleText: pasteText, liveClient: () {
            final c = RecordingClient(AnthropicClient());
            captures.add(c);
            return c;
          });
          store.setReplay(false);
          store.selectLevel(li);
          store.selectExperiment(ei);
          store.selectSide(side);

          final turns = <Map<String, dynamic>>[];
          final recordings = <String, dynamic>{};
          for (var t = 0; t < exp.inputs.length; t++) {
            final input = exp.inputs[t];
            final key = store.nextRecordingKey;
            final chatBefore = store.chat.length;
            final sending = store.send(input);
            await _answerCards(store, sending);
            final capture = captures.isEmpty ? null : captures.last;
            final sent = input.replaceAll(pasteSchedule, pasteText.trim()).trim();
            turns.add({
              'key': key,
              'input': input.replaceAll(pasteSchedule, '[pasted schedule]'),
              'state': store.state.runtimeType.toString(),
              'chat': [for (final item in store.chat.skip(chatBefore)) _describe(item)],
              'trace': [for (final e in store.trace) _trace(e)],
              'requestSections': [
                for (final s in store.lastRequest?.sections ?? const [])
                  '${s.dropped ? '(dropped) ' : ''}${s.label} ≈${s.tokens}'
              ],
              'exactTokens': store.contextTokens,
              'checks': [
                for (final c in store.checks)
                  {'n': c.def.number, 'name': c.def.name, 'result': c.result.name, 'detail': c.detail}
              ],
              'memory': store.memoryFacts.toList(),
              'calendar': store.calendar.map((s) => s.title).toList(),
              'exports': store.exports.toList(),
            });
            if (capture != null && capture.captured.isNotEmpty) {
              recordings[key] = Recording(
                key: key,
                input: sent,
                savedAt: DateTime.now(),
                exchanges: List.of(capture.captured),
              ).toJson();
            }
          }

          final file = File('build/live_runs/${name.replaceAll('/', '__')}.json');
          file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
            'run': name,
            'level': level.name,
            'experiment': exp.name,
            'notes': exp.notes,
            'turns': turns,
            'recordings': recordings,
          }));
          // ignore: avoid_print
          print('wrote ${file.path}');
        }, skip: skip, timeout: const Timeout(Duration(minutes: 8)));
      }
    }
  }
}

Future<void> _answerCards(AppStore store, Future<void> sending) async {
  var done = false;
  sending.then((_) => done = true);
  while (!done) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (final item in store.chat.toList()) {
      if (item is ApprovalCard && item.decision == Decision.pending) store.decide(item.id, true);
      if (item is MemoryCard && item.decision == Decision.pending) store.decide(item.id, true);
    }
  }
}

Map<String, dynamic> _trace(TraceEvent e) =>
    {'kind': e.kind.name, 'label': e.label, 'ms': e.durMs, if (e.note != null) 'note': e.note};

String _describe(ChatItem item) => switch (item) {
      UserText(:final text, :final pastedLines) =>
        'USER: $text${pastedLines > 0 ? ' [+ pasted schedule, $pastedLines lines]' : ''}',
      AssistantText(:final text) => 'ASSISTANT: $text',
      AppText(:final text) => 'APP: $text',
      DividerText(:final text) => '--- $text ---',
      ErrorText(:final text) => 'ERROR: $text',
      BudgetError(:final tokens, :final budget) => 'BUDGET ERROR: $tokens tokens, limit $budget',
      PlanCard(:final sessions, :final unknownIds) =>
        'PLAN CARD: ${sessions.map((s) => '${s.start}-${s.end} ${s.title} (${s.room}${s.isRoundtable ? ', roundtable' : ''})').join(' | ')}'
            '${unknownIds.isEmpty ? '' : ' | UNKNOWN: ${unknownIds.join(', ')}'}',
      ToolGroup(:final calls) =>
        'TOOLS: ${calls.map((c) => '${c.signature} -> ${c.state.name}: ${c.summary}').join(' || ')}',
      ApprovalCard(:final tool, :final sessions, :final decision) =>
        'APPROVAL CARD ($tool, ${decision.name}): ${sessions.map((s) => s.title).join(' | ')}',
      MemoryCard(:final fact, :final decision) => 'MEMORY CARD (${decision.name}): $fact',
    };
