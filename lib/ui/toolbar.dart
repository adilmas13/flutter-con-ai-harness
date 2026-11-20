import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../agent/agent_state.dart';
import '../agent/levels.dart';
import '../config.dart';
import '../stores/app_store.dart';
import 'theme.dart';

/// Above the app window: presenter controls for level and experiment.
class PresenterBar extends StatelessWidget {
  const PresenterBar({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Observer(builder: (_) {
      final exps = store.level.experiments;
      // Two fixed rows, so changing level never moves the level chips or
      // changes the bar's height.
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              for (var i = 0; i < levels.length; i++) ...[
                _Chip(
                  label: levels[i].name,
                  prefix: '${levels[i].number}',
                  selected: i == store.levelIndex,
                  onTap: () => store.selectLevel(i),
                  dark: true,
                ),
                const SizedBox(width: 6),
              ],
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: store.state.isBusy ? null : store.resetForStage,
                icon: const Icon(Icons.replay, size: 16),
                label: const Text('Reset for stage'),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: Row(children: [
                if (exps.length > 1) ...[
                  const Cap('Experiment'),
                  const SizedBox(width: 8),
                  for (var i = 0; i < exps.length; i++) ...[
                    _Chip(
                      label: exps[i].name,
                      selected: i == store.experimentIndex,
                      onTap: () => store.selectExperiment(i),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(store.experiment.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: p.muted)),
                ),
              ]),
            ),
          ],
        ),
      );
    });
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.prefix,
    this.dark = false,
  });
  final String label;
  final String? prefix;
  final bool selected, dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bg = selected ? (dark ? p.fg : p.accent) : p.window;
    final fg = selected ? (dark ? p.window : p.onAccent) : p.fg;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dark ? 8 : 99),
        side: BorderSide(color: selected ? bg : p.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(dark ? 8 : 99),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dark ? 11 : 12, vertical: 6),
          child: Text.rich(TextSpan(children: [
            if (prefix != null)
              TextSpan(
                  text: '$prefix  ',
                  style: TextStyle(
                      fontFamily: monoFamily, fontSize: 12, color: fg.withValues(alpha: .7))),
            TextSpan(text: label, style: TextStyle(fontSize: 14, color: fg)),
          ])),
        ),
      ),
    );
  }
}

/// The app's own toolbar: the harness switch, API key status, inspector.
class AppToolbar extends StatelessWidget {
  const AppToolbar({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Observer(builder: (_) {
      final exp = store.experiment;
      return Container(
        color: p.bar,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Text('Day Planner',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.fg)),
            const SizedBox(width: 16),
            if (exp.baseline)
              _Tag('Baseline · bare model')
            else
              Segmented(
                options: ['Without ${exp.change}', 'With ${exp.change}'],
                selected: store.side == Side.without ? 0 : 1,
                onChanged: (i) => store.selectSide(i == 0 ? Side.without : Side.withPiece),
              ),
            const Spacer(),
            Tooltip(
              message: AppConfig.hasKey ? 'Live calls to ${AppConfig.model}' : 'No API key in .env',
              child: Icon(
                AppConfig.hasKey ? Icons.cloud_done_outlined : Icons.key_off_outlined,
                size: 18,
                color: AppConfig.hasKey ? p.ok : p.crit,
              ),
            ),
            const SizedBox(width: 16),
            ContextRing(
                used: store.contextTokens, budget: AppConfig.contextBudget),
            const SizedBox(width: 12),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: store.inspectorOpen ? p.accent : p.window,
                foregroundColor: store.inspectorOpen ? p.onAccent : p.fg,
                side: BorderSide(color: store.inspectorOpen ? p.accent : p.line),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: store.toggleInspector,
              child: const Text('Inspector'),
            ),
          ],
        ),
      );
    });
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            border: Border.all(color: context.pal.line),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 13, color: context.pal.muted)),
      );
}

class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < options.length; i++)
          Material(
            color: i == selected ? p.fg : p.window,
            child: InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: i > 0 ? Border(left: BorderSide(color: p.line)) : null,
                ),
                child: Text(options[i],
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400,
                        color: i == selected ? p.window : p.fg)),
              ),
            ),
          ),
      ]),
    );
  }
}

class ContextRing extends StatelessWidget {
  const ContextRing({super.key, required this.used, required this.budget});
  final int used, budget;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final f = used / budget;
    final color = f >= 1 ? p.crit : (f >= .7 ? p.warn : p.accent);
    return Tooltip(
      message: '$used of $budget tokens (teaching budget)',
      child: Row(children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CustomPaint(painter: _RingPainter(math.min(f, 1), color, p.line)),
        ),
        const SizedBox(width: 6),
        Text('${(f * 100).round()}% context',
            style: TextStyle(
                fontSize: 12.5,
                color: p.muted,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.f, this.color, this.track);
  final double f;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, paint..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * f, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.f != f || old.color != color;
}
