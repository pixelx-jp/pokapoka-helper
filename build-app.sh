#!/bin/bash
# Build CueCompanion.app bundle

set -e

APP_NAME="CueCompanion"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME..."

# Build release binary
swift build -c release

echo "Creating app bundle..."

# Clean previous build
rm -rf "$APP_DIR"

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/$APP_NAME" "$MACOS_DIR/"

# Copy Info.plist
cp "Info.plist" "$CONTENTS_DIR/"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "Done! Created $APP_DIR"
echo ""
echo "To install:"
echo "  1. Move $APP_DIR to /Applications"
echo "  2. Double-click to launch"
echo "  3. Grant permissions when prompted"
echo ""
echo "URL Scheme: cuecompanion://start"
