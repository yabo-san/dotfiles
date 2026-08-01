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

    # "primary" -- the monitor at the desktop origin.
    #
    # This is THE useful target, because it is where an unconfigured game will
    # open. Windows puts the primary display at (0,0) and games that pin
    # themselves pin to (0,0); Dishonored does exactly this, which is why it kept
    # appearing on the ultrawide.
    #
    # It is also what Display Helper manipulates - its DLL calls SetPrimaryDisplay
    # / CDS_SET_PRIMARY and nothing else. So by the time this script runs, DH has
    # already made the game's chosen screen primary, and "primary" resolves to the
    # right monitor whether DH is configured for the game or not.
    if want == "primary":
        for idx, mon in enumerate(mons):
            if int(mon.get("x", -1)) == 0 and int(mon.get("y", -1)) == 0:
                logging.info("target 'primary' -> monitor %d (%sx%s at origin)",
                             idx, mon.get("width"), mon.get("height"))
                return idx
        logging.warning("no monitor at the desktop origin; cannot resolve 'primary'")
        return None

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


def settle_window(hwnd: int, stable_for: float = 1.5, timeout: float = 25.0) -> bool:
    """
    Block until the game stops moving/resizing its own window.

    Returns True if it settled, False if it was still changing at `timeout`
    (in which case placement goes ahead anyway — a moving target beats no
    attempt at all).

    Why this exists: a window existing is not the same as a game being finished
    with it. Unreal creates a 160x120 placeholder during init, then resizes and
    re-styles it when the renderer comes up. Anything we do before that gets
    silently reverted by the game — the chrome grows back and the position snaps
    to (0,0) — which looks exactly like our code not working.
    """
    deadline = time.monotonic() + timeout
    last = None
    stable_since = None

    while time.monotonic() < deadline:
        rect = window_rect(hwnd)
        if rect is None:
            return False

        # Reject nonsense. A starting game can report absurd rects - Dishonored
        # produced 32160x32028 - and treating one of those as "settled" makes the
        # whole thing act during init, which is exactly when the game will undo
        # it. Anything bigger than the virtual desktop is not a real window yet.
        w, h = rect[2] - rect[0], rect[3] - rect[1]
        if w <= 0 or h <= 0 or w > 20000 or h > 20000:
            logging.info("ignoring bogus rect %dx%d while the game starts up", w, h)
            last = None
            stable_since = None
            time.sleep(POLL_INTERVAL_S)
            continue

        if rect == last:
            if stable_since is None:
                stable_since = time.monotonic()
            elif time.monotonic() - stable_since >= stable_for:
                w, h = rect[2] - rect[0], rect[3] - rect[1]
                logging.info("window settled at %dx%d after %.1fs",
                             w, h, timeout - (deadline - time.monotonic()))
                return True
        else:
            if last is not None:
                logging.info("window still changing: %s -> %s", last, rect)
            stable_since = None
            last = rect

        time.sleep(POLL_INTERVAL_S)

    logging.warning("window never settled in %.0fs — placing anyway", timeout)
    return False


def enforce_placement(hwnd: int, mon: dict, strip: bool, seconds: float = 20.0) -> None:
    """
    Keep the window where we put it while the game finishes starting.

    Placing once is not enough. Dishonored opens on the right monitor, then
    completes its init and re-asserts BOTH its style (the title bar comes back)
    and its position (it snaps to 0,0 - the primary monitor's origin, i.e. the
    ultrawide). Everything we did gets undone about a second later, which is
    indistinguishable from us never having run.

    So watch it. Any time it drifts off the target monitor or regrows chrome, put
    it back. This is what GlazeWM does that a one-shot SetWindowPos does not: it
    has an event loop and simply keeps winning.

    Bounded, because this cannot run forever - by the time the game is at its
    menu it has stopped fighting.
    """
    mx, my = int(mon.get("x", 0)), int(mon.get("y", 0))
    mw, mh = int(mon.get("width", 0)), int(mon.get("height", 0))
    deadline = time.monotonic() + seconds
    fixes = 0

    while time.monotonic() < deadline:
        time.sleep(0.5)

        rect = window_rect(hwnd)
        if rect is None:
            break  # window is gone; nothing to enforce

        drifted = not (mx - 8 <= rect[0] <= mx + 8 and my - 8 <= rect[1] <= my + 8)
        regrew = strip and bool(chrome_bits(hwnd))

        if not drifted and not regrew:
            continue

        fixes += 1

        # GIVE UP EARLY. Some games re-assert their own window continuously -
        # Dishonored does it about every 2.5 seconds, style AND position. Fighting
        # that is a war we lose anyway, and every round is a visible FLICKER on the
        # owner's screen, which is worse than doing nothing.
        #
        # A game that pins itself to (0,0) is pinning itself to the PRIMARY
        # monitor's origin. The only thing that actually relocates it is changing
        # which monitor is primary before launch - which is exactly what Display
        # Helper does, and why it exists as the fallback for these titles.
        if fixes > 2:
            logging.warning(
                "enforce: the game keeps re-asserting its own window (%d reverts). "
                "NOT fighting it - that only flickers. This title pins itself to the "
                "primary monitor; hand it to Display Helper, which switches the "
                "primary before launch, and we will just clear the screen for it.",
                fixes,
            )
            return

        if regrew:
            logging.info("enforce: chrome came back — stripping again (fix %d)", fixes)
            try:
                apply_borderless(hwnd)
            except Exception:
                logging.exception("enforce: re-strip failed")

        if drifted:
            logging.info("enforce: window drifted to (%d,%d) — putting it back (fix %d)",
                         rect[0], rect[1], fixes)
            place_on_monitor(hwnd, mon, tries=1)

    if fixes:
        logging.info("enforce: corrected the game %d time(s) over %.0fs", fixes, seconds)
    else:
        logging.info("enforce: window stayed put, no corrections needed")


