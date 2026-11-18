import '../agent/tools.dart';
import '../data/schedule.dart';

/// What the chat shows. Immutable: the store replaces an item to update it.
sealed class ChatItem {
  const ChatItem();
}

class UserText extends ChatItem {
  const UserText(this.text, {this.pastedLines = 0});
  final String text;

  /// When the user pasted the schedule: how many lines were pasted.
  final int pastedLines;
}

class AssistantText extends ChatItem {
  const AssistantText(this.text, {this.fromRecording = false});
  final String text;
  final bool fromRecording;
}

/// Written by the app, not the model (for example, after the step limit).
class AppText extends ChatItem {
  const AppText(this.text);
  final String text;
}

class DividerText extends ChatItem {
  const DividerText(this.text);
  final String text;
}

class ErrorText extends ChatItem {
  const ErrorText(this.text);
  final String text;
}

class BudgetError extends ChatItem {
  const BudgetError(this.tokens, this.budget);
  final int tokens;
  final int budget;
}

class PlanCard extends ChatItem {
  const PlanCard(this.sessions, this.unknownIds);
  final List<Session> sessions;
  final List<String> unknownIds;
}

enum CallState { running, ok, rejected, failed, declined }

class ToolCallView {
  const ToolCallView(this.name, this.args, this.state, [this.summary = '']);
  final String name;
  final Map<String, dynamic> args;
  final CallState state;
  final String summary;

  String get signature {
    final a = args.entries.map((e) {
      final v = e.value;
      return '${e.key}: ${v is String ? '"$v"' : v}';
    }).join(', ');
    return '$name($a)';
  }

  ToolCallView finish(ToolOutcome o) => ToolCallView(
        name,
        args,
        switch (o.status) {
          ToolStatus.ok => CallState.ok,
          ToolStatus.rejected || ToolStatus.notAvailable => CallState.rejected,
          ToolStatus.failed => CallState.failed,
          ToolStatus.declined => CallState.declined,
        },
        o.summary,
      );
}

/// Consecutive tool calls in one turn, shown as one collapsible card.
class ToolGroup extends ChatItem {
  const ToolGroup(this.calls, {this.expanded = false});
  final List<ToolCallView> calls;
  final bool expanded;

  ToolGroup copyWith({List<ToolCallView>? calls, bool? expanded}) =>
      ToolGroup(calls ?? this.calls, expanded: expanded ?? this.expanded);
}

enum Decision { pending, yes, no }

class ApprovalCard extends ChatItem {
  const ApprovalCard(this.id, this.tool, this.sessions, this.args, this.decision);
  final int id;
  final String tool;
  final List<Session> sessions;
  final Map<String, dynamic> args;
  final Decision decision;
}

class MemoryCard extends ChatItem {
  const MemoryCard(this.id, this.fact, this.decision);
  final int id;
  final String fact;
  final Decision decision;
}
