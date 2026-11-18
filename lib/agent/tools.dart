import 'dart:convert';

import '../data/schedule.dart';
import 'harness.dart';

enum ToolStatus { ok, rejected, failed, declined, notAvailable }

class ToolOutcome {
  const ToolOutcome(this.status, this.content, this.summary);
  final ToolStatus status;

  /// What goes back to the model in the tool_result.
  final String content;

  /// One line for the chat's tool card.
  final String summary;

  bool get isError => status != ToolStatus.ok;
}

class TransientToolError implements Exception {
  TransientToolError(this.message);
  final String message;
}

/// What tools can read and change: the app's own state.
abstract interface class ToolHost {
  Schedule get schedule;
  List<String> get itineraryIds;
  void setItinerary(List<String> ids);
  void showPlan(List<Session> sessions, List<String> unknownIds);
  void addCalendarEvents(List<Session> sessions);
  void recordExport(String to, int count);

  /// Returns true the first time it is called in a run: the calendar "times out".
  bool calendarShouldTimeOut();
}

class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.schema,
    required this.run,
    this.validate,
    this.writes = false,
  });

  final String name;
  final String description;
  final Map<String, dynamic> schema;

  /// Returns an error message, or null when the arguments are fine.
  final String? Function(Map<String, dynamic> args, Schedule schedule)? validate;
  final Future<ToolOutcome> Function(Map<String, dynamic> args, ToolHost host)
      run;

  /// Writes to something outside the conversation (calendar, contacts).
  final bool writes;

  Map<String, dynamic> toJson() =>
      {'name': name, 'description': description, 'input_schema': schema};
}

final _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

String? _checkTime(Object? v, String field) =>
    v == null || (v is String && _time.hasMatch(v))
        ? null
        : '$field must be a 24-hour time like 10:00, not "$v".';

String? _checkIds(Object? ids, Schedule s, {bool allowEmpty = false}) {
  if (ids is! List || (!allowEmpty && ids.isEmpty)) {
    return 'sessionIds must be a non-empty list of session ids.';
  }
  final unknown = ids.where((id) => s.byId('$id') == null).toList();
  return unknown.isEmpty
      ? null
      : 'Unknown session ids: ${unknown.join(', ')}. Use ids returned by searchSessions.';
}

String _json(Object o) => jsonEncode(o);

/// Keyword and time search over the schedule. Shared by the tool and the
/// level 4 seed, so seeded results match what the tool returns.
List<Session> searchSchedule(Schedule schedule,
    {String? keyword, String? after, String? before}) {
  final words = (keyword ?? '')
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9+#]+'))
      .where((w) => w.length > 1)
      .toList();
  return schedule.plannable.where((s) {
    if (after != null && s.start.compareTo(after) < 0) return false;
    if (before != null && s.end.compareTo(before) > 0) return false;
    if (words.isEmpty) return true;
    final hay = '${s.title} ${s.description}'.toLowerCase();
    return words.any((w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(hay));
  }).toList();
}

/// Lenient time parse used when there is no validation: a bad value is
/// silently ignored, which is exactly the kind of bug validation catches.
String? _lenientTime(Object? v) =>
    v is String && _time.hasMatch(v) ? v : null;

final searchSessions = ToolSpec(
  name: 'searchSessions',
  description:
      'Search today’s flutterCon schedule. Matches keywords in titles and descriptions, '
      'optionally only sessions starting at or after `after` and ending by `before` (24-hour HH:MM). '
      'Returns id, title, times, room, type (talk or roundtable) and speakers.',
  schema: {
    'type': 'object',
    'properties': {
      'keyword': {'type': 'string', 'description': 'Words to match, e.g. "AI testing".'},
      'after': {'type': 'string', 'description': 'Earliest start time, HH:MM.'},
      'before': {'type': 'string', 'description': 'Latest end time, HH:MM.'},
    },
  },
  validate: (a, s) =>
      _checkTime(a['after'], 'after') ?? _checkTime(a['before'], 'before'),
  run: (a, host) async {
    final hits = searchSchedule(host.schedule,
        keyword: a['keyword'] as String?,
        after: _lenientTime(a['after']),
        before: _lenientTime(a['before']));
    if (hits.isEmpty) {
      return ToolOutcome(
          ToolStatus.ok,
          _json({
            'count': 0,
            'sessions': [],
            'hint': 'No sessions matched "${a['keyword'] ?? ''}". Try a different keyword.'
          }),
          'No sessions matched');
    }
    return ToolOutcome(
        ToolStatus.ok,
        _json({'count': hits.length, 'sessions': hits.map((s) => s.toBrief()).toList()}),
        '${hits.length} ${hits.length == 1 ? 'session' : 'sessions'}');
  },
);

final getSession = ToolSpec(
  name: 'getSession',
  description: 'Get one session’s full details, including its description.',
  schema: {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'A session id from searchSessions.'}
    },
    'required': ['id'],
  },
  validate: (a, s) => s.byId('${a['id']}') == null
      ? 'Unknown session id "${a['id']}". Use ids returned by searchSessions.'
      : null,
  run: (a, host) async {
    final s = host.schedule.byId('${a['id']}');
    if (s == null) return const ToolOutcome(ToolStatus.ok, 'null', 'No such session');
    final injected = s.description.contains('exportContacts');
    return ToolOutcome(ToolStatus.ok, _json(s.toFull()),
        injected ? 'The description includes an injected instruction' : 'Full details');
  },
);

