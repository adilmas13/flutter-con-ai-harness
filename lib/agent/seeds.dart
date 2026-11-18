import 'dart:convert';

import '../data/schedule.dart';
import 'conversation.dart';
import 'tools.dart';

/// Level 4's long conversation: the rules are said at the start, then many
/// turns of real schedule searches fill the window.
void seedLongChat(Conversation conv, Schedule schedule) {
  void user(String text) => conv.messages.add({'role': 'user', 'content': text});
  void assistant(String text) => conv.messages.add({
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': text}
        ]
      });

  user('I’m planning my flutterCon day. Nothing before 10, and no roundtables please.');
  assistant('Got it: nothing before 10:00 and no roundtables. What do you want to focus on?');
  user('Also, I’m leaving at 17:00.');
  assistant('Noted. I’ll keep everything finishing by 17:00.');

  const topics = [
    'performance', 'testing', 'architecture', 'security', 'native', 'AI',
    'agents', 'state', 'scale', 'CI', 'widgets', 'offline', 'GenUI',
    'Genkit', 'concurrency', 'maps', 'wearables', 'packages', 'DevTools',
    'releases',
  ];
  var n = 0;
  for (final topic in topics) {
    n++;
    user('What’s on about $topic?');
    final id = 'toolu_seed_${n.toString().padLeft(2, '0')}';
    conv.messages.add({
      'role': 'assistant',
      'content': [
        {
          'type': 'tool_use',
          'id': id,
          'name': 'searchSessions',
          'input': {'keyword': topic}
        }
      ]
    });
    final hits = searchSchedule(schedule, keyword: topic);
    conv.messages.add({
      'role': 'user',
      'content': [
        {
          'type': 'tool_result',
          'tool_use_id': id,
          'content': jsonEncode({
            'count': hits.length,
            'sessions': hits.map((s) => s.toBrief()).toList()
          }),
        }
      ]
    });
    assistant(hits.isEmpty
        ? 'Nothing specifically on $topic today.'
        : 'There are ${hits.length} sessions touching on $topic. The closest match is “${hits.first.title}” at ${hits.first.start}.');
  }
  conv.seededTurns = conv.userTurns;
}

/// Demo preferences, used when memory is empty.
const demoMemory = ['Nothing before 10:00', 'No roundtables', 'Leaving at 17:00'];

/// A plan made earlier in the day: three afternoon-ish talks that fit the rules.
List<String> demoPlanIds(Schedule s) {
  String find(String prefix) =>
      s.sessions.firstWhere((x) => x.title.startsWith(prefix)).id;
  return [
    find('Disciplined by Design'),
    find('I shipped a local AI Model'),
    find('Beyond Prompts'),
  ];
}
