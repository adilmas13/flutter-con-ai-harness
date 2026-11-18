import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../agent/levels.dart';
import '../config.dart';
import '../stores/app_store.dart';
import '../stores/chat_items.dart';

/// Development aid: `just screens` launches the app with AUTOPILOT=true. It
/// replays every recorded experiment in the real window, screenshots each
/// final screen to build/screens/, then quits. Never used on stage.
const autopilot = bool.fromEnvironment('AUTOPILOT');

final screenKey = GlobalKey();

Future<void> runAutopilot(AppStore store) async {
  final dir = Directory('${AppConfig.projectDir}/build/screens')..createSync(recursive: true);
  await _settle(1500);

  for (var li = 0; li < levels.length; li++) {
    final level = levels[li];
    for (var ei = 0; ei < level.experiments.length; ei++) {
      final exp = level.experiments[ei];
      for (final side in exp.baseline ? [Side.without] : Side.values) {
        store.selectLevel(li);
        store.selectExperiment(ei);
        store.selectSide(side);
        store.setReplay(true);
        if (!store.inspectorOpen) store.toggleInspector();
        store.setTab(li >= 5 ? InspectorTab.trace : InspectorTab.context);

        for (final input in exp.inputs) {
          final sending = store.send(input);
          var done = false;
          sending.then((_) => done = true);
          while (!done) {
            await _settle(150);
            for (final item in store.chat.toList()) {
              if (item is ApprovalCard && item.decision == Decision.pending) {
                await _settle(600); // let the card be seen
                store.decide(item.id, true);
              }
              if (item is MemoryCard && item.decision == Decision.pending) {
                store.decide(item.id, true);
              }
            }
          }
        }
        await _settle(900);
        final name =
            'L${level.number}_${exp.id}_${exp.baseline ? 'baseline' : side.name}';
        await _capture('${dir.path}/$name.png');
        store.setTab(InspectorTab.checks);
        await _settle(500);
        await _capture('${dir.path}/${name}_checks.png');
      }
    }
  }
  exit(0);
}

Future<void> _settle(int ms) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
  await WidgetsBinding.instance.endOfFrame;
}

Future<void> _capture(String path) async {
  final boundary = screenKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}
