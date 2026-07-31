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
    # CREATE_NO_WINDOW is essential, not cosmetic: find_window polls every 0.5s
    # for up to 90s, and without it EVERY glazewm call flashes a console window.
    # That is what made PowerShell appear to open and close repeatedly while a
    # game was starting.
    proc = subprocess.run(
        [_glazewm_exe(), *args],
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        timeout=15,
        creationflags=0x08000000,  # CREATE_NO_WINDOW
    )
    if proc.returncode != 0:
        raise RuntimeError(f"glazewm {' '.join(args)} failed: {(proc.stderr or '').strip()}")
    return json.loads(proc.stdout)


def _process_path(hwnd: int) -> str:
    """Full exe path behind a window, via its owning PID."""
    import ctypes
    from ctypes import wintypes

    pid = wintypes.DWORD()
    ctypes.windll.user32.GetWindowThreadProcessId(ctypes.c_void_p(hwnd), ctypes.byref(pid))
    if not pid.value:
        return ""
    # PROCESS_QUERY_LIMITED_INFORMATION — works without elevation, unlike the
    # older PROCESS_QUERY_INFORMATION.
    handle = ctypes.windll.kernel32.OpenProcess(0x1000, False, pid.value)
    if not handle:
        return ""
    try:
        size = wintypes.DWORD(32768)
        buf = ctypes.create_unicode_buffer(size.value)
        if ctypes.windll.kernel32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size)):
            return buf.value
        return ""
    finally:
        ctypes.windll.kernel32.CloseHandle(handle)


def find_window(
    process_name: str, timeout: float, install_dir: str = ""
) -> tuple[str, int] | tuple[None, None]:
    r"""
    Poll GlazeWM until the game's window appears. Returns (uuid, hwnd).

    MATCHING BY INSTALL DIRECTORY IS THE PRIMARY PATH, and it is lifted straight
    from how Playnite's own Steam plugin does it —
    SteamLibrary/SteamGameController.cs:198 calls
    `procMon.WatchDirectoryProcesses(installDirectory, false)` and reports
    whatever process tree starts in there. It never tracks the launched pid.

    That is also exactly why $StartedProcessId is useless for Steam titles: for
    Dishonored it reported `vcredist_x64`, because
    ...\common\Dishonored\Binaries\Redist\vcredist_x64.exe lives INSIDE the
    install directory and the monitor caught it first. Matching on the directory
    but requiring a real WINDOW skips redists, installers and other prerequisites
    for free, since they either have no window or are long gone by then.

    Falls back to process-name matching when no install dir is known.
    """
    root = os.path.normcase(os.path.abspath(install_dir)) if install_dir else ""
    target = process_name.lower() if process_name else ""
    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        for hwnd in _visible_windows():
            path = _process_path(hwnd)
            if not path:
                continue

            hit = False
            if root and os.path.normcase(path).startswith(root):
                hit = True
                why = f"install dir ({path})"
            elif target and os.path.splitext(os.path.basename(path))[0].lower() == target:
                hit = True
                why = f"process name ({path})"

            if hit:
                logging.info("matched by %s", why)
                return _glazewm_id_for(hwnd), hwnd

        time.sleep(POLL_INTERVAL_S)

    logging.error(
        "no window after %.0fs (install_dir=%r process=%r)", timeout, install_dir, process_name
    )
    return None, None


def _visible_windows() -> list[int]:
    """
    Every visible top-level window, straight from Win32.

    Deliberately NOT `glazewm query windows`: that only lists windows GlazeWM has
    already CLAIMED. A game that hasn't been managed yet — or one that is
    explicitly ignored — is invisible to it, so the game would never be found.
    Enumerate ourselves, then ask GlazeWM about the window afterwards.
    """
    import ctypes

    found: list[int] = []
    user32 = ctypes.windll.user32
    proto = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def cb(hwnd, _):
        if user32.IsWindowVisible(ctypes.c_void_p(hwnd)):
            found.append(hwnd)
        return True

    user32.EnumWindows(proto(cb), None)
    return found


