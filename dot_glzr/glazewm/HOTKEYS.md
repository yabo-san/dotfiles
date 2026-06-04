# GlazeWM Hotkeys — my config, plain English

> The confusing part is GlazeWM, so this documents GlazeWM. The other two key
> systems (AutoHotkey backtick, Raycast) are just there to recreate my mac
> setup — noted at the bottom, not the focus.

---

## The ONE rule that explains all of it

> **`lwin` (Windows key) = the GlazeWM trigger.**
> **Add `shift` and it flips from "go / do" to "move / send".**
>
> - `lwin` + **letter** → do something to the focused **window**
> - `lwin` + **number** → go to a **workspace**
> - `+ shift` → **send/move** instead of go/focus

Everything below is just that rule applied.

---

## Workspaces

A workspace = one screenful of windows you flip between. Four named, each pinned
to a monitor:

| # | Name | Monitor |
|---|------|---------|
| 1 | main | ultrawide (21:9) |
| 2 | texting | Acer (16:9) |
| 3 | music | Acer (16:9) |
| 4 | gamedev | ultrawide (21:9) |
| 5–9 | overflow | focused monitor |

**The two actions people mix up:**

| Key | Plain English |
|-----|---------------|
| `lwin + 1…9` | **I go to** that workspace (teleport me) |
| `lwin + shift + 1…9` | **send the window** to that workspace + follow it |
| `lwin + s` / `lwin + a` | next / previous workspace |
| `lwin + tab` | jump to the workspace I was just on |
| `lwin + shift + a / f / d` | move the **whole workspace** to monitor left / right / up |

> Mnemonic: **bare number = move ME. shift+number = move the WINDOW.**

---

## The focused window

### Move it (vim hjkl)
| Key | Direction |
|-----|-----------|
| `lwin + h` | left |
| `lwin + j` | down |
| `lwin + k` | up |
| `lwin + shift + l` | right ⚠️ |

⚠️ Right is `lwin+shift+l`, NOT `lwin+l` — Windows reserves `Win+L` for lock at a
level GlazeWM can't touch. (`Win+L` is bridged to move-right via Raycast instead.)

### Resize it
| Key | Effect |
|-----|--------|
| `lwin + u` / `lwin + p` | thinner / wider |
| `lwin + o` / `lwin + i` | taller / shorter |

### Change its mode (tiling / floating / fullscreen)
| Key | Effect |
|-----|--------|
| `lwin + t` | **tile** it (snap into the grid) |
| `lwin + shift + space` | **float** it (free-floating, centered) |
| `lwin + m` | **fullscreen** |
| `lwin + shift + m` | **minimize** |
| `lwin + space` | cycle focus: tiling → floating → fullscreen |
| `lwin + v` | flip tiling direction (next window opens beside vs below) |
| `lwin + shift + q` | **close** the window |

> tiling vs floating: **tiling** = GlazeWM auto-arranges it in the grid.
> **floating** = normal free window, GlazeWM leaves its size/position alone.
> (Your default is float — only allowlisted apps tile.)

---

## Control GlazeWM itself
| Key | Effect |
|-----|--------|
| `lwin + shift + p` | **pause** GlazeWM (freezes ALL binds until pressed again) |
| `lwin + shift + r` | reload config (after editing config.yaml) |
| `lwin + shift + w` | redraw all windows (if layout glitches) |
| `lwin + shift + e` | quit GlazeWM |

---

## NOT GlazeWM (so stop looking for these in config.yaml)

These recreate the mac setup; they live in other tools, not GlazeWM:

| Key | Does | Owned by |
|-----|------|----------|
| `` ` `` (bare backtick) | toggle the WezTerm quake dropdown | AutoHotkey (`quake-hotkey.ahk`) |
| `ctrl + ` ` `` | type a literal backtick | AutoHotkey |
| `alt + space` | open Raycast launcher | Raycast |
| `Win + L` | move window right (bridge for the key GlazeWM can't have) | Raycast → GlazeWM CLI |

See `WIN-L-BRIDGE.md` for the Win+L registry+Raycast details.

---

## TL;DR cheat card

```
lwin + h/j/k/l ......... move window  (right = lwin+shift+l)
lwin + u/p/o/i ......... resize window
lwin + t ............... tile      lwin+shift+space ... float
lwin + m ............... fullscreen  lwin+shift+m ..... minimize
lwin + shift + q ....... close window
lwin + 1..9 ............ GO TO workspace N
lwin + shift + 1..9 .... SEND window to workspace N
lwin + s / a / tab ..... next / prev / recent workspace
lwin + shift + a/f/d ... move workspace to monitor L/R/U
lwin + shift + p ....... pause    lwin+shift+r ... reload
`  = quake term   |   ctrl+` = literal `   |   alt+space = Raycast
```
