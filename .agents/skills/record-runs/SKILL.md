---
name: record-runs
description: Record live Claude runs for each level and verify replay for the stage. Use when preparing or checking recordings/recordings.json, or when a replayed run behaves differently from the live one.
---

# Recording runs for the stage

The stage path is **replay**: saved model replies, with real tools, approvals and checks.

## Record

1. The user adds `ANTHROPIC_API_KEY` to `.env`. Never read it back, print it, log it or commit it.
2. `just run`. This passes `.env` and `PROJECT_DIR`, so saving writes to `recordings/recordings.json` in the repo. Without `PROJECT_DIR`, recordings are read-only.
3. For each level and experiment, run **Without** and then **With** with the suggested inputs, in order. Level 2 has two turns per side.
4. Keep a run only if it shows the intended difference:
   - The "without" run fails the way the slide says.
   - The "with" run passes.
   - The Checks tab agrees with both.
5. Press **Save run** after each good turn. The key is `L{level}/{experiment}/{side}/turn-{n}`.

## Verify

- `just recordings` lists what is saved. All 6 levels need both sides.
- Switch to **Replay**, restart each experiment and send the same inputs. A trace note saying “request differs from recording” means the code or seed changed since recording. Re-record that run.
- Rehearse once with Wi-Fi off.

## Notes

- Live behaviour varies. If a failure doesn't reproduce, change the suggested input or the seed rather than faking a reply. Then re-record both sides.
- Recordings hold full requests and responses. They contain no key, but read them before committing.
- Commit recordings with `feat(recordings): ...` (see the `phase-complete` skill).