def workspace_monitor_index(ws_name: str) -> int | None:
    """Which monitor index currently hosts this workspace (None if nowhere)."""
    try:
        for idx, mon in enumerate(monitors()):
            for ws in mon.get("children", []):
                if ws.get("name") == ws_name:
                    return idx
    except Exception as exc:
        logging.warning("query monitors failed: %s", exc)
    return None


def monitor_index_of_hwnd(hwnd: int) -> int | None:
    """
    Which monitor is this window physically on?

    Geometry, not GlazeWM's model. `monitor_index_of_process` walks the WM's own
    tree, so it only ever sees windows the WM has claimed -- useless for a game
    that is ignored, floating, or simply not managed yet, which is the normal case
    for the untagged games Display Helper handles.

    Uses the window's CENTRE rather than its origin: a window straddling two
    screens belongs to the one showing most of it, and a maximised window whose
    origin sits a pixel outside its own monitor still resolves correctly.
    """
    rect = window_rect(hwnd)
    if not rect:
        return None
    left, top, right, bottom = rect
    cx, cy = (left + right) // 2, (top + bottom) // 2

    try:
        mons = monitors()
    except Exception as exc:
        logging.warning("query monitors failed: %s", exc)
        return None

    for idx, mon in enumerate(mons):
        mx, my = int(mon.get("x", 0)), int(mon.get("y", 0))
        mw, mh = int(mon.get("width", 0)), int(mon.get("height", 0))
        if mx <= cx < mx + mw and my <= cy < my + mh:
            logging.info(
                "window centre (%d,%d) is on monitor %d (%dx%d at %d,%d)",
                cx, cy, idx, mw, mh, mx, my,
            )
            return idx

    logging.warning("window centre (%d,%d) is on no known monitor", cx, cy)
    return None


def _window_covers_monitor(hwnd: int, mon_index: int, ratio: float = 0.85) -> bool:
    """
    Is this window actually filling the monitor?

    The test for "this game has taken the screen". Deliberately generous: a
    borderless-fullscreen window matches the monitor exactly, while a game running
    at a lower resolution than the desktop, or one that leaves a taskbar strip,
    still covers the great majority of it. A launcher, config dialog or small
    windowed game does not come close.
    """
    rect = window_rect(hwnd)
    if not rect:
        return False
    left, top, right, bottom = rect
    win_area = max(0, right - left) * max(0, bottom - top)

    try:
        mon = monitors()[mon_index]
    except Exception:
        return False

    mon_area = int(mon.get("width", 0)) * int(mon.get("height", 0))
    if mon_area <= 0:
        return False

    covered = win_area / mon_area
    logging.info(
        "window covers %.0f%% of monitor %d (need %.0f%%)",
        covered * 100, mon_index, ratio * 100,
    )
    return covered >= ratio


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


SOLO_STATE = os.path.join(os.path.dirname(LOG_PATH), "solo-state.json")


def _monitor_id(mon: dict) -> str:
    """A stable-ish identity for a monitor, best available first."""
    return (mon.get("devicePath") or mon.get("hardwareId")
            or f"{mon.get('width')}x{mon.get('height')}")


