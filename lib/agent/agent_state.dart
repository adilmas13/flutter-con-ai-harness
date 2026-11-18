/// Where the loop is. The model is unpredictable; this is not.
/// Adding a state forces every `switch` over it (UI included) to handle it.
sealed class AgentState {
  const AgentState();
}

class Idle extends AgentState {
  const Idle();
}

class CheckingBudget extends AgentState {
  const CheckingBudget();
}

class Shrinking extends AgentState {
  const Shrinking(this.how);
  final String how;
}

class Thinking extends AgentState {
  const Thinking(this.step);
  final int step;
}

class CallingTool extends AgentState {
  const CallingTool(this.name);
  final String name;
}

class AwaitingApproval extends AgentState {
  const AwaitingApproval(this.tool);
  final String tool;
}

class AwaitingConfirmation extends AgentState {
  const AwaitingConfirmation(this.fact);
  final String fact;
}

class Done extends AgentState {
  const Done();
}

class Stopped extends AgentState {
  const Stopped(this.reason);
  final String reason;
}

class Blocked extends AgentState {
  const Blocked(this.tokens);
  final int tokens;
}

class Failed extends AgentState {
  const Failed(this.message);
  final String message;
}

extension AgentStateLabel on AgentState {
  String get label => switch (this) {
        Idle() => 'Idle',
        CheckingBudget() => 'CheckingBudget',
        Shrinking() => 'Shrinking',
        Thinking() => 'Thinking',
        CallingTool() => 'CallingTool',
        AwaitingApproval() => 'AwaitingApproval',
        AwaitingConfirmation() => 'AwaitingConfirmation',
        Done() => 'Done',
        Stopped() => 'Stopped',
        Blocked() => 'Blocked',
        Failed() => 'Failed',
      };

  bool get isBusy => switch (this) {
        Idle() || Done() || Stopped() || Blocked() || Failed() => false,
        _ => true,
      };
}
