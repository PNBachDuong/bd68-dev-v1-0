# OpenCode MCP Notes For BD68 Dev v1.0

The portable profile assumes these tools if your OpenCode environment exposes them:
- `memoryai`
- `chub`
- `vfs`

If OpenCode is connected to the same MCP stack as Codex:
- keep the tool names the same
- keep the retrieval order the same
- keep the context hygiene rules the same

If a tool is missing in OpenCode:
- keep the rule intent
- use the closest equivalent retrieval or code discovery tool available in that environment

The portable profile is intentionally tool-aware, not tool-hardcoded.
