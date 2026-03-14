# BD68 Dev v1.1

`BD68 Dev v1.1` la bo kit agent portable, doc lap IDE cho workflow WildSoul. Goi nay chuan hoa quy trinh retrieval-first (chub lam baseline docs, Context7 fallback, Serena cho local code), planning ngan gon, va dung bo reference local da curate kem provenance de lam viec nhanh va on dinh; cac repo tong hop nhu `awesome-llm-apps` chi dung de tham khao y tuong, con implement luon bam docs chinh thuc.

This repo is now organized as an IDE-agnostic pack:
- `core/` is the source of truth for the shared operating profile
- `references/` contains curated GitHub-backed retrieval sources and optional guidance files
- `adapters/` contains IDE-specific bootstrap files
- `scripts/` contains installers or helper scripts
  - `scripts/codex_guard_send.ps1`: preflight payload budget check + auto mode selection (`Safe/Balanced/Aggressive`)
  - `scripts/context_guard_thread.js`: local runtime thread route for automatic pre-send guard enforcement
  - `scripts/context_guard_thread_metrics.ps1`: read latest thread input/output token metrics from runtime log
  - `scripts/context_guard_thread_trace.ps1`: show pipeline metrics for `input -> thread -> llmgate` and `llmgate -> thread`
  - `scripts/context_guard_thread_status.ps1`: thread health + auto failover switch (`thread -> direct llmgate` when thread is down)
  - `scripts/start_context_guard_thread.ps1`: start thread route (foreground or `-Background`)
  - `scripts/enable_context_guard_thread.ps1`: point global Codex `llmgate` base_url to the local thread route
  - `scripts/disable_context_guard_thread.ps1`: rollback global Codex config from backup

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
- auto-installs MCP binaries for `chub` (best effort, with explicit status output)
- keeps direct llmgate route by default (no thread/proxy auto-enable)
- creates `config.toml` or missing llmgate section automatically if not present
- creates a backup when `config.toml` already exists
- can optionally enable thread route, startup launcher, and immediate health check when explicitly requested

Requirement:
- target machine needs internet access
- `node` and `npm` are required to install `chub` and to run thread runtime (`context_guard_thread.js`)
- if MCP install fails and you still want profile/thread setup only, use `-FailOnMcpInstallError:$false`

Useful optional flags:
- `-EnableProxy:$true` to switch to local thread route (`http://127.0.0.1:8787`)
- `-InstallMcpBinaries:$false` to skip MCP binary installation
- `-FailOnMcpInstallError:$false` to continue install even if MCP installation fails
- `-RegisterProxyStartup:$true` to create startup launcher for thread route
- `-StartProxyNow:$true` to start thread route immediately and run health check
- `-CodexRootPath <path>` to test against a custom clean directory

After the command completes, open a new Codex thread (or restart app) to ensure runtime picks up the updated profile and thread route.

