#!/usr/bin/env sh
# setup-constructor.sh: clones or updates GMEdit-Constructor into GMEdit's per-OS plugins folder.
# GMEdit itself comes from itch.io. Run with sh on macOS, or git-bash on Windows.
set -eu

case "$(uname -s)" in
  Darwin*) PLUGINS="$HOME/Library/Application Support/AceGM/GMEdit/plugins" ;;
  *)       PLUGINS="${APPDATA:-$HOME/AppData/Roaming}/AceGM/GMEdit/plugins" ;;  # Windows
esac

# macOS: strip the Gatekeeper quarantine xattr from the itch.io GMEdit.app, or it won't launch.
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
