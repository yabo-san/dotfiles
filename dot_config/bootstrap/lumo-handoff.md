# Lumo coding stack — runbook / handoff

Your Claude-Code replacement, running on Proton Lumo. Everything here is verified working
on macOS as of 2026-07-29 (real Lumo round-trips + a passing tool-call test).

```
opencode (Claude-Code-style TUI)          <- you type here (`dormin`)
   └─ provider "lumo-tamer" -> http://localhost:3003/v1
        └─ lumo-tamer (local OpenAI-compatible proxy)
             └─ Proton Lumo   (auth: SRP login, auto-refresh, key in OS keychain)
```

- **opencode** — the agent/UI. Installed via `anomalyco/tap/opencode` (mac) / `scoop install opencode` (win).
- **lumo-tamer** — `~/lumo-tamer`, a local proxy that speaks the OpenAI API and forwards to Lumo. Run `git pull` to update.
- **go** — only needed to build lumo-tamer's `proton-auth` (SRP login) binary.

## Daily use
```
dormin                 # opens the opencode TUI on Lumo (auto-starts the backend if down)
dormin "do X and Y"    # one-shot query, non-interactive
```
`dormin` lives in `dot_zshrc` and the PowerShell profile. It curls :3003 to see if the backend
is up; if not, it starts `node dist/src/tamer.js server` detached.

## Always-on backend (launchd, macOS)
The lumo-tamer server runs as a launchd agent so it's always up (survives reboots, restarts on
crash, refreshes tokens 24/7) — no cold start, and `dormin` never needs to launch it.
- Plist: `~/Library/LaunchAgents/com.yabo.lumo-tamer.plist` (chezmoi-managed, mac-only; auto-loaded by a run_onchange script on `chezmoi apply`).
- Controls:
  - `launchctl list | grep lumo-tamer`  — status (2nd column 0 = healthy)
  - `launchctl unload ~/Library/LaunchAgents/com.yabo.lumo-tamer.plist`  — stop
  - `launchctl load -w ~/Library/LaunchAgents/com.yabo.lumo-tamer.plist`  — start
- First load reads the vault key from the login keychain — click **Always Allow** once.
- Not on macOS? Skip this; `dormin` auto-starts the server on demand instead.

## First-time setup on a NEW machine
1. Install packages: `brew bundle` (mac) or `scoop import` + `winget import` (win).
2. Build + configure the stack:  `bash ~/.config/bootstrap/setup-lumo.sh`  (or `setup-lumo.ps1` on win).
   - Generates a random local API key, writes `~/lumo-tamer/config.yaml` and `~/.config/opencode/opencode.json`.
   - Secrets are NOT in the dotfiles git — they're generated per machine.
3. Log in to Proton once:  `cd ~/lumo-tamer && tamer auth login`  (username, password, TOTP).
4. `dormin`.

## Auth & refresh (why you rarely re-login)
- Access token lasts ~12h. lumo-tamer auto-refreshes every 8h while running, and on any 401.
- Token/vault live in `~/lumo-tamer/sessions/vault.enc`, encrypted with a key in your OS keychain.
- Manual refresh: `curl -X POST localhost:3003/v1/auth/refresh -H "Authorization: Bearer <key>"` — verified to bump expiry ~12h -> 24h.
- **You only re-run `tamer auth login` if:** you revoke the session in Proton, change your Proton
  password, or leave it unused long enough for the refresh token to lapse (weeks, not hours).
- First `dormin` after a long gap may pause ~1s while it refreshes on the first request. Normal.

## Switching models / adding providers
- Lumo tiers: edit `"model"` in `~/.config/opencode/opencode.json` to `lumo-tamer/lumo` (auto),
  `lumo-tamer/lumo-max` (strongest), or `lumo-tamer/lumo-lite` (fastest). Or `opencode -m lumo-tamer/lumo-max`.
- Add **Kimi** (Moonshot, stronger for coding): add a second `provider` block with
  `baseURL: https://api.moonshot.ai/v1` and your Moonshot key. Same `dormin`, pick per task.
- Add a **local/offline** model: run Ollama or LM Studio, add a provider with
  `baseURL: http://localhost:11434/v1` (Ollama) and any coder model (Qwen2.5-Coder-32B, Devstral, GLM-4).

## Gotchas we hit (so you don't rediscover them)
- **"check server logs" / connection error** = backend not running OR not authed. lumo-tamer FATALS on
  boot if the vault is missing — do `tamer auth login`. Check `/tmp/lumo-tamer.log`.
- **`dormin` with no args used to crash** (`got "dummy"`): opencode's `--continue` fails when there's no
  prior session. Fixed — bare `dormin` now just opens the TUI. Pick an old session inside the TUI.
- **macOS keychain password prompt from `node`**: that's the OS gating access to the vault key, not node
  stealing anything. Click **Always Allow** for the `lumo-tamer` item to stop the prompts.
- **Mock mode** (`test.mock.enabled`) crashes with `ConversationStore not initialized` unless you also set
  `conversations.useFallbackStore: false`. Only relevant for offline testing.

## Fit notes for your workload (game-dev "make it JSON-driven" refactors)
- Tool-calling through Lumo works cleanly (tested). The real limiter is Lumo's **context window** (~22K-token warning).
- Your "prompt a batch, then review the diff" workflow is the forgiving one — your spec + your review carry it.
- **Scope prompts by subsystem/file**, not whole-engine. "Extract enemy stats in `enemy.gd` into `enemies.json`
  + add a loader" = fine. "Make the entire engine data-driven in one go" = overflows context; it loses track.
- For big multi-file sweeps, switch that session to `lumo-max` or a bigger-context provider (Kimi / local coder).
- Honest quality bar: Lumo (and self-hostable coders) are a step below Claude. Roughly a tie with each other;
  Lumo Max is Proton's strongest tier; local coders win on privacy/no-limits at similar quality.

## Files
- `~/lumo-tamer/config.yaml` — proxy config (generated; has the local API key).
- `~/.config/opencode/opencode.json` — opencode provider + default model + permissions.
- `~/.config/opencode/AGENTS.md` — global agent rules (incl. "clone+grep repos, don't HTTP-fetch").
- `dot_zshrc` / PowerShell profile — the `dormin` function.
- `Brewfile` / `scoopfile.json` — opencode + go.
- `dot_config/bootstrap/setup-lumo.{sh,ps1}` — one-command bootstrap for a fresh machine.
- `Library/LaunchAgents/com.yabo.lumo-tamer.plist` — always-on backend service (macOS only).
