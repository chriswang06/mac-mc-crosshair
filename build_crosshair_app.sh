#!/bin/bash
set -e

APP_NAME="Crosshair"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RES"

# Compile the Swift source into a native binary
swiftc -O "$BUILD_DIR/crosshair.swift" -o "$MACOS/$APP_NAME"

# Info.plist — LSUIElement=true keeps it out of the Dock/menu bar
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>com.chriswang.crosshair.slackow</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><false/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so the binary's identity stays stable for permission grants
codesign --force --deep --sign - "$APP_DIR"

echo "Built: $APP_DIR"
echo "Run: open \"$APP_DIR\"  (or double-click it in Finder)"
