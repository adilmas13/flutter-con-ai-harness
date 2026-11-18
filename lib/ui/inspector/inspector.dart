import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../agent/agent_loop.dart';
import '../../agent/agent_state.dart';
import '../../agent/checks.dart';
import '../../agent/context_builder.dart';
import '../../agent/harness.dart';
import '../../config.dart';
import '../../stores/app_store.dart';
import '../theme.dart';

class Inspector extends StatelessWidget {
  const Inspector({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Observer(builder: (_) {
      final showMemory = store.config.has(HarnessPiece.memory) ||
          store.otherConfig.has(HarnessPiece.memory) ||
          store.experiment.calendarTools;
      final tabs = [
        (InspectorTab.context, 'Context'),
        (InspectorTab.trace, 'Trace'),
        if (showMemory) (InspectorTab.memory, 'Memory'),
        (InspectorTab.checks, 'Checks'),
      ];
      final tab = tabs.any((t) => t.$1 == store.inspectorTab)
          ? store.inspectorTab
          : InspectorTab.context;
      return Container(
        decoration: BoxDecoration(
          color: p.bar,
          border: Border(left: BorderSide(color: p.line)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
            child: Row(children: [
              const Cap('Inspector'),
              const SizedBox(width: 10),
              for (final (t, label) in tabs)
                InkWell(
                  onTap: () => store.setTab(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: t == tab ? p.accent : Colors.transparent, width: 2)),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: t == tab ? p.fg : p.muted)),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: switch (tab) {
              InspectorTab.context => _ContextTab(store: store),
              InspectorTab.trace => _TraceTab(store: store),
              InspectorTab.memory => _MemoryTab(store: store),
              InspectorTab.checks => _ChecksTab(store: store),
            },
          ),
        ]),
      );
    });
  }
}

class _ContextTab extends StatefulWidget {
  const _ContextTab({required this.store});
  final AppStore store;
  @override
  State<_ContextTab> createState() => _ContextTabState();
}

class _ContextTabState extends State<_ContextTab> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final store = widget.store;
    return Observer(builder: (_) {
      final req = store.lastRequest;
      if (req == null) return const SizedBox();
      final live = req.sections.where((s) => !s.dropped).toList();
      final total = store.contextTokens;
      final exact = store.lastExactTokens != null;
      final byKind = <SectionKind, int>{};
      for (final s in live) {
        byKind[s.kind] = (byKind[s.kind] ?? 0) + s.tokens;
      }
      final estTotal = byKind.values.fold(0, (a, b) => a + b);
      final scale = total > AppConfig.contextBudget ? total : AppConfig.contextBudget;
      final over = total > AppConfig.contextBudget;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('$total',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('of ${AppConfig.contextBudget} tokens${exact ? '' : ' (estimate)'}',
              style: TextStyle(color: p.muted)),
          const Spacer(),
          over
              ? Text('Over the limit',
                  style: TextStyle(color: p.crit, fontWeight: FontWeight.w600))
              : Cap('${(total / AppConfig.contextBudget * 100).round()}% used'),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 16,
            color: p.sunk,
            child: Row(children: [
              for (final k in SectionKind.values)
                if ((byKind[k] ?? 0) > 0)
                  Expanded(
                    flex: ((byKind[k]! / (estTotal == 0 ? 1 : estTotal)) * total / scale * 1000)
                        .round()
                        .clamp(1, 1000),
                    child: Container(color: p.section(k)),
                  ),
              Expanded(
                flex: ((1 - total / scale) * 1000).round().clamp(0, 1000),
                child: const SizedBox(),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          for (final k in SectionKind.values)
            if ((byKind[k] ?? 0) > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: p.section(k), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 5),
                Text('${_kindLabel(k)} ≈${byKind[k]}',
                    style: TextStyle(fontSize: 12.5, color: p.muted)),
              ]),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          const Cap('The request'),
          const Spacer(),
          Text('Raw JSON', style: TextStyle(fontSize: 13, color: p.muted)),
          Switch(value: store.showRawJson, onChanged: store.setRawJson),
        ]),
        const SizedBox(height: 6),
        if (store.showRawJson)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: p.window,
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(8)),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(_redacted(req.request.body)),
              style: const TextStyle(fontFamily: monoFamily, fontSize: 11.5),
            ),
          )
        else
          for (var i = 0; i < req.sections.length; i++) ...[
            _SectionRow(
              section: req.sections[i],
              open: _open == i,
              onTap: () => setState(() => _open = _open == i ? null : i),
            ),
            const SizedBox(height: 5),
          ],
      ]);
    });
  }

  static String _kindLabel(SectionKind k) => switch (k) {
        SectionKind.instructions => 'Instructions',
        SectionKind.memory => 'Memory',
        SectionKind.summary => 'Summary',
        SectionKind.conversation => 'Conversation',
        SectionKind.toolResults => 'Tool results',
      };

  /// Long tool lists and messages are shortened for display only.
  static Object? _redacted(Object? v) {
    if (v is Map) return v.map((k, e) => MapEntry(k, _redacted(e)));
    if (v is List) {
      if (v.length > 40) return [...v.take(40).map(_redacted), '… ${v.length - 40} more'];
      return v.map(_redacted).toList();
    }
    if (v is String && v.length > 1200) return '${v.substring(0, 1200)}… (${v.length} chars)';
    return v;
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section, required this.open, required this.onTap});
  final RequestSection section;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = section;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Material(
        color: p.window,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: p.line), borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Opacity(
            opacity: s.dropped ? .55 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: p.section(s.kind), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(s.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          decoration: s.dropped ? TextDecoration.lineThrough : null)),
                ),
                Text('${s.dropped ? 'dropped · ' : ''}≈${s.tokens}',
                    style: TextStyle(fontFamily: monoFamily, fontSize: 12, color: p.muted)),
              ]),
            ),
          ),
        ),
      ),
      if (open)
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
              color: p.window,
              border: Border(left: BorderSide(color: p.section(s.kind), width: 4)),
              borderRadius: BorderRadius.circular(6)),
          child: SingleChildScrollView(
            child: SelectableText(s.text,
                style: const TextStyle(fontFamily: monoFamily, fontSize: 12, height: 1.5)),
          ),
        ),
    ]);
  }
}

