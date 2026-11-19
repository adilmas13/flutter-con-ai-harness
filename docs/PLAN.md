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

## Phase 2: Core agent (levels 1–6 logic) ✅

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
- ✅ Tests with a fake model client: every level’s without and with run, plus replay (`test/levels_test.dart`)
- ✅ Robustness tests: network error, Cancel, fixed starting state, multi-turn save, rule phrasing (`test/robustness_test.dart`); 27 tests pass
- ✅ The level 4 seed’s local estimate is over the 4,800-token threshold, so the budget check runs (covered by a test)
- ✅ Confirmed with real `count_tokens`: the seed is 12,576 tokens

## Phase 3: App UI ✅

- ✅ Theme tokens (light and dark) matching the mockup
- ✅ Presenter bar (levels, experiments, notes)
- ✅ App toolbar: Without/With switch, Live/Replay, recording indicator, context ring, Inspector button
- ✅ Harness bar: 13 pieces (dashed, on, or new), score
- ✅ Chat: user and assistant messages, app messages, tool card (collapsible), plan card (rule breaches highlighted), budget error card, approval card, memory card, errors, working indicator
- ✅ Composer with suggested inputs, Save run, restart
- ✅ Inspector: Context (exact total, stacked bar, sections, raw JSON), Trace (waterfall, loop state, steps), Memory (memory, plan, calendar, leaked data), Checks
- ✅ `flutter analyze` clean
- ✅ macOS build and launch smoke test (no key: shows the missing-key state)
- ✅ Visual pass: `just screens` replays every recorded experiment in the real window and saves 34 screenshots to `build/screens/`. It found and fixed the budget-card labels, retry order in the trace, and an outdated level 5 note
- ⬜ Light-theme screenshot pass (screens were taken in dark mode)
- ✅ Window opens centred at 1440×900, titled “Day Planner”

## Phase 3b: Fixes from the plan review ✅

A reviewer agent checked the plan against the code. Fixed:

- ✅ Any failure (timeout, network, a login page instead of JSON) ends the turn as `Failed`, so the app never stays busy. The HTTP client retries 408/409/429/5xx/529 and network errors twice.
- ✅ **Cancel** button while a turn runs. It also declines pending approval and memory cards.
- ✅ Every experiment starts from a **fixed state** (memory, plan, calendar), so replay doesn’t depend on what ran before.
- ✅ **Save run saves the whole conversation** (every live turn); failed or cancelled runs can’t be saved. Replay notes when the typed input differs from the recording.
- ✅ **Reset for stage** button: level 1, inspector closed, replay on when recordings exist. The app starts in Replay when recordings exist.
- ✅ Level 4 seed uses the same search as the tool. The “no invented sessions” check needs three or more times written as text. Rule parsing handles more phrasings (“earlier than 10am”, “leaving by 5pm”, “skip the roundtables”).
- ✅ Sharper triggers: the vague request says “keep searching until you’re sure”, and empty searches suggest another keyword. The level 6 injection reads like an organiser’s note asking to call `exportContacts`.
- ✅ `just release` and `just open-release` for the stage build.

Still open from the review:
- ⬜ The budget check runs once per turn, before the first call. Tool results later in the turn can go over without being caught (acceptable for the demo; note it if asked).
- ⬜ “Follow-ups work” checks that history was sent, not that the answer was right (by design: it tests the harness).

## Phase 4: Live runs and recordings ✅ (rehearsal pending)

Order matters: **freeze prompts, tool descriptions and seeds before recording.** Any later change makes replay show “request differs”. Record along the stage order (levels 1→6), then build the release app.


