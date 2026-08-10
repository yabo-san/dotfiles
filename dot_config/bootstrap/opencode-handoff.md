# opencode coding stack — runbook / handoff

Your Claude-Code replacement. Default model is **ollama on yabohome** (tailscale
`100.70.242.116:11434`).

```
opencode (Claude-Code-style TUI)          <- you type here (`dormin`)
   └─ provider "ollama" -> http://100.70.242.116:11434/v1   (DEFAULT: qwen3:8b-16k)
```

## Why the default is `qwen3:8b-16k`, not stock `qwen3:14b`

Stock qwen3 breaks opencode's tool-calling loop in **two** ways, both silent,
and the naive fix has a VRAM trap that a third bug — see below — made fatal.

1. **Ollama's default context is tiny (4096 tokens).** opencode's agent loop sends
   tool-calling instructions that blow past it within a few turns → the model
   "loses the session" and hallucinates junk tool calls (e.g. reading
   `/absolute/path/to/file.txt`). The fix everyone uses: bake `num_ctx` into a
   Modelfile variant, because env vars get overridden by Ollama's VRAM
   auto-detection but a Modelfile `PARAMETER` cannot.
2. **Qwen3 thinking mode leaks** into the transcript and corrupts tool calls.
   Verified: same model, `think: false` → perfectly-formed tool call. The config
   passes it via `"options": { "think": false }`.

**VRAM trap (why 8B, not 14B).** The 14B weights are 9.3 GB; the KV cache is
proportional to context. `qwen3:14b-opencode` at 32k resident = **13.7 GB VRAM**.
On a 16 GB card that's a *dedicated-GPU* model: the moment Godot (or anything
else) wants VRAM, opencode crashed and the whole desktop lagged. Measured options:

| model | VRAM at 16k | VRAM at 32k |
|---|---|---|
| `qwen3:8b` | **7.2 GB** | 9.5 GB |
| `qwen3:14b` | ~11.4 GB | 13.7 GB |

`qwen3:8b-16k` (7.2 GB) leaves ~9 GB for Godot + desktop + terminal. It tool-calls
identically to the 14B — same qwen3 family, `think: false` verified clean.
Do **not** drop below qwen3 class: `qwen2.5-coder` (4.7 GB) emits the tool call as
plain text with no `tool_calls` field — opencode cannot execute it.

`num_ctx` is a **ceiling, not a fixed cost** — a short prompt is just as fast; the
only real cost is VRAM for the KV cache. No re-quant needed — qwen3 is already
Q4_K_M from Ollama and squeezing it further hurts it.

### The one-time recipe (per machine that runs the model — i.e. yabohome/Windows)

```pwsh
# Modelfile (2 lines is the whole fix)
"FROM qwen3:8b
PARAMETER num_ctx 16384" | Set-Content "$env:TEMP\Modelfile.qwen3"
ollama pull qwen3:8b
ollama create qwen3:8b-16k -f "$env:TEMP\Modelfile.qwen3"
```
Then `opencode.json` references `qwen3:8b-16k` with `"options": { "think": false }`.
That's it — there is deliberately **no auto-install** anywhere; this is a paste-in
recipe, re-run it whenever you re-set up a machine. If you ever want the 14B back,
same recipe with `FROM qwen3:14b` / `num_ctx 16384` and edit the two model refs.



- **opencode** — the agent/UI. Installed via `anomalyco/tap/opencode` (mac) / `scoop install opencode` (win).
- **ollama** — runs headless on `yabohome` (this Windows box), bound to the tailscale IP only. Model loads on first request, unloads after ~5 min idle — zero VRAM when dormant. Reach it from any tailnet node.

## Daily use
```
dormin                 # opens the opencode TUI (default model: ollama on yabohome)
dormin "do X and Y"    # one-shot query, non-interactive
```
`dormin` lives in `dot_zshrc` and the PowerShell profile. It just calls opencode —
ollama is a daemon, nothing to auto-start.

## The server (Windows box)
- Runs headless via `setup-opencode.ps1`: `ollama serve` bound to `OLLAMA_HOST=100.70.242.116`.
- This is the ONLY box that runs models. The Mac is a thin client over tailscale.
- Control:
  - `ollama list`  — installed models
  - `ollama pull qwen3:8b`  — add a model
  - `OLLAMA_HOST=0.0.0.0` would expose it to the whole LAN — don't. Tailscale IP only.
- Dormancy is built in: the model loads into VRAM on the first request and unloads
  after `OLLAMA_KEEP_ALIVE` (default 5 m). Idle footprint is the ~200 MB daemon.

## First-time setup on a NEW machine
- **Mac/Linux (thin client)** — `bash ~/.config/bootstrap/setup-opencode.sh`. Writes
  `~/.config/opencode/opencode.json` pointing at ollama on yabohome over tailscale.
  Downloads **nothing** — no ollama, no models. All compute happens on yabohome.
- **Windows (the server)** — `pwsh ~\.config\bootstrap\setup-opencode.ps1`. Runs
  `ollama serve`, and `qwen3:8b-16k` must exist here (see recipe above).
1. Install packages first: `brew bundle` (mac) or `scoop import` + `winget import` (win).
2. Run the setup script for that machine's role.
3. `dormin`.

## Switching models / adding providers
- Ollama models: `ollama pull <model>`, then edit `"models"` + `"model"` in
  `~/.config/opencode/opencode.json`. Or per-session: `opencode -m ollama/qwen3:8b-16k`.
- Add any OpenAI-compatible backend (Lumo, Kimi, LM Studio) as a second `provider`
  block with its `baseURL` — same `dormin`, pick per task.

## Fit notes for your workload (game-dev "make it JSON-driven" refactors)
- qwen3:8b is a local model — a step below the frontier hosts, but free, private,
  and uncapped. **Scope prompts by subsystem/file**, not whole-engine.
- Your "prompt a batch, then review the diff" workflow is the forgiving one — your
  spec + your review carry it.
- `./status.sh` ALL GREEN before every commit (sim-core rule). The gate is the safety net.

## Files
- `~/.config/opencode/opencode.json` — opencode provider + default model + permissions.
- `~/.config/opencode/AGENTS.md` — global agent rules (incl. "clone+grep repos, don't HTTP-fetch").
- `dot_zshrc` / PowerShell profile — the `dormin` function.
- `Brewfile` / `scoopfile.json` — opencode + ollama.
- `dot_config/bootstrap/setup-opencode.{sh,ps1}` — one-command bootstrap for a fresh machine.