def _glazewm_id_for(hwnd: int) -> str | None:
    """GlazeWM's container uuid for a window, or None if it isn't managing it."""
    try:
        for w in _glazewm("query", "windows")["data"]["windows"]:
            if int(w.get("handle") or 0) == hwnd:
                return w["id"]
    except Exception as exc:
        logging.warning("could not resolve glazewm id: %s", exc)
    return None


# ---------------------------------------------------------------------------
# Borderless: strip the window chrome so a tiling WM can manage the game.
#
# Ported from Borderless Gaming (Codeusa/Borderless-Gaming, GPLv2),
# BorderlessGaming.Logic/Windows/Manipulation.cs:66-93 (the style masks) and
# :388-394 (the engines that need a delayed re-apply).
#
# The game is ALREADY in windowed mode -- all this does is remove the bars,
# which is exactly Borderless Gaming's end use case. We deliberately do NOT
# resize: Borderless Gaming fills the monitor because nothing else would, but
# here GlazeWM owns placement, and resizing too would mean fighting it for the
# same window on every redraw. Chrome is ours, geometry is the WM's.
#
# This lives here rather than in a Playnite C# extension on purpose -- no build
# step, no deploy script, no second project to maintain, and the window is
# already in hand from the query above.
# ---------------------------------------------------------------------------

GWL_STYLE = -16
GWL_EXSTYLE = -20

WS_CAPTION = 0x00C00000      # Border | DlgFrame
WS_THICKFRAME = 0x00040000
WS_SYSMENU = 0x00080000
WS_MAXIMIZEBOX = 0x00010000
WS_MINIMIZEBOX = 0x00020000

WS_EX_DLGMODALFRAME = 0x00000001
WS_EX_COMPOSITED = 0x02000000
WS_EX_WINDOWEDGE = 0x00000100
WS_EX_CLIENTEDGE = 0x00000200
WS_EX_STATICEDGE = 0x00020000
WS_EX_TOOLWINDOW = 0x00000080
WS_EX_APPWINDOW = 0x00040000
# NOTE: Borderless Gaming also strips WS_EX_LAYERED. We don't -- games using
# per-pixel alpha go fully invisible without it.

SWP_NOSIZE = 0x0001
SWP_NOMOVE = 0x0002
SWP_NOZORDER = 0x0004
SWP_FRAMECHANGED = 0x0020
SWP_NOOWNERZORDER = 0x0200
SWP_NOSENDCHANGING = 0x0400

# Engines that rewrite their own styles shortly after the window appears, so a
# single immediate strip gets clobbered (Manipulation.cs:388-394).
DELAYED_ENGINE_CLASSES = ("yygamemakeryy", "unrealwindow")


def _window_class(hwnd: int) -> str:
    import ctypes

    buf = ctypes.create_unicode_buffer(256)
    ctypes.windll.user32.GetClassNameW(hwnd, buf, 256)
    return buf.value or ""


def chrome_bits(hwnd: int) -> list[str]:
    """
    Which chrome style bits are currently set. Empty = already borderless.

    This is the whole of "can we detect a natively-borderless game": read the
    style word. Reliable and cheap. What we CANNOT detect is whether a game
    *offers* a borderless mode in its options — that is per-game knowledge, and
    the user has to set it. All we can see is the window in front of us.
    """
    import ctypes

    user32 = ctypes.windll.user32
    get_long = getattr(user32, "GetWindowLongPtrW", None) or user32.GetWindowLongW
    get_long.restype = ctypes.c_ssize_t
    style = get_long(hwnd, GWL_STYLE)
    names = ("WS_CAPTION", "WS_THICKFRAME", "WS_SYSMENU", "WS_MAXIMIZEBOX", "WS_MINIMIZEBOX")
    return [n for n in names if style & globals()[n]]


