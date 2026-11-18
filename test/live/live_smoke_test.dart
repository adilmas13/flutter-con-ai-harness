@Tags(['live'])
library;

import 'dart:io';

import 'package:day_planner/agent/levels.dart';
import 'package:day_planner/agent/model_client.dart';
import 'package:day_planner/agent/recordings.dart';
import 'package:day_planner/config.dart';
import 'package:day_planner/data/schedule.dart';
import 'package:day_planner/stores/app_store.dart';
import 'package:day_planner/stores/chat_items.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real calls to Claude. Run with `just live-smoke`; skipped without a key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = AppConfig.hasKey ? false : 'No ANTHROPIC_API_KEY in .env';
  late Schedule schedule;
  setUpAll(() async {
    // The test binding fakes HTTP; live tests need the real network.
    HttpOverrides.global = null;
    schedule = await Schedule.load();
  });

  void report(String name, AppStore s) {
    // ignore: avoid_print
    print('\n== $name · state ${s.state.runtimeType}');
    for (final item in s.chat) {
      final line = switch (item) {
        UserText(:final text) => 'you: $text',
        AssistantText(:final text) => 'model: $text',
        AppText(:final text) => 'app: $text',
        ToolGroup(:final calls) => 'tools: ${calls.map((c) => '${c.signature} → ${c.summary}').join(' | ')}',
        PlanCard(:final sessions) => 'plan: ${sessions.map((x) => '${x.start} ${x.title}').join(' / ')}',
        ErrorText(:final text) => 'ERROR: $text',
        BudgetError(:final tokens) => 'BUDGET: $tokens tokens',
        _ => item.runtimeType.toString(),
      };
      // ignore: avoid_print
      print('  $line');
    }
    for (final c in s.checks) {
      // ignore: avoid_print
      print('  check ${c.def.number} ${c.result.name}: ${c.detail}');
    }
  }

  test('level 1: plain call works', () async {
    final s = AppStore(schedule, RecordingStore());
    s.setReplay(false);
    await s.send('Plan my flutterCon day around AI talks.');
    report('L1 baseline', s);
    expect(s.chat.whereType<ErrorText>(), isEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('level 3 with tools: loop, tool calls, plan', () async {
    final s = AppStore(schedule, RecordingStore())
      ..setReplay(false)
      ..selectLevel(2)
      ..selectSide(Side.withPiece);
    await s.send('Plan my day around AI talks. Nothing before 10, and no roundtables.');
    report('L3 plan · with tools', s);
    expect(s.chat.whereType<ErrorText>(), isEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('level 4: real token count of the seeded chat', () async {
    final s = AppStore(schedule, RecordingStore())
      ..selectLevel(3)
      ..selectSide(Side.without);
    final n = await AnthropicClient().countTokens(s.lastRequest!.request);
    // ignore: avoid_print
    print('\n== L4 seed: $n tokens (budget ${AppConfig.contextBudget})');
    expect(n, greaterThan(AppConfig.contextBudget));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 1)));
}
