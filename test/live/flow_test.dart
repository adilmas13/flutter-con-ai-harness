@Tags(['live'])
library;

import 'dart:io';

import 'package:day_planner/agent/levels.dart';
import 'package:day_planner/agent/recordings.dart';
import 'package:day_planner/config.dart';
import 'package:day_planner/data/schedule.dart';
import 'package:day_planner/stores/app_store.dart';
import 'package:day_planner/stores/chat_items.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// The whole talk, live, as one accumulating conversation: every level's
/// Without then With run, with the suggested inputs. Prints a transcript.
/// Run with `just live-flow`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = AppConfig.hasKey ? false : 'No ANTHROPIC_API_KEY in .env';

  test('stage path', () async {
    HttpOverrides.global = null;
    final store = AppStore(await Schedule.load(), RecordingStore(),
        scheduleText: await rootBundle.loadString('assets/schedule_paste.txt'));
    final out = StringBuffer();
    var errors = 0;
    for (var li = 0; li < levels.length; li++) {
      for (var ei = 0; ei < levels[li].experiments.length; ei++) {
        final exp = levels[li].experiments[ei];
        store.selectLevel(li);
        store.selectExperiment(ei);
        for (final side in exp.baseline ? [Side.without] : Side.values) {
          store.selectSide(side);
          final before = store.chat.length;
          for (final input in exp.inputs) {
            final sending = store.send(input);
            var done = false;
            sending.then((_) => done = true);
            while (!done) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              for (final i in store.chat.toList()) {
                if (i is ApprovalCard && i.decision == Decision.pending) store.decide(i.id, true);
                if (i is MemoryCard && i.decision == Decision.pending) store.decide(i.id, true);
              }
            }
          }
          out.writeln('\n#### L${levels[li].number} ${exp.name} · ${exp.baseline ? 'baseline' : side.name} · ${store.state.runtimeType} · ${store.contextTokens} tokens');
          for (final i in store.chat.skip(before)) {
            final line = switch (i) {
              UserText(:final text) => 'YOU: $text',
              AssistantText(:final text, :final interim) => '${interim ? 'note' : 'MODEL'}: $text',
              AppText(:final text) => 'APP: $text',
              ErrorText(:final text) => 'ERROR: $text',
              BudgetError(:final tokens) => 'BLOCKED: $tokens tokens',
              PlanCard(:final sessions) => 'PLAN: ${sessions.map((s) => '${s.start} ${s.title}').join(' | ')}',
              ToolGroup(:final calls) => 'TOOLS: ${calls.map((c) => '${c.name} → ${c.summary}').join(' | ')}',
              DividerText(:final text) => '--- $text',
              ApprovalCard(:final decision) => 'APPROVAL ${decision.name}',
              MemoryCard(:final fact) => 'MEMORY: $fact',
            };
            if (i is ErrorText) errors++;
            out.writeln(line);
          }
          out.writeln('checks: ${store.checks.where((c) => c.result.name != 'notApplicable').map((c) => '${c.def.number}:${c.result.name}').join(' ')}');
        }
      }
    }
    File('build/live_flow.md').writeAsStringSync(out.toString());
    // ignore: avoid_print
    print(out);
    expect(errors, 0);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 15)));
}
