#!/bin/sh
# Install the SadServers CLI (sads) into ~/.local/bin.
# run_once: chezmoi executes this once (re-runs only if this script's contents change).
set -eu

DEST="$HOME/.local/bin"
mkdir -p "$DEST"

# Already installed -> nothing to do.
if [ -x "$DEST/sads" ]; then
	exit 0
fi

os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
	Darwin)
		case "$arch" in
			arm64)  f="sads_v0.1.0_darwin_arm64" ;;
			x86_64) f="sads_v0.1.0_darwin_amd64" ;;
			*) echo "sads: unsupported macOS arch: $arch" >&2; exit 1 ;;
		esac
		;;
	Linux)
		case "$arch" in
			aarch64|arm64) f="sads_v0.1.1_linux_arm64" ;;
			x86_64)        f="sads_v0.1.1_linux_amd64" ;;
			*) echo "sads: unsupported Linux arch: $arch" >&2; exit 1 ;;
		esac
		;;
	*) echo "sads: unsupported OS: $os" >&2; exit 1 ;;
esac

url="https://cdn.sadservers.com/$f"
echo "sads: downloading $url"
curl -fsSL "$url" -o "$DEST/sads"
chmod +x "$DEST/sads"

# macOS Gatekeeper: strip the quarantine flag so the unsigned binary runs without the manual allow.
if [ "$os" = "Darwin" ]; then
	xattr -d com.apple.quarantine "$DEST/sads" 2>/dev/null || true
fi

"$DEST/sads" -v 2>/dev/null || true
echo "sads: installed to $DEST/sads"
echo "sads: finish with -> sads auth   &&   sads config --path ~/.ssh/id_ed25519"
