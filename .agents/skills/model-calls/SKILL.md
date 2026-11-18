---
name: model-calls
description: How this app calls Claude (raw HTTP Messages API, our own loop) and the API rules the harness must respect. Use when changing lib/agent/model_client.dart, context_builder.dart, agent_loop.dart, or anything that shapes a request.
---

# Calling Claude

- **Endpoint:** `POST https://api.anthropic.com/v1/messages`, with headers `x-api-key`, `anthropic-version: 2026-10-21` and `anthropic-beta: server-side-fallback-2026-07-01`. The budget check uses `POST /v1/messages/count_tokens`. There is no official Dart SDK; raw HTTP also keeps the inspector's raw JSON exactly what is sent.
- **Model:** `claude-opus-5-5` (override with the `CLAUDE_MODEL` dart-define). Effort is `low` for stage speed, set through `output_config.effort`. Thinking is always on with this model, so never send `thinking: {type: "disabled"}` or `budget_tokens`; both return a 400.
- **One round trip per call.** The loop is ours. Never use a framework or SDK helper that runs the tool loop.
- **Tool choice:** `tool_choice` `any` or a named `tool` returns a 400 on this model. Steer from the system prompt instead (“Whenever you recommend sessions, call showPlan”).
- **Tool results:** send every `tool_result` for one assistant turn in a single user message. A failed tool sets `is_error: true`.
- **Check `stop_reason`** before reading content. `refusal` means Claude declined; `fallbacks: "default"` lets the API retry on another model.

## Append-only history (important)

Claude's thinking blocks are bound to the exact earlier conversation. For accounts created on or after 31 Aug 2026, editing earlier messages, the system prompt or the tools mid-conversation returns a 400.

- Pass assistant `content` back **unchanged**, thinking blocks included. `Conversation.messages` stores it raw.
- The system prompt is frozen per conversation. Memory is snapshotted when the conversation starts.
- Declare the full tool list at the start of a conversation. Tools differ between runs, never within one.
- New data goes in new messages, or behind a tool (`getItinerary`), not into an edited system prompt.
- Shrinking (level 4) changes history by design. The builder strips thinking blocks from the turns it keeps, and the summary goes into the first kept user message.

If a live call returns 400 after shrinking, look at these rules first.
