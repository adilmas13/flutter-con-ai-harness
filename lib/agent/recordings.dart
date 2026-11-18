import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import 'model_client.dart';

class Recording {
  Recording({
    required this.key,
    required this.input,
    required this.savedAt,
    required this.exchanges,
  });

  final String key;
  final String input;
  final DateTime savedAt;
  final List<Exchange> exchanges;

  Map<String, dynamic> toJson() => {
        'input': input,
        'savedAt': savedAt.toIso8601String(),
        'exchanges': exchanges.map((e) => e.toJson()).toList(),
      };

  factory Recording.fromJson(String key, Map<String, dynamic> j) => Recording(
        key: key,
        input: j['input'] as String,
        savedAt: DateTime.parse(j['savedAt'] as String),
        exchanges: (j['exchanges'] as List)
            .map((e) => Exchange.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Saved runs, keyed by level / experiment / side / turn.
///
/// Reads `recordings/recordings.json` from the project folder when the app is
/// started with `PROJECT_DIR` (see `tool/run.sh`), and writes back to it.
/// Otherwise it falls back to the copy bundled with the app, read-only.
class RecordingStore {
  final Map<String, Recording> _all = {};
  bool get canWrite => AppConfig.recordingsPath != null;

  static String keyFor({
    required int level,
    required String experiment,
    required String side,
    required int turn,
  }) =>
      'L$level/$experiment/$side/turn-$turn';

  Recording? operator [](String key) => _all[key];
  int get count => _all.length;

  Future<void> load() async {
    String raw;
    final path = AppConfig.recordingsPath;
    if (path != null && File(path).existsSync()) {
      raw = await File(path).readAsString();
    } else {
      raw = await rootBundle.loadString('recordings/recordings.json');
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final recs = (json['recordings'] as Map).cast<String, dynamic>();
    _all
      ..clear()
      ..addAll({
        for (final e in recs.entries)
          e.key: Recording.fromJson(e.key, (e.value as Map).cast())
      });
  }

  Future<void> save(Recording recording) async {
    final path = AppConfig.recordingsPath;
    if (path == null) {
      throw StateError(
          'Recordings are read-only. Start the app with tool/run.sh to save.');
    }
    _all[recording.key] = recording;
    final keys = _all.keys.toList()..sort();
    final out = {
      'version': 1,
      'recordings': {for (final k in keys) k: _all[k]!.toJson()},
    };
    await File(path).writeAsString(
        const JsonEncoder.withIndent('  ').convert(out));
  }
}
