# Playnite ↔ GlazeWM TODO

## Pause GlazeWM during games (ONLY IF a game misbehaves)

Background: games already **float by default** under the opt-in window_rules model,
so GlazeWM does not tile/fight them. A pause script is only needed if a *specific*
game flickers, gets resized, or loses fullscreen with GlazeWM running.

**Do NOT use `wm-exit`** — exiting cloaks (hides) windows on non-visible workspaces
and does NOT reliably un-hide them (known bug glzr-io/glazewm#79). Windows would
vanish until manually recovered.

**Use `wm-toggle-pause`** — suspends management, leaves all windows in place.

### Implementation (prefer PER-GAME, not global)
Playnite supports pre/post-game scripts (per-game or global, in PowerShell).

- Pre-game script:
  `& "C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe" command wm-toggle-pause`
- Post-game script (toggle back):
  `& "C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe" command wm-toggle-pause`

Risk with global toggle: if pause state desyncs (game crash skips post-script),
the toggle could leave GlazeWM paused or unpause mid-session. A guarded version
should QUERY state first rather than blind-toggle. Revisit only if needed.

Decision: defer until a real game misbehaves. Most likely never needed.
