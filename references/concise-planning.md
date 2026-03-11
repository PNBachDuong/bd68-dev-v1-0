# Concise Planning

Reference adapted from the `concise-planning` skill in:
- https://github.com/majiayu000/claude-skill-registry/tree/main/skills/concise-planning

## Why Use It
- The goal is not more planning. The goal is better planning with fewer tokens.
- This workflow helps avoid over-planning, speculative branching, and context-heavy roadmaps.

## When To Use
- The user asks for a plan, roadmap, checklist, or breakdown.
- The task is large enough that a short structure improves execution.
- We need to realign scope before coding or before proposing architecture.

## When Not To Use
- The next concrete step is already obvious.
- The task is a simple one-step implementation.
- A long exploratory plan would add more tokens than value.

## Workflow
1. Confirm the immediate goal in one line.
2. Run retrieval first if the task is technical or depends on project context.
3. Produce only the minimum useful plan, usually 3-5 steps.
4. Split large work into now, next, and later instead of expanding every branch.
5. Start execution as soon as the next safe action is clear.

## Output Style
- Prefer short bullets over long paragraphs.
- Prefer action verbs over analysis-heavy prose.
- Keep assumptions explicit and minimal.
- Trim optional branches unless the tradeoff is material.

## Token Hygiene
- Do not restate all background context in the plan.
- Do not duplicate retrieved docs inside the plan.
- Do not create nested plans unless the user explicitly wants detailed project-management output.
- Update the plan only when scope changes, not after every tiny step.

## Success Criteria
- The plan helps execution start faster.
- The plan reduces follow-up clarification instead of increasing it.
- The plan stays short enough that it does not become the main source of token cost.
