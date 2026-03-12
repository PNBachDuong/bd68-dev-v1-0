# BD68 Dev v1.0 Portable Profile

Purpose: portable operating profile for BD68 and WildSoul work across agent IDEs.

## Core Intent
- Keep retrieval disciplined.
- Keep planning concise.
- Keep long-running threads healthy.
- Prefer execution over ceremony.

## Retrieval Order
- If the environment provides `memoryai`, call `memory_bootstrap` exactly once at session start.
- Use `memory_recall` only for related follow-up work, and keep the query narrow and task-specific.
- If the environment provides `chub`, use `chub_search` then `chub_get` before coding any third-party API, SDK, or framework.
- If the environment provides `vfs`, use `vfs` before `rg`, `grep`, or broad read-all file inspection when the goal is local code structure discovery.
- Use raw text search only for bodies, strings, config keys, JSON, CSS, Markdown, or other literal text search.

## Memory Guardrails
- Do not repeat `memory_bootstrap` in the same session unless the user explicitly asks for a reset-style re-bootstrap.
- Do not write memory just to restate a known preference.
- Call `memory_compact` only at wrap-up, explicit close, or when the context is truly near its limit and compacting is needed to continue safely.
- Use `memory_health` only when diagnosing context growth or deciding whether compacting is needed.

## Context Hygiene
- Open a new thread earlier when the current thread becomes long, starts to drift, or accumulates stale context.
- Keep retrieval narrow and current-task-specific.
- Prefer a clean handoff to a new thread over trying to rescue a saturated thread.

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
- If skill discovery is needed, review `references/antigravity.md` narrowly.
- Do not browse catalogs by default.

## Output Expectations
- Keep answers concise unless the user explicitly wants depth.
- Surface assumptions when they materially affect behavior.
- Keep the short GPT-5.4 cost block format if the environment supports cost wrap-up.
