#!/usr/bin/env sh
# setup-constructor.sh — cross-platform GMEdit-Constructor installer (macOS + Windows).
#
# Does exactly "what we did to set up Constructor": clone (or update) the Constructor
# plugin into GMEdit's user-data plugins folder, which differs per OS. GMEdit itself
# comes from itch.io (or the Playnite extension on Windows) — not handled here.
#
#   macOS:           sh setup-constructor.sh
#   Windows (git-bash, which ships with git): sh setup-constructor.sh
#   (Windows-native equivalent also exists: bootstrap/setup-gmedit.ps1)
set -eu

case "$(uname -s)" in
  Darwin*) PLUGINS="$HOME/Library/Application Support/AceGM/GMEdit/plugins" ;;
  *)       PLUGINS="${APPDATA:-$HOME/AppData/Roaming}/AceGM/GMEdit/plugins" ;;  # Windows
esac

# macOS: apps downloaded outside the App Store (itch.io GMEdit) get a Gatekeeper
# quarantine xattr that blocks launch ("damaged / unidentified developer"). Strip it
# from GMEdit.app wherever it landed so it'll actually open.
if [ "$(uname -s)" = "Darwin" ]; then
  for app in /Applications/GMEdit.app "$HOME/Applications/GMEdit.app" "$HOME/Downloads/GMEdit.app"; do
    if [ -d "$app" ]; then
      echo "[ok] de-quarantining $app"
      xattr -cr "$app" 2>/dev/null || true
    fi
  done
fi

mkdir -p "$PLUGINS"
DIR="$PLUGINS/GMEdit-Constructor"

if [ -d "$DIR/.git" ]; then
  echo "[ok] updating Constructor (git pull)"
  git -C "$DIR" pull --ff-only
else
  echo "[ok] cloning Constructor -> $DIR"
  git clone https://github.com/thennothinghappened/GMEdit-Constructor "$DIR"
fi

echo "[done] Restart GMEdit to load the plugin."
echo "[note] A project needs a runtime that MATCHES its pinned line AND is signed-in/"
echo "       licensed on that channel. If Constructor cites an old runtime after you"
echo "       convert a project, RESTART GMEdit — it caches the requirement."
