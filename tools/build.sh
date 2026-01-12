#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_ROOT/app-macos"
BUILD_DIR="$PROJECT_ROOT/build"

echo "Building Clify..."

cd "$APP_DIR"

# Build the Swift package
swift build -c release

# Create app bundle structure
APP_BUNDLE="$BUILD_DIR/Clify.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/Clify" "$MACOS_DIR/"

# Copy Info.plist
cp "Resources/Info.plist" "$CONTENTS_DIR/"

# Bundle gifski binary
GIFSKI_PATH="/opt/homebrew/bin/gifski"
if [ -f "$GIFSKI_PATH" ]; then
    # Resolve symlink to get actual binary
    GIFSKI_REAL=$(readlink -f "$GIFSKI_PATH" 2>/dev/null || realpath "$GIFSKI_PATH")
    cp "$GIFSKI_REAL" "$RESOURCES_DIR/gifski"
    chmod +x "$RESOURCES_DIR/gifski"
    echo "Bundled gifski from $GIFSKI_REAL"
else
    echo "WARNING: gifski not found at $GIFSKI_PATH"
    echo "         Install with: brew install gifski"
    echo "         App will not work without gifski!"
fi

# Ad-hoc code sign to preserve permissions across rebuilds
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
echo "Or: $MACOS_DIR/Clify"