- ✅ Add `ANTHROPIC_API_KEY` to `.env` (user)
- ✅ Live smoke test (`just live-smoke`): key, model, fallback header, `count_tokens`, and the tool loop all work. The level 4 seed is 12,576 real tokens (over 8,000).
- ✅ **Level 1 story:** Opus 5.5 doesn’t invent sessions; it says it has no schedule and asks for it. New story: “it knows only what you send it”.
- ✅ **Pasted schedule at levels 1–2** (user tested, works): suggestions paste the compact schedule (`{schedule}` → `assets/schedule_paste.txt`, always the same text). Level 1: without the schedule, then with it. Level 2: paste, then the follow-up, without and with history. Level 3 swaps pasting for tools.
- ✅ Check 1 accepts a text plan whose sessions are named in the schedule (pasted), and fails one whose sessions aren’t
- ✅ Agenda scraper: `just scrape` regenerates `assets/schedule.json`, `assets/schedule_paste.txt` and `docs/agenda.md`; run it again on Friday
- ⬜ Update the v2 talk-flow slides for the new level 1–2 story (knows only what you send; paste, then tools)
- ✅ Live runner (`just run-live`), evaluator review, `just promote` and offline replay check (`just verify-replay`, part of `just check`)
- ✅ Round 1, all 17 runs live: the evaluator flagged 3 app bugs (checks 1 and 2, vague search returning everything), unclear inputs, approval order and section totals. All fixed.
- ⏸ **Round 2: Anthropic credits ran out** after L1–L3. Levels 4–6 failed with “credit balance is too low”. **User: top up credits**, then `just run-live L4`, `L5`, `L6` and `L3/vague`
- ✅ Evaluator round 2: **recorded** L3 plan/with and L4 summarise/without; replay verified offline (`just verify-replay`)
- ✅ Level 2 now adds history only (the context builder moved to level 3 with the tools), so its two runs differ by nothing else; level 1–2 inputs ask for two sentences or a short list
- ✅ Credits topped up (new key); rounds 3–6 run live. Fixes along the way: L2 talks-only input, a rule-aware L4 seed, a neutral getSession label, check 1 matches on 4 words, check 2 wording after shrinking
- ✅ **All 17 experiment sides recorded (20 turns)**, each approved by the evaluator agent and fact-checked against the schedule. Presenter notes cover the known quirks (L2 re-sorts the swapped talk to #4; L4 remove “corrects” answers it can’t see; L6 resisted the injection and retried on its own)
- ✅ `just verify-replay`: every recording replays offline with identical requests, state and checks
- ✅ L3 vague loops now: 16 model calls without the limit (safety cap), stopped at 8 with it
- ⬜ Tune prompts and inputs where a failure doesn’t reproduce (for example the vague request, or the summary losing “leaving at 17:00”)
- ✅ Save good runs for every level, side and turn; replay them all end to end offline
- ⬜ `just release` after the final recordings; rehearse from the release build with Wi-Fi off (**next**)
- ⬜ If level 3’s vague request or level 6’s injection doesn’t trigger live, adjust the input or the tool’s reply, then re-record both sides

## Phase 4b: Rework after user review 🔄

- ✅ **Concise replies:** a reply-style line goes into every request (at most three short sentences or five list items, no headings or tables). It shows as its own Inspector section and says nothing about the app.
- ✅ **One conversation across levels (accumulator):** history carries from level to level. Within a level, Without and With each branch from the shared history. Only the With run of a level’s first experiment carries forward (never a Without run; level 5’s new conversation replaces it once run), and each level starts from the nearest earlier level’s result, so going back never brings later history with it. Level 4 fast-forwards with seeded turns when history is short; level 5’s “New conversation” starts fresh by design.
- ✅ Earlier turns are sent as plain text (old thinking dropped oldest-first, tool calls written as text), so history works across levels with different system prompts and tools
- ✅ **No-paste story for levels 1–3:** L1 knows nothing; L2 the user names three talks, then “swap the second one”; L3 “use the schedule” to find a real performance talk with tools
- ✅ **Replay set aside for now:** the app starts in Live, and the old recordings were cleared because they no longer match. The replay feature stays.
- ✅ Live run of the whole stage path as one conversation (`just live-flow`, transcript in `build/live_flow.md`): no API errors, every check as intended, replies mostly 2–4 sentences
- ✅ Fix: experiments within one level start from the level’s history (L4 “remove” had started from the summarised chat)
- ✅ Inspector **System prompt** panel: the full prompt for this side, compared line by line with the other side
- ⬜ Re-record once the flow is settled

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
- ✅ Conventional Commits, enforced by `just commit` (the first commit predates this and is left as pushed)
- ✅ Project skills in `.agents/skills/` (phase-complete, add-experiment, record-runs, mobx-store, model-calls), with `.claude/skills` linked to them
- ✅ First commit and push: project setup, plus core agent and UI (written, not yet verified)
- ⬜ Commit and push again after each later phase

---

## Known risks

- **Live behaviour varies.** Some failures (a runaway loop at low effort, a lossy summary, following the injected instruction) may not happen live. Level 6’s without side still fails check 7 through the unapproved calendar write. Recordings are the stage path.
- **History-editing check.** Opus 5.5 rejects edited history for new accounts. The harness keeps conversations append-only, and strips thinking blocks from turns kept after shrinking. This needs confirming on a live run at level 4.
- **Refusal fallback header.** The `server-side-fallback-2026-07-01` beta is sent on every request. If the account rejects it, remove it in `model_client.dart`.