class _TraceTab extends StatelessWidget {
  const _TraceTab({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Observer(builder: (_) {
      final events = store.trace.toList();
      final steps = events.where((e) => e.kind == TraceKind.model).length;
      final limited = store.config.has(HarnessPiece.stepLimit);
      final end = events.fold<int>(1, (a, e) => e.startMs + e.durMs > a ? e.startMs + e.durMs : a);
      Color col(TraceKind k) => switch (k) {
            TraceKind.model => p.conversation,
            TraceKind.summary => p.summary,
            TraceKind.tool => p.toolResults,
            TraceKind.failed || TraceKind.limit => p.crit,
            TraceKind.wait => p.warn,
          };
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Text('Loop state', style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: p.window,
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(6)),
            child: Text(store.state.label,
                style: const TextStyle(fontFamily: monoFamily, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Text('step $steps ${limited ? 'of ${AppConfig.stepLimit}' : '· no limit'}',
              style: TextStyle(color: p.muted, fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        if (events.isEmpty)
          Text('Nothing has run yet.', style: TextStyle(color: p.muted)),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                SizedBox(
                  width: 150,
                  child: Text(e.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: e.kind == TraceKind.model ? null : monoFamily)),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (_, c) {
                    final w = (e.durMs / end * c.maxWidth).clamp(3.0, c.maxWidth);
                    final l = (e.startMs / end * c.maxWidth).clamp(0.0, c.maxWidth - w);
                    return Container(
                      height: 14,
                      decoration: BoxDecoration(
                          color: p.sunk, borderRadius: BorderRadius.circular(4)),
                      child: Stack(children: [
                        Positioned(
                          left: l,
                          width: w,
                          top: 0,
                          bottom: 0,
                          child: Container(
                              decoration: BoxDecoration(
                                  color: col(e.kind),
                                  borderRadius: BorderRadius.circular(4))),
                        ),
                      ]),
                    );
                  }),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                      e.durMs >= 1000 ? '${(e.durMs / 1000).toStringAsFixed(1)}s' : '${e.durMs}ms',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: monoFamily, fontSize: 12, color: p.muted)),
                ),
              ]),
              if (e.note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(e.note!,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: switch (e.kind) {
                            TraceKind.failed || TraceKind.limit => p.crit,
                            TraceKind.wait => p.warn,
                            _ => p.muted,
                          })),
                ),
            ]),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, children: [
          for (final (k, l) in [
            (TraceKind.model, 'Model call'),
            (TraceKind.tool, 'Tool ran'),
            (TraceKind.wait, 'Waiting'),
            (TraceKind.failed, 'Rejected or failed'),
          ])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, color: col(k)),
              const SizedBox(width: 5),
              Text(l, style: TextStyle(fontSize: 12.5, color: p.muted)),
            ]),
        ]),
      ]);
    });
  }
}

