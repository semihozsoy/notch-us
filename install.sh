#!/bin/sh
# Installs the latest Notch Us release to ~/Applications.
# Usage: curl -fsSL https://raw.githubusercontent.com/semihozsoy/notch-us/master/install.sh | sh
set -e

URL="https://github.com/semihozsoy/notch-us/releases/latest/download/NotchUs.zip"
DEST="$HOME/Applications"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "🌮 Downloading Notch Us..."
curl -fsSL "$URL" -o "$TMP/NotchUs.zip"
ditto -x -k "$TMP/NotchUs.zip" "$TMP"

pkill -x NotchUs 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/NotchUs.app"
mv "$TMP/NotchUs.app" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/NotchUs.app" 2>/dev/null || true

open "$DEST/NotchUs.app"
echo "✅ Installed to $DEST/NotchUs.app. Look up at your menu bar (and your notch)."
