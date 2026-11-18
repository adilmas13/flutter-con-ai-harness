import 'dart:convert';
import 'dart:io';

import 'package:day_planner/agent/levels.dart';
import 'package:day_planner/agent/model_client.dart';
import 'package:day_planner/agent/recordings.dart';
import 'package:day_planner/data/schedule.dart';
import 'package:day_planner/stores/app_store.dart';
import 'package:day_planner/stores/chat_items.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Replays every recorded experiment offline, exactly as on stage, and checks
/// it reproduces the recorded requests. When the live run's review file is
/// present (build/live_runs/), the replayed chat and checks must match it too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Schedule schedule;
  late String pasteText;
  final recordings = RecordingStore(path: 'recordings/recordings.json');

  setUpAll(() async {
    schedule = await Schedule.load();
    pasteText = await rootBundle.loadString('assets/schedule_paste.txt');
    await recordings.load();
  });

  test('recordings file is readable', () => expect(recordings.count, greaterThanOrEqualTo(0)));

  for (var li = 0; li < levels.length; li++) {
    final level = levels[li];
    for (var ei = 0; ei < level.experiments.length; ei++) {
      final exp = level.experiments[ei];
      for (final side in exp.baseline ? [Side.without] : Side.values) {
        final sideKey = exp.baseline ? 'baseline' : (side == Side.without ? 'without' : 'with');
        final name = 'L${level.number}/${exp.id}/$sideKey';

        test('replay $name', () async {
          final first = RecordingStore.keyFor(
              level: level.number, experiment: exp.id, side: sideKey, turn: 0);
          if (recordings[first] == null) {
            markTestSkipped('not recorded yet');
            return;
          }
          final store = AppStore(schedule, recordings,
              scheduleText: pasteText,
              liveClient: () => throw StateError('replay must not call the network'));
          store.selectLevel(li);
          store.selectExperiment(ei);
          store.selectSide(side);
          store.setReplay(true);

          final live = File('build/live_runs/${name.replaceAll('/', '__')}.json');
          final liveTurns = live.existsSync()
              ? (jsonDecode(live.readAsStringSync())['turns'] as List)
              : null;

          for (var t = 0; t < exp.inputs.length; t++) {
            final key = store.nextRecordingKey;
            expect(recordings[key], isNotNull, reason: '$key is missing');
            final before = store.chat.length;
            final sending = store.send(exp.inputs[t]);
            var done = false;
            sending.then((_) => done = true);
            while (!done) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              for (final item in store.chat.toList()) {
                if (item is ApprovalCard && item.decision == Decision.pending) store.decide(item.id, true);
                if (item is MemoryCard && item.decision == Decision.pending) store.decide(item.id, true);
              }
            }

            final notes = store.trace.map((e) => e.note ?? '').join('\n');
            expect(notes, isNot(contains('differs from recording')),
                reason: '$key: the app now sends a different request than was recorded');
            expect(store.chat.skip(before).whereType<ErrorText>(), isEmpty,
                reason: '$key: replay produced an error');

            if (liveTurns != null) {
              final recorded = liveTurns[t] as Map<String, dynamic>;
              expect(store.state.runtimeType.toString(), recorded['state'], reason: key);
              expect(
                [for (final c in store.checks) c.result.name],
                [for (final c in recorded['checks'] as List) c['result']],
                reason: '$key: checks differ from the live run',
              );
            }
          }
        });
      }
    }
  }

  test('a replay never touches the network', () {
    expect(() => ReplayClient(const []).send(ModelRequest({'messages': []})),
        throwsA(isA<ModelException>()));
  });
}
