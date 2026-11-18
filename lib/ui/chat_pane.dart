import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../agent/agent_state.dart';
import '../stores/app_store.dart';
import 'chat_cards.dart';
import 'theme.dart';

class ChatPane extends StatefulWidget {
  const ChatPane({super.key, required this.store});
  final AppStore store;

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  int _lastCount = 0;

  AppStore get store => widget.store;

  void _send([String? text]) {
    final t = text ?? _input.text;
    if (t.trim().isEmpty) return;
    _input.clear();
    store.send(t);
    _focus.requestFocus();
  }

  void _maybeScroll(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final items = store.chat.toList();
      _maybeScroll(items.length);
      final busy = store.state.isBusy;
      return Column(children: [
        Expanded(
          child: items.isEmpty
              ? _EmptyState(store: store)
              : ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                  itemCount: items.length + (busy ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: i == items.length
                          ? _Working(state: store.state, onCancel: store.cancel)
                          : ChatCard(store: store, index: i, item: items[i]),
                    ),
                  ),
                ),
        ),
        _Composer(
          store: store,
          controller: _input,
          focus: _focus,
          onSend: _send,
        ),
      ]);
    });
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_note_outlined, size: 36, color: p.faint),
          const SizedBox(height: 10),
          Text('Plan your flutterCon day',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.fg)),
          const SizedBox(height: 6),
          Text('Ask about today’s 65 sessions. Use a suggestion below to run this level’s experiment.',
              textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
        ]),
      ),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.state, required this.onCancel});
  final AgentState state;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final text = switch (state) {
      CheckingBudget() => 'Checking the request fits the window…',
      Shrinking(:final how) => '$how…',
      Thinking(:final step) => 'Thinking · step $step',
      CallingTool(:final name) => 'Running $name…',
      AwaitingApproval() => 'Waiting for your approval',
      AwaitingConfirmation() => 'Waiting for you to confirm',
      Idle() || Done() || Stopped() || Blocked() || Failed() => '',
    };
    return Row(children: [
      SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)),
      const SizedBox(width: 10),
      Text(text, style: TextStyle(color: p.muted, fontSize: 13.5)),
      const SizedBox(width: 8),
      TextButton(onPressed: onCancel, child: const Text('Cancel')),
    ]);
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.store,
    required this.controller,
    required this.focus,
    required this.onSend,
  });
  final AppStore store;
  final TextEditingController controller;
  final FocusNode focus;
  final void Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Observer(builder: (_) {
      final busy = store.state.isBusy;
      final inputs = store.experiment.inputs;
      return Container(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final t in inputs)
                      ActionChip(
                        label: Text(t, style: const TextStyle(fontSize: 12.5)),
                        onPressed: busy ? null : () => onSend(t),
                        backgroundColor: p.window,
                        side: BorderSide(color: p.line),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99)),
                      ),
                  ]),
                ),
                if (store.canSave)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilledButton.icon(
                      onPressed: store.saveRun,
                      icon: const Icon(Icons.save_alt, size: 16),
                      label: const Text('Save run'),
                    ),
                  ),
                IconButton(
                  tooltip: 'Start this conversation again',
                  onPressed: busy ? null : store.restart,
                  icon: Icon(Icons.restart_alt, color: p.muted),
                ),
              ]),
              if (store.toast != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Icon(Icons.check_circle, size: 16, color: p.ok),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(store.toast!,
                            style: TextStyle(fontSize: 12.5, color: p.muted))),
                    TextButton(onPressed: store.dismissToast, child: const Text('OK')),
                  ]),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                focusNode: focus,
                enabled: !busy,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Ask about the flutterCon schedule…',
                  filled: true,
                  fillColor: p.window,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: p.line)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: p.line)),
                  suffixIcon: IconButton(
                    onPressed: busy ? null : onSend,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
