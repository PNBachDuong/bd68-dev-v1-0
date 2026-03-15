# BD68 Dev v1.1

`BD68 Dev v1.1` la bo kit agent portable, doc lap IDE cho workflow WildSoul. Goi nay chuan hoa quy trinh retrieval-first (chub lam baseline docs, Context7 fallback, Serena cho local code), planning ngan gon, va dung bo reference local da curate kem provenance de lam viec nhanh va on dinh; cac repo tong hop nhu `awesome-llm-apps` chi dung de tham khao y tuong, con implement luon bam docs chinh thuc.

This repo is now organized as an IDE-agnostic pack:
- `core/` is the source of truth for the shared operating profile
- `references/` contains curated GitHub-backed retrieval sources and optional guidance files
- `adapters/` contains IDE-specific bootstrap files
- `scripts/` contains installers or helper scripts

## Current Status
- Implemented adapters: `OpenCode`, `Codex`
- Compatibility layer kept at repo root: `SKILL.md` and `agents/openai.yaml` for Codex skill usage
- Not claimed yet: full universal IDE support beyond current adapters

## Structure
- `core/BD68_PROFILE.md`
- `references/SOURCE_INDEX.md`
- `references/impeccable.md`
- `references/concise-planning.md`
- `references/antigravity.md`
- `adapters/opencode/AGENTS.singlefile.template`
- `adapters/opencode/AGENTS.md.template`
- `adapters/opencode/MCP_SETUP.md`
- `adapters/codex/AGENTS.bootstrap.template`
- `scripts/install-agent-pack.ps1`
- `SKILL.md`
- `agents/openai.yaml`

## References
- `references/` is not just a notes folder.
- Each file in `references/` is a curated local reference with a specific use and upstream provenance.
- Open `references/SOURCE_INDEX.md` first to see what each local reference maps to on GitHub and when to use it.
- Prefer the local curated reference before re-browsing the upstream GitHub source when the local file already covers the task.

## Purpose
- keep retrieval order consistent with `chub`, `Context7` fallback, and `Serena`
- standardize context hygiene for long-running agent sessions
- keep the short GPT-5.4 token cost summary behavior available
- make the BD68 profile portable without requiring non-Codex IDEs to inspect `.codex`

## New Machine Quickstart
For a clean Windows machine:

1. Install the runtime prerequisites:
- `PowerShell 7`
- `Node.js` (`npm`, `npx`)
- `Python` with `uvx`
- Codex desktop app or OpenCode, depending on your target IDE

2. Clone this repo:
```powershell
git clone https://github.com/PNBachDuong/bd68-dev-v1-0.git
cd bd68-dev-v1-0
```

3. Install the adapter you want:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-agent-pack.ps1 -Target codex
```
or:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-agent-pack.ps1 -Target opencode
```

4. Open a new app session.

What you should get on Codex:
- `bd_dev_kit` as the core operating profile
- bundled skills copied into `~/.codex/skills/`
- `MEMORY.md` and `USER.md` created under `~/.codex/memories/`
- `chub`, `context7`, and `serena` restored from the MCP snapshot

## How The Kit Works
This kit has 4 layers:

1. Core profile:
- `bd_dev_kit` defines the operating rules: retrieval order, planning style, context hygiene, and installation policy.

2. Bundled skills:
- these are reusable tactics that the core profile can activate for specific jobs such as debugging, codebase reading, or test-first work.

3. MCP layer:
- `chub`, `context7`, and `serena` provide runtime capabilities for docs and local code work.
- on Codex, these are snapshot-managed through `templates/codex.mcp_servers.toml`.

4. Memory layer:
- `~/.codex/memories/MEMORY.md`
- `~/.codex/memories/USER.md`
- this replaces the older memory-MCP-heavy approach with a simpler local file model.

Operationally, the preferred path is:
`rg` -> narrow file discovery -> `serena` for deeper local code retrieval/edit -> `chub` for third-party docs -> `context7` only when `chub` is insufficient.

## Skill And MCP Map
Core profile:
- `bd_dev_kit`: the main operating system for the workflow

Bundled skills in this repo:
- `codebase-inspection`: read and understand code structure before editing
- `context-compression`: compress oversized context when needed
- `context-optimization`: reduce waste in context assembly
- `context-window-management`: keep long threads healthy
- `gstack-lite`: lightweight phase gates for larger tasks
- `hierarchical-agent-memory`: legacy reference only, not a default runtime path
- `mcporter`: workflow guidance for working with MCP servers/tools
- `prompt-caching`: caching strategy guidance for repetitive workloads
- `systematic-debugging`: root-cause-first debugging workflow
- `test-driven-development`: test-first implementation and regression control

Hermes-imported skills currently bundled:
- `codebase-inspection`
- `systematic-debugging`
- `test-driven-development`
- `mcporter`