def _monitor_index_by_id(mid: str) -> int | None:
    for idx, mon in enumerate(monitors()):
        if _monitor_id(mon) == mid:
            return idx
    return None


def _save_solo_state(ws_name: str, displaced: list[dict]) -> None:
    """
    Remember where displaced workspaces came from, so exit can put them back.

    Keyed by devicePath/hardwareId rather than monitor INDEX, because indices are
    recomputed from x-coordinates on any display change and would point at the
    wrong screen after one.
    """
    try:
        os.makedirs(os.path.dirname(SOLO_STATE), exist_ok=True)
        with open(SOLO_STATE, "w", encoding="utf-8") as fh:
            json.dump({"workspace": ws_name, "displaced": displaced}, fh, indent=2)
        logging.info("solo: recorded %d displaced workspace(s)", len(displaced))
    except Exception as exc:
        logging.warning("solo: could not save state: %s", exc)


def restore_solo_state(ws_name: str) -> None:
    """
    Put displaced workspaces back where they were before the game took the screen.

    Only moves a workspace still sitting where WE pushed it — if it was moved by
    hand since, that was deliberate and we leave it alone. State is consumed
    either way so a stale file can't act on a later launch.
    """
    if not os.path.exists(SOLO_STATE):
        return
    try:
        with open(SOLO_STATE, encoding="utf-8") as fh:
            state = json.load(fh)
    except Exception as exc:
        logging.warning("restore: unreadable state: %s", exc)
        return

    if state.get("workspace") != ws_name:
        logging.info("restore: state is for workspace %s, not %s — ignoring",
                     state.get("workspace"), ws_name)
        return

    for entry in state.get("displaced", []):
        name, home_id, pushed_to = entry.get("name"), entry.get("home"), entry.get("pushed_to")
        if not name or not home_id:
            continue

        # GlazeWM will not move an EMPTY workspace — it deactivates instead, and
        # disappears from the tree. Nothing to restore in that case, and nothing
        # lost either: an empty workspace re-homes itself on next activation IF it
        # has bind_to_monitor set. Workspaces without a binding land wherever they
        # are activated, which is a config gap, not something to fight here.
        occupants = 0
        for mon in monitors():
            for ws in mon.get("children", []):
                if ws.get("name") == name:
                    occupants = len(ws.get("children", []))
        if occupants == 0:
            logging.info("restore: ws%s is empty — leaving it to re-home on activation", name)
            continue
        home_idx = _monitor_index_by_id(home_id)
        if home_idx is None:
            logging.info("restore: %s's monitor is gone — leaving it", name)
            continue

        current = None
        for idx, mon in enumerate(monitors()):
            for ws in mon.get("children", []):
                if ws.get("name") == name:
                    current = idx
        if current is None or current == home_idx:
            continue
        if pushed_to is not None and _monitor_id(monitors()[current]) != pushed_to:
            logging.info("restore: %s was moved by hand since — leaving it", name)
            continue

        _step_workspace_to(name, home_idx)

    try:
        os.remove(SOLO_STATE)
    except Exception:
        pass


