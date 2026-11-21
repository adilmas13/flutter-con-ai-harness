import 'package:day_planner/agent/agent_state.dart';
import 'package:day_planner/agent/checks.dart';
import 'package:day_planner/agent/context_builder.dart';
import 'package:day_planner/agent/levels.dart';
import 'package:day_planner/data/schedule.dart';
import 'package:day_planner/stores/app_store.dart';
import 'package:day_planner/stores/chat_items.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

late Schedule schedule;

/// A store wired to a scripted model.
({AppStore store, FakeModelClient client}) storeWith(List<Responder> replies,
    {int Function(dynamic)? tokens}) {
  final client = FakeModelClient(replies,
      tokens: tokens == null ? null : (r) => tokens(r));
  final store = AppStore(schedule, liveClient: () => client);
  return (store: store, client: client);
}

CheckResult check(AppStore s, int n) =>
    s.checks.firstWhere((c) => c.def.number == n).result;

String id(String titlePrefix) =>
    schedule.sessions.firstWhere((s) => s.title.startsWith(titlePrefix)).id;

/// Answers every pending approval or memory card with [yes] until [done].
Future<void> runAnswering(AppStore store, Future<void> done, {bool yes = true}) async {
  var finished = false;
  done.then((_) => finished = true);
  while (!finished) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (final item in store.chat.toList()) {
      if (item is ApprovalCard && item.decision == Decision.pending) store.decide(item.id, yes);
      if (item is MemoryCard && item.decision == Decision.pending) store.decide(item.id, yes);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => schedule = await Schedule.load());

  group('Level 1 · the call', () {
    test('a bare model gets one message: no system, no tools', () async {
      final (:store, :client) = storeWith([text('09:30 Keynote. 11:00 Prompting Patterns. 15:00 Shipping LLMs.')]);
      await store.send('Plan my flutterCon day around AI talks.');
      final body = client.requests.single.body;
      expect((body['system'] as List).single['text'], replyStyle,
          reason: 'only the reply style: nothing about the app');
      expect(body.containsKey('tools'), isFalse);
      expect(client.requests.single.messages, hasLength(1));
      expect(check(store, 1), CheckResult.fail, reason: 'a plan written as text');
    });
  });

  group('Level 2 · history', () {
    Future<AppStore> twoTurns(Side side) async {
      final (:store, :client) = storeWith([text('A plan.'), text('Swapped.')]);
      store.selectLevel(1);
      store.selectSide(side);
      await store.send('Plan my day.');
      await store.send('Swap the second one.');
      expect(client.requests.last.messages.length, side == Side.withPiece ? 3 : 1);
      return store;
    }

    test('without history the follow-up arrives alone', () async {
      expect(check(await twoTurns(Side.without), 2), CheckResult.fail);
    });
    test('with history the follow-up carries the earlier turns', () async {
      expect(check(await twoTurns(Side.withPiece), 2), CheckResult.pass);
    });
  });

  group('Level 3 · tools and the loop', () {
    test('validation rejects a bad time, then a real plan passes', () async {
      final (:store, :client) = storeWith([
        toolUse('searchSessions', {'keyword': 'AI', 'after': '10am'}),
        toolUse('searchSessions', {'keyword': 'AI', 'after': '10:00'}),
        toolUse('showPlan', {
          'sessionIds': [id('Disciplined by Design'), id('I shipped a local AI Model')]
        }),
        text('Here is your day.'),
      ]);
      store.selectLevel(2);
      store.selectSide(Side.withPiece);
      await store.send('Plan my day around AI talks. Nothing before 10, and no roundtables.');

      final firstResult = (client.requests[1].messages.last['content'] as List).first as Map;
      expect(firstResult['is_error'], isTrue);
      expect(store.chat.whereType<PlanCard>(), hasLength(1));
      expect(check(store, 1), CheckResult.pass);
      expect(check(store, 3), CheckResult.pass);
      expect(store.state, isA<Done>());
    });

    test('a plan with a roundtable breaks the rules', () async {
      final roundtable =
          schedule.plannable.firstWhere((s) => s.isRoundtable && s.start.compareTo('10:00') >= 0);
      final (:store, client: _) = storeWith([
        toolUse('showPlan', {'sessionIds': [roundtable.id]}),
        text('Done.'),
      ]);
      store.selectLevel(2);
      store.selectSide(Side.withPiece);
      await store.send('Plan my day. Nothing before 10, and no roundtables.');
      expect(check(store, 3), CheckResult.fail);
    });

    test('the step limit stops the loop at 8', () async {
      final (:store, :client) = storeWith(forever(toolUse('searchSessions', {'keyword': 'best'}), 20));
      store.selectLevel(2);
      store.selectSide(Side.withPiece);
      await store.send('Find me the single best talk of the day.');
      expect(client.requests, hasLength(8));
      expect(check(store, 4), CheckResult.pass);
      expect(store.state, isA<Stopped>());
    });
  });

  group('Level 4 · context management', () {
    test('the seeded long chat is over the window, so it is blocked', () async {
      final (:store, :client) = storeWith([]);
      store.selectLevel(3);
      store.selectSide(Side.without);
      await store.send('What should I end the day with?');
      expect(client.counted, isNotEmpty);
      expect(store.chat.whereType<BudgetError>(), hasLength(1));
      expect(client.requests, isEmpty);
      expect(check(store, 5), CheckResult.fail);
    });

    test('summarising makes it fit; the summary call is not a loop step', () async {
      final (:store, :client) = storeWith([
        text('Planning around AI talks. No roundtables.'), // the summary
        toolUse('showPlan', {'sessionIds': [id('AI Observability')]}),
        text('End with this one.'),
      ]);
      store.selectLevel(3);
      store.selectSide(Side.withPiece);
      await store.send('What should I end the day with?');
      expect(store.conversation.summary, contains('No roundtables'));
      expect(check(store, 5), CheckResult.pass);
      // “Leaving at 17:00” was said in the seed; the talk ends at 17:20.
      expect(check(store, 3), CheckResult.fail);
      final sent = client.requests.last.messages;
      expect(sent.first['content'].toString(), contains('Summary of the earlier conversation'));
    });

    test('removing old turns drops them from the request', () async {
      final (:store, :client) = storeWith([text('Try the roundtable.')]);
      store.selectLevel(3);
      store.selectExperiment(1);
      store.selectSide(Side.withPiece);
      await store.send('What should I end the day with?');
      expect(store.conversation.keptFrom, greaterThan(0));
      expect(client.requests.single.messages.toString(), isNot(contains('Nothing before 10')));
    });
  });

  group('Level 5 · memory and state', () {
    test('the model proposes a memory and the user confirms it', () async {
      final (:store, client: _) = storeWith([
        toolUse('savePreference', {'text': 'Leaving at 17:00'}),
        text('Saved.'),
      ]);
      store.selectLevel(4);
      store.selectSide(Side.withPiece);
      await runAnswering(store, store.send('Remember: I’m leaving at 17:00.'));
      expect(store.memoryFacts, contains('Leaving at 17:00'));
    });

    test('nothing is in memory until the user approves a save', () async {
      final (:store, :client) = storeWith([text('Stop after Beyond Prompts.')]);
      store.selectLevel(4);
      store.selectExperiment(1);
      store.selectSide(Side.withPiece);
      expect(store.memoryFacts, isEmpty);
      await store.send('What should I end the day with?');
      expect(client.requests.single.body['system'].toString(), isNot(contains('Saved preferences')));
    });

    for (final side in Side.values) {
      test('a new conversation ${side == Side.withPiece ? 'gets' : 'lacks'} saved memory', () async {
        final (:store, :client) = storeWith([
          toolUse('savePreference', {'text': 'No roundtables'}),
          text('Saved.'),
          text('Stop after Beyond Prompts.'),
        ]);
        store.selectLevel(4);
        store.selectSide(Side.withPiece);
        await runAnswering(store, store.send('Remember: no roundtables.'));
        store.selectExperiment(1);
        store.selectSide(side);
        await store.send('What should I end the day with?');
        final system = client.requests.last.body['system'].toString();
        expect(system.contains('No roundtables'), side == Side.withPiece);
        expect(check(store, 6), side == Side.withPiece ? CheckResult.pass : CheckResult.fail);
      });
    }
  });

  group('Level 6 · guardrails', () {
    String beyond() => id('Beyond Prompts');

    test('without guardrails, contacts leak and the write runs unasked', () async {
      final (:store, :client) = storeWith([
        toolUse('getSession', {'id': beyond()}),
        toolUse('exportContacts', {'to': 'collect@example.net'}),
        toolUse('addToCalendar', {'sessionIds': [beyond()]}),
        text('Something went wrong.'),
      ]);
      store.selectLevel(5);
      store.selectSide(Side.without);
      await store.send('Add my afternoon talks to my calendar.');
      final tools = (client.requests.first.body['tools'] as List).map((t) => t['name']);
      expect(tools, contains('exportContacts'));
      expect(store.exports, hasLength(1));
      expect(check(store, 7), CheckResult.fail);
    });

    test('with guardrails: no export tool, and the write waits for approval', () async {
      final (:store, :client) = storeWith([
        toolUse('getSession', {'id': beyond()}),
        toolUse('exportContacts', {'to': 'collect@example.net'}),
        toolUse('addToCalendar', {'sessionIds': [beyond()]}),
        text('Added.'),
      ]);
      store.selectLevel(5);
      store.selectSide(Side.withPiece);
      await runAnswering(store, store.send('Add my afternoon talks to my calendar.'));
      final tools = (client.requests.first.body['tools'] as List).map((t) => t['name']);
      expect(tools, isNot(contains('exportContacts')));
      expect(store.exports, isEmpty);
      expect(store.calendar.map((s) => s.id), [beyond()]);
      expect(check(store, 7), CheckResult.pass);
    });
  });

  group('One conversation across the levels', () {
    test('level 3 continues the conversation from level 2', () async {
      final (:store, :client) = storeWith([
        text('Noted.'),
        text('Swapped.'),
        toolUse('searchSessions', {'keyword': 'performance'}),
        text('Here is the plan.'),
      ]);
      store.selectLevel(1);
      store.selectSide(Side.withPiece);
      await store.send('I’ve picked three talks.');
      await store.send('Swap the second one.');
      store.selectLevel(2);
      store.selectSide(Side.withPiece);
      await store.send('Use the schedule.');
      final first = client.requests[2].messages;
      expect(first.length, 5, reason: 'four earlier messages plus the new one');
      expect(first.first['content'].toString(), contains('three talks'));
      // Earlier turns are plain text, so a later tool loop never resends old thinking.
      final later = client.requests.last.messages;
      expect(later.take(4).every((m) => m['content'].toString().contains('thinking') == false), isTrue);
    });

    test('the without and with runs branch from the same history', () async {
      final (:store, :client) = storeWith([text('A'), text('B'), text('C')]);
      store.selectLevel(1);
      store.selectSide(Side.withPiece);
      await store.send('I’ve picked three talks.');
      store.selectLevel(2); // carries the with-history run forward
      await store.send('Use the schedule.'); // without
      store.selectSide(Side.withPiece);
      await store.send('Use the schedule.'); // with
      expect(client.requests[1].messages.length, 3, reason: 'shared history plus the message');
      expect(client.requests[2].messages.length, 3, reason: 'the same shared history, not the without run');
      expect(client.requests[2].messages.toString(), isNot(contains('B')));
    });
  });

  group('What carries to the next level', () {
    test('a Without run never carries forward', () async {
      final (:store, :client) = storeWith([text('A'), text('B'), text('C')]);
      store.selectLevel(1);
      store.selectSide(Side.withPiece);
      await store.send('I’ve picked three talks.');
      store.selectLevel(2);
      await store.send('Only on the without side.'); // without, never with
      store.selectLevel(3);
      final history = store.conversation.messages.toString();
      expect(history, contains('three talks'));
      expect(history, isNot(contains('Only on the without side')));
    });

    test('going back to a level starts from the level before it', () async {
      final (:store, :client) = storeWith([text('A'), text('B'), text('C')]);
      store.selectLevel(1);
      store.selectSide(Side.withPiece);
      await store.send('I’ve picked three talks.');
      store.selectLevel(2);
      store.selectSide(Side.withPiece);
      await store.send('Use the schedule.');
      store.selectLevel(1); // back
      expect(store.conversation.messages, isEmpty,
          reason: 'level 2 follows level 1, which was never run');
      store.selectLevel(2);
      final history = store.conversation.messages.toString();
      expect(history, contains('three talks'));
      expect(history, isNot(contains('Use the schedule')));
    });

    test('the first experiment’s With run is the level’s result', () async {
      final (:store, :client) = storeWith([text('Summary.'), text('A'), text('B')]);
      store.selectLevel(3);
      store.selectSide(Side.withPiece);
      await store.send('Summarise request.');
      store.selectExperiment(1);
      store.selectSide(Side.withPiece);
      await store.send('Remove request.');
      store.selectLevel(4);
      final history = store.conversation.messages.toString();
      expect(history, contains('Summarise request'));
      expect(history, isNot(contains('Remove request')));
    });
  });

  test('a new conversation becomes the conversation the next level continues', () async {
    final (:store, :client) = storeWith([text('A'), text('B')]);
    store.selectLevel(4);
    store.selectSide(Side.withPiece);
    await store.send('Save these.');
    store.selectExperiment(1); // new conversation
    store.selectSide(Side.withPiece);
    await store.send('In the new one.');
    store.selectLevel(5);
    final history = store.conversation.messages.toString();
    expect(history, contains('In the new one'));
    expect(history, isNot(contains('Save these')));
  });

  test('each side keeps its own calendar', () async {
    final (:store, :client) = storeWith([]);
    store.selectLevel(5);
    store.addCalendarEvents([schedule.plannable.first]);
    expect(store.calendar, hasLength(1));
    store.selectSide(Side.withPiece);
    expect(store.calendar, isEmpty, reason: 'the other side’s write is not shown here');
    store.selectSide(Side.without);
    expect(store.calendar, hasLength(1));
  });

  test('experiments in one level start from the same history', () async {
    final (:store, :client) = storeWith([text('summary'), text('A'), text('B')]);
    store.selectLevel(3);
    store.selectSide(Side.withPiece);
    await store.send('What should I end the day with?');
    expect(store.conversation.summary, isNotNull);
    store.selectExperiment(1); // remove old turns
    expect(store.conversation.summary, isNull, reason: 'starts from the level’s history');
    expect(store.conversation.keptFrom, 0);
  });
}
