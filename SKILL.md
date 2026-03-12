---
name: bd68-dev-v1-0
description: Personal Codex operating profile for BD68 and WildSoul sessions. Use only when continuing BD68 or WildSoul work, reviewing the custom Codex setup (memoryai, chub, vfs, and installed skills), deciding whether a new skill should be installed or promoted, using the Impeccable design compass before frontend brainstorming or planning, applying concise-planning and context hygiene defaults for long-running sessions, checking the antigravity skill library only when an actually needed skill is missing, or producing the short GPT-5.4 token cost summary at chat wrap-up.
---

# BD68 Dev v1.0

## Use This Skill For
- Continue BD68 or WildSoul work with the existing Codex setup.
- Review or explain the current MCP and skill stack.
- Decide whether a candidate skill is worth adding.
- Check the Impeccable design compass before frontend brainstorming or design planning.
- Use concise-planning when the user asks for a plan, roadmap, or task breakdown.
- Use the antigravity skill library as a lookup source only when the current installed skills do not cover a repeated need.
- Output the short token and cost summary at chat wrap-up.

## Do Not Use This Skill For
- Generic coding work that does not depend on the BD68 setup.
- Third-party API implementation already covered by `get-api-docs` and `chub`.
- Routine verification already covered by `lint-and-validate`.
- Browsing the antigravity catalog by default when an installed skill already fits.

## Retrieval Order
- Start with `memory_bootstrap` exactly once at session start.
- In the same session, do not call `memory_bootstrap` again unless the user explicitly asks for a reset-style re-bootstrap.
- Use `memory_recall` only for related follow-up work, and keep the query narrow and task-specific.
- Before using a pack reference, open `references/SOURCE_INDEX.md` to confirm which local file matches the need and what GitHub source it mirrors or adapts.
- When the pack already contains a curated local reference for the current task, read that local reference first and treat it as a valid retrieval source with provenance.
- Use `chub_search` then `chub_get` before coding any third-party API, SDK, or framework.
- Use `vfs` before `rg`, `grep`, or broad file reads for local code structure, declarations, signatures, classes, methods, and types.
- Use `rg` or `grep` for bodies, strings, config keys, JSON, CSS, Markdown, or raw text.
- Only go back to GitHub, web, or broader lookup when the local curated reference is missing, insufficient, or clearly out of scope.
- Retrieval loop guard:
  - Never repeat an identical `vfs` call (same path and same pattern/query) within the same turn or subtask.
  - Default `vfs` budget per subtask: one discovery call plus one refinement call.
  - If `vfs` returns empty, unchanged, or non-actionable results twice, stop `vfs` and switch to targeted `rg` or file reads.
  - Skip `vfs` for non-structure tasks such as policy discussion, debugging tool behavior, token-cost reporting, or status summaries.
## MemoryAI Guardrails
- Treat repeated `memory_bootstrap` in one thread as a warning sign for token waste.
- Do not call `memory_store` or similar write tools just to restate an already-known preference; recall first.
- Call `memory_compact` only at chat wrap-up, explicit `chốt phiên`, or when the context is clearly near a limit and compacting is necessary to continue safely.
- Do not compact during active exploration unless the context is genuinely near a limit and the user-facing work would otherwise suffer.
- Use `memory_health` only when checking a suspected context-growth problem or right before deciding whether to compact.

## Context Hygiene
- Open a new thread earlier when the current thread becomes long, starts to drift, or accumulates too much stale context.
- Keep `memory_recall` queries narrow, current-task-specific, and tied to related follow-up work only.
- Use `vfs` first when the need is code structure discovery, and avoid broad read-all exploration unless narrower retrieval is insufficient.
- Do not allow retrieval loops: if the same `vfs` query was already attempted and no new signal exists, do not call it again.
## Current Stack
- MCPs: `memoryai`, `chub`, `vfs`.
- Skills: `get-api-docs`, `mcp-builder`, `github`, `stripe-best-practices`, `webapp-testing`, `frontend-design`, `context-window-management`, `lint-and-validate`.
- Add a new skill only if it fills a repeated gap and is likely to reduce either tool calls or context usage.

