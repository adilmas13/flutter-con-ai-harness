---
name: add-experiment
description: Add or change a level or before-and-after experiment in the Day Planner demo (harness pieces, inputs, seeds, tools, checks). Use when editing lib/agent/levels.dart, harness.dart, tools.dart, checks.dart or seeds.dart.
---

# Adding or changing an experiment

Every experiment is the **same input** run on two harnesses that differ only by the pieces the level adds. Keep it that way: if the "without" and "with" runs differ in anything else, the comparison stops meaning anything.

## Where things live

| Change | File |
|---|---|
| Level name, takeaway, experiments, suggested inputs, seed | `lib/agent/levels.dart` |
| Harness pieces and the harness for each level | `lib/agent/harness.dart` (`Harnesses`) |
| A tool, its validation and its handler | `lib/agent/tools.dart`; which tools a harness gets is decided in `toolsFor` |
| How a piece changes the loop | `lib/agent/agent_loop.dart`; each piece is an `if (config.has(...))` branch |
| What goes into the request | `lib/agent/context_builder.dart` |
| The 7 checks | `lib/agent/checks.dart`; keep them deterministic, computed from `TurnRecord` |
| Seeded conversations, demo memory and plan | `lib/agent/seeds.dart` |

## Rules

- **A new harness piece** goes in the `HarnessPiece` enum, in talk order, with its level. The harness bar shows it automatically.
- **Changing what a request contains** (system text, tool descriptions, seeds) changes model behaviour. Re-run the affected levels live (`just live-flow` or `just stage-run`) and check the replies.
- **Keep conversations append-only** (see the `model-calls` skill).
- **Add or update a test** in `test/` for the before and after of the experiment, using `FakeModelClient`.
- **Update `docs/PLAN.md`**, and the talk-flow slides if the narrative changes.
