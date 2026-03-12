# Reference Source Index

Use this file to decide which local reference to open first.

Rule:
- If a current task matches one of these references, prefer the local file first.
- Treat the local file as a valid retrieval source with provenance.
- Only go back to the upstream GitHub source when the bundled local reference is missing a needed detail.

## `impeccable.md`
- Local file: `references/impeccable.md`
- Upstream repo: `pbakaus/impeccable`
- Upstream URLs:
  - `https://github.com/pbakaus/impeccable`
  - `https://raw.githubusercontent.com/pbakaus/impeccable/main/source/skills/frontend-design/SKILL.md`
- Use for:
  - frontend brainstorming
  - design planning
  - checking anti-generic UI direction before proposing concepts
- Treat as:
  - a design compass
  - not an implementation API source

## `concise-planning.md`
- Local file: `references/concise-planning.md`
- Upstream repo: `majiayu000/claude-skill-registry`
- Upstream URL:
  - `https://github.com/majiayu000/claude-skill-registry/tree/main/skills/concise-planning`
- Use for:
  - short execution-biased plans
  - roadmap trimming
  - keeping planning token-efficient
- Treat as:
  - a workflow guide
  - not a technical API source

## `antigravity.md`
- Local file: `references/antigravity.md`
- Upstream repo: `sickn33/antigravity-awesome-skills`
- Upstream URLs:
  - `https://github.com/sickn33/antigravity-awesome-skills`
  - `https://raw.githubusercontent.com/sickn33/antigravity-awesome-skills/main/CATALOG.md`
- Use for:
  - narrow skill discovery when a repeated gap exists
  - evaluating whether another skill is worth adding
- Treat as:
  - a lookup library
  - not a default install list
  - not a direct implementation source of truth
