# Implementation plan and status

The single source of truth for what is done and what is left. Update the status here whenever a task changes.

**Talk:** Beyond Prompts: Context, Memory & Agent Loops for Reliable AI-Powered Flutter Apps. flutterCon India 2026, **Saturday 21 Nov**, 14:15–14:55, Junior Ballroom, two speakers.

**Status key:** ✅ done · 🔄 in progress · ⬜ not started · ⏸ blocked on the user · 💤 deferred by decision

_Last updated: 2026-11-18_

---

## Decisions (settled in discussion)

| Topic | Decision |
|---|---|
| Audience | Flutter/Dart developers who use AI daily without knowing how it works. An AI concepts talk with Flutter as the vehicle. |
| Frame | Start from something known (your coding assistant), build an app layer by layer, then map back. Product-agnostic wording. |
| Structure | Harness engineering throughout. Each level is a before-and-after experiment with the **same input**, without and with one new harness piece, scored by the same 7 checks. |
| Demo app | One macOS Flutter app: a planner plus a collapsible inspector (Context, Trace, Memory, Checks), using the real flutterCon India schedule. |
| Data flow | Pure tools. The schedule stays in the app; the model only sees tool results. |
| Model | Claude `claude-opus-5-5`, effort `low`, raw HTTP to the Messages API. Our own loop, one round trip per call. |
| Live and replay | Run live. Save the runs you like to `recordings/recordings.json`. Replay plays saved model replies back; tools, approvals and checks still run. |
| State management | MobX (codegen). |
| Secrets | `ANTHROPIC_API_KEY` in `.env`, git-ignored, left blank for the user. |
| Git | Personal identity for this repo (`adilmas13@gmail.com`), remote `adilmas13/flutter-con-ai-harness`. Commit and push after each phase (user’s instruction). |
| Commands | `just` recipes for everything (`justfile`). |
| Deferred | Opening coding-assistant clip, the speaker split, fitting to 40 minutes. |

---

## Phase 0: Discussion and design ✅

- ✅ Research what changed in AI agents since the abstract was written (Aug/Sep → Nov 2026)
- ✅ Evaluate the outside plan and research report (approach B rejected)
- ✅ Audience, frame, demo app, six levels, failure → fix → takeaway per level
- ✅ Inspector design (direction B: clean assistant plus inspector drawer)
- ✅ Real schedule as data (Sessionize feed)
- ✅ v2 restructure: before-and-after experiments, growing harness, 7 checks
- ✅ Planning artifact with v1 and v2 app mockups and talk-flow slides: https://claude.ai/artifact/Mtd4WQPbEwwPKuHvD1d1bB

## Phase 1: Project setup ✅

- ✅ Flutter macOS project (`day_planner`), Flutter 3.44.8 / Dart 3.12.2
- ✅ Packages: `mobx`, `flutter_mobx`, `http`; dev: `mobx_codegen`, `build_runner`
- ✅ `assets/schedule.json`: 65 real sessions, with the injected instruction in our own talk’s description
- ✅ `.env` (blank key, git-ignored), `tool/run.sh` (passes `.env` and `PROJECT_DIR`)
- ✅ macOS entitlements: network client allowed, app sandbox off so recordings can be written to the project
- ✅ Git repo with personal identity, remote added (nothing committed)
- ✅ `AGENTS.md` with `CLAUDE.md` and `GEMINI.md` symlinked to it

## Phase 2: Core agent (levels 1–6 logic) ✅ written · ⬜ verified

