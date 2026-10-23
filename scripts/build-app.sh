#!/usr/bin/env bash
# Builds MonitorBar.app (menu bar only), signs it, and packages build/MonitorBar-<version>.dmg.
#
# Signing: uses $SIGN_IDENTITY when set (a "Developer ID Application: ..." identity), otherwise an
# ad-hoc signature. Notarization is a separate step and needs an Apple Developer account.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MonitorBar"
EXECUTABLE="MonitorWidget"
VERSION="${VERSION:-1.0.0}"
BUNDLE_ID="${BUNDLE_ID:-local.monitorbar}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

BUILD="build"
APP="$BUILD/$APP_NAME.app"
DMG="$BUILD/$APP_NAME-$VERSION.dmg"
STAGING="$BUILD/dmg-staging"

swift build -c release --product "$EXECUTABLE"
swift build -c release --product monitorctl

# Icon: regenerate only when missing, so builds stay fast.
if [[ ! -f "$BUILD/icon/AppIcon.icns" ]]; then
    mkdir -p "$BUILD/icon"
    swift scripts/make-icon.swift "$BUILD/icon"
    iconutil -c icns "$BUILD/icon/AppIcon.iconset" -o "$BUILD/icon/AppIcon.icns"
fi

rm -rf "$APP" "$STAGING" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp ".build/release/monitorctl" "$APP/Contents/Resources/monitorctl"
cp "$BUILD/icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --verbose=2 "$APP" 2>&1 | tail -1

# DMG with the app and an Applications shortcut for drag-and-drop install.
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "Built $APP and $DMG"
