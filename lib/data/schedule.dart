import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

enum SessionKind { talk, roundtable, booth, breakTime }

class Session {
  const Session({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.room,
    required this.kind,
    required this.speakers,
    required this.description,
  });

  final String id;
  final String title;
  final String start; // HH:MM
  final String end; // HH:MM
  final String room;
  final SessionKind kind;
  final List<String> speakers;
  final String description;

  bool get isRoundtable => kind == SessionKind.roundtable;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        title: json['title'] as String,
        start: json['start'] as String,
        end: json['end'] as String,
        room: json['room'] as String,
        kind: switch (json['kind']) {
          'roundtable' => SessionKind.roundtable,
          'booth' => SessionKind.booth,
          'break' => SessionKind.breakTime,
          _ => SessionKind.talk,
        },
        speakers: (json['speakers'] as List).cast<String>(),
        description: json['description'] as String,
      );

  /// What a search returns: no description, to keep tool results small.
  Map<String, dynamic> toBrief() => {
        'id': id,
        'title': title,
        'start': start,
        'end': end,
        'room': room,
        'type': kind == SessionKind.roundtable ? 'roundtable' : 'talk',
        'speakers': speakers,
      };

  Map<String, dynamic> toFull() => {...toBrief(), 'description': description};
}

class Schedule {
  Schedule(this.event, this.date, this.venue, this.sessions);

  final String event;
  final String date;
  final String venue;
  final List<Session> sessions;

  late final Map<String, Session> _byId = {for (final s in sessions) s.id: s};

  Session? byId(String id) => _byId[id];

  /// Talks and roundtables only: breaks and booths are not plannable.
  Iterable<Session> get plannable => sessions.where(
      (s) => s.kind == SessionKind.talk || s.kind == SessionKind.roundtable);

  static Future<Schedule> load() async {
    final raw = jsonDecode(await rootBundle.loadString('assets/schedule.json'))
        as Map<String, dynamic>;
    return Schedule(
      raw['event'] as String,
      raw['date'] as String,
      raw['venue'] as String,
      (raw['sessions'] as List)
          .map((e) => Session.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
