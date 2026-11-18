import 'dart:async';
import 'dart:io';

import 'package:day_planner/agent/agent_state.dart';
import 'package:day_planner/agent/checks.dart';
import 'package:day_planner/agent/levels.dart';
import 'package:day_planner/agent/model_client.dart';
import 'package:day_planner/agent/recordings.dart';
import 'package:day_planner/data/schedule.dart';
import 'package:day_planner/stores/app_store.dart';
import 'package:day_planner/stores/chat_items.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

late Schedule schedule;

/// A model call that never returns, like a hung network request.
class HangingClient implements ModelClient {
  @override
  Future<ModelReply> send(ModelRequest request) => Completer<ModelReply>().future;
  @override
  Future<int> countTokens(ModelRequest request) async => 100;
}

/// A model call that fails with something other than an API error.
class BrokenClient implements ModelClient {
  @override
  Future<ModelReply> send(ModelRequest request) async =>
      throw const SocketException('Network is unreachable');
  @override
  Future<int> countTokens(ModelRequest request) async => 100;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => schedule = await Schedule.load());

  test('a network error ends the turn instead of locking the app', () async {
    final store = AppStore(schedule, RecordingStore(), liveClient: BrokenClient.new);
    await store.send('Plan my day.');
    expect(store.state, isA<Failed>());
    expect(store.state.isBusy, isFalse);
    expect(store.canSave, isFalse);
    store.selectLevel(1); // not locked
    expect(store.levelIndex, 1);
  });

  test('Cancel frees a hung run', () async {
    final store = AppStore(schedule, RecordingStore(), liveClient: HangingClient.new);
    final run = store.send('Plan my day.');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.state.isBusy, isTrue);
    store.cancel();
    await run;
    expect(store.state, isA<Stopped>());
    expect(store.canSave, isFalse);
  });

  test('every experiment starts from the same state, whatever ran before', () async {
    final client = FakeModelClient([
      toolUse('savePreference', {'text': 'Something else'}),
      text('ok'),
    ]);
    final store = AppStore(schedule, RecordingStore(), liveClient: () => client);
    store.selectLevel(4);
    store.selectSide(Side.withPiece);
    final run = store.send('Remember something.');
    while (store.chat.whereType<MemoryCard>().isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    store.decide(store.chat.whereType<MemoryCard>().first.id, true);
    await run;
    expect(store.memoryFacts, ['Something else']);

    store.selectLevel(5);
    expect(store.memoryFacts, ['Nothing before 10:00', 'No roundtables', 'Leaving at 17:00']);
    expect(store.itinerary, hasLength(3));
    expect(store.calendar, isEmpty);
  });

  test('Save run stores every turn of the conversation', () async {
    final dir = Directory.systemTemp.createTempSync('rec');
    final path = '${dir.path}/r.json';
    File(path).writeAsStringSync('{"version":1,"recordings":{}}');
    final recs = RecordingStore(path: path);
    await recs.load();
    final client = FakeModelClient([text('A plan.'), text('Swapped.')]);
    final store = AppStore(schedule, recs, liveClient: () => client);
    store.selectLevel(1);
    store.selectSide(Side.withPiece);
    await store.send('Plan my day.');
    await store.send('Swap the second one.');
    await store.saveRun();
    expect(recs['L2/follow-up/with/turn-0'], isNotNull);
    expect(recs['L2/follow-up/with/turn-1'], isNotNull);
    dir.deleteSync(recursive: true);
  });

  group('rules are read from how people actually say them', () {
    for (final (text, field) in [
      ('Nothing before 10, and no roundtables.', 'min'),
      ('No talks earlier than 10am please', 'min'),
      ('Skip the roundtables', 'round'),
      ('I’m leaving at 17:00.', 'max'),
      ('Leaving by 5pm', 'max'),
      ('Ends by 17:00', 'max'),
    ]) {
      test(text, () {
        final r = Rules.from([text]);
        switch (field) {
          case 'min':
            expect(r.minStart, '10:00');
          case 'round':
            expect(r.noRoundtables, isTrue);
          case 'max':
            expect(r.maxEnd, '17:00');
        }
      });
    }

    test('stating the rules is not a plan written as text', () {
      final t = TurnRecord()..timesInText = 2;
      final out = runChecks(t, Rules(), schedule);
      expect(out.first.result, CheckResult.notApplicable);
    });
  });
}
