#!/bin/zsh
# Builds NotchUs.app and installs it to ~/Applications.
set -e
cd "$(dirname "$0")"

swift build -c release
APP=build/NotchUs.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/NotchUs "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>NotchUs</string>
  <key>CFBundleDisplayName</key><string>Notch Us</string>
  <key>CFBundleIdentifier</key><string>dev.semihozsoy.notchus</string>
  <key>CFBundleExecutable</key><string>NotchUs</string>
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
  pkill -x NotchUs || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/NotchUs.app
  cp -R "$APP" ~/Applications/
  open ~/Applications/NotchUs.app
  echo "Installed to ~/Applications/NotchUs.app"
fi
