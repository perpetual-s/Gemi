#!/bin/bash
# Unified DMG creation script for Gemi
# This script builds the app in Xcode and creates a production-ready DMG
# Usage: ./scripts/build-dmg.sh [--skip-build]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
BUILD_DIR="$PROJECT_ROOT/Gemi/build"
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
APP_NAME="Gemi"
DMG_NAME="Gemi"
SKIP_BUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [--skip-build]"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== Gemi DMG Builder ===${NC}"
echo -e "${BLUE}Project root: $PROJECT_ROOT${NC}"

# Step 1: Note about authentication
echo -e "\n${GREEN}ℹ Using mlx-community models - no authentication required${NC}"

# Step 2: Build the app (unless skipped)
if [ "$SKIP_BUILD" = false ]; then
    echo -e "\n${YELLOW}Building Gemi in Xcode...${NC}"
    cd "$PROJECT_ROOT/Gemi"
    
    # Clean build folder
    echo -e "${YELLOW}Cleaning previous builds...${NC}"
    rm -rf "$BUILD_DIR"
    
    # Build for release
    echo -e "${YELLOW}Building Release configuration...${NC}"
    xcodebuild -project Gemi.xcodeproj \
               -scheme Gemi \
               -configuration Release \
               -derivedDataPath "$BUILD_DIR/DerivedData" \
               ONLY_ACTIVE_ARCH=NO \
               build
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Build completed successfully${NC}"
    else
        echo -e "${RED}✗ Build failed${NC}"
        exit 1
    fi
else
    echo -e "\n${YELLOW}Skipping build step (--skip-build flag used)${NC}"
fi

# Step 3: Find the built app
echo -e "\n${YELLOW}Locating built app...${NC}"
APP_PATH=""

# First check our custom build directory
if [ -d "$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app" ]; then
    APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
    echo -e "${YELLOW}Found in custom build directory${NC}"
else
    # Fall back to searching in default DerivedData
    echo -e "${YELLOW}Searching in DerivedData...${NC}"
    
    # Look for Release build first
    APP_PATH=$(find "$DERIVED_DATA_PATH" -name "$APP_NAME.app" -path "*/Release/*" -type d 2>/dev/null | head -n 1)
    
    # If no Release build, look for Debug build
    if [ -z "$APP_PATH" ]; then
        echo -e "${YELLOW}No Release build found, looking for Debug build...${NC}"
        APP_PATH=$(find "$DERIVED_DATA_PATH" -name "$APP_NAME.app" -path "*/Debug/*" -type d 2>/dev/null | head -n 1)
        
        if [ -n "$APP_PATH" ]; then
            echo -e "${YELLOW}⚠ Found Debug build. For production, build with Release configuration.${NC}"
        fi
    fi
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}✗ Could not find $APP_NAME.app${NC}"
    echo -e "${YELLOW}  Make sure to build the app in Xcode first${NC}"
    echo -e "${YELLOW}  You can build it with: xcodebuild -project Gemi/Gemi.xcodeproj -scheme Gemi -configuration Release${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found app at: $APP_PATH${NC}"

# Step 4: No need to copy .env for mlx-community models
echo -e "\n${GREEN}✓ No authentication files needed${NC}"

# Step 5: Create the DMG
echo -e "\n${YELLOW}Creating DMG installer...${NC}"

# Clean up any existing DMG files
rm -f "$PROJECT_ROOT/$DMG_NAME.dmg"
rm -f "$PROJECT_ROOT/$DMG_NAME-tmp.dmg"

# Use the final DMG creation script
cd "$PROJECT_ROOT"
"$SCRIPT_DIR/create-dmg-final.sh" "$APP_PATH"

if [ -f "$PROJECT_ROOT/$DMG_NAME-Installer.dmg" ]; then
    echo -e "${GREEN}✓ DMG created successfully: $DMG_NAME-Installer.dmg${NC}"
    
    # Show file info
    DMG_SIZE=$(du -h "$PROJECT_ROOT/$DMG_NAME-Installer.dmg" | cut -f1)
    echo -e "${BLUE}  Size: $DMG_SIZE${NC}"
    echo -e "${BLUE}  Location: $PROJECT_ROOT/$DMG_NAME-Installer.dmg${NC}"
    
    # Open in Finder
    echo -e "\n${YELLOW}Opening DMG location in Finder...${NC}"
    open -R "$PROJECT_ROOT/$DMG_NAME-Installer.dmg"
else
    echo -e "${RED}✗ DMG creation failed${NC}"
    exit 1
fi

echo -e "\n${GREEN}=== Build Complete ===${NC}"
echo -e "${BLUE}Your production-ready DMG is at: $PROJECT_ROOT/$DMG_NAME-Installer.dmg${NC}"
echo -e "\n${GREEN}✓ All done!${NC}"