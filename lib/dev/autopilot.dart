import 'dart:convert';
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

/// `just stage-run`: the whole talk live, driven the way a presenter clicks.
const autopilotLive = bool.fromEnvironment('AUTOPILOT_LIVE');

/// Stop after this level number (0 = run them all).
const autopilotUntil = int.fromEnvironment('AUTOPILOT_UNTIL');

final screenKey = GlobalKey();

Future<void> runAutopilot(AppStore store) async {
  if (autopilotLive) return _runStage(store);
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

/// The whole talk live as one conversation, driven like a presenter: change
/// level once, then experiment, then side. Screenshots and a transcript go to
/// build/stage/. Costs real model calls.
Future<void> _runStage(AppStore store) async {
  final dir = Directory('${AppConfig.projectDir}/build/stage');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  final runs = <Map<String, dynamic>>[];
  void write() => File('${dir.path}/run.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(runs));
  await _settle(1500);
  try {
    for (var li = 0; li < levels.length; li++) {
      final level = levels[li];
      if (autopilotUntil > 0 && level.number > autopilotUntil) break;
      if (li != store.levelIndex) store.selectLevel(li);
      for (var ei = 0; ei < level.experiments.length; ei++) {
        final exp = level.experiments[ei];
        if (ei != store.experimentIndex) store.selectExperiment(ei);
        for (final side in exp.baseline ? [Side.without] : Side.values) {
          store.selectSide(side);
          if (!store.inspectorOpen) store.toggleInspector();
          store.setTab(InspectorTab.context);
          final name = 'L${level.number}_${exp.id}_${exp.baseline ? 'baseline' : side.name}';
          final shots = <String>[];
          Future<void> shoot(String tag) async {
            await _settle(500);
            await _capture('${dir.path}/${name}_$tag.png');
            shots.add('${name}_$tag.png');
          }

          final run = <String, dynamic>{
            'name': name,
            'level': level.number,
            'levelName': level.name,
            'experiment': exp.name,
            'side': exp.baseline ? 'baseline' : side.name,
            'notes': exp.notes,
            'harness': store.config.pieces.map((p) => p.name).toList(),
            'messagesAtStart': store.conversation.messages.length,
            'memoryAtStart': store.memoryFacts.toList(),
            'turns': <Map<String, dynamic>>[],
          };
          runs.add(run);
          await shoot('before');
          var cards = 0;
          for (final input in exp.inputs) {
            final chatBefore = store.chat.length;
            final sending = store.send(input);
            var done = false;
            sending.then((_) => done = true);
            while (!done) {
              await _settle(150);
              for (final item in store.chat.toList()) {
                final pending = (item is ApprovalCard && item.decision == Decision.pending) ||
                    (item is MemoryCard && item.decision == Decision.pending);
                if (!pending) continue;
                if (cards++ < 2) await shoot('card$cards');
                store.decide(item is ApprovalCard ? item.id : (item as MemoryCard).id, true);
              }
            }
            (run['turns'] as List).add({
              'input': input,
              'state': store.state.runtimeType.toString(),
              'chat': [for (final item in store.chat.skip(chatBefore)) _describe(item)],
              'trace': [
                for (final e in store.trace)
                  '${e.kind.name} · ${e.label} · ${e.durMs}ms${e.note == null ? '' : ' · ${e.note}'}'
              ],
              'sections': [
                for (final s in store.lastRequest?.sections ?? const [])
                  '${s.dropped ? '(dropped) ' : ''}${s.label} ≈${s.tokens}'
              ],
              'tokens': store.contextTokens,
              'checks': [
                for (final c in store.checks)
                  '${c.def.number} ${c.def.name}: ${c.result.name} · ${c.detail}'
              ],
              'memory': store.memoryFacts.toList(),
              'calendar': store.calendar.map((s) => s.title).toList(),
              'exports': store.exports.toList(),
            });
            write();
          }
          await shoot('context');
          store.setTab(InspectorTab.trace);
          await shoot('trace');
          if (li == 4) {
            store.setTab(InspectorTab.memory);
            await shoot('memory');
          }
          store.setTab(InspectorTab.checks);
          await shoot('checks');
          run['shots'] = shots;
          write();
        }
      }
    }
  } catch (e, st) {
    File('${dir.path}/error.txt').writeAsStringSync('$e\n$st');
    exit(1);
  }
  exit(0);
}

String _describe(ChatItem item) => switch (item) {
      UserText(:final text) => 'USER: $text',
      AssistantText(:final text, :final interim) => '${interim ? 'ASSISTANT (interim)' : 'ASSISTANT'}: $text',
      AppText(:final text) => 'APP: $text',
      DividerText(:final text) => '--- $text ---',
      ErrorText(:final text) => 'ERROR: $text',
      BudgetError(:final tokens, :final budget) => 'BUDGET ERROR: $tokens tokens, limit $budget',
      PlanCard(:final sessions, :final unknownIds) =>
        'PLAN CARD: ${sessions.map((s) => '${s.start}-${s.end} ${s.title} (${s.room}${s.isRoundtable ? ', roundtable' : ''})').join(' | ')}'
            '${unknownIds.isEmpty ? '' : ' | UNKNOWN: ${unknownIds.join(', ')}'}',
      ToolGroup(:final calls) =>
        'TOOLS: ${calls.map((c) => '${c.signature} -> ${c.state.name}: ${c.summary}').join(' || ')}',
      ApprovalCard(:final tool, :final sessions, :final decision) =>
        'APPROVAL CARD ($tool, ${decision.name}): ${sessions.map((s) => s.title).join(' | ')}',
      MemoryCard(:final fact, :final decision) => 'MEMORY CARD (${decision.name}): $fact',
    };
