import 'package:flutter/material.dart';

import '../data/schedule.dart';
import '../stores/app_store.dart';
import '../stores/chat_items.dart';
import 'theme.dart';

/// One chat item. The switch is exhaustive: a new item type won't compile
/// until it has a widget.
class ChatCard extends StatelessWidget {
  const ChatCard({super.key, required this.store, required this.index, required this.item});
  final AppStore store;
  final int index;
  final ChatItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return switch (item) {
      UserText(:final text) => Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
                color: p.userBubble, borderRadius: BorderRadius.circular(16)),
            child: SelectableText(text, style: const TextStyle(fontSize: 15.5)),
          ),
        ),
      AssistantText(:final text, :final fromRecording) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(text, style: const TextStyle(fontSize: 15.5, height: 1.5)),
            if (fromRecording)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Replayed from a saved run',
                    style: TextStyle(fontSize: 12, color: p.muted)),
              ),
          ],
        ),
      AppText(:final text) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 15.5, height: 1.5)),
            Text('Sent by the app, not the model',
                style: TextStyle(fontSize: 12, color: p.muted)),
          ],
        ),
      DividerText(:final text) => Row(children: [
          Expanded(child: Divider(color: p.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(text, style: TextStyle(fontSize: 12.5, color: p.faint)),
          ),
          Expanded(child: Divider(color: p.line)),
        ]),
      ErrorText(:final text) => _Notice(text: text, color: p.crit, bg: p.critBg),
      BudgetError(:final tokens, :final budget) =>
        _BudgetCard(tokens: tokens, budget: budget),
      PlanCard(:final sessions, :final unknownIds) =>
        _PlanCard(store: store, sessions: sessions, unknownIds: unknownIds),
      ToolGroup() => _ToolCard(store: store, index: index, group: item as ToolGroup),
      ApprovalCard() => _ApprovalCard(store: store, card: item as ApprovalCard),
      MemoryCard() => _MemoryCard(store: store, card: item as MemoryCard),
    };
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color, required this.bg});
  final String text;
  final Color color, bg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: color.withValues(alpha: .5)),
            borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: color, fontSize: 14)),
      );
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.tokens, required this.budget});
  final int tokens, budget;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final at = budget / tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.critBg,
        border: Border.all(color: p.crit),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 14,
            backgroundColor: p.crit,
            child: Text('!', style: TextStyle(color: p.window, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('This conversation is too long to send',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
                'The request needs $tokens tokens, and the window allows $budget. '
                'Nothing in this harness can shrink a conversation yet.',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (_, c) {
              return Stack(clipBehavior: Clip.none, children: [
                Container(
                    height: 10,
                    decoration: BoxDecoration(
                        color: p.crit, borderRadius: BorderRadius.circular(5))),
                Positioned(
                  left: c.maxWidth * at - 1,
                  top: -3,
                  bottom: -3,
                  child: Container(width: 2, color: p.fg),
                ),
              ]);
            }),
            const SizedBox(height: 4),
            LayoutBuilder(builder: (_, c) {
              return SizedBox(
                height: 16,
                child: Stack(children: [
                  Text('0', style: TextStyle(fontSize: 12, color: p.muted)),
                  Positioned(
                    right: c.maxWidth * (1 - at) + 4,
                    child: Text('limit $budget',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: p.fg)),
                  ),
                  Positioned(
                      right: 0,
                      child: Text('$tokens',
                          style: TextStyle(fontSize: 12, color: p.muted))),
                ]),
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.store, required this.sessions, required this.unknownIds});
  final AppStore store;
  final List<Session> sessions;
  final List<String> unknownIds;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rules = store.rules;
    Widget row(String time, String title, String sub, List<String> problems) {
      final bad = problems.isNotEmpty;
      return Container(
        color: bad ? p.critBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 52,
              child: Text(time,
                  style: TextStyle(fontFamily: monoFamily, fontSize: 13, color: p.muted))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14.5,
                      color: bad ? p.crit : p.fg)),
              Text(sub, style: TextStyle(fontSize: 12.5, color: p.muted)),
              for (final pr in problems)
                Text('Breaks a rule: $pr',
                    style: TextStyle(fontSize: 12, color: p.crit)),
            ]),
          ),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: p.line), borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final s in sessions) ...[
          row(s.start, s.title,
              '${s.room} · until ${s.end}${s.speakers.isEmpty ? '' : ' · ${s.speakers.join(', ')}'}',
              rules.breaches(s)),
          Divider(height: 1, color: p.line),
        ],
        for (final id in unknownIds)
          row('?', 'Unknown session “$id”', 'Not in the schedule', const ['invented']),
      ]),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.store, required this.index, required this.group});
  final AppStore store;
  final int index;
  final ToolGroup group;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final calls = group.calls;
    final counts = <String>[
      '${calls.length} ${calls.length == 1 ? 'step' : 'steps'}',
      for (final (s, w) in [
        (CallState.rejected, 'rejected'),
        (CallState.failed, 'failed'),
        (CallState.declined, 'declined'),
      ])
        if (calls.where((c) => c.state == s).length case final n when n > 0) '$n $w',
    ];
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: p.line), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => store.toggleToolGroup(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              AnimatedRotation(
                turns: group.expanded ? .25 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.chevron_right, size: 18, color: p.muted),
              ),
              const SizedBox(width: 6),
              const Expanded(
                  child: Text('Used the planner’s tools', style: TextStyle(fontSize: 14))),
              Text(counts.join(' · '), style: TextStyle(fontSize: 13, color: p.muted)),
            ]),
          ),
        ),
        if (group.expanded)
          for (final c in calls)
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _StatusDot(c.state),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SelectableText(c.signature,
                        style: const TextStyle(fontFamily: monoFamily, fontSize: 12.5)),
                    if (c.summary.isNotEmpty)
                      Text(c.summary,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: c.state == CallState.ok ? p.muted : p.crit)),
                  ]),
                ),
              ]),
            ),
      ]),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.state);
  final CallState state;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (color, glyph) = switch (state) {
      CallState.running => (p.warn, '…'),
      CallState.ok => (p.ok, '✓'),
      CallState.rejected => (p.crit, '✕'),
      CallState.failed => (p.crit, '!'),
      CallState.declined => (p.muted, '–'),
    };
    return Container(
      width: 17,
      height: 17,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(glyph,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.window)),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.store, required this.card});
  final AppStore store;
  final ApprovalCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (card.decision == Decision.no) {
      return _Dashed('You didn’t allow this, so nothing was changed.');
    }
    final isCalendar = card.tool == 'addToCalendar';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: p.warn),
        borderRadius: BorderRadius.circular(12),
        color: p.window,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill('WRITES', fg: p.warn, bg: p.warnBg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                isCalendar
                    ? 'Add ${card.sessions.length} events to your calendar?'
                    : 'Allow ${card.tool}?',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
        ]),
        const SizedBox(height: 10),
        if (isCalendar)
          for (final s in card.sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                      border: Border.all(color: p.line),
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Text('NOV',
                        style: TextStyle(
                            fontSize: 9.5, fontWeight: FontWeight.w700, color: p.crit)),
                    const Text('21',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    Text('${s.start}–${s.end} · ${s.room}',
                        style: TextStyle(fontSize: 12.5, color: p.muted)),
                  ]),
                ),
              ]),
            )
        else
          Text('${card.args}', style: const TextStyle(fontFamily: monoFamily, fontSize: 12.5)),
        if (isCalendar)
          Text('Calendar: Personal · Reminder 10 minutes before',
              style: TextStyle(fontSize: 12.5, color: p.muted)),
        const SizedBox(height: 10),
        if (card.decision == Decision.pending)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
                onPressed: () => store.decide(card.id, false),
                child: const Text('Don’t allow')),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: () => store.decide(card.id, true),
                child: Text(isCalendar ? 'Add events' : 'Allow')),
          ])
        else
          Text('Approved', style: TextStyle(color: p.ok, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.store, required this.card});
  final AppStore store;
  final MemoryCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (card.decision == Decision.no) {
      return _Dashed('Not saved. “${card.fact}” applies to this conversation only.');
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          border: Border.all(color: p.line), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill('MEMORY', fg: p.memory, bg: p.sunk),
          const SizedBox(width: 8),
          Text(
              card.decision == Decision.pending
                  ? 'Remember this for later conversations?'
                  : 'Saved to memory',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        ]),
        const SizedBox(height: 8),
        Text('“${card.fact}”', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 8),
        if (card.decision == Decision.pending)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
                onPressed: () => store.decide(card.id, false), child: const Text('Not now')),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: () => store.decide(card.id, true), child: const Text('Remember')),
          ])
        else
          Text('✓ Available in every new conversation',
              style: TextStyle(color: p.ok, fontWeight: FontWeight.w600, fontSize: 13.5)),
      ]),
    );
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            border: Border.all(color: context.pal.line),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: context.pal.muted, fontSize: 14)),
      );
}
