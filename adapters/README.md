# Adapters

Each adapter translates the shared BD68 profile into the format expected by a specific agent IDE.

Rules:
- `core/` remains the source of truth
- adapters should stay as thin as possible
- references should be shared from `references/` instead of duplicated per adapter
- do not assume `.codex` exists unless the adapter is specifically for Codex

Current implementation:
- `opencode/`: implemented and installable

Planned later:
- other IDE adapters can be added without changing the shared profile shape
