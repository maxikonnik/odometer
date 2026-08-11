#!/bin/bash
# Builds Odometer.app from the SwiftPM executable. No Xcode required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/Odometer.app"
CONTENTS="$APP/Contents"
VERSION="${ODOMETER_VERSION:-1.0.0}"

cd "$ROOT"
swift build -c release --product Odometer

BINARY="$(swift build -c release --product Odometer --show-bin-path)/Odometer"
if [ ! -x "$BINARY" ]; then
  echo "error: built binary not found at $BINARY" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BINARY" "$CONTENTS/MacOS/Odometer"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Odometer</string>
    <key>CFBundleDisplayName</key><string>Odometer</string>
    <key>CFBundleIdentifier</key><string>com.komo4ekk.odometer</string>
    <key>CFBundleExecutable</key><string>Odometer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key><string>Odometer выводит вперёд окно терминала, который ждёт вашего решения.</string>
    <key>NSHumanReadableCopyright</key><string>Odometer</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: required for local notifications and Keychain prompts.
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP"

echo "Built $APP"
echo "Install with: cp -R \"$APP\" /Applications/"
