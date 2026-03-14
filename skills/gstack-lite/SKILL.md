---
name: gstack-lite
description: Lightweight orchestration gates for Codex. Use when a task needs phase checkpoints with product-gate, engineering-gate, and ship-gate without running a full always-on orchestrator.
---

# gstack-lite

## Use This Skill For
- Add lightweight coordination gates to medium or high-impact tasks.
- Align scope and risk early before implementation starts.
- Keep release readiness explicit before handoff.

## Do Not Use This Skill For
- Always-on execution for every turn.
- Replacing `lint-and-validate`, `webapp-testing`, or `github`.
- One-shot low-risk tasks where gating adds overhead.

## Gate Set
1. `product-gate`
- Define user outcome, success criteria, and key risks.
- Freeze what is in scope and what is out of scope.

2. `engineering-gate`
- Confirm architecture, interfaces, migration plan, and rollback path.
- Check dependency and integration risk before coding expands.

3. `ship-gate`
- Confirm quality evidence, release checklist, and handoff readiness.
- Decide go/no-go with concrete follow-up actions.

## Operating Rules
- Default `OFF`; turn on only when the current phase needs a gate.
- Run each gate once per phase, then turn it off.
- Keep gate output concise and decision-oriented.
- If retrieval evidence is missing for a technical claim, return `không đủ dữ liệu`.

## Boundary Contract
- `gstack-lite` handles coordination and decision checkpoints only.
- `lint-and-validate` handles static checks and validation tasks.
- `webapp-testing` handles browser and E2E verification.
- `github` handles branching, PR flow, and repo operations.

## Status-Line Compatibility
- Follow the shared Guard/SkillGate status-line standard already emitted by runtime metrics.
- Do not add a second custom status-line format from this skill.
