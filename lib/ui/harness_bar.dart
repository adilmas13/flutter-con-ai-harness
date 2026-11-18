import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../agent/checks.dart';
import '../agent/harness.dart';
import '../agent/levels.dart';
import '../stores/app_store.dart';
import 'theme.dart';

/// Every harness piece, dashed until built, highlighted when this level adds it.
class HarnessBar extends StatelessWidget {
  const HarnessBar({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Observer(builder: (_) {
      final now = store.config;
      final before = store.experiment.config(Side.without);
      final showNew = store.side == Side.withPiece && !store.experiment.baseline;
      final applicable =
          store.checks.where((c) => c.result != CheckResult.notApplicable);
      final passed = applicable.where((c) => c.result == CheckResult.pass).length;
      return Container(
        decoration: BoxDecoration(
          color: p.window,
          border: Border(top: BorderSide(color: p.line), bottom: BorderSide(color: p.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          const Cap('Harness'),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final piece in HarnessPiece.values)
                _PieceChip(
                  piece.label,
                  on: now.has(piece),
                  isNew: showNew && now.has(piece) && !before.has(piece),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Text(
            applicable.isEmpty ? 'Checks –' : 'Checks $passed / ${applicable.length}',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: applicable.isEmpty
                    ? p.faint
                    : (passed == applicable.length ? p.ok : p.crit)),
          ),
        ]),
      );
    });
  }
}

class _PieceChip extends StatelessWidget {
  const _PieceChip(this.label, {required this.on, required this.isNew});
  final String label;
  final bool on, isNew;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bg = isNew ? p.accent : (on ? p.sunk : Colors.transparent);
    final fg = isNew ? p.onAccent : (on ? p.fg : p.faint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isNew ? p.accent : p.line,
          width: on ? 1 : .8,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: isNew ? FontWeight.w600 : FontWeight.w400,
              color: fg,
              decoration: on ? null : TextDecoration.none)),
    );
  }
}