def _step_workspace_to(name: str, target_index: int) -> bool:
    """
    Walk a workspace onto a monitor, trying every direction and verifying.

    move-workspace --direction only resolves to a GEOMETRICALLY adjacent monitor,
    and adjacency needs real overlap on the perpendicular axis — on this desk the
    Acer and CRT merely touch at y=552 and never overlap, so 'left' between them
    silently does nothing. Hence: try all four, check by re-querying.
    """
    def where(n: str) -> int | None:
        for idx, mon in enumerate(monitors()):
            for ws in mon.get("children", []):
                if ws.get("name") == n:
                    return idx
        return None

    for attempt in range(4):
        current = where(name)
        if current is None:
            # An empty workspace deactivates and vanishes from the tree entirely.
            # Focusing it re-activates it — on its bound monitor if it has one.
            logging.info("ws%s is not active; activating it", name)
            try:
                _glazewm("command", "focus", "--workspace", name)
                time.sleep(0.4)
            except Exception as exc:
                logging.warning("could not activate ws%s: %s", name, exc)
                return False
            current = where(name)
            if current is None:
                logging.warning("ws%s still not in the tree", name)
                return False

        if current == target_index:
            logging.info("ws%s is on monitor %d", name, target_index)
            return True

        moved = False
        for direction in ("left", "right", "up", "down"):
            try:
                _glazewm("command", "focus", "--workspace", name)
                time.sleep(0.2)
                _glazewm("command", "move-workspace", "--direction", direction)
                time.sleep(0.35)
            except Exception as exc:
                logging.warning("ws%s %s errored: %s", name, direction, exc)
                continue
            after = where(name)
            logging.info("ws%s %s: monitor %s -> %s", name, direction, current, after)
            if after is not None and after != current:
                moved = True
                break

        if not moved:
            logging.warning("ws%s would not move off monitor %s (attempt %d)", name, current, attempt + 1)
            return False
    logging.warning("ws%s did not reach monitor %d after 4 passes", name, target_index)
    return False


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
    displaced: list[dict] = []

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
        # ONLY MOVE WORKSPACES THAT HAVE WINDOWS ON THEM.
        #
        # An EMPTY workspace sitting on the game's monitor is harmless - there is
        # nothing on it to see, and the game covers the screen regardless. Moving
        # it is not just pointless, it is actively destructive: GlazeWM will not
        # move an empty workspace by direction, so it gets pushed away by some
        # other means and then CANNOT BE PUT BACK on exit. That is what left the
        # Acer with no workspaces and comms/music stranded on the ultrawide, twice.
        others = [
            ws for ws in mons[target_index].get("children", [])
            if ws.get("name")
            and ws.get("name") != ws_name
            and ws.get("children")          # has windows; empty ones stay put
        ]
        if not others:
            break

        name = others[0]["name"]
        home_id = _monitor_id(mons[target_index])
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
            landed = monitor_of(name)
            if landed != target_index:
                logging.info("solo: pushed workspace %s off monitor %d (%s)", name, target_index, direction)
                displaced.append({
                    "name": name,
                    "home": home_id,
                    "pushed_to": _monitor_id(monitors()[landed]) if landed is not None else None,
                })
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

    _save_solo_state(ws_name, displaced)

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
    parser.add_argument("--use-workspace", action="store_true",
                        help="also give the game its own GlazeWM workspace on the "
                             "target monitor. OFF by default: the workspace dance is "
                             "what kept failing, and when it fails the game is dragged "
                             "to whatever monitor the workspace is stuck on")
    parser.add_argument("--solo-monitor", action="store_true",
                        help="clear OTHER workspaces off the target monitor. OFF by "
                             "default: GlazeWM already displays only one workspace per "
                             "monitor, so a game on its own workspace owns the screen "
                             "already, and the restore afterwards is unreliable")
    parser.add_argument("--only-if-covers", action="store_true",
                        help="evacuate mode: only claim an INFERRED monitor when the "
                             "game is actually filling it (untagged games)")
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
        # Called from post-game.ps1 when the game exits. Put the displaced
        # workspaces back BEFORE moving focus, so focus lands on a settled layout.
        restore_solo_state(args.workspace)
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
        if target_index is None and (args.install_dir or args.process):
            # Last resort, and the one that actually works for an untagged game.
            # monitor_index_of_process() matches by PROCESS NAME against GlazeWM's
            # own model, and both halves of that are unreliable here: Playnite
            # hands us the wrong process for Steam titles (vcredist), and a game
            # GlazeWM is ignoring or has not claimed never appears in the model at
            # all. Find the window the same way 'place' does -- by install
            # directory -- and work the monitor out from where it physically is.
            _, hwnd = find_window(args.process, args.timeout, args.install_dir)
            if hwnd:
                target_index = monitor_index_of_hwnd(hwnd)

                # An UNTAGGED game is a guess: nobody told us it wants this screen,
                # we inferred it from where a window happened to open. Claiming a
                # monitor for a small windowed game would throw every workspace off
                # it -- and if that monitor is the main one, that is the whole
                # desktop. So only claim a screen the game is actually FILLING.
                if args.only_if_covers and not _window_covers_monitor(hwnd, target_index):
                    logging.info(
                        "evacuate: untagged game is not filling monitor %d — "
                        "leaving it alone", target_index,
                    )
                    return 0
        if target_index is None:
            logging.error("evacuate: could not determine which monitor to clear")
            return 1

        # Same contract as 'place': the monitor ends up hosting ONE workspace,
        # ours, and nothing else. The only difference is that we never touch the
        # game's window — it is fullscreen or handles its own borderless, so the
        # WM has no business resizing it. It still gets a screen to itself.
        move_workspace_to_monitor(args.workspace, target_index)
        solo_workspace_on_monitor(args.workspace, target_index)
        logging.info(
            "SUMMARY %s | mode=exclusive | window untouched | target=%s | workspace=%s",
            args.game or "?", args.target or "(auto)", args.workspace,
        )
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

    # WAIT FOR THE WINDOW TO SETTLE before touching anything.
    #
    # A game is not done with its window when that window first exists. Unreal
    # creates a 160x120 placeholder during init, long before it knows its
    # resolution, then resizes and re-styles it once the renderer comes up. Strip
    # and place at first sight and the game simply undoes both: Dishonored kept
    # snapping back to (0,0) at 1008x715 and re-growing its title bar, even with
    # the WM ignoring it entirely.
    #
    # Borderless Gaming hit this years ago and solved it the same way, with a
    # per-engine delay before manipulating a window (Manipulation.cs:388-394).
    # Rather than keep a list of engines, just watch the geometry and act once it
    # stops moving.
    settle_window(hwnd)

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
    target_index = resolve_monitor_index(args.target) if args.target else None

    # THE JOB IS: MOVE A WINDOW TO A SCREEN, HOLD IT, LET GO.
    #
    # Everything below this that touches WORKSPACES is opt-in (--use-workspace),
    # because the workspace choreography is what kept breaking and it was never
    # needed. Handing the game to workspace 8 means the game follows workspace 8 —
    # and when "gave up moving workspace 8 to monitor 0" happens, the game gets
    # dragged to whatever monitor that workspace is stuck on. That is the actual
    # reason Dishonored ended up on the ultrawide.
    #
    # Without it: find the window, strip the chrome, put it on the monitor, keep it
    # there while the game finishes starting, stop. GlazeWM leaves game windows
    # floating anyway, so there is nothing to co-ordinate with.
    if window_id and args.use_workspace:
        _glazewm("command", "--id", window_id, "set-tiling")
        time.sleep(0.3)

        # FOCUS THE TARGET MONITOR FIRST. A workspace materialises on whichever
        # monitor is focused, so moving the window to its workspace while the
        # target is focused lands the whole thing there in one step.
        #
        # This replaces stepping the workspace across monitors with
        # `move-workspace --direction`, which kept failing: an EMPTY workspace
        # will not move at all, directions resolve to the nearest adjacent
        # monitor (so "left" off the ultrawide hits the CRT, never the Acer),
        # and the result was "gave up moving workspace 8 to monitor 0" followed
        # by the game being placed on whatever screen the workspace was stuck on.
        if target_index is not None:
            _glazewm("command", "focus", "--monitor", str(target_index))
            time.sleep(0.4)

        _glazewm("command", "--id", window_id, "move", "--workspace", args.workspace)
        time.sleep(0.4)

    if target_index is not None:
        if args.use_workspace:
            where = workspace_monitor_index(args.workspace)
            if where != target_index:
                logging.info("workspace %s is on monitor %s, wanted %s — moving it",
                             args.workspace, where, target_index)
                move_workspace_to_monitor(args.workspace, target_index)
            else:
                logging.info("workspace %s is already on monitor %d",
                             args.workspace, target_index)

            # SOLO IS OFF BY DEFAULT, and --solo-monitor is now needed to ask for
            # it. GlazeWM only ever DISPLAYS one workspace per monitor (verified:
            # every monitor reports isDisplayed=true on exactly one child), so a
            # game on its own workspace already has that screen to itself. Solo
            # was solving a problem that does not exist, and it was destructive:
            # it shoved comms and music off the Acer, and the restore afterwards
            # could not put them back because an emptied workspace will not move.
            if args.solo_monitor:
                solo_workspace_on_monitor(args.workspace, target_index)

        # THE ACTUAL JOB: put the window on the screen, then hold it there while
        # the game finishes starting. GlazeWM gets the size right and the POSITION
        # wrong on monitors at negative coordinates, so place it ourselves and
        # verify. AFTER any workspace work, since that triggers re-layouts.
        mons = monitors()
        if target_index < len(mons):
            place_on_monitor(hwnd, mons[target_index])
            enforce_placement(hwnd, mons[target_index],
                              strip=not (was_bare or args.no_borderless))

    if args.game and args.use_workspace:
        # Label the workspace so the bar shows what's running.
        loc = workspace_location(args.workspace)
        if loc:
            _glazewm("command", "--id", loc[0], "update-workspace-config", "--display-name", args.game)

    # maximized=false is required: the default (true) calls Win32 maximize, which
    # silently does nothing on windows lacking WS_MAXIMIZEBOX -- i.e. most games.
    if window_id and args.use_workspace:
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





