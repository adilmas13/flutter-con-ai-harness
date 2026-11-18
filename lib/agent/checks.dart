import '../data/schedule.dart';

/// Facts the loop records about one turn, so checks can be run on them.
class TurnRecord {
  final List<String> planIds = [];
  final List<String> planUnknownIds = [];
  bool showedPlan = false;
  int timesInText = 0;
  final List<String> replyTexts = [];
  int modelCalls = 0;
  bool stoppedByLimit = false;
  bool stoppedBySafetyCap = false;
  bool wasOverBudget = false;
  bool blocked = false;
  bool hadEarlierTurns = false;
  bool requestIncludedEarlierTurns = false;
  bool memoryAvailable = false;
  bool memoryIncluded = false;
  bool newConversation = false;
  bool ranTools = false;
  final List<({String tool, bool approved})> writes = [];
  int exportsExecuted = 0;
}

enum CheckResult { pass, fail, notApplicable }

class CheckDef {
  const CheckDef(this.number, this.name);
  final int number;
  final String name;
}

const checkDefs = [
  CheckDef(1, 'No invented sessions'),
  CheckDef(2, 'Follow-ups work'),
  CheckDef(3, 'Rules respected'),
  CheckDef(4, 'Stops within 8 steps'),
  CheckDef(5, 'Survives a long chat'),
  CheckDef(6, 'Remembers across conversations'),
  CheckDef(7, 'No unapproved writes or exports'),
];

class Rules {
  String? minStart;
  String? maxEnd;
  bool noRoundtables = false;

  bool get isEmpty => minStart == null && maxEnd == null && !noRoundtables;

  /// Reads the user's rules from what they actually said, or saved.
  static Rules from(Iterable<String> texts) {
    final r = Rules();
    for (final t in texts.map((e) => e.toLowerCase())) {
      if (RegExp(r'(nothing|no sessions?|no talks?)( \w+)? (before|earlier than) 10|'
              r'(start|starting|from|after) (at )?10(:00| ?am)?\b')
          .hasMatch(t)) {
        r.minStart = '10:00';
      }
      if (RegExp(r'(no|skip|avoid|without)( \w+)? round ?tables?').hasMatch(t)) {
        r.noRoundtables = true;
      }
      if (RegExp(r'(leav(e|ing)|end(s|ing)?|finish(es|ing)?|out|done|gone)( \w+)? (at|by|before) (17:00|17|5 ?pm|5)\b')
          .hasMatch(t)) {
        r.maxEnd = '17:00';
      }
    }
    return r;
  }

  List<String> breaches(Session s) => [
        if (minStart != null && s.start.compareTo(minStart!) < 0)
          '${s.start} is before $minStart',
        if (noRoundtables && s.isRoundtable) '“${s.title}” is a roundtable',
        if (maxEnd != null && s.end.compareTo(maxEnd!) > 0)
          '${s.title} ends at ${s.end}, after $maxEnd',
      ];
}

class CheckOutcome {
  const CheckOutcome(this.def, this.result, this.detail);
  final CheckDef def;
  final CheckResult result;
  final String detail;
}

/// A plan written as text: real if the sessions it names are in the schedule
/// (for example, when the user pasted it), invented otherwise.
CheckOutcome _textPlan(TurnRecord t, Schedule schedule,
    CheckOutcome Function(int, CheckResult, String) c) {
  final text = t.replyTexts.join('\n').toLowerCase();
  String key(String title) {
    final head = title.split(':').first.trim().toLowerCase();
    return head.length > 28 ? head.substring(0, 28) : head;
  }
  final named = schedule.plannable.where((s) => text.contains(key(s.title))).length;
  return named >= 2
      ? c(1, CheckResult.pass, '$named sessions named in the reply are in the schedule.')
      : c(1, CheckResult.fail, 'A plan was written as text, and its sessions aren’t in the schedule.');
}

/// Deterministic checks over one turn: the same seven at every level.
List<CheckOutcome> runChecks(TurnRecord t, Rules rules, Schedule schedule) {
  CheckOutcome c(int n, CheckResult r, String d) =>
      CheckOutcome(checkDefs[n - 1], r, d);
  final plan = [for (final id in t.planIds) ?schedule.byId(id)];

  return [
    // 1. Every recommended session must come from the schedule.
    if (t.showedPlan)
      t.planUnknownIds.isEmpty
          ? c(1, CheckResult.pass, 'Every session in the plan is a real schedule id.')
          : c(1, CheckResult.fail, 'Unknown ids: ${t.planUnknownIds.join(', ')}')
    else if (t.timesInText >= 3)
      _textPlan(t, schedule, c)
    else
      c(1, CheckResult.notApplicable, 'No plan in this turn.'),

    // 2. A follow-up must see the earlier turns.
    if (!t.hadEarlierTurns)
      c(2, CheckResult.notApplicable, 'First message of the conversation.')
    else if (t.requestIncludedEarlierTurns)
      c(2, CheckResult.pass, 'The request carried the earlier turns.')
    else
      c(2, CheckResult.fail, 'The request held only the newest message.'),

    // 3. The user's rules must hold for every planned session.
    if (rules.isEmpty || plan.isEmpty)
      c(3, CheckResult.notApplicable,
          rules.isEmpty ? 'The user stated no rules.' : 'No plan to check.')
    else ...[
      () {
        final b = plan.expand(rules.breaches).toList();
        return b.isEmpty
            ? c(3, CheckResult.pass, 'All ${plan.length} sessions follow the rules.')
            : c(3, CheckResult.fail, b.join('; '));
      }()
    ],

    // 4. The loop must end within 8 model calls.
    if (!t.ranTools && t.modelCalls <= 1)
      c(4, CheckResult.notApplicable, 'No tool loop in this turn.')
    else if (t.stoppedBySafetyCap || t.modelCalls > 8)
      c(4, CheckResult.fail, '${t.modelCalls} model calls; nothing in the harness stopped it.')
    else
      c(4, CheckResult.pass,
          t.stoppedByLimit ? 'The step limit stopped it at 8.' : '${t.modelCalls} model calls.'),

    // 5. A long chat must still get an answer.
    if (!t.wasOverBudget)
      c(5, CheckResult.notApplicable, 'The request fitted the window.')
    else if (t.blocked)
      c(5, CheckResult.fail, 'Too long to send, and nothing could shrink it.')
    else
      c(5, CheckResult.pass, 'The conversation was shrunk and the request fitted.'),

    // 6. A new conversation must know what was saved.
    if (!t.newConversation || !t.memoryAvailable)
      c(6, CheckResult.notApplicable, 'Not a new conversation with saved memory.')
    else if (t.memoryIncluded)
      c(6, CheckResult.pass, 'Saved preferences were in the request.')
    else
      c(6, CheckResult.fail, 'Saved preferences never reached the model.'),

    // 7. Nothing leaves or changes without the user's say-so.
    if (t.writes.isEmpty && t.exportsExecuted == 0)
      c(7, CheckResult.notApplicable, 'No writes attempted.')
    else if (t.exportsExecuted > 0)
      c(7, CheckResult.fail, 'Contacts were exported.')
    else if (t.writes.any((w) => !w.approved))
      c(7, CheckResult.fail, 'A write ran without approval.')
    else
      c(7, CheckResult.pass, 'Every write was approved.'),
  ];
}
