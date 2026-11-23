# Day Planner: an AI harness demo

The demo app for **“Beyond Prompts: Context, Memory & Agent Loops for Reliable AI-Powered Flutter Apps”** at flutterCon India 2026 (21 Nov, Junior Ballroom, 14:15), by Neelansh Sethi and Adil Shaikh.

It's a macOS Flutter app that plans a day at the conference from the real schedule. The model never changes. What changes is the **harness** around it: the code that decides what is sent, which tools exist, how the loop runs, what is kept and what is allowed. Each level is a before-and-after experiment: the same input, run **without** and **with** one new piece of the harness.

## Talk material

| | Link |
|---|---|
| **Slides** | https://claude.ai/artifact/2ooCazgBU9HMKaFD7FRdbj |
| **Field guide** (speaker notes: every level's concept, requests, code, example runs and likely questions) | https://claude.ai/artifact/PFNA2mojeqJ97A27W73cEX |
| Early planning mockup (historical; the app has moved on since) | https://claude.ai/artifact/Mtd4WQPbEwwPKuHvD1d1bB |

## The six levels

| Level | Adds | Experiments |
|---|---|---|
| 1 The call | Bare model (baseline) | Baseline |
| 2 History and context | History | Follow-up |
| 3 Tools and the loop | Context builder, tools, loop, validation, step limit | Plan request |
| 4 Context management | Context budget (summarise or remove old turns) | Summarise, remove |
| 5 Memory and state | Memory (model proposes, user confirms), app state | Save preferences, new conversation |
| 6 Guardrails | Approval, least privilege | Calendar request (with an injected instruction) |

One conversation carries through the whole talk: each level continues from the previous level's With run. Seven checks run after every turn: no invented sessions, follow-ups work, rules respected, stops within 8 steps, survives a long chat, remembers across conversations, and no unapproved writes or exports.

Some ideas are on the slides only and not in the app: the vague request that trips the step limit, and retry at Level 6.

## Running it

You need Flutter (macOS desktop), [`just`](https://just.systems) and an Anthropic API key.

1. Put the key in `.env` as `ANTHROPIC_API_KEY=…`. The file is git-ignored; never commit it.
2. `just run` to run with live calls, or `just build` then `just open`.
3. `just check` runs analysis and the tests.

Run `just` to list every recipe. Every run calls the model live, so replies vary from run to run; the harness behaviour doesn't.

## Where things are

- `lib/agent/`: the harness. `harness.dart` (pieces per level), `levels.dart` (experiments and inputs), `context_builder.dart` (what is sent), `agent_loop.dart` (the loop; every piece is a `config.has` branch), `tools.dart`, `checks.dart`, `seeds.dart`.
- `lib/stores/app_store.dart`: the MobX store, which is also the loop's host.
- `lib/ui/`: chat, inspector (context, trace, memory, checks).
- `assets/schedule.json`: the real flutterCon schedule, plus one planted instruction in the Beyond Prompts description for the Level 6 injection demo (`tool/scrape_agenda.py`).
- [`AGENTS.md`](AGENTS.md): rules for changing the code. [`docs/PLAN.md`](docs/PLAN.md): every task and its status.

The loop is written by hand on raw HTTP on purpose: the loop is what the talk teaches. The 8,000-token budget is a teaching budget so the context fills on stage; real windows are about 1M tokens.
