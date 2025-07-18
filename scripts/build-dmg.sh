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
DMG_NAME="Gemi-Installer"
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

# Step 1: Check for .env file
echo -e "\n${YELLOW}Checking for .env file...${NC}"
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${GREEN}✓ Found .env file${NC}"
    # Verify it contains HuggingFace token
    if grep -q "HUGGINGFACE_TOKEN=" "$PROJECT_ROOT/.env"; then
        echo -e "${GREEN}✓ HuggingFace token found in .env${NC}"
    else
        echo -e "${RED}✗ Warning: HUGGINGFACE_TOKEN not found in .env file${NC}"
        echo -e "${YELLOW}  Model downloads may fail without the token${NC}"
    fi
else
    echo -e "${RED}✗ .env file not found at $PROJECT_ROOT/.env${NC}"
    echo -e "${YELLOW}  Creating template .env file...${NC}"
    cat > "$PROJECT_ROOT/.env" << 'EOF'
# HuggingFace token for accessing Gemma models
# Replace with your actual token from https://huggingface.co/settings/tokens
HUGGINGFACE_TOKEN=your_token_here
EOF
    echo -e "${RED}  Please edit .env and add your HuggingFace token${NC}"
    exit 1
fi

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
else
    # Fall back to searching in default DerivedData
    echo -e "${YELLOW}Searching in DerivedData...${NC}"
    APP_PATH=$(find "$DERIVED_DATA_PATH" -name "$APP_NAME.app" -path "*/Release/*" -type d | head -n 1)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}✗ Could not find $APP_NAME.app${NC}"
    echo -e "${YELLOW}  Make sure to build the app in Xcode first${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found app at: $APP_PATH${NC}"

# Step 4: Verify .env is in the app bundle
echo -e "\n${YELLOW}Verifying .env in app bundle...${NC}"
if [ -f "$APP_PATH/Contents/Resources/.env" ]; then
    echo -e "${GREEN}✓ .env file is included in app bundle${NC}"
else
    echo -e "${YELLOW}⚠ .env not found in app bundle, copying it now...${NC}"
    cp "$PROJECT_ROOT/.env" "$APP_PATH/Contents/Resources/"
    if [ -f "$APP_PATH/Contents/Resources/.env" ]; then
        echo -e "${GREEN}✓ .env file copied to app bundle${NC}"
    else
        echo -e "${RED}✗ Failed to copy .env to app bundle${NC}"
        exit 1
    fi
fi

# Step 5: Create the DMG
echo -e "\n${YELLOW}Creating DMG installer...${NC}"

# Clean up any existing DMG files
rm -f "$PROJECT_ROOT/$DMG_NAME.dmg"
rm -f "$PROJECT_ROOT/$DMG_NAME-tmp.dmg"

# Run the DMG creation script
if [ -f "$SCRIPT_DIR/create-dmg.sh" ]; then
    cd "$PROJECT_ROOT"
    "$SCRIPT_DIR/create-dmg.sh" "$APP_PATH"
    
    if [ -f "$PROJECT_ROOT/$DMG_NAME.dmg" ]; then
        echo -e "${GREEN}✓ DMG created successfully: $DMG_NAME.dmg${NC}"
        
        # Show file info
        DMG_SIZE=$(du -h "$PROJECT_ROOT/$DMG_NAME.dmg" | cut -f1)
        echo -e "${BLUE}  Size: $DMG_SIZE${NC}"
        echo -e "${BLUE}  Location: $PROJECT_ROOT/$DMG_NAME.dmg${NC}"
        
        # Open in Finder
        echo -e "\n${YELLOW}Opening DMG location in Finder...${NC}"
        open -R "$PROJECT_ROOT/$DMG_NAME.dmg"
    else
        echo -e "${RED}✗ DMG creation failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ create-dmg.sh not found at $SCRIPT_DIR/create-dmg.sh${NC}"
    exit 1
fi

echo -e "\n${GREEN}=== Build Complete ===${NC}"
echo -e "${BLUE}Your production-ready DMG is at: $PROJECT_ROOT/$DMG_NAME.dmg${NC}"

# Optional: Mount and show the DMG
read -p "Would you like to mount and view the DMG? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Mounting DMG...${NC}"
    hdiutil attach "$PROJECT_ROOT/$DMG_NAME.dmg"
fi

echo -e "\n${GREEN}✓ All done!${NC}"