#!/bin/bash
# Unified Build and Package Script for Gemi
# This script combines all build, bundle, and DMG creation steps

set -e  # Exit on any error

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEMI_PROJECT="$PROJECT_ROOT/Gemi/Gemi.xcodeproj"
SERVER_DIR="$PROJECT_ROOT/python-inference-server"
BUILD_CONFIG="${1:-Release}"  # Default to Release, can pass Debug as argument
CREATE_DMG="${2:-yes}"  # Default to creating DMG

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏗️  Gemi Build and Package Script${NC}"
echo "================================="
echo "Configuration: $BUILD_CONFIG"
echo "Create DMG: $CREATE_DMG"
echo "Project root: $PROJECT_ROOT"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists xcodebuild; then
    echo -e "${RED}❌ Error: xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

# UV is bundled, no need to check Python

# Step 1: Build GemiServer.app
echo ""
echo -e "${BLUE}Step 1: Building GemiServer.app${NC}"
echo "--------------------------------"

cd "$SERVER_DIR"

# Check if create_bundle_uv.sh exists
if [ ! -f "create_bundle_uv.sh" ]; then
    echo -e "${RED}❌ Error: create_bundle_uv.sh not found in $SERVER_DIR${NC}"
    exit 1
fi

# Run the UV bundle creation script
echo -e "${YELLOW}Creating UV-based server bundle...${NC}"
./create_bundle_uv.sh

# Verify GemiServer.app was built
if [ ! -d "dist/GemiServer.app" ]; then
    echo -e "${RED}❌ Error: GemiServer.app build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ GemiServer.app built successfully${NC}"

# Step 2: Build Gemi.app using Xcode
echo ""
echo -e "${BLUE}Step 2: Building Gemi.app${NC}"
echo "-------------------------"

# Clean and build using Xcode derived data
DERIVED_DATA_PATH="${HOME}/Library/Developer/Xcode/DerivedData"
BUILD_DIR=$(xcodebuild -project "$GEMI_PROJECT" -showBuildSettings -configuration $BUILD_CONFIG | grep -m 1 'BUILD_DIR' | awk '{print $3}')

if [ -z "$BUILD_DIR" ]; then
    # Fallback to finding it manually
    BUILD_DIR="$(find "$DERIVED_DATA_PATH" -name "Gemi-*" -type d | head -1)/Build/Products/$BUILD_CONFIG"
fi

echo -e "${YELLOW}Building Gemi with Xcode...${NC}"
xcodebuild -project "$GEMI_PROJECT" \
    -scheme "Gemi" \
    -configuration "$BUILD_CONFIG" \
    clean build \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Find the built app
GEMI_APP="$BUILD_DIR/Gemi.app"

if [ ! -d "$GEMI_APP" ]; then
    echo -e "${RED}❌ Error: Gemi.app not found at $GEMI_APP${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Gemi.app built successfully${NC}"

# Step 3: Bundle GemiServer.app inside Gemi.app
echo ""
echo -e "${BLUE}Step 3: Bundling GemiServer.app${NC}"
echo "--------------------------------"

RESOURCES_DIR="$GEMI_APP/Contents/Resources"
SERVER_SOURCE="$SERVER_DIR/dist/GemiServer.app"
SERVER_DEST="$RESOURCES_DIR/GemiServer.app"

# Remove old server bundle if exists
if [ -d "$SERVER_DEST" ]; then
    echo -e "${YELLOW}Removing old GemiServer.app bundle...${NC}"
    rm -rf "$SERVER_DEST"
fi

# Copy GemiServer.app to Resources
echo -e "${YELLOW}Copying GemiServer.app to Gemi.app bundle...${NC}"
cp -R "$SERVER_SOURCE" "$SERVER_DEST"

# Verify the copy
if [ ! -d "$SERVER_DEST" ]; then
    echo -e "${RED}❌ Error: Failed to bundle GemiServer.app${NC}"
    exit 1
fi

# Check bundle size
SERVER_SIZE=$(du -sh "$SERVER_DEST" | cut -f1)
echo -e "${GREEN}✅ Bundled GemiServer.app (size: $SERVER_SIZE)${NC}"

# Step 4: Create DMG if requested
if [ "$CREATE_DMG" = "yes" ]; then
    echo ""
    echo -e "${BLUE}Step 4: Creating DMG${NC}"
    echo "--------------------"
    
    DMG_NAME="Gemi"
    DMG_VOLUME_NAME="Gemi - AI Diary"
    DMG_PATH="$PROJECT_ROOT/${DMG_NAME}.dmg"
    
    # Remove old DMG if exists
    if [ -f "$DMG_PATH" ]; then
        echo -e "${YELLOW}Removing old DMG...${NC}"
        rm -f "$DMG_PATH"
    fi
    
    # Use advanced DMG creation script if available
    ADVANCED_DMG_SCRIPT="$PROJECT_ROOT/Gemi/scripts/create_dmg_advanced.sh"
    if [ -f "$ADVANCED_DMG_SCRIPT" ]; then
        echo -e "${YELLOW}Using advanced DMG creation...${NC}"
        "$ADVANCED_DMG_SCRIPT"
    else
        # Fallback to simple DMG creation
        echo -e "${YELLOW}Creating DMG from $GEMI_APP...${NC}"
        hdiutil create -volname "$DMG_VOLUME_NAME" \
            -srcfolder "$GEMI_APP" \
            -ov \
            -format UDZO \
            "$DMG_PATH"
    fi
    
    # Get final DMG size
    DMG_FINAL_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
    
    echo -e "${GREEN}✅ DMG created successfully!${NC}"
    echo ""
    echo "DMG Information:"
    echo "Location: $DMG_PATH"
    echo "Size: $DMG_FINAL_SIZE"
    echo "Volume Name: $DMG_VOLUME_NAME"
fi

# Final verification
echo ""
echo -e "${BLUE}Verifying final bundle...${NC}"

# Check Gemi.app
if [ -f "$GEMI_APP/Contents/MacOS/Gemi" ]; then
    echo -e "${GREEN}✅ Gemi executable found${NC}"
else
    echo -e "${RED}❌ Warning: Gemi executable not found${NC}"
fi

# Check bundled GemiServer.app
if [ -f "$SERVER_DEST/Contents/MacOS/GemiServer" ]; then
    echo -e "${GREEN}✅ GemiServer executable found${NC}"
else
    echo -e "${RED}❌ Warning: GemiServer executable not found${NC}"
fi

# Get final sizes
GEMI_SIZE=$(du -sh "$GEMI_APP" | cut -f1)

# Summary
echo ""
echo -e "${GREEN}🎉 Build Complete!${NC}"
echo "=================="
echo -e "${BLUE}Build configuration:${NC} $BUILD_CONFIG"
echo -e "${BLUE}Gemi.app location:${NC} $GEMI_APP"
echo -e "${BLUE}Gemi.app size:${NC} $GEMI_SIZE"
if [ "$CREATE_DMG" = "yes" ]; then
    echo -e "${BLUE}DMG location:${NC} $DMG_PATH"
    echo -e "${BLUE}DMG size:${NC} $DMG_FINAL_SIZE"
fi
echo ""
echo -e "${GREEN}GemiServer.app is bundled at:${NC}"
echo "  $SERVER_DEST"
echo ""
echo -e "${YELLOW}To test the app:${NC}"
echo "  open \"$GEMI_APP\""
echo ""