#!/bin/zsh
# Builds NotchUs.app and installs it to ~/Applications.
# UNIVERSAL=1 builds for both Apple Silicon and Intel; VERSION sets the app version.
set -e
cd "$(dirname "$0")"

# Defaults to the latest git tag (v1.2.0 -> 1.2.0) so local builds report the right version.
VERSION=${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}
VERSION=${VERSION:-1.0.0}
APP=build/NotchUs.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ "$UNIVERSAL" == "1" ]]; then
  bins=()
  for arch in arm64 x86_64; do
    swift build -c release --arch $arch
    bins+=("$(swift build -c release --arch $arch --show-bin-path)/NotchUs")
  done
  lipo -create "${bins[@]}" -output "$APP/Contents/MacOS/NotchUs"
else
  swift build -c release
  cp .build/release/NotchUs "$APP/Contents/MacOS/"
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>NotchUs</string>
  <key>CFBundleDisplayName</key><string>Notch Us</string>
  <key>CFBundleIdentifier</key><string>dev.semihozsoy.notchus</string>
  <key>CFBundleExecutable</key><string>NotchUs</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>tr</string></array>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
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
