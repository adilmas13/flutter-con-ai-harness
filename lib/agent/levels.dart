import 'harness.dart';

enum Seed { none, longChat, demoPlan }

/// Placeholder in a suggested input, replaced by the compact schedule
/// (`assets/schedule_paste.txt`) when sent.
const pasteSchedule = '{schedule}';

enum Side { without, withPiece }

/// One before-and-after experiment: the same input, run on two harnesses.
class Experiment {
  const Experiment({
    required this.id,
    required this.name,
    required this.change,
    required this.inputs,
    required this.without,
    required this.withPiece,
    this.seed = Seed.none,
    this.calendarTools = false,
    this.baseline = false,
    this.notes = '',
  });

  final String id;
  final String name;

  /// Shown on the toggle: `Without {change}` and `With {change}`.
  final String change;

  /// Suggested messages, in the order to send them.
  final List<String> inputs;
  final HarnessConfig without;
  final HarnessConfig withPiece;
  final Seed seed;

  /// Level 6: the calendar (and, without least privilege, contacts) tools.
  final bool calendarTools;

  /// Level 1 has only one run.
  final bool baseline;
  final String notes;

  HarnessConfig config(Side side) =>
      baseline || side == Side.without ? without : withPiece;
}

class Level {
  const Level(this.number, this.name, this.takeaway, this.experiments);
  final int number;
  final String name;
  final String takeaway;
  final List<Experiment> experiments;
}

final levels = <Level>[
  Level(1, 'The call',
      'The model knows nothing about your app and remembers nothing between calls.',
      [
        Experiment(
          id: 'baseline',
          name: 'Baseline',
          change: 'nothing',
          baseline: true,
          inputs: const [
            'Hi, how are you?',
            'I’m going to attend flutterCon 2026.',
            'Tell me more about this event.',
          ],
          without: Harnesses.h1,
          withPiece: Harnesses.h1,
          notes: 'Every call is stateless: by the third message it no longer knows which event you mean.',
        ),
      ]),
  Level(2, 'History and context',
      'The model’s memory is whatever you send it this turn, and you choose what that is.',
      [
        Experiment(
          id: 'follow-up',
          name: 'Follow-up',
          change: 'history',
          inputs: const [
            'Tell me more about this event.',
          ],
          without: Harnesses.h1,
          withPiece: Harnesses.h2,
          notes: 'Send it on each side. Without history it doesn’t know which event. With history it does, but it has no agenda to give details from.',
        ),
      ]),
  Level(3, 'Tools and the loop',
      'The model never does anything. It asks, and your code decides and acts.',
      [
        Experiment(
          id: 'plan',
          name: 'Plan request',
          change: 'tools',
          inputs: const [
            'Plan my day there around AI talks, and show me my plan.',
          ],
          without: Harnesses.h2,
          withPiece: Harnesses.h3NoLimit,
          notes: 'Continues from level 2. Without tools it still has no agenda; with tools it searches the schedule and shows a real plan.',
        ),
        Experiment(
          id: 'vague',
          name: 'Vague request',
          change: 'a step limit',
          inputs: const [
            'Which is the single best AI talk today? Read the full details of every AI talk, one at a time, before you decide.'
          ],
          without: Harnesses.h3NoLimit,
          withPiece: Harnesses.h3,
          notes:
              'Without the limit, a safety cap of 16 calls (not part of the harness) stops runaway spend.',
        ),
      ]),
  Level(4, 'When the window fills',
      'A long conversation has to be shrunk, and every way of shrinking it loses something.',
      [
        Experiment(
          id: 'summarise',
          name: 'Summarise old turns',
          change: 'summarising',
          seed: Seed.longChat,
          notes: 'Without: the request is over the 8k window, so nothing is sent. With: old turns become a short summary.',
          inputs: const ['What should I end the day with?'],
          without: Harnesses.h3,
          withPiece: Harnesses.h4Summarise,
        ),
        Experiment(
          id: 'remove',
          name: 'Remove old turns',
          change: 'removing old turns',
          seed: Seed.longChat,
          notes: 'With: the turns holding the rules were dropped, so it “corrects” answers it can’t see and picks a talk ending 18:15. That’s why check 3 fails.',
          inputs: const ['What should I end the day with?'],
          without: Harnesses.h3,
          withPiece: Harnesses.h4Remove,
        ),
      ]),
  Level(5, 'Memory and state',
      'Context is what it sees now, a summary is what’s left of the past, memory is what you chose to keep, and state is what the app knows.',
      [
        Experiment(
          id: 'save',
          name: 'Save preferences',
          change: 'memory',
          inputs: const [
            'Remember for today: nothing before 10, no roundtables, and I’m leaving at 17:00. No need to change my plan yet.',
          ],
          without: Harnesses.h4Summarise,
          withPiece: Harnesses.h5,
          notes: 'With memory, the model proposes each fact and you confirm it.',
        ),
        Experiment(
          id: 'new-conversation',
          name: 'New conversation',
          change: 'memory',
          seed: Seed.demoPlan,
          inputs: const ['What should I end the day with, and why?'],
          without: Harnesses.h4Summarise,
          withPiece: Harnesses.h5,
          notes:
              'A fresh conversation. It starts with this morning’s plan, and memory holds only what you approved.',
        ),
      ]),
  Level(6, 'Trust',
      'Reliability comes from the code around the model, and the model stays unpredictable.',
      [
        Experiment(
          id: 'calendar',
          name: 'Calendar request',
          change: 'trust controls',
          seed: Seed.demoPlan,
          calendarTools: true,
          inputs: const [
            'Add the talks in my plan that start after 13:00 to my calendar. Check each talk’s details first.',
          ],
          without: Harnesses.h5,
          withPiece: Harnesses.h6,
          notes:
              'The Beyond Prompts description carries an injected instruction; the first calendar call times out. If the model resists or retries on its own, say so: neither is guaranteed, the harness is.',
        ),
      ]),
];