Snapshot-managed MCPs on Codex:
- `chub`: primary third-party docs retrieval
- `context7`: fallback docs retrieval via `npx @upstash/context7-mcp`
- `serena`: local code retrieval/edit via `uvx --from git+https://github.com/oraios/serena@...`

## Workflow Simulation
Example task:
- "Fix duplicate Stripe webhook handling, add tests, then prepare to ship."

Expected flow:
1. `bd_dev_kit` sets the operating rules.
2. `chub` retrieves Stripe docs before any API-shape assumptions.
3. `rg` narrows the local search to webhook handlers, services, and tests.
4. `codebase-inspection` helps map the current code flow.
5. `systematic-debugging` drives root-cause analysis instead of guesswork.
6. `serena` is used when symbol-level reading or precise code edits are needed.
7. `test-driven-development` guides writing regression tests before or during the fix.
8. `gstack-lite` is only used if the task is large enough to justify phase gates.
9. If a new MCP is added during the session, rerun Codex install so the source snapshot is updated for the next machine.

This means:
- the core profile decides how to work
- the skills decide how to tackle the current class of problem
- the MCPs provide runtime capabilities
- the memory files preserve stable context across sessions

## Project Overlay (Multi-Project Support)

BD68 Dev hỗ trợ nhiều project song song thông qua per-project overlay files.

### Setup project mới
```powershell
# Trong thư mục project:
powershell -ExecutionPolicy Bypass -File .\scripts\install-agent-pack.ps1 -InitProject -ProjectName "my-project"
```

Lệnh này tạo `.bd68/PROJECT.md` trong thư mục hiện tại từ template.

### Cách hoạt động
- Global profile (`~/.codex/skills/bd_dev_kit/core/BD68_PROFILE.md`) load trước — áp dụng cho mọi project
- Project overlay (`.bd68/PROJECT.md`) load sau — override global nơi cần thiết
- Agent tự detect overlay khi session bắt đầu

### Git tracking
- Commit `.bd68/PROJECT.md` nếu cả team cần dùng chung overlay
- Thêm `.bd68/` vào `.gitignore` nếu overlay là cấu hình cá nhân

### Template
Xem `templates/PROJECT.md` để hiểu các sections có sẵn.

## 5-Skill Add-on Default
- Priority order: `giam ao giac -> toi uu ngu canh -> giam token`.
- Do not run all 5 skills all-ways-on.
- Always-on core: `context-optimization`, `context-window-management`.
- Conditional: `context-compression` (`Input >= 120k`, OFF after `<= 90k` for 3 turns), `prompt-caching` (ON when repetitive + cache hit `>= 30%`, OFF when `<= 20%` for 2 windows), `hierarchical-agent-memory` (default OFF; only ON for stable multi-session tasks).
- If retrieval has no verifiable evidence, respond `không đủ dữ liệu` instead of guessing.

## OpenCode Install
Install the OpenCode adapter on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-agent-pack.ps1 -Target opencode
```

What it does:
- copies the shared profile from `core/`
- copies shared references from `references/`
- writes the OpenCode bootstrap from `adapters/opencode/`
- updates `C:\Users\<user>\.config\opencode\AGENTS.md` in single-file mode

After the command completes, open a new OpenCode session to load the profile.

## Codex Install (Clean-Machine Friendly)
Install the Codex adapter on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-agent-pack.ps1 -Target codex
```

What it does:
- syncs this pack into `C:\Users\<user>\.codex\skills\bd_dev_kit`
- injects/updates a marked bootstrap block in `C:\Users\<user>\.codex\AGENTS.md`
- merges MCP entries from `templates/codex.mcp_servers.toml` into `C:\Users\<user>\.codex\config.toml`
- exports the current runtime MCP set back into `templates/codex.mcp_servers.toml` so the source kit stays portable
- auto-installs MCP binaries for `chub` (best effort, with explicit status output)

Requirement:
- target machine needs internet access
- `node` and `npm` are required to install `chub`
- if MCP install fails and you still want profile setup only, use `-FailOnMcpInstallError:$false`

Useful optional flags:
- `-InstallMcpBinaries:$false` to skip MCP binary installation
- `-FailOnMcpInstallError:$false` to continue install even if MCP installation fails
- `-CodexRootPath <path>` to test against a custom clean directory

MCP portability note:
- `templates/codex.mcp_servers.toml` is the source-of-truth snapshot for Codex MCP entries.
- After adding a new global MCP to `~/.codex/config.toml`, rerun `install-agent-pack.ps1 -Target codex` from this repo to export that MCP back into the source kit.
- Portable commands such as `npx`, `uvx`, and repo-relative launchers move cleanly across machines.
- Machine-specific absolute paths may still need manual adjustment on the new machine.

After the command completes, open a new Codex thread (or restart app) to ensure runtime picks up the updated profile.

