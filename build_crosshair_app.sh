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
  <key>CFBundleIdentifier</key><string>com.chriswang.crosshair</string>
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

# Sign with a stable identity so the Input Monitoring permission survives
# rebuilds. Create a self-signed cert named "Crosshair Self-Signed" in
# Keychain Access first (Certificate Assistant → Create a Certificate, type
# "Code Signing", self-signed root). Falls back to ad-hoc if the cert isn't found.
# We look up by SHA1 so an untrusted self-signed cert still works.
CODESIGN_IDENTITY="Crosshair Self-Signed"
CERT_SHA1=$(security find-identity -p codesigning 2>/dev/null \
  | awk -v name="$CODESIGN_IDENTITY" 'index($0, name) { print $2; exit }')
if [ -n "$CERT_SHA1" ]; then
  codesign --force --deep --sign "$CERT_SHA1" "$APP_DIR"
  echo "Signed with: $CODESIGN_IDENTITY ($CERT_SHA1)"
else
  codesign --force --deep --sign - "$APP_DIR"
  echo "Signed ad-hoc (no '$CODESIGN_IDENTITY' cert found in Keychain)"
fi

echo "Built: $APP_DIR"
echo "Run: open \"$APP_DIR\"  (or double-click it in Finder)"
