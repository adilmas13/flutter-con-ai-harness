# Day Planner: FlutterCon AI harness demo

The demo app for the talk **“Beyond Prompts: Context, Memory & Agent Loops for Reliable AI-Powered Flutter Apps”** (flutterCon India 2026, 21 Nov, Junior Ballroom, 14:15). It's a macOS Flutter app that plans a day at the conference from the real schedule. It's built so the audience can watch a harness grow around a model, one piece per level.

`CLAUDE.md` and `GEMINI.md` are symlinks to this file. Edit `AGENTS.md` only.

**Status and plan:** [`docs/PLAN.md`](docs/PLAN.md) has every phase and task with its status. Read it before starting work. Update it whenever a task's status changes.

## What the app teaches

There are six levels. Each is a **before-and-after experiment**: the same input, run **without** and **with** one new harness piece.

| Level | Adds | Experiments |
|---|---|---|
| 1 The call | Bare model (baseline) | Baseline |
| 2 History and context | History, context builder | Follow-up |
| 3 Tools and the loop | Tools, loop, validation, step limit | Plan request, vague request |
| 4 When the window fills | Context budget (summarise or remove old turns) | Summarise, remove |
| 5 Memory and state | Memory (model proposes, user confirms), app state | Save preferences, new conversation |
| 6 Trust | Approval, least privilege, retry | Calendar request (with an injected instruction) |

The same seven checks run after every turn: no invented sessions, follow-ups work, rules respected, stops within 8 steps, survives a long chat, remembers across conversations, and no unapproved writes or exports.

## Commands

Every project command is a [`just`](https://just.systems) recipe; run `just` to list them. Use the recipes rather than raw commands.

| Recipe | Does |
|---|---|
| `just run` | Run on macOS with `.env` and `PROJECT_DIR` (live calls, recordings saved here) |
| `just gen` | Regenerate MobX code after changing a store |
| `just check` | `analyze` + `test`; run before every commit |
| `just build` / `just open` | Build the macOS app, launch the last build |
| `just recordings` | List saved recordings |
| `just commit "message"` / `just push` | Commit (refuses if `.env` is staged) and push |

Commit and push after each phase in `docs/PLAN.md` is completed. Commit messages follow [Conventional Commits](https://www.conventionalcommits.org) (`type(scope): summary`); `just commit` rejects anything else.

## Skills

Project skills live in `.agents/skills/` (`.claude/skills` links there). Read the matching one before the task:

| Skill | Use when |
|---|---|
| `phase-complete` | Finishing a task or phase: verify, update the plan, commit, push |
| `add-experiment` | Adding or changing a level, experiment, harness piece, tool, check or seed |
| `record-runs` | Recording live runs and checking replay for the stage |
| `mobx-store` | Changing the store or a widget that observes it |
| `model-calls` | Anything that shapes a request to Claude; append-only history rules |

- `.env` holds `ANTHROPIC_API_KEY` and is git-ignored. **Never commit it, print it, or put the key anywhere else.**
- `PROJECT_DIR` lets the app write recordings back to `recordings/recordings.json`. Without it, recordings are read-only from the bundled copy.
- In **Live** mode the app calls Claude. After a run you like, press **Save run**. **Replay** plays the saved model replies back for that level, experiment, side and turn. Tools, approvals and checks still run for real.


## Layout

```
lib/
  config.dart              build-time config (--dart-define), budgets and limits
  data/schedule.dart       schedule model; assets/schedule.json is the real flutterCon schedule
  agent/
    harness.dart           HarnessPiece enum and the harness for each level
    levels.dart            levels and experiments (inputs, seeds, without/with harness)
    model_client.dart      ModelClient interface, AnthropicClient (raw HTTP), recording and replay
    recordings.dart        recordings/recordings.json store
    context_builder.dart   builds each request from state, and labels its sections for the inspector
    conversation.dart      append-only API message list, plus shrink state
    agent_loop.dart        the loop; every harness piece is a branch
    agent_state.dart       sealed AgentState, rendered with exhaustive switches
    tools.dart             tool specs, validation, handlers
    checks.dart            the seven checks
    seeds.dart             level 4 long chat, demo memory and plan
  stores/app_store.dart    MobX store; it is also the loop's host
  ui/                      app shell, chat, inspector (context, trace, memory, checks)
```

## Rules for changes

- **The loop is ours.** Every model call is a single round trip. Never use an SDK or framework feature that runs the tool loop, because the loop is what the talk teaches.
- **Keep conversations append-only.** Claude's thinking blocks are only valid if earlier messages never change. Freeze the system prompt for the whole conversation: memory is snapshotted when the conversation starts. Add new data as new messages. When shrinking, strip thinking blocks from the turns that are kept.
- **Model:** `claude-opus-5-5` by default, effort `low` for stage speed. Requests use raw HTTP to `POST /v1/messages`, plus `count_tokens` for the budget check.
- **Product-agnostic wording.** UI text and slides say “your coding assistant”, never a product name.
- **Keep it honest.** Replies from a recording are labelled as replay. The 8,000-token budget is a teaching budget; real windows are 1M. The safety cap (16 calls) is not part of the harness being taught.
- **State management is MobX.** Any mutation, including those from loop host callbacks, happens in `@action` methods.
- Keep code readable on a slide: small functions, clear names, few comments that explain why.
