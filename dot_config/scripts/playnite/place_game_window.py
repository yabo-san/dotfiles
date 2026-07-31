#!/usr/bin/env python3
r"""
place_game_window.py — put a launched game's window where Playnite says it goes.

Called DETACHED by game-started.ps1 (Playnite's global "Game started script").
It must never run inline: Playnite executes scripts synchronously on its WPF UI
thread, so any polling here would freeze the whole app until it finished.

The contract:
  * Playnite owns the per-game metadata (which display).  Nothing about any
    individual game lives in the GlazeWM config -- that stays generic.
  * We wait for the game's window to exist, hand it to GlazeWM, and put the
    game workspace on the tagged monitor.
  * Games are assumed to launch WINDOWED (Borderless Gaming strips the chrome).
    We never change display mode, resolution, or which monitor is primary --
    that re-anchors the desktop and makes GlazeWM re-layout every monitor.

Monitors are resolved by hardwareId (EDID, e.g. ACR0414), NOT by the \\.\DISPLAYn
GDI name, which is renumbered by driver resets and display-config changes.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import shutil
import subprocess
import sys
import time

LOG_PATH = os.path.join(os.path.expanduser("~"), ".config", "scripts", "playnite", "place-window.log")

WINDOW_TIMEOUT_S = 90.0  # how long to wait for the game to put a window up
POLL_INTERVAL_S = 0.5


def _setup_logging() -> None:
    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    logging.basicConfig(
        filename=LOG_PATH,
        filemode="a",
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )


def _glazewm_exe() -> str:
    found = shutil.which("glazewm")
    if found:
        return found
    fallback = r"C:\Program Files\glzr.io\GlazeWM\glazewm.exe"
    if os.path.exists(fallback):
        return fallback
    raise FileNotFoundError("glazewm.exe not found on PATH or in Program Files")


def _glazewm(*args: str) -> dict:
    """Run a glazewm CLI call and return its parsed JSON response.

    encoding is pinned to UTF-8: GlazeWM emits UTF-8, but Python would otherwise
    decode with the console codepage (cp1252 here) and blow up on the Font
    Awesome glyphs used as workspace display_names.
    """
    proc = subprocess.run(
        [_glazewm_exe(), *args],
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        timeout=15,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"glazewm {' '.join(args)} failed: {(proc.stderr or '').strip()}")
    return json.loads(proc.stdout)


def find_window(process_name: str, timeout: float) -> str | None:
    """Poll GlazeWM until a managed window for `process_name` appears; return its UUID."""
    target = process_name.lower()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            windows = _glazewm("query", "windows")["data"]["windows"]
        except Exception as exc:  # GlazeWM may be mid-restart; keep waiting
            logging.warning("query windows failed (retrying): %s", exc)
            windows = []
        for w in windows:
            if (w.get("processName") or "").lower() == target:
                logging.info("found window %s (%s) for %s", w["id"], w.get("title"), process_name)
                return w["id"]
        time.sleep(POLL_INTERVAL_S)
    return None


def monitors() -> list[dict]:
    """Monitors in GlazeWM index order -- position in this list IS bind_to_monitor."""
    return _glazewm("query", "monitors")["data"]["monitors"]


def _monitor_aliases() -> dict:
    """Friendly monitor names from ~/.config/monitors.json (declared in chezmoi)."""
    path = os.path.join(os.path.expanduser("~"), ".config", "monitors.json")
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError:
        return {}
    except Exception as exc:
        logging.warning("could not read %s: %s", path, exc)
        return {}
    return {k.lower(): v for k, v in (data.get("monitors") or {}).items()}


def resolve_monitor_index(target: str) -> int | None:
    r"""
    Map a target to a live monitor index.

    Accepts, in order of preference:
      * a FRIENDLY NAME from ~/.config/monitors.json ("crt", "ultrawide")
      * hardwareId  (ACR0414, GSM772B)     -- EDID id, stable per model
      * devicePath  (\\?\DISPLAY#...)      -- stable per panel+port
      * deviceName  (\\.\DISPLAY9)         -- Display Helper's format; DRIFTS
      * resolution  (1024x768)             -- last resort, for panels with no EDID

    Prefer friendly names everywhere. GDI names get reassigned by driver resets
    and display-config changes; label a monitor once via the Raycast "Label
    Monitor" command and refer to that name forever after.
    """
    if not target:
        return None
    want = target.strip().lower()
    mons = monitors()

    # Friendly name -> whatever stable ids we recorded for it.
    alias = _monitor_aliases().get(want)
    if alias:
        for key in ("devicePath", "hardwareId"):
            value = (alias.get(key) or "").lower()
            if not value:
                continue
            for idx, mon in enumerate(mons):
                if (mon.get(key) or "").lower() == value:
                    logging.info("target %r -> alias -> monitor %d by %s", target, idx, key)
                    return idx
        res = (alias.get("resolution") or "").lower()
        if res:
            for idx, mon in enumerate(mons):
                if f"{mon.get('width')}x{mon.get('height')}".lower() == res:
                    logging.info("target %r -> alias -> monitor %d by resolution", target, idx)
                    return idx
        logging.warning("target %r is a known label but matched no attached monitor", target)
    for key in ("hardwareId", "devicePath", "deviceName"):
        for idx, mon in enumerate(mons):
            if (mon.get(key) or "").lower() == want:
                logging.info("target %r matched monitor %d by %s", target, idx, key)
                return idx
    # A monitor with no EDID (a CRT on a passive adapter) reports the useless
    # hardwareId 'Default_Monitor', so allow addressing it by resolution.
    for idx, mon in enumerate(mons):
        if f"{mon.get('width')}x{mon.get('height')}".lower() == want:
            logging.info("target %r matched monitor %d by resolution", target, idx)
            return idx
    logging.warning(
        "target %r matched no monitor; available: %s",
        target,
        [(i, m.get("hardwareId"), m.get("deviceName")) for i, m in enumerate(mons)],
    )
    return None


def workspace_location(name: str) -> tuple[str, int] | None:
    """Return (workspace uuid, index of the monitor it currently sits on)."""
    for idx, mon in enumerate(monitors()):
        for ws in mon.get("children", []):
            if ws.get("name") == name:
                return ws["id"], idx
    return None


def move_workspace_to_monitor(ws_name: str, target_index: int) -> None:
    """
    Step a workspace onto `target_index`.

    GlazeWM has no absolute 'move workspace to monitor N' -- MoveWorkspace only
    takes a direction -- so we walk it one monitor at a time. Monitors are
    ordered left-to-right, so the sign of the delta is the direction.
    """
    for _ in range(len(monitors())):
        loc = workspace_location(ws_name)
        if loc is None:
            logging.warning("workspace %s not found while re-homing", ws_name)
            return
        ws_id, current = loc
        if current == target_index:
            return
        direction = "right" if target_index > current else "left"
        _glazewm("command", "--id", ws_id, "move-workspace", "--direction", direction)
        time.sleep(0.15)
    logging.warning("gave up moving workspace %s to monitor %d", ws_name, target_index)


def evacuate_monitor(target_index: int) -> None:
    """
    Clear every workspace off `target_index` and leave the monitor to the game.

    For games that force exclusive fullscreen and pick their own display (via
    Display Helper). We can't stop the display re-anchor those cause, so instead
    we get out of the way: nothing of ours is left on that screen to be shoved
    around, and the other monitors carry on as normal. Generalises evict-crt.ps1.
    """
    # Step away from the target: toward the left neighbour unless we're leftmost.
    direction = "left" if target_index > 0 else "right"
    for _ in range(len(monitors()) * 8):  # bounded; each pass moves at most one
        mons = monitors()
        if target_index >= len(mons):
            return
        occupants = [ws for ws in mons[target_index].get("children", []) if ws.get("name")]
        if not occupants:
            logging.info("monitor %d evacuated", target_index)
            return
        ws = occupants[0]
        logging.info("evicting workspace %s from monitor %d (%s)", ws.get("name"), target_index, direction)
        _glazewm("command", "--id", ws["id"], "move-workspace", "--direction", direction)
        time.sleep(0.15)
    logging.warning("could not fully evacuate monitor %d", target_index)


def main() -> int:
    parser = argparse.ArgumentParser(description="Place a game window via GlazeWM.")
    parser.add_argument("--process", default="", help="process name of the game (no .exe); 'place' mode only")
    parser.add_argument("--workspace", default="8", help="GlazeWM workspace to host the game")
    parser.add_argument("--target", default="", help="monitor hardwareId / devicePath / deviceName")
    parser.add_argument("--game", default="", help="game name, for the workspace label and logs")
    parser.add_argument("--timeout", type=float, default=WINDOW_TIMEOUT_S)
    parser.add_argument(
        "--mode",
        choices=("place", "evacuate", "home"),
        default="place",
        help=(
            "place    = wait for the game window and host it on a workspace; "
            "evacuate = clear every workspace off a monitor and hands off; "
            "home     = move one workspace onto a monitor (no window involved)"
        ),
    )
    args = parser.parse_args()

    _setup_logging()
    logging.info(
        "--- %s | mode=%s process=%s target=%r ws=%s",
        args.game or "?", args.mode, args.process, args.target, args.workspace,
    )

    if args.mode == "home":
        # Used by the monitor Raycast scripts, not by Playnite.
        target_index = resolve_monitor_index(args.target)
        if target_index is None:
            logging.error("home: no target monitor resolved from %r", args.target)
            return 1
        move_workspace_to_monitor(args.workspace, target_index)
        return 0

    if args.mode == "evacuate":
        # The game owns the screen. Don't touch its window at all -- managing an
        # exclusive-fullscreen window means DWM border calls on it, which is what
        # crashes Unreal and breaks DirectInput grabs.
        target_index = resolve_monitor_index(args.target)
        if target_index is None:
            logging.error("evacuate: no target monitor resolved from %r", args.target)
            return 1
        evacuate_monitor(target_index)
        return 0

    if not args.process:
        parser.error("--process is required for --mode place")

    window_id = find_window(args.process, args.timeout)
    if window_id is None:
        logging.error("no window for %s after %.0fs -- giving up", args.process, args.timeout)
        return 1

    # Home the game first, so the workspace exists before we try to move it.
    _glazewm("command", "--id", window_id, "move", "--workspace", args.workspace)

    if args.target:
        target_index = resolve_monitor_index(args.target)
        if target_index is not None:
            move_workspace_to_monitor(args.workspace, target_index)

    if args.game:
        # Label the workspace so the bar shows what's running.
        loc = workspace_location(args.workspace)
        if loc:
            _glazewm("command", "--id", loc[0], "update-workspace-config", "--display-name", args.game)

    # maximized=false is required: the default (true) calls Win32 maximize, which
    # silently does nothing on windows lacking WS_MAXIMIZEBOX -- i.e. most games.
    _glazewm("command", "--id", window_id, "set-fullscreen", "--maximized=false")

    logging.info("placed %s on workspace %s", args.process, args.workspace)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        _setup_logging()
        logging.exception("unhandled error")
        sys.exit(1)
