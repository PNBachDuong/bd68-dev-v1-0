---
name: bd_dev_kit
description: Personal Codex operating profile for BD68 and WildSoul sessions. Use only when continuing BD68 or WildSoul work, reviewing the custom Codex setup (chub/context7 docs flow, Serena local code flow, and installed skills), deciding whether a new skill should be installed or promoted, using the Impeccable design compass before frontend brainstorming or planning, applying concise-planning and context hygiene defaults for long-running sessions, checking the antigravity skill library only when an actually needed skill is missing, or producing the short GPT-5.4 token cost summary at chat wrap-up.
---

# BD68 Dev v1.1

## Use This Skill For
- Continue BD68 or WildSoul work with the existing Codex setup.
- Review or explain the current MCP and skill stack.
- Decide whether a candidate skill is worth adding.
- Apply Serena-first local code retrieval/edit policy.
- Apply gstack-lite orchestration gates only when needed.
- Operate the 5-skill add-on gate (`context-window-management`, `context-optimization`, `context-compression`, `prompt-caching`, `hierarchical-agent-memory`) with risk-first defaults.
- Check the Impeccable design compass before frontend brainstorming or design planning.
- Use concise-planning when the user asks for a plan, roadmap, or task breakdown.
- Use the antigravity skill library as a lookup source only when the current installed skills do not cover a repeated need.
- Output the short token and cost summary at chat wrap-up.

## Do Not Use This Skill For
- Generic coding work that does not depend on the BD68 setup.
- Third-party API implementation already covered by `get-api-docs` and `chub`.
- Routine verification already covered by `lint-and-validate`.
- Letting gstack overlap with `lint-and-validate`, `webapp-testing`, or `github`.
- Browsing the antigravity catalog by default when an installed skill already fits.

## Retrieval Order
- Before using a pack reference, open `references/SOURCE_INDEX.md` to confirm which local file matches the need and what GitHub source it mirrors or adapts.
- When the pack already contains a curated local reference for the current task, read that local reference first and treat it as a valid retrieval source with provenance.
- Use `chub_search` then `chub_get` before coding any third-party API, SDK, or framework.
- If `chub` has no actionable entry or lacks required version-specific detail, use Context7 as fallback/accelerator (`resolve-library-id` -> `query-docs`).
- If retrieval does not provide verifiable evidence for a technical claim, return `không đủ dữ liệu` instead of guessing.
- Use targeted `rg`/`grep` and focused file reads for local code discovery, declarations, and implementation checks.
- Use `rg` or `grep` for bodies, strings, config keys, JSON, CSS, Markdown, or raw text.
- Only go back to GitHub, web, or broader lookup when the local curated reference is missing, insufficient, or clearly out of scope.
- Retrieval loop guard:
  - Never repeat an identical retrieval call (same tool and same query) within the same turn or subtask.
  - Default retrieval budget per subtask: one discovery call plus one refinement call.
  - If retrieval returns empty, unchanged, or non-actionable results twice, stop repeating and switch to focused file reads.
## Context Hygiene
- Open a new thread earlier when the current thread becomes long, starts to drift, or accumulates too much stale context.
- Use targeted search and focused reads when the need is code structure discovery, and avoid broad read-all exploration unless narrower retrieval is insufficient.
- Do not allow retrieval loops: if the same query was already attempted and no new signal exists, do not call it again.

## Codex Thread Payload Hygiene
- Treat sudden thread token growth as a reliability bug, not only a pricing issue.
- In request assembly, keep one canonical message representation (`messages` or `extra_body.messages`) and never send both.
- Do not include internal encrypted payloads, action envelopes, or raw debug blobs in model input.
- Replace inline `data:image/*;base64` history entries with lightweight attachment references.
- Store full tool logs out-of-band; keep only compact tool summaries in conversational context.
- Enforce a pre-send token budget guard: trim tool output, drop non-essential payload, and summarize old turns when over budget.
- Use a sliding-window dialog history plus a compact summary for older turns.
## Current Stack
- MCPs: `chub`, `context7`, `serena`.
- Optional MCP fallback/accelerator for docs: `context7` (after `chub` only when needed).
- Local code retrieval/edit: `serena` is preferred once onboarded.
- Workflow orchestration: gstack-lite gates only (`product-gate`, `engineering-gate`, `ship-gate`), not always-on.
- Anti-guessing libraries for Python agent flows: `pydantic-ai`, `instructor`, `langsmith` (`langgraph` optional for orchestration-heavy graphs).
- Core skills: `get-api-docs`, `mcp-builder`, `github`, `stripe-best-practices`, `webapp-testing`, `frontend-design`, `lint-and-validate`.
- Context add-on skills: `context-window-management`, `context-optimization`, `context-compression`, `prompt-caching`, `hierarchical-agent-memory` (apply by gate, not all-ways-on).
- Add a new skill only if it fills a repeated gap and is likely to reduce either tool calls or context usage.

## 5-Skill Add-on Gate
- Priority order: `giam ao giac -> toi uu ngu canh -> giam token`.
- Never run all five skills all-ways-on. Use gated activation with hysteresis.
- Always-on core:
  - `context-optimization`
  - `context-window-management`
- Conditional activation:
  - `context-compression`: ON when `Input >= 120,000` tokens or payload is clearly oversized for one-shot; OFF only after `Input <= 90,000` for at least 3 consecutive turns.
  - `prompt-caching`: ON when request pattern is repetitive and cache hit stays `>= 30%`; OFF when cache hit drops to `<= 20%` for 2 windows or stale-cache regressions appear.
  - `hierarchical-agent-memory`: default OFF. ON only for multi-session or long-horizon work with stable persistence backend. Keep OFF for one-shot sessions.
- Safety precedence:
  - If retrieval has no verifiable evidence, answer `không đủ dữ liệu`.
  - If compression drops critical facts, roll back compression first.
  - If persisted memory conflicts with fresh retrieval, trust fresh retrieval and temporarily disable hierarchical memory.

## Serena And gstack-lite
- Serena is primary for local code retrieval/edit when local-code complexity is medium or high.
- Use gstack-lite only as coordination gates:
  - `product-gate`: goals, user impact, risk framing.
  - `engineering-gate`: architecture, interfaces, rollback path.
  - `ship-gate`: release checklist and handoff readiness.
- Do not run gstack-lite all-ways-on; activate per phase and turn it off after gate completion.
- Do not let gstack-lite overlap with `lint-and-validate`, `webapp-testing`, or `github`.

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
- Do not rely on compacting alone to rescue an already-saturated thread; prefer a clean handoff into a new thread.

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



