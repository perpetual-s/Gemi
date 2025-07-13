#!/bin/bash
# Simple build script that bypasses export issues

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEMI_PROJECT="$PROJECT_ROOT/Gemi/Gemi.xcodeproj"
SERVER_DIR="$PROJECT_ROOT/python-inference-server"

echo "🏗️  Simple Gemi Build Script"
echo "==========================="

# Step 1: Check if GemiServer.app exists
if [ ! -d "$SERVER_DIR/dist/GemiServer.app" ]; then
    echo "Building GemiServer.app..."
    cd "$SERVER_DIR"
    ./build_app.sh
fi

# Step 2: Build Gemi.app
echo "Building Gemi.app..."
xcodebuild -project "$GEMI_PROJECT" \
    -scheme "Gemi" \
    -configuration Debug \
    clean build \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO

# Step 3: Find the built app
BUILD_DIR=$(xcodebuild -project "$GEMI_PROJECT" -showBuildSettings -configuration Debug | grep "BUILT_PRODUCTS_DIR" | grep -v "DEPLOYMENT_LOCATION" | head -1 | awk '{print $3}')
GEMI_APP="$BUILD_DIR/Gemi.app"

if [ ! -d "$GEMI_APP" ]; then
    echo "❌ Error: Gemi.app not found at $GEMI_APP"
    exit 1
fi

# Step 4: Bundle GemiServer.app
echo "Bundling GemiServer.app..."
RESOURCES_DIR="$GEMI_APP/Contents/Resources"
mkdir -p "$RESOURCES_DIR"
cp -R "$SERVER_DIR/dist/GemiServer.app" "$RESOURCES_DIR/"

# Step 5: Copy to release directory
echo "Copying to release directory..."
rm -rf "$PROJECT_ROOT/gemi-release"
mkdir -p "$PROJECT_ROOT/gemi-release"
cp -R "$GEMI_APP" "$PROJECT_ROOT/gemi-release/"

echo "✅ Build complete!"
echo "App location: $PROJECT_ROOT/gemi-release/Gemi.app"
echo ""
echo "Test with: open \"$PROJECT_ROOT/gemi-release/Gemi.app\""