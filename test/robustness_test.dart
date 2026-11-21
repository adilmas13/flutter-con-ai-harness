import 'dart:async';
import 'dart:io';

import 'package:day_planner/agent/agent_state.dart';
import 'package:day_planner/agent/checks.dart';
import 'package:day_planner/agent/levels.dart';
import 'package:day_planner/agent/model_client.dart';
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
    final store = AppStore(schedule, liveClient: BrokenClient.new);
    await store.send('Plan my day.');
    expect(store.state, isA<Failed>());
    expect(store.state.isBusy, isFalse);
    store.selectLevel(1); // not locked
    expect(store.levelIndex, 1);
  });

  test('Cancel frees a hung run', () async {
    final store = AppStore(schedule, liveClient: HangingClient.new);
    final run = store.send('Plan my day.');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.state.isBusy, isTrue);
    store.cancel();
    await run;
    expect(store.state, isA<Stopped>());
  });

  test('memory saved at level 5 carries into level 6', () async {
    final client = FakeModelClient([
      toolUse('savePreference', {'text': 'Something else'}),
      text('ok'),
    ]);
    final store = AppStore(schedule, liveClient: () => client);
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
    expect(store.memoryFacts, ['Something else']);
    expect(store.itinerary, hasLength(3), reason: 'demo plan when none was made');
    expect(store.calendar, isEmpty);
  });

  test('a suggested plan never replaces the saved plan', () async {
    final saved = AppStore(schedule)..selectLevel(4)..selectExperiment(1);
    final planned = saved.itinerary.toList();
    final late = schedule.sessions.where((s) => s.start.compareTo('16:00') >= 0).first.id;
    final client = FakeModelClient([
      toolUse('showPlan', {'sessionIds': [late]}),
      text('End with that one.'),
    ]);
    final store = AppStore(schedule, liveClient: () => client)
      ..selectLevel(4)
      ..selectExperiment(1)
      ..selectSide(Side.withPiece);
    await store.send('What should I end the day with?');
    expect(store.chat.whereType<PlanCard>(), hasLength(1));
    expect(store.itinerary, planned);
  });

  test('going back to a level reopens the experiment last used there', () {
    final store = AppStore(schedule)
      ..selectLevel(3)
      ..selectExperiment(1)
      ..selectLevel(4);
    expect(store.experimentIndex, 0, reason: 'first visit opens the first experiment');
    store.selectLevel(3);
    expect(store.experiment.id, 'remove');
    store.resetForStage();
    store.selectLevel(3);
    expect(store.experimentIndex, 0, reason: 'reset forgets it');
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

    test('a text plan built from a pasted schedule counts as real', () {
      final t = TurnRecord()
        ..timesInText = 4
        ..replyTexts.add('12:00 Disciplined by Design. 13:20 I shipped a local AI Model. '
            '14:15 Beyond Prompts. 16:40 AI Observability for LLM-Powered Flutter Apps.');
      expect(runChecks(t, Rules(), schedule).first.result, CheckResult.pass);
      final invented = TurnRecord()
        ..timesInText = 3
        ..replyTexts.add('09:30 Keynote: Flutter in 2030. 11:00 Prompting Patterns. 15:00 LLMs.');
      expect(runChecks(invented, Rules(), schedule).first.result, CheckResult.fail);
    });

    test('the pasted schedule replaces the placeholder when sent', () async {
      final client = FakeModelClient([text('ok')]);
      final store = AppStore(schedule,
          liveClient: () => client, scheduleText: 'SCHEDULE LINES');
      await store.send('Plan my day. Here’s the schedule:\n\n{schedule}');
      expect(client.requests.single.messages.single['content'], contains('SCHEDULE LINES'));
      expect(store.chat.whereType<UserText>().single.pastedLines, 1);
    });

    test('stating the rules is not a plan written as text', () {
      final t = TurnRecord()..timesInText = 2;
      final out = runChecks(t, Rules(), schedule);
      expect(out.first.result, CheckResult.notApplicable);
    });
  });
}