class _MemoryTab extends StatelessWidget {
  const _MemoryTab({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget item(String title, [String? sub, Widget? trailing]) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: p.window,
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                if (sub != null) Text(sub, style: TextStyle(fontSize: 12.5, color: p.muted)),
              ]),
            ),
            ?trailing,
          ]),
        );
    Widget empty(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: TextStyle(color: p.muted, fontSize: 13.5)));

    return Observer(builder: (_) {
      final memOn = store.config.has(HarnessPiece.memory);
      final stateOn = store.config.has(HarnessPiece.appState);
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Cap('Memory · kept across conversations'),
          const Spacer(),
          TextButton(onPressed: store.resetMemory, child: const Text('Reset all')),
        ]),
        if (!memOn)
          empty('This harness has no memory: nothing below reaches the model.'),
        if (store.memoryFacts.isEmpty) empty('Nothing saved.'),
        for (final f in store.memoryFacts)
          item(f, null, Pill('Saved', fg: p.ok, bg: p.okBg)),
        const SizedBox(height: 12),
        const Cap('Task state · today’s plan, held by the app'),
        const SizedBox(height: 6),
        if (!stateOn) empty('This harness keeps no plan between conversations.'),
        if (store.itinerary.isEmpty) empty('No plan saved.'),
        for (final id in store.itinerary)
          if (store.schedule.byId(id) case final s?)
            item('${s.start} ${s.title}', '${s.room} · until ${s.end}'),
        if (store.calendar.isNotEmpty || store.experiment.calendarTools) ...[
          const SizedBox(height: 12),
          const Cap('Calendar'),
          const SizedBox(height: 6),
          if (store.calendar.isEmpty) empty('No events.'),
          for (final s in store.calendar) item('${s.start} ${s.title}', s.room),
        ],
        if (store.exports.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Cap('Data sent out of the app'),
          const SizedBox(height: 6),
          for (final e in store.exports)
            item(e, 'Triggered by an instruction hidden in a session description',
                Pill('Leaked', fg: p.crit, bg: p.critBg)),
        ],
      ]);
    });
  }
}

class _ChecksTab extends StatelessWidget {
  const _ChecksTab({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Observer(builder: (_) {
      final checks = store.checks;
      if (checks.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
              store.state is Idle
                  ? 'Send a message. The same seven checks run after every turn.'
                  : 'Checks run when the turn finishes.',
              style: TextStyle(color: p.muted)),
        );
      }
      final applicable = checks.where((c) => c.result != CheckResult.notApplicable);
      final passed = applicable.where((c) => c.result == CheckResult.pass).length;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('$passed', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('of ${applicable.length} applicable checks pass',
              style: TextStyle(color: p.muted)),
        ]),
        const SizedBox(height: 6),
        const Cap('The same 7 checks run at every level'),
        const SizedBox(height: 10),
        for (final c in checks)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
                color: p.window,
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(8)),
            child: Opacity(
              opacity: c.result == CheckResult.notApplicable ? .5 : 1,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (c.result) {
                      CheckResult.pass => p.ok,
                      CheckResult.fail => p.crit,
                      CheckResult.notApplicable => p.faint,
                    },
                  ),
                  child: Text(
                      switch (c.result) {
                        CheckResult.pass => '✓',
                        CheckResult.fail => '✕',
                        CheckResult.notApplicable => '–',
                      },
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: p.window)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c.def.number}. ${c.def.name}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(c.detail, style: TextStyle(fontSize: 12.5, color: p.muted)),
                  ]),
                ),
              ]),
            ),
          ),
      ]);
    });
  }
}
