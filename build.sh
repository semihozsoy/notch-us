#!/bin/zsh
# Builds ClaudeNotch.app and installs it to ~/Applications.
set -e
cd "$(dirname "$0")"

swift build -c release
APP=build/ClaudeNotch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ClaudeNotch "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ClaudeNotch</string>
  <key>CFBundleDisplayName</key><string>Claude Notch</string>
  <key>CFBundleIdentifier</key><string>dev.semihozsoy.claudenotch</string>
  <key>CFBundleExecutable</key><string>ClaudeNotch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"

if [[ "$1" == "--install" ]]; then
  pkill -x ClaudeNotch || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/ClaudeNotch.app
  cp -R "$APP" ~/Applications/
  open ~/Applications/ClaudeNotch.app
  echo "Installed to ~/Applications/ClaudeNotch.app"
fi