- ✅ `config.dart`: model, effort, 8,000-token teaching budget, step limit 8, safety cap 16
- ✅ `harness.dart`: 13 harness pieces, a harness per level
- ✅ `levels.dart`: 6 levels, 9 experiments, suggested inputs, seeds
- ✅ `model_client.dart`: `ModelClient` interface, `AnthropicClient` (raw HTTP, `count_tokens`, refusal fallback), `RecordingClient`, `ReplayClient` (flags requests that differ from the recording)
- ✅ `recordings.dart`: load and save `recordings/recordings.json`, keyed by level/experiment/side/turn
- ✅ `conversation.dart`: append-only API messages, memory snapshot, shrink state
- ✅ `context_builder.dart`: builds each request from state, with labelled sections; strips stale thinking blocks after shrinking
- ✅ `tools.dart`: searchSessions, getSession, showPlan, savePreference, getItinerary, addToCalendar (first call times out), exportContacts (only without least privilege), with validation
- ✅ `agent_loop.dart`: loop with every harness piece as a branch (history, tools, validation, step limit, safety cap, budget check, summarise or remove, memory confirmation, approval, retry), plus trace events
- ✅ `agent_state.dart`: sealed states, exhaustive switches
- ✅ `checks.dart`: the 7 deterministic checks, and rules parsed from what the user said or saved
- ✅ `seeds.dart`: level 4 long chat (20 real search rounds), demo memory and plan
- ⬜ Unit tests with a fake model client, one per level’s before and after
- ⬜ Confirm the level 4 seed is over 8,000 tokens with `count_tokens` (needs the key)

## Phase 3: App UI ✅ written · ⬜ verified

- ✅ Theme tokens (light and dark) matching the mockup
- ✅ Presenter bar (levels, experiments, notes)
- ✅ App toolbar: Without/With switch, Live/Replay, recording indicator, context ring, Inspector button
- ✅ Harness bar: 13 pieces (dashed, on, or new), score
- ✅ Chat: user and assistant messages, app messages, tool card (collapsible), plan card (rule breaches highlighted), budget error card, approval card, memory card, errors, working indicator
- ✅ Composer with suggested inputs, Save run, restart
- ✅ Inspector: Context (exact total, stacked bar, sections, raw JSON), Trace (waterfall, loop state, steps), Memory (memory, plan, calendar, leaked data), Checks
- ✅ `flutter analyze` clean
- ⬜ macOS build and launch smoke test (no key: shows the missing-key state)
- ⬜ Screenshot review of each level at stage resolution, light and dark
- ⬜ Window default size for the projector (for example 1440×900)

## Phase 4: Live runs and recordings ⏸ needs the API key

- ⏸ Add `ANTHROPIC_API_KEY` to `.env` (**user**)
- ⬜ Run each experiment live, without and with; check that each failure shows up
- ⬜ Tune prompts and inputs where a failure doesn’t reproduce (for example the vague request, or the summary losing “leaving at 17:00”)
- ⬜ Save good runs for every level, side and turn; replay them all end to end offline
- ⬜ Rehearse with Wi-Fi off, in replay mode only

## Phase 5: Polish ⬜

- ⬜ Keyboard shortcuts for the presenter (level 1–6, toggle without/with, open inspector)
- ⬜ Projector legibility pass (font sizes, contrast)
- ⬜ Update the planning artifact’s raw JSON shape to match the Messages API
- ⬜ README for people cloning the repo after the talk (replay works without a key)

## Phase 6: Talk materials ⬜

- ⬜ Slide deck from the v2 talk flow (24 slides), with the scoreboard reflecting real recorded runs
- ⬜ Code slides taken from the real source (loop, sealed state, context builder)
- 💤 Opening clip of a coding assistant fixing a failing test (enhancement)
- 💤 Speaker split between the two presenters
- 💤 Fit to 40 minutes, then a timed rehearsal

## Phase 7: Repository 🔄

The user asked to commit and push after each phase.

- ✅ `justfile` with recipes for every project command (`just` lists them)
- 🔄 First commit and push: project setup, plus core agent and UI (written, not yet verified)
- ⬜ Commit and push again after each later phase

---

## Known risks

- **Live behaviour varies.** Some failures (context rot, a lossy summary, trying the injected instruction) may not happen on every live run. Recordings are the stage path.
- **History-editing check.** Opus 5.5 rejects edited history for new accounts. The harness keeps conversations append-only, and strips thinking blocks from turns kept after shrinking. This needs confirming on a live run at level 4.
- **Refusal fallback header.** The `server-side-fallback-2026-07-01` beta is sent on every request. If the account rejects it, remove it in `model_client.dart`.
