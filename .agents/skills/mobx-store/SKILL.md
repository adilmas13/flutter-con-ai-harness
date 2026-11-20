---
name: mobx-store
description: Rules for changing the MobX store (lib/stores/app_store.dart) and the widgets that observe it. Use when adding state, actions, or loop host callbacks, or when a widget doesn't update.
---

# MobX in this app

- **One store**, `AppStore` (`lib/stores/app_store.dart`). It is also the agent loop's `LoopHost` and `ToolHost`.
- **Codegen:** after changing any `@observable`, `@computed` or `@action`, run `just gen`. Commit the generated `app_store.g.dart`.
- **Every mutation happens inside an `@action`,** including callbacks the loop makes (`setState`, `addTrace`, `toolStarted` and the rest). Writing an observed value outside an action trips MobX's write policy in debug builds.
- **`async` actions** (`send`, `saveRun`) are wrapped per continuation. Mutate state after an `await` in a separate `@action` method, like `_finishTurn` and `_saved`.
- **Chat items are immutable.** To update one (a tool card finishing, an approval decided), replace it: `chat[i] = updated`. Don't mutate fields.
- **A `@computed` only tracks observables.** `Conversation` is a plain object, so values derived from it are plain getters (`rules`) or depend on an observable counter (`sentTurns`).
- **Widgets read state inside `Observer`.** Keep each `Observer` small, around the part that changes.
- **Switching level, experiment or side calls `_resetConversation()`.** It refuses while a turn is running (`state.isBusy`), because a pending approval would otherwise never complete.
