---
name: phase-complete
description: Finish a phase or task from docs/PLAN.md: verify, update the plan's status, write a Conventional Commit and push. Use whenever a task or phase in docs/PLAN.md is completed, or before any commit in this repo.
---

# Completing a phase

1. **Verify.** Run `just check` (analyze and test). After a MobX store change, run `just gen` first. If the change touches the UI, build it with `just build`. Don't mark anything done while a check fails.
2. **Update `docs/PLAN.md`.**
   - Change each finished task's status (✅ done, 🔄 in progress, ⬜ not started, ⏸ blocked on the user, 💤 deferred).
   - Mark the phase heading ✅ when all its tasks are done.
   - Set `_Last updated:` to today's date.
   - Add any new risks or tasks you found. Never delete history; mark items done instead.
3. **Commit** with `just commit "<message>"`, which refuses to commit if `.env` is staged. Use [Conventional Commits](https://www.conventionalcommits.org):
   - Format: `type(scope): summary`, imperative, lower case, no trailing full stop, 72 characters or fewer.
   - Types: `feat`, `fix`, `test`, `docs`, `refactor`, `chore`, `build`, `style`, `perf`.
   - Scopes used here: `agent`, `ui`, `store`, `tools`, `checks`, `levels`, `plan`, `skills`, `macos`.
   - Examples: `feat(agent): add retry for transient tool errors`, `test(levels): cover before and after for all six levels`, `docs(plan): mark phase 3 verified`.
   - Split unrelated changes into separate commits.
4. **Push** with `just push`. The user asked for a commit and push after each phase.

Never commit `.env` or any API key. Never rewrite pushed history unless the user asks.
