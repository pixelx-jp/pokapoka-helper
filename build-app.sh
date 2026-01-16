#!/bin/bash
# Build pokapoka Helper app bundle and DMG

set -e

APP_NAME="pokapoka Helper"
BUNDLE_ID="com.pixelx.pokapoka-helper"
VERSION="1.0.0"
DMG_NAME="pokapoka-helper-mac"

echo "=== Building $APP_NAME v$VERSION ==="

# Create icon if not exists
if [ ! -f "AppIcon.icns" ]; then
    echo "Creating app icon..."
    ./create-icon.sh
fi

# Build release binary
echo "Compiling..."
swift build -c release

# Setup paths
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous build
rm -rf "$APP_DIR"

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/arm64-apple-macosx/release/CueCompanion" "$MACOS_DIR/$APP_NAME"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>pokapoka Helper needs microphone access.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>pokapoka Helper needs screen recording permission to capture system audio.</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>$BUNDLE_ID</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>pokapoka-helper</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy icon if exists
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RESOURCES_DIR/"
fi

echo "Created: $APP_DIR"

# Create DMG
echo "Creating DMG..."
rm -f "$DMG_NAME.dmg"

# 检查是否有 create-dmg（更美观的 DMG）
if command -v create-dmg &> /dev/null && [ -f "AppIcon.icns" ]; then
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_DIR" 175 190 \
        --hide-extension "$APP_DIR" \
        --app-drop-link 425 190 \
        "$DMG_NAME.dmg" \
        "$APP_DIR"
else
    # 简单方式
    rm -rf dmg-temp
    mkdir -p dmg-temp
    cp -R "$APP_DIR" dmg-temp/
    hdiutil create -volname "$APP_NAME" \
        -srcfolder dmg-temp \
        -ov -format UDZO \
        "$DMG_NAME.dmg"
    rm -rf dmg-temp
fi

echo ""
echo "=== Done! ==="
echo "  App: $APP_DIR"
echo "  DMG: $DMG_NAME.dmg"
echo ""
echo "To release on GitHub:"
echo "  gh release create v$VERSION $DMG_NAME.dmg --title '$APP_NAME v$VERSION'"