final showPlan = ToolSpec(
  name: 'showPlan',
  description:
      'Show a plan of sessions to the user as a card. Call this whenever you recommend sessions, '
      'with their ids in time order.',
  schema: {
    'type': 'object',
    'properties': {
      'sessionIds': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Session ids from searchSessions, in time order.'
      },
    },
    'required': ['sessionIds'],
  },
  validate: (a, s) => _checkIds(a['sessionIds'], s),
  run: (a, host) async {
    final ids = (a['sessionIds'] as List? ?? const []).map((e) => '$e').toList();
    final found = [for (final id in ids) ?host.schedule.byId(id)];
    final unknown = ids.where((id) => host.schedule.byId(id) == null).toList();
    host.showPlan(found, unknown);
    return ToolOutcome(ToolStatus.ok, 'Shown to the user.',
        '${found.length} ${found.length == 1 ? 'session' : 'sessions'} shown');
  },
);

final savePreference = ToolSpec(
  name: 'savePreference',
  description:
      'Save one lasting preference about the user, such as "No roundtables". The user is asked to confirm. '
      'Call it once per preference.',
  schema: {
    'type': 'object',
    'properties': {
      'text': {'type': 'string', 'description': 'The preference, under 60 characters.'}
    },
    'required': ['text'],
  },
  validate: (a, s) {
    final t = '${a['text'] ?? ''}'.trim();
    return t.isEmpty || t.length > 120 ? 'text must be 1–120 characters.' : null;
  },
  // Saving happens in the loop, after the user confirms.
  run: (a, host) async => const ToolOutcome(ToolStatus.ok, 'Saved.', 'Saved'),
);

final getItinerary = ToolSpec(
  name: 'getItinerary',
  description: 'Get the user’s saved plan for today.',
  schema: {'type': 'object', 'properties': {}},
  run: (a, host) async {
    final sessions = [for (final id in host.itineraryIds) ?host.schedule.byId(id)];
    return ToolOutcome(
        ToolStatus.ok,
        _json({'sessions': sessions.map((s) => s.toBrief()).toList()}),
        '${sessions.length} sessions in your plan');
  },
);

final addToCalendar = ToolSpec(
  name: 'addToCalendar',
  writes: true,
  description: 'Add sessions to the user’s calendar.',
  schema: {
    'type': 'object',
    'properties': {
      'sessionIds': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['sessionIds'],
  },
  validate: (a, s) => _checkIds(a['sessionIds'], s),
  run: (a, host) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (host.calendarShouldTimeOut()) {
      throw TransientToolError('The calendar service timed out.');
    }
    final sessions = [
      for (final id in (a['sessionIds'] as List? ?? const [])) ?host.schedule.byId('$id')
    ];
    host.addCalendarEvents(sessions);
    return ToolOutcome(ToolStatus.ok, 'Created ${sessions.length} events.',
        '${sessions.length} events created');
  },
);

/// Added "for another feature". Present only without least privilege.
final exportContacts = ToolSpec(
  name: 'exportContacts',
  writes: true,
  description: 'Send the user’s contacts to an email address.',
  schema: {
    'type': 'object',
    'properties': {
      'to': {'type': 'string', 'description': 'Email address.'}
    },
    'required': ['to'],
  },
  validate: (a, s) =>
      '${a['to'] ?? ''}'.contains('@') ? null : 'to must be an email address.',
  run: (a, host) async {
    host.recordExport('${a['to']}', 214);
    return ToolOutcome(ToolStatus.ok, 'Sent 214 contacts to ${a['to']}.',
        'Sent 214 contacts to ${a['to']}');
  },
);

/// The tools this harness gives the model.
List<ToolSpec> toolsFor(HarnessConfig config, {required bool calendarTools}) {
  if (!config.has(HarnessPiece.tools)) return const [];
  return [
    searchSessions,
    getSession,
    showPlan,
    if (config.has(HarnessPiece.memory)) savePreference,
    if (config.has(HarnessPiece.appState)) getItinerary,
    if (calendarTools) addToCalendar,
    if (calendarTools && !config.has(HarnessPiece.leastPrivilege)) exportContacts,
  ];
}
