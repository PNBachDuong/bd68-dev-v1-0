# Context Guard Runtime Proxy

Files:
- `scripts/context_guard_proxy.js`
- `scripts/start_context_guard_proxy.ps1`
- `scripts/stop_context_guard_proxy.ps1`
- `scripts/enable_context_guard_proxy.ps1`
- `scripts/disable_context_guard_proxy.ps1`

## What it does
- Adds a local HTTP proxy in front of `llmgate`.
- Computes preflight payload estimate from real request body.
- Auto applies guard by thresholds:
  - `< 200,000`: monitor only
  - `>= 200,000`: apply `Balanced` by default (can disable)
  - `>= 240,000`: apply `Balanced`
  - `>= 250,000`: apply `Aggressive`
- Forwards request to upstream and returns upstream response.

## Start proxy
Recommended (foreground in a dedicated terminal):
```powershell
.\scripts\start_context_guard_proxy.ps1
```

Optional background mode:
```powershell
.\scripts\start_context_guard_proxy.ps1 -Background
```

Disable apply-at-soft behavior:
```powershell
.\scripts\start_context_guard_proxy.ps1 -DisableApplyAtSoftThreshold
```

Health check:
```powershell
curl.exe -s http://127.0.0.1:8787/__guard/health
```

## Enable in Codex global config
```powershell
.\scripts\enable_context_guard_proxy.ps1
```

This updates:
- `C:\Users\ngath\.codex\config.toml`
- backup at `C:\Users\ngath\.codex\config.toml.context-guard.bak`

Note:
- Default proxy base URL is `http://127.0.0.1:8787` (without `/v1`) to avoid path duplication.

## Disable / rollback
```powershell
.\scripts\disable_context_guard_proxy.ps1
.\scripts\stop_context_guard_proxy.ps1
```

## Notes
- Keep proxy running while Codex desktop is active.
- If Codex is already open, restart app or open a new thread/session to pick up changed `base_url`.