def make_borderless(hwnd: int) -> bool:
    """Clear the chrome style bits. Geometry is left entirely alone."""
    import ctypes

    if not hwnd:
        return False
    user32 = ctypes.windll.user32

    # GetWindowLongPtrW only exists on 64-bit; 32-bit exports GetWindowLongW.
    get_long = getattr(user32, "GetWindowLongPtrW", None) or user32.GetWindowLongW
    set_long = getattr(user32, "SetWindowLongPtrW", None) or user32.SetWindowLongW
    get_long.restype = ctypes.c_ssize_t
    set_long.restype = ctypes.c_ssize_t
    set_long.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_ssize_t]

    style = get_long(hwnd, GWL_STYLE)
    ex_style = get_long(hwnd, GWL_EXSTYLE)

    new_style = style & ~(
        WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MAXIMIZEBOX | WS_MINIMIZEBOX
    )
    new_ex = ex_style & ~(
        WS_EX_DLGMODALFRAME | WS_EX_COMPOSITED | WS_EX_WINDOWEDGE
        | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE | WS_EX_TOOLWINDOW | WS_EX_APPWINDOW
    )

    if new_style == style and new_ex == ex_style:
        logging.info("hwnd %#x already bare", hwnd)
        return True

    set_long(hwnd, GWL_STYLE, new_style)
    set_long(hwnd, GWL_EXSTYLE, new_ex)

    # SWP_FRAMECHANGED is required after a style change or Windows keeps drawing
    # the old frame. NOMOVE|NOSIZE keeps the WM in charge of geometry.
    user32.SetWindowPos(
        ctypes.c_void_p(hwnd), None, 0, 0, 0, 0,
        SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER
        | SWP_NOOWNERZORDER | SWP_NOSENDCHANGING,
    )
    logging.info("stripped chrome from hwnd %#x (class %s)", hwnd, _window_class(hwnd))
    return True


def _make_dpi_aware() -> None:
    """
    Make THIS thread per-monitor-DPI-aware before any geometry work.

    Without it Windows virtualises coordinates for a non-aware process and the
    numbers come back scaled: asking for 1024x768 at -1032,552 on the CRT landed
    1040x777 at -1039,552. Same fix quake-wezterm.ps1 already applies for the
    same reason (mixed-DPI monitors).
    """
    import ctypes

    try:
        # DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
        ctypes.windll.user32.SetThreadDpiAwarenessContext(ctypes.c_void_p(-4))
    except Exception as exc:  # pre-1703 Windows: not fatal, just less accurate
        logging.warning("could not set DPI awareness: %s", exc)


def window_rect(hwnd: int) -> tuple[int, int, int, int] | None:
    """(x, y, w, h) straight from Win32. GROUND TRUTH.

    `glazewm query` reports GlazeWM's INTERNAL MODEL, which diverges silently:
    it happily reported a window at -2550,-848 on one monitor while the window
    was actually at 0,0 on another. Never trust it for geometry.
    """
    import ctypes

    class RECT(ctypes.Structure):
        _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                    ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

    r = RECT()
    if not ctypes.windll.user32.GetWindowRect(ctypes.c_void_p(hwnd), ctypes.byref(r)):
        return None
    return r.left, r.top, r.right - r.left, r.bottom - r.top


def place_on_monitor(hwnd: int, mon: dict, tries: int = 3) -> bool:
    """
    Put the window on a monitor with a raw SetWindowPos, and VERIFY it landed.

    GlazeWM applies the size correctly but misses the position on monitors at
    negative coordinates — the window ends up at 0,0 (the primary origin) while
    GlazeWM believes it moved. Games are not fighting back: a raw SetWindowPos
    to the same rect moves them and holds indefinitely. So we do the positioning
    ourselves and check the result rather than trusting anyone's model.
    """
    import ctypes

    # ORDER MATTERS: strip the chrome BEFORE calling this. GetWindowRect includes
    # the invisible DWM resize border (WS_THICKFRAME), so a still-bordered window
    # reads ~7px off on every edge. Once the frame styles are gone it lands
    # EXACTLY — verified to the pixel on all three monitors.
    #
    # Deliberately NOT calling _make_dpi_aware(): GlazeWM reports bounds in the
    # same non-aware space this process uses, so they agree. Turning awareness on
    # makes us physical while GlazeWM stays logical and the numbers diverge.
    x, y = int(mon["x"]), int(mon["y"])
    w, h = int(mon["width"]), int(mon["height"])
    flags = 0x0004 | 0x0010 | 0x0020  # NOZORDER | NOACTIVATE | FRAMECHANGED

    for attempt in range(1, tries + 1):
        ctypes.windll.user32.SetWindowPos(
            ctypes.c_void_p(hwnd), None, x, y, w, h, flags
        )
        time.sleep(0.6)
        got = window_rect(hwnd)
        if got and abs(got[0] - x) <= 4 and abs(got[1] - y) <= 4:
            logging.info("placed at %s,%s %sx%s (attempt %d)", *got[:4], attempt)
            return True
        logging.warning("placement attempt %d landed at %s, wanted %s,%s", attempt, got, x, y)

    logging.error("could not place window on %s after %d tries", mon.get("hardwareId"), tries)
    return False


