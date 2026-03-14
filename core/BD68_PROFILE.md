# BD68 Dev v1.0 Portable Profile

Purpose: portable operating profile for BD68 and WildSoul work across agent IDEs.

## Core Intent
- Keep retrieval disciplined.
- Keep planning concise.
- Keep long-running threads healthy.
- Prefer execution over ceremony.

## Retrieval Order
- Open `references/SOURCE_INDEX.md` before using a pack reference so the source and intent are explicit.
- If the pack already contains a curated local reference for the current need, read that local file first and treat it as a valid retrieval source with provenance.
- If the environment provides `chub`, use `chub_search` then `chub_get` before coding any third-party API, SDK, or framework.
- If `chub` has no actionable entry or lacks required version-specific detail, use Context7 as fallback/accelerator (`resolve-library-id` then `query-docs`).
- If retrieval does not provide verifiable evidence for a technical claim, answer `không đủ dữ liệu` instead of guessing.
- Use targeted `rg`/`grep` and focused file reads for local code discovery.
- Use raw text search only for bodies, strings, config keys, JSON, CSS, Markdown, or other literal text search.
- Only go back to GitHub or broader external retrieval when the local curated reference is missing or insufficient.
- Retrieval loop guard:
  - Never repeat an identical retrieval call (same tool and same query) within the same turn or subtask.
  - Default retrieval budget per subtask: one discovery call plus one refinement call.
  - If retrieval returns empty, unchanged, or non-actionable results twice, stop repeating and switch to focused file reads.
## Context Hygiene
- Open a new thread earlier when the current thread becomes long, starts to drift, or accumulates stale context.
- Keep retrieval narrow and current-task-specific.
- Prefer a clean handoff to a new thread over trying to rescue a saturated thread.
- Do not allow retrieval loops: if the same query was already attempted and no new signal exists, do not call it again.

## Codex Thread Payload Hygiene
- Treat sudden thread token growth as a reliability bug, not only a pricing issue.
- In request assembly, keep one canonical message representation (`messages` or `extra_body.messages`) and never send both.
- Do not include internal encrypted payloads, action envelopes, or raw debug blobs in model input.
- Replace inline `data:image/*;base64` history entries with lightweight attachment references.
- Store full tool logs out-of-band; keep only compact tool summaries in conversational context.
- Enforce a pre-send token budget guard: trim tool output, drop non-essential payload, and summarize old turns when over budget.
- Use a sliding-window dialog history plus a compact summary for older turns.
## Pack References
- `references/` contains curated GitHub-backed references bundled with this pack.
- `references/SOURCE_INDEX.md` maps each local reference to its upstream GitHub source and intended use.
- Treat these files as first-pass retrieval sources, not as optional notes.

## Concise Planning
- For planning, roadmap, or implementation breakdown requests, prefer concise-planning.
- Keep plans short, execution-biased, and retrieval-backed.
- Prefer the minimum useful plan over exhaustive decomposition.
- Use `now`, `next`, and `later` for larger tasks.
- If the next concrete action is obvious, act instead of expanding the plan.

## Context Window Budget
- Treat `400,000` tokens as the global maximum context budget when the runtime supports it.
- Under the current `llmgate` plus `gpt-5.4` runtime, the observed effective model context window is `258,400`, so the practical hard limit remains `258,400` until the provider or model changes.
- Treat `~250,000` tokens as an early warning threshold under the current runtime.
- Do not rely on compacting alone to save an already-overloaded thread.

## Design Compass
- Before brainstorming frontend ideas or writing a design plan, review `references/impeccable.md`.
- Use it as a design north star, not as a decorative checklist.

## Skill Library Lookup
- Only look outside the current stack when a repeated need is not covered cleanly.
- If skill discovery is needed, review `references/antigravity.md` narrowly after checking `references/SOURCE_INDEX.md`.
- Do not browse catalogs by default.
- For anti-guessing in Python agent flows, prefer `pydantic-ai`, `instructor`, and `langsmith` (`langgraph` optional for orchestration-heavy workflows).
- Treat `Shubhamsaboo/awesome-llm-apps` as an idea catalog only, not as a technical baseline or source of truth.
- Before implementation, confirm API and SDK behavior with official docs.

## Serena And gstack-lite
- Prefer `serena` for local code retrieval/edit when the task touches medium or large code scopes.
- Use gstack only as lightweight orchestration gates (`product-gate`, `engineering-gate`, `ship-gate`).
- Do not run gstack all-ways-on.
- Do not let gstack overlap with `lint-and-validate`, `webapp-testing`, or `github`.

## 5-Skill Add-on Gate
- Priority order: `giam ao giac -> toi uu ngu canh -> giam token`.
- Never run all five skills all-ways-on. Use gated activation with hysteresis.
- Always-on core:
  - `context-optimization`
  - `context-window-management`
- Conditional activation:
  - `context-compression`: ON when `Input >= 120,000` tokens or one-shot payload is clearly oversized; OFF only after `Input <= 90,000` for at least 3 consecutive turns.
  - `prompt-caching`: ON when request pattern is repetitive and cache hit stays `>= 30%`; OFF when cache hit drops to `<= 20%` for 2 windows or stale-cache regressions appear.
  - `hierarchical-agent-memory`: default OFF. ON only for multi-session or long-horizon tasks with stable persistence backend. Keep OFF for one-shot sessions.
- Safety precedence:
  - If retrieval has no verifiable evidence, answer `không đủ dữ liệu`.
  - If compression drops critical facts, roll back compression first.
  - If persisted memory conflicts with fresh retrieval, trust fresh retrieval and temporarily disable hierarchical memory.

## Output Expectations
- Keep answers concise unless the user explicitly wants depth.
- Surface assumptions when they materially affect behavior.
- Keep the short GPT-5.4 cost block format if the environment supports cost wrap-up.
- On end-of-session wrap-up, include Guard Context status:
  - `Guard Context: bật/tắt | chế độ: Safe/Balanced/Aggressive | đường chạy: runtime-token/manual`
  - `Guard Context giảm payload: ...% | nguồn: đo thực tế/ước tính`