## Pack References
- `references/SOURCE_INDEX.md` is the provenance index for local references included in this pack.
- Treat files in `references/` as curated GitHub-backed retrieval sources, not as casual notes.
- Prefer the local curated reference over re-browsing its upstream GitHub source when the local file already covers the current need.
- Cite or mention when a conclusion comes from a local curated reference versus fresh external retrieval.

## Skill Library Lookup
- Before looking outside the installed stack, check whether an existing skill already covers the task.
- If a repeated need is still uncovered, open `references/SOURCE_INDEX.md` and then review [references/antigravity.md](references/antigravity.md).
- Treat antigravity-awesome-skills as a lookup library, not a default skill source.
- Search narrowly: start from bundles or a shortlist, then open only the candidate `SKILL.md` files that match the need.
- Do not install a skill from antigravity until the use case is repeated, the overlap is low, and the likely token or workflow benefit is clear.

## Design Compass
- Before brainstorming frontend ideas or writing a design plan, open `references/SOURCE_INDEX.md` and then review [references/impeccable.md](references/impeccable.md).
- Treat Impeccable as a design north star, not as a mandatory install.
- Use it to pressure-test ideas against common AI-looking anti-patterns before committing to a direction.
- Keep the output compact: choose one clear aesthetic direction, list 2-4 non-negotiable design principles, and avoid over-specifying decorative details too early.

## Concise Planning
- Before writing a plan, roadmap, or task breakdown, open `references/SOURCE_INDEX.md` and then review [references/concise-planning.md](references/concise-planning.md).
- Keep plans short, execution-biased, and retrieval-backed.
- Prefer the minimum useful plan over exhaustive decomposition.
- Use `now`, `next`, and `later` for larger tasks.
- When the next concrete action is obvious, act instead of expanding the plan.

## Context Window Budget
- Treat `400,000` tokens as the global maximum context budget when the runtime supports it.
- Under the current `llmgate` + `gpt-5.4` runtime, the observed effective model context window is `258,400`, so the practical hard limit remains `258,400` until the provider or model changes.
- Open a new thread well before the effective limit; under the current runtime, treat `~250,000` tokens as a warning threshold and hand off earlier if the thread starts to drift.
- Do not rely on `memory_compact` to rescue an already-saturated thread; prefer a clean handoff into a new thread.

## Update Logging
- Maintain `UPDATE_LOG.md` for every approved change to this installed Codex skill.
- When an approved GitHub sync happens, add a matching entry to the repo copy of `UPDATE_LOG.md` and include the commit id after the push.
- Keep each entry short and factual: date, scope, summary, files, notes.

## Chat Cost Summary
Output exactly this block when the user asks to close the chat or requests token cost:
```text
MCP overhead token: thấp/vừa/cao
Token Input: ...
Token Output: ...
Tổng phí USD: ...
VFS tiết kiệm: ... token
VFS giảm: ...% khi không sử dụng
```
- This pricing profile is for `GPT-5.4` only.
- If the model changes, rename this pricing profile or create a new skill/version before using a new formula.
- Pricing:
  - Input: `$2.50 / 1M tokens`
  - Output: `$15.00 / 1M tokens`
  - Cache read: `$14.85 / 1M tokens`
  - Cache write: `$14.85 / 1M tokens`
- Full cost formula for this profile:
  - `(input_tokens * 2.50 + output_tokens * 15.00 + cache_read_tokens * 14.85 + cache_write_tokens * 14.85) / 1_000_000`
- If exact usage is available, use the exact values.
- If exact usage is unavailable, prefer a clearly labeled estimate instead of inventing precision.
- VFS reporting rules:
  - If an exact `vfs bench` result exists for the current task, use its saved-token and reduction-percent values.
  - If only `vfs stats` or a previous benchmark exists, report a clearly labeled estimate.
  - If VFS was not used in the task, set `VFS tiết kiệm: 0 token` and `VFS giảm: 0% khi không sử dụng`.


