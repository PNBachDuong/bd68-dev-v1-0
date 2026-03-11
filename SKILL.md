---
name: bd68-dev-v1-0
description: Personal Codex operating profile for BD68 and WildSoul sessions. Use only when continuing BD68 or WildSoul work, reviewing the custom Codex setup (memoryai, chub, vfs, and installed skills), deciding whether a new skill should be installed or promoted, or producing the short GPT-5.4 token cost summary at chat wrap-up.
---

# BD68 Dev v1.0

## Use This Skill For
- Continue BD68 or WildSoul work with the existing Codex setup.
- Review or explain the current MCP and skill stack.
- Decide whether a candidate skill is worth adding.
- Output the short token and cost summary at chat wrap-up.

## Do Not Use This Skill For
- Generic coding work that does not depend on the BD68 setup.
- Third-party API implementation already covered by `get-api-docs` and `chub`.
- Routine verification already covered by `lint-and-validate`.

## Retrieval Order
- Start with `memory_bootstrap` at session start and `memory_recall` for follow-up work.
- Use `chub_search` then `chub_get` before coding any third-party API, SDK, or framework.
- Use `vfs` before `rg` or `grep` for local code structure, declarations, signatures, classes, methods, and types.
- Use `rg` or `grep` for bodies, strings, config keys, JSON, CSS, Markdown, or raw text.

## Current Stack
- MCPs: `memoryai`, `chub`, `vfs`.
- Skills: `get-api-docs`, `mcp-builder`, `github`, `stripe-best-practices`, `webapp-testing`, `frontend-design`, `context-window-management`, `lint-and-validate`.
- Add a new skill only if it fills a repeated gap and is likely to reduce either tool calls or context usage.

## Chat Cost Summary
Output exactly this block when the user asks to close the chat or requests token cost:
```text
MCP overhead token: thấp/vừa/cao
Token Input: ...
Token Output: ...
Tổng phí USD: ...
```
- This pricing profile is for `GPT-5.4` only.
- If the model changes, rename this pricing profile or create a new skill/version before using a new formula.
- Pricing:
  - Input: `$2.50 / 1M tokens`
  - Output: `$15.00 / 1M tokens`
  - Cache read: `$0.250 / 1M tokens`
  - Cache write: `$0 / 1M tokens`
- Default cache assumption for this profile:
  - `cache_read_tokens = input_tokens * 0.99`
  - `cache_write_tokens = 0`
  - `uncached_input_tokens = input_tokens * 0.01`
- Total cost formula for this profile:
  - `((input_tokens * 0.01) * 2.50 + (input_tokens * 0.99) * 0.250 + output_tokens * 15.00 + cache_write_tokens * 0) / 1_000_000`
- If exact usage is available, use the exact values.
- If exact usage is unavailable, prefer a clearly labeled estimate instead of inventing precision:
  - `Token Input`: estimate from current conversation context tokens when that is the only visible metric.
  - `Token Output`: estimate from the assistant response generated in that turn.
  - `Cache read`: estimate as `99%` of `Token Input`.
  - `Cache write`: use `0` unless the environment exposes real cache counts.
- When using estimated values, say briefly that they are estimates rather than billing-exact numbers.