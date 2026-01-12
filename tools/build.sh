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

# Copy app icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/"
    echo "Copied app icon"
fi

# Bundle gifski binary (universal for arm64 + x86_64)
GIFSKI_UNIVERSAL="$BUILD_DIR/gifski-universal"

build_universal_gifski() {
    echo "Building universal gifski binary..."

    # Check if cargo is available
    if ! command -v cargo &> /dev/null; then
        echo "ERROR: cargo not found. Install Rust: https://rustup.rs"
        return 1
    fi

    # Add targets if not already installed
    rustup target add aarch64-apple-darwin x86_64-apple-darwin 2>/dev/null || true

    # Create temp directory for gifski build
    GIFSKI_BUILD_DIR="$BUILD_DIR/gifski-build"
    rm -rf "$GIFSKI_BUILD_DIR"
    mkdir -p "$GIFSKI_BUILD_DIR"

    # Clone gifski (shallow)
    echo "Cloning gifski..."
    git clone --depth 1 https://github.com/ImageOptim/gifski.git "$GIFSKI_BUILD_DIR/gifski" 2>/dev/null

    cd "$GIFSKI_BUILD_DIR/gifski"

    # Build for both architectures (no video feature needed - we extract frames via AVFoundation)
    echo "Building arm64..."
    cargo build --release --target aarch64-apple-darwin

    echo "Building x86_64..."
    cargo build --release --target x86_64-apple-darwin

    # Create universal binary with lipo
    echo "Creating universal binary..."
    lipo -create \
        target/aarch64-apple-darwin/release/gifski \
        target/x86_64-apple-darwin/release/gifski \
        -output "$GIFSKI_UNIVERSAL"

    cd "$PROJECT_ROOT"
    rm -rf "$GIFSKI_BUILD_DIR"

    echo "Universal gifski built successfully"
    return 0
}

# Try to use existing universal binary, or build one
if [ -f "$GIFSKI_UNIVERSAL" ]; then
    echo "Using cached universal gifski binary"
elif [ -f "$RESOURCES_DIR/gifski" ] && lipo -info "$RESOURCES_DIR/gifski" 2>/dev/null | grep -q "x86_64.*arm64\|arm64.*x86_64"; then
    echo "Existing bundled gifski is already universal"
    GIFSKI_UNIVERSAL="$RESOURCES_DIR/gifski"
else
    # Check homebrew paths for existing installation
    GIFSKI_HOMEBREW=""
    if [ -f "/opt/homebrew/bin/gifski" ]; then
        GIFSKI_HOMEBREW="/opt/homebrew/bin/gifski"
    elif [ -f "/usr/local/bin/gifski" ]; then
        GIFSKI_HOMEBREW="/usr/local/bin/gifski"
    fi

    if [ -n "$GIFSKI_HOMEBREW" ]; then
        # Check if homebrew version is universal
        if lipo -info "$GIFSKI_HOMEBREW" 2>/dev/null | grep -q "x86_64.*arm64\|arm64.*x86_64"; then
            echo "Using universal gifski from homebrew"
            GIFSKI_REAL=$(readlink -f "$GIFSKI_HOMEBREW" 2>/dev/null || realpath "$GIFSKI_HOMEBREW")
            cp "$GIFSKI_REAL" "$GIFSKI_UNIVERSAL"
        else
            echo "Homebrew gifski is not universal, building from source..."
            build_universal_gifski || {
                echo "WARNING: Failed to build universal gifski"
                echo "         Falling back to single-architecture binary"
                echo "         App may not work on all Macs!"
                GIFSKI_REAL=$(readlink -f "$GIFSKI_HOMEBREW" 2>/dev/null || realpath "$GIFSKI_HOMEBREW")
                cp "$GIFSKI_REAL" "$GIFSKI_UNIVERSAL"
            }
        fi
    else
        echo "gifski not found, building from source..."
        build_universal_gifski || {
            echo "ERROR: Failed to build gifski and no homebrew version found"
            echo "       Install with: brew install gifski"
            echo "       Or install Rust: https://rustup.rs"
            exit 1
        }
    fi
fi

# Copy to resources
cp "$GIFSKI_UNIVERSAL" "$RESOURCES_DIR/gifski"
chmod +x "$RESOURCES_DIR/gifski"
echo "Bundled gifski: $(lipo -info "$RESOURCES_DIR/gifski" 2>/dev/null || file "$RESOURCES_DIR/gifski")"

# Ad-hoc code sign to preserve permissions across rebuilds
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
echo "Or: $MACOS_DIR/Clify"
