#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_ROOT/app-macos"
BUILD_DIR="$PROJECT_ROOT/build"

echo "Building Clif..."

cd "$APP_DIR"

# Build the Swift package
swift build -c release

# Create app bundle structure
APP_BUNDLE="$BUILD_DIR/Clif.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/Clif" "$MACOS_DIR/"

# Copy Info.plist
cp "Resources/Info.plist" "$CONTENTS_DIR/"

# Ad-hoc code sign to preserve permissions across rebuilds
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
echo "Or: $MACOS_DIR/Clif"
