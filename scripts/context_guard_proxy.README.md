# Context Guard Runtime Proxy

Files:
- `scripts/context_guard_proxy.js`
- `scripts/start_context_guard_proxy.ps1`
- `scripts/stop_context_guard_proxy.ps1`
- `scripts/enable_context_guard_proxy.ps1`
- `scripts/disable_context_guard_proxy.ps1`
- `scripts/context_guard_proxy_trace.ps1`

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

Trace latest pipeline metrics:
```powershell
.\scripts\context_guard_proxy_trace.ps1 | Format-List *
```

Auto failover status (default: enabled):
```powershell
.\scripts\context_guard_proxy_status.ps1 | Format-List *
```
- If proxy is down and config currently points to `http://127.0.0.1:8787`, it auto-switches to `https://llmgate.app/v1`.
- If proxy is up and config currently points to direct llmgate, it auto-switches back to proxy.

Common StatusLine format (`StatusFormatVersion = v1`):
- `Proxy local: đang bật/tắt | Guard: bật/tắt | Mode: ... | Proxy Input: ... | Proxy Output: ... | trigger mềm: chưa kích hoạt/đã kích hoạt`

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
