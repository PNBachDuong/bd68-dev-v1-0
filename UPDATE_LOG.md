# Update Log

Track every approved change to the installed Codex skill and every approved GitHub sync for `BD68 Dev v1.0`.

## Format
- Date: local date in Asia/Bangkok
- Scope: `codex`, `github`, or `codex+github`
- Summary: short description of what changed
- Files: touched files only
- Notes: optional details such as validation status or commit id

## History
| Date | Scope | Summary | Files | Notes |
| --- | --- | --- | --- | --- |
| 2026-03-11 | codex | Created `BD68 Dev v1.0` custom skill and validated metadata. | `SKILL.md`, `agents/openai.yaml` | Trigger narrowed for BD68/WildSoul setup, skill triage, and GPT-5.4 wrap-up. |
| 2026-03-11 | github | Published standalone `bd68-dev-v1-0` repository. | `README.md`, `SKILL.md`, `agents/openai.yaml` | Initial push completed after merging remote initial commit. |
| 2026-03-11 | codex+github | Added pricing and estimation rules to the GPT-5.4 wrap-up profile. | `SKILL.md` | Synced to GitHub after approval. |
| 2026-03-11 | codex+github | Updated pricing profile to GPT-5.4-only and revised full cost formula. | `SKILL.md` | Includes current pricing and fallback wording. |
| 2026-03-11 | codex+github | Added VFS wrap-up metrics to the summary block. | `SKILL.md` | Added `VFS tiết kiệm` and `VFS giảm` lines. |
| 2026-03-11 | codex+github | Added update log tracking for future approved changes. | `SKILL.md`, `UPDATE_LOG.md` | GitHub synced at commit `5bbbc43`. |
| 2026-03-11 | codex | Added Impeccable as a design compass reference for brainstorming and planning. | `SKILL.md`, `references/impeccable.md`, `UPDATE_LOG.md` | Local Codex skill only. GitHub not synced yet. |
| 2026-03-11 | github | Synced Impeccable design compass to GitHub. | `SKILL.md`, `UPDATE_LOG.md`, `references/impeccable.md` | Commit `83cdf42`. |
| 2026-03-11 | codex | Added local-only `concise-planning` test guidance for WildSoul planning workflows. | `SKILL.md`, `references/concise-planning.md`, `UPDATE_LOG.md`, `AGENTS.md` | Workspace-only test before any global or GitHub promotion. |
| 2026-03-11 | codex | Consolidated WildSoul local context hygiene and concise-planning test rules, then reloaded them for this session. | `SKILL.md`, `UPDATE_LOG.md`, `AGENTS.md` | Focused on early new-thread handoff, single bootstrap, narrow recall, compact-at-wrap-up, and vfs-first retrieval. |
| 2026-03-12 | codex | Promoted context hygiene and concise-planning defaults from WildSoul local testing into the global BD68 Dev v1.0 skill and global MCP policy. | `SKILL.md`, `UPDATE_LOG.md`, `references/concise-planning.md`, `C:\Users\ngath\.codex\AGENTS.md`, `AGENTS.md` | Added early new-thread guidance, single bootstrap discipline, narrow recall, compact-at-wrap-up, vfs-first retrieval, and concise-planning defaults. |
| 2026-03-12 | github | Synced promoted context hygiene and concise-planning defaults to GitHub. | `SKILL.md`, `UPDATE_LOG.md`, `references/antigravity.md`, `references/concise-planning.md` | Commit `23c45ea`. |
| 2026-03-12 | codex | Mirrored the new global context-window budget rules into the local BD68 Dev v1.0 repo working copy. | `SKILL.md`, `UPDATE_LOG.md` | Not pushed to GitHub in this step. |
| 2026-03-12 | github | Synced the context-window budget policy update to GitHub. | `SKILL.md`, `UPDATE_LOG.md` | Commit `3ba2e62`. |
| 2026-03-12 | codex | Added a portable OpenCode bootstrap pack with a one-command installer and BD68 profile adapter files. | `README.md`, `UPDATE_LOG.md`, `portable/core/BD68_PROFILE.md`, `portable/opencode/AGENTS.md.template`, `portable/opencode/MCP_SETUP.md`, `scripts/install-agent-pack.ps1` | Local implementation only until a later GitHub sync is approved. |
| 2026-03-12 | codex | Upgraded the OpenCode portable pack to single-file bootstrap mode so OpenCode can read the full BD68 operating rules directly from AGENTS.md. | `README.md`, `UPDATE_LOG.md`, `portable/opencode/AGENTS.singlefile.template`, `scripts/install-agent-pack.ps1` | Keeps archive/reference files, but the active OpenCode bootstrap is now self-contained in AGENTS.md. |
| 2026-03-12 | codex | Refactored the pack into a cleaner IDE-agnostic structure with `core/`, `adapters/`, and shared `references/`, while keeping Codex root files only as compatibility artifacts. | `README.md`, `UPDATE_LOG.md`, `core/BD68_PROFILE.md`, `adapters/README.md`, `adapters/opencode/AGENTS.md.template`, `adapters/opencode/AGENTS.singlefile.template`, `adapters/opencode/MCP_SETUP.md`, `scripts/install-agent-pack.ps1` | OpenCode remains the only implemented adapter; repo is cleaner and no longer centered on `.codex` for non-Codex runtimes. |
| 2026-03-12 | github | Synced the IDE-agnostic pack refactor and OpenCode adapter layout to GitHub. | `README.md`, `UPDATE_LOG.md`, `core/BD68_PROFILE.md`, `adapters/README.md`, `adapters/opencode/AGENTS.md.template`, `adapters/opencode/AGENTS.singlefile.template`, `adapters/opencode/MCP_SETUP.md`, `scripts/install-agent-pack.ps1` | Commit `519933a`. |
| 2026-03-12 | codex | Clarified that bundled `references/` files are curated GitHub-backed retrieval sources with provenance, added `references/SOURCE_INDEX.md`, updated the OpenCode adapter guidance, and taught the installer to copy the provenance index into the installed pack. | `SKILL.md`, `README.md`, `core/BD68_PROFILE.md`, `references/SOURCE_INDEX.md`, `adapters/opencode/AGENTS.singlefile.template`, `adapters/opencode/AGENTS.md.template`, `scripts/install-agent-pack.ps1`, `UPDATE_LOG.md` | Fixes the agent behavior gap where local pack references could be mistaken for optional notes instead of valid retrieval sources. |
| 2026-03-12 | github | Synced the reference-provenance update so bundled `references/` files are treated as GitHub-backed retrieval sources, and published `references/SOURCE_INDEX.md` plus the OpenCode installer/runtime update. | `README.md`, `SKILL.md`, `UPDATE_LOG.md`, `core/BD68_PROFILE.md`, `references/SOURCE_INDEX.md`, `adapters/opencode/AGENTS.singlefile.template`, `adapters/opencode/AGENTS.md.template`, `scripts/install-agent-pack.ps1` | Commit `68a25ec`. |
| 2026-03-12 | codex | Added anti-loop retrieval guardrails to prevent repeated VFS tool calls (identical-call block, per-subtask budget, stop-after-non-actionable, and non-structure skip) and aligned pack policy with the new global rule. | `SKILL.md`, `core/BD68_PROFILE.md`, `adapters/opencode/AGENTS.singlefile.template`, `UPDATE_LOG.md` | Added after debugging input token bloat caused by repeated VFS invocation loops. |
| 2026-03-12 | github | Synced anti-loop VFS retrieval guardrails to GitHub to prevent repeated tool-call loops and input-token bloat. | `SKILL.md`, `core/BD68_PROFILE.md`, `adapters/opencode/AGENTS.singlefile.template`, `UPDATE_LOG.md` | Commit `2aec3bc`. |
| 2026-03-12 | codex | Added VFS-call reporting rule: after each turn that calls `vfs`, always append MCP usage level + called MCP name and VFS on/off + optimization percent, with explicit estimate wording when exact percent is unavailable. | `AGENTS.md`, `SKILL.md`, `core/BD68_PROFILE.md`, `adapters/opencode/AGENTS.singlefile.template`, `UPDATE_LOG.md` | Enforces stable post-VFS reporting format and prevents fake precision. |
| 2026-03-12 | github | Synced mandatory post-VFS reporting format to GitHub: MCP usage level + called MCP name, VFS on/off + optimization percent, and explicit estimate wording when exact percent is unavailable. | `SKILL.md`, `core/BD68_PROFILE.md`, `adapters/opencode/AGENTS.singlefile.template`, `UPDATE_LOG.md` | Commit `17dc725`. |