def apply_borderless(hwnd: int) -> None:
    """make_borderless, plus the re-apply that stubborn engines need."""
    cls = _window_class(hwnd).lower()
    if any(name in cls for name in DELAYED_ENGINE_CLASSES):
        logging.info("engine %r rewrites its own styles - delaying", cls)
        time.sleep(5)
    make_borderless(hwnd)
    # One re-apply covers engines that re-assert styles once during init, without
    # the permanent 3-second poll loop Borderless Gaming has to run.
    time.sleep(2)
    make_borderless(hwnd)


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


def monitor_index_of_process(process_name: str, timeout: float) -> int | None:
    """
    Which monitor did this game's window land on?

    For 'display:exclusive', the game picks its own screen (or Display Helper
    picks for it), so there is no tag telling us which one to clear. Wait for the
    window, then walk monitors -> workspaces -> windows to find where it went.
    """
    target = process_name.lower()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            mons = monitors()
        except Exception as exc:
            logging.warning("query monitors failed (retrying): %s", exc)
            mons = []
        for idx, mon in enumerate(mons):
            for ws in mon.get("children", []):
                for win in ws.get("children", []):
                    if (win.get("processName") or "").lower() == target:
                        logging.info("%s landed on monitor %d", process_name, idx)
                        return idx
        time.sleep(POLL_INTERVAL_S)
    logging.warning("never found a window for %s to locate", process_name)
    return None


def release_workspace(ws_name: str, focus_after: str = "1") -> None:
    """
    Free the game's workspace after the game exits.

    GlazeWM deactivates an empty workspace by itself when keep_alive is false, so
    there is nothing to "delete" — the problem is being left STRANDED on an empty
    workspace, possibly on the CRT, staring at nothing. So: confirm it's empty,
    then move focus somewhere sane.

    If the game left windows behind (a launcher, a crash dialog) we leave the
    workspace alone rather than yanking focus away from something the user may
    still need.
    """
    try:
        mons = monitors()
    except Exception as exc:
        logging.warning("release: could not query monitors: %s", exc)
        return

    occupants = 0
    found = False
    for mon in mons:
        for ws in mon.get("children", []):
            if ws.get("name") == ws_name:
                found = True
                occupants = len(ws.get("children", []))

    if not found:
        logging.info("release: workspace %s already gone", ws_name)
    elif occupants:
        logging.info("release: workspace %s still holds %d window(s) — leaving it", ws_name, occupants)
        return
    else:
        logging.info("release: workspace %s is empty", ws_name)

    try:
        _glazewm("command", "focus", "--workspace", focus_after)
        logging.info("release: focused workspace %s", focus_after)
    except Exception as exc:
        logging.warning("release: could not focus %s: %s", focus_after, exc)


