# BD68 Dev v1.1

`BD68 Dev v1.1` la bo kit agent portable, doc lap IDE cho workflow WildSoul. Goi nay chuan hoa quy trinh retrieval-first (`memoryai -> chub -> vfs`), planning ngan gon, va dung bo reference local da curate kem provenance de lam viec nhanh va on dinh; cac repo tong hop nhu `awesome-llm-apps` chi dung de tham khao y tuong, con implement luon bam docs chinh thuc.

This repo is now organized as an IDE-agnostic pack:
- `core/` is the source of truth for the shared operating profile
- `references/` contains curated GitHub-backed retrieval sources and optional guidance files
- `adapters/` contains IDE-specific bootstrap files
- `scripts/` contains installers or helper scripts
  - `scripts/codex_guard_send.ps1`: preflight payload budget check + auto mode selection (`Safe/Balanced/Aggressive`)
  - `scripts/context_guard_proxy.js`: local runtime proxy for automatic pre-send guard enforcement
  - `scripts/context_guard_proxy_metrics.ps1`: read latest proxy input/output token metrics from runtime log
  - `scripts/start_context_guard_proxy.ps1`: start proxy (foreground or `-Background`)
  - `scripts/enable_context_guard_proxy.ps1`: point global Codex `llmgate` base_url to the local proxy
  - `scripts/disable_context_guard_proxy.ps1`: rollback global Codex config from backup

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
- keep retrieval order consistent with `memoryai`, `chub`, and `vfs`
- standardize context hygiene for long-running agent sessions
- keep the short GPT-5.4 token cost summary behavior available
- make the BD68 profile portable without requiring non-Codex IDEs to inspect `.codex`

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
- syncs this pack into `C:\Users\<user>\.codex\skills\bd68-dev-v1-0`
- injects/updates a marked bootstrap block in `C:\Users\<user>\.codex\AGENTS.md`
- auto-installs MCP binaries for `memoryai`, `chub`, and `vfs` (best effort, with explicit status output)
- sets proxy runtime base URL to `http://127.0.0.1:8787` under `[model_providers.llmgate]`
- creates `config.toml` or missing llmgate section automatically if not present
- creates a backup when `config.toml` already exists
- optionally registers a startup launcher and can start proxy immediately

Requirement:
- target machine needs internet access
- `node` and `npm` are required to install `memoryai/chub` and to run proxy runtime (`context_guard_proxy.js`)
- vfs is installed from GitHub release when missing (`TrNgTien/vfs`)
- if MCP install fails and you still want profile/proxy setup only, use `-FailOnMcpInstallError:$false`

Useful optional flags:
- `-EnableProxy:$false` to install profile only, without proxy config changes
- `-InstallMcpBinaries:$false` to skip MCP binary installation
- `-FailOnMcpInstallError:$false` to continue install even if MCP installation fails
- `-RegisterProxyStartup:$false` to skip startup launcher creation
- `-StartProxyNow:$false` to skip immediate proxy start/health wait
- `-CodexRootPath <path>` to test against a custom clean directory

After the command completes, open a new Codex thread (or restart app) to ensure runtime picks up the updated profile and proxy route.
