# Antigravity Skill Library

Use this reference only when the installed skills are not enough for a repeated need.

Source:
- https://github.com/sickn33/antigravity-awesome-skills
- https://raw.githubusercontent.com/sickn33/antigravity-awesome-skills/main/CATALOG.md

## Role
- This repo is a lookup library for candidate skills.
- It is not a default install target.
- It should not be browsed by default on normal tasks.

## When To Check It
- The task repeats and current skills do not cover it cleanly.
- The gap is procedural enough that a reusable skill could reduce tool calls or context.
- The likely value is higher than just solving the task ad hoc once.

## Search Order
- Check installed skills first.
- Start with antigravity bundles or a narrow shortlist, not the full catalog.
- Open only the candidate `SKILL.md` files that seem relevant.
- Reject high-overlap skills unless they offer a clear workflow or token-efficiency advantage.

## Install Decision Rule
Only recommend or install a skill from this library when all of these are true:
- repeated use case
- current stack is insufficient
- overlap is acceptably low
- likely token or workflow gain is clear
- security and command scope look reasonable

## Anti-Patterns
- Do not install full bundles by default.
- Do not browse the entire catalog for a one-off task.
- Do not add a skill just because it looks interesting.
- Do not replace an existing working skill without evidence that the new one is materially better.