def solo_workspace_on_monitor(ws_name: str, target_index: int) -> None:
    """
    Leave ONLY the game's workspace on the target monitor, then display it.

    Placing the game is not enough on its own: the monitor can already be hosting
    half a dozen other workspaces, and GlazeWM shows one at a time — so the game
    ends up on a workspace that isn't the displayed one, and whatever WAS
    displayed keeps the screen. Observed exactly that with Thief: the window was
    correctly at -1032,552 on the CRT while the CRT was still showing workspace 4
    with zen and pwsh on it.

    So: push every OTHER workspace off, then focus the game's. That is the
    "nothing else on that monitor while the game runs" half of the contract.
    """
    # Try every direction and CHECK the workspace actually left.
    #
    # move-workspace --direction only finds a GEOMETRICALLY adjacent monitor, and
    # "adjacent" needs real overlap on the perpendicular axis. On this desk the
    # Acer spans y -888..552 and the CRT starts exactly AT 552 — they touch on a
    # single line and never overlap, so "left" from the CRT resolves to nothing
    # and silently does nothing. Only the ultrawide is a valid horizontal
    # neighbour. Rather than reason about the layout, just try each direction and
    # verify by re-querying.
    def monitor_of(name: str) -> int | None:
        for idx, mon in enumerate(monitors()):
            for ws in mon.get("children", []):
                if ws.get("name") == name:
                    return idx
        return None

    for _ in range(24):  # bounded; each pass moves at most one workspace
        mons = monitors()
        if target_index >= len(mons):
            return
        others = [
            ws for ws in mons[target_index].get("children", [])
            if ws.get("name") and ws.get("name") != ws_name
        ]
        if not others:
            break

        name = others[0]["name"]
        moved = False
        for direction in ("right", "left", "up", "down"):
            try:
                _glazewm("command", "focus", "--workspace", name)
                time.sleep(0.15)
                _glazewm("command", "move-workspace", "--direction", direction)
                time.sleep(0.25)
            except Exception as exc:
                logging.warning("solo: %s %s failed: %s", name, direction, exc)
                continue
            if monitor_of(name) != target_index:
                logging.info("solo: pushed workspace %s off monitor %d (%s)", name, target_index, direction)
                moved = True
                break

        if not moved:
            # An EMPTY workspace often refuses to move at all — but an empty one
            # isn't covering the game either, so it's harmless. Stop rather than
            # spin.
            logging.warning("solo: workspace %s would not move off monitor %d — leaving it", name, target_index)
            break
    else:
        logging.warning("solo: gave up clearing monitor %d", target_index)

    # Make the game's workspace the one actually on screen.
    try:
        _glazewm("command", "focus", "--workspace", ws_name)
        logging.info("solo: focused workspace %s", ws_name)
    except Exception as exc:
        logging.warning("solo: could not focus %s: %s", ws_name, exc)


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
    parser.add_argument("--process", default="", help="process name of the game (no .exe); fallback matcher")
    parser.add_argument("--install-dir", default="", help="game install directory - PRIMARY matcher, mirrors Playnite's own Steam plugin")
    parser.add_argument("--workspace", default="8", help="GlazeWM workspace to host the game")
    parser.add_argument("--target", default="", help="monitor hardwareId / devicePath / deviceName")
    parser.add_argument("--game", default="", help="game name, for the workspace label and logs")
    parser.add_argument("--timeout", type=float, default=WINDOW_TIMEOUT_S)
    parser.add_argument("--focus-after", default="1", help="workspace to focus once the game exits")
    parser.add_argument("--share-monitor", action="store_true",
                        help="do NOT clear other workspaces off the target monitor")
    parser.add_argument(
        "--no-borderless",
        action="store_true",
        help="skip the chrome strip in 'place' mode (for a game that fights it)",
    )
    parser.add_argument(
        "--mode",
        choices=("place", "evacuate", "home", "release"),
        default="place",
        help=(
            "place    = wait for the game window and host it on a workspace; "
            "evacuate = clear every workspace off a monitor and hands off; "
            "home     = move one workspace onto a monitor (no window involved); "
            "release  = the game exited: free its workspace and restore focus"
        ),
    )
    args = parser.parse_args()

    _setup_logging()
    logging.info(
        "--- %s | mode=%s process=%s target=%r ws=%s",
        args.game or "?", args.mode, args.process, args.target, args.workspace,
    )

    if args.mode == "release":
        # Called from post-game.ps1 when the game exits.
        release_workspace(args.workspace, args.focus_after)
        return 0

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
        if target_index is None and args.process:
            # No explicit screen named ('display:exclusive'): the game chose one
            # itself, so find its window and clear whichever monitor it landed on.
            target_index = monitor_index_of_process(args.process, args.timeout)
        if target_index is None:
            logging.error("evacuate: could not determine which monitor to clear")
            return 1
        evacuate_monitor(target_index)
        return 0

    if not args.process and not args.install_dir:
        parser.error("--mode place needs --install-dir (preferred) or --process")

    window_id, hwnd = find_window(args.process, args.timeout, args.install_dir)
    # Gate on HWND, not on GlazeWM's container id. A window GlazeWM isn't
    # managing (ignored by a rule, or not yet claimed) still has a perfectly good
    # HWND, and the strip plus raw placement work without GlazeWM entirely.
    # GlazeWM is only needed for the workspace and fullscreen steps below.
    if not hwnd:
        logging.error("no window after %.0fs -- giving up", args.timeout)
        return 1
    if window_id is None:
        logging.info("GlazeWM is not managing this window — placing it directly")

    # Strip the chrome FIRST. 'place' mode means "the WM manages this game", and a
    # bordered window is one the WM can only manage badly. Do it before handing
    # geometry to GlazeWM so it lays out against the final frame — and because
    # GetWindowRect includes the invisible DWM resize border, so a still-bordered
    # window measures ~7px off on every edge.
    was_bare = not chrome_bits(hwnd)
    if was_bare:
        # We can see the window has no chrome. We CANNOT see why. It could be the
        # game's own borderless mode, or another tool stripped it earlier —
        # SetWindowLong is permanent for the life of that window, so a strip by
        # e.g. Borderless Gaming survives even after that app is closed. Do not
        # claim to know which; a fresh launch will show the truth, because a new
        # window comes up with chrome again unless the game itself removes it.
        logging.info("window already has no chrome — skipping the strip (cause unknown)")
    elif not args.no_borderless:
        try:
            apply_borderless(hwnd)
        except Exception:
            logging.exception("borderless failed (continuing to placement anyway)")

    # Home the game first, so the workspace exists before we try to move it.
    # Tiling, not floating: a floating window's rect is snapshotted at manage
    # time (manage_window.rs:189-209) and would pin the game at whatever tiny
    # size it happened to have during startup.
    if window_id:
        _glazewm("command", "--id", window_id, "set-tiling")
        time.sleep(0.3)
        _glazewm("command", "--id", window_id, "move", "--workspace", args.workspace)

    if args.target:
        target_index = resolve_monitor_index(args.target)
        if target_index is not None:
            move_workspace_to_monitor(args.workspace, target_index)

            # Clear every other workspace off that monitor and display the game's.
            # Without this the game lands correctly but the monitor carries on
            # showing whatever workspace it was already displaying.
            if not args.share_monitor:
                solo_workspace_on_monitor(args.workspace, target_index)

            # GlazeWM gets the size right and the POSITION wrong on monitors at
            # negative coordinates, so do the placement ourselves and verify.
            # AFTER the solo pass, since moving workspaces triggers re-layouts.
            mons = monitors()
            if target_index < len(mons):
                place_on_monitor(hwnd, mons[target_index])

    if args.game:
        # Label the workspace so the bar shows what's running.
        loc = workspace_location(args.workspace)
        if loc:
            _glazewm("command", "--id", loc[0], "update-workspace-config", "--display-name", args.game)

    # maximized=false is required: the default (true) calls Win32 maximize, which
    # silently does nothing on windows lacking WS_MAXIMIZEBOX -- i.e. most games.
    if window_id:
        _glazewm("command", "--id", window_id, "set-fullscreen", "--maximized=false")

    # One line you can actually read when something misbehaves. Everything here
    # is measured, not assumed — the rect comes from GetWindowRect, never from
    # `glazewm query`, which reports GlazeWM's model and diverges silently.
    final = window_rect(hwnd)
    logging.info(
        "SUMMARY %s | borderless=%s | target=%s | workspace=%s | rect=%s | managed=%s",
        args.game or args.process or "?",
        "already-bare" if was_bare else "stripped-by-us",
        args.target or "(none)",
        args.workspace,
        final,
        "yes" if window_id else "no",
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        _setup_logging()
        logging.exception("unhandled error")
        sys.exit(1)




