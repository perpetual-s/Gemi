#!/bin/bash

# Gemi DMG Creator - Beautiful Installer with Drag & Drop
# Build in Xcode (Cmd+B), then run this script

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🎨 Gemi DMG Creator${NC}"
echo "===================="

# Find Gemi.app
echo -e "${BLUE}Finding Gemi.app...${NC}"
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Gemi.app" -type d 2>/dev/null | head -1)

if [[ ! -d "$APP" ]]; then
    echo -e "${RED}❌ Gemi.app not found!${NC}"
    echo "Build in Xcode first (Cmd+B)"
    exit 1
fi

echo -e "${GREEN}✓ Found${NC}"

# Setup paths
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="$PROJECT_ROOT/Gemi.dmg"
VOLUME_NAME="Gemi"
BACKGROUND="$PROJECT_ROOT/Documentation/assets/dmg-background-enhanced.png"

# Copy .env file into app bundle if it exists
ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
    echo -e "${BLUE}Including .env file in app bundle...${NC}"
    cp "$ENV_FILE" "$APP/Contents/Resources/" || echo -e "${RED}Warning: Could not copy .env file${NC}"
    echo -e "${GREEN}✓ .env file included${NC}"
else
    echo -e "${RED}⚠️  Warning: .env file not found at project root${NC}"
    echo "The app will not be able to download models without the HuggingFace token."
fi

# Verify no server artifacts
if [[ -d "$APP/Contents/Resources/GemiServer.app" ]]; then
    echo -e "${RED}❌ Error: Found old GemiServer.app in the build!${NC}"
    echo -e "${YELLOW}This is from an old build. Please run:${NC}"
    echo "  ./scripts/clean-build.sh"
    echo "  Then rebuild in Xcode before creating DMG"
    exit 1
fi

# Check for create-dmg
if command -v create-dmg &> /dev/null; then
    echo -e "${BLUE}Creating beautiful DMG with background...${NC}"
    
    # Clean up
    rm -f "$DMG_PATH"
    
    # Use create-dmg for the best result
    create-dmg \
        --volname "$VOLUME_NAME" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 128 \
        --icon "Gemi.app" 180 185 \
        --hide-extension "Gemi.app" \
        --app-drop-link 480 185 \
        --background "$BACKGROUND" \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP"
    
    SUCCESS=$?
else
    echo -e "${BLUE}Installing create-dmg for beautiful DMGs...${NC}"
    
    # Try to install create-dmg
    if command -v brew &> /dev/null; then
        brew install create-dmg
        
        # Try again with create-dmg
        if command -v create-dmg &> /dev/null; then
            rm -f "$DMG_PATH"
            create-dmg \
                --volname "$VOLUME_NAME" \
                --window-pos 200 120 \
                --window-size 660 400 \
                --icon-size 128 \
                --icon "Gemi.app" 180 185 \
                --hide-extension "Gemi.app" \
                --app-drop-link 480 185 \
                --background "$BACKGROUND" \
                --no-internet-enable \
                "$DMG_PATH" \
                "$APP"
            SUCCESS=$?
        else
            SUCCESS=1
        fi
    else
        echo "Homebrew not found. Install from https://brew.sh"
        SUCCESS=1
    fi
fi

# Fallback method if create-dmg isn't available
if [[ $SUCCESS -ne 0 ]]; then
    echo -e "${BLUE}Using manual method...${NC}"
    
    # Create temp directory
    TEMP_DIR="/tmp/gemi-dmg-$$"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR/.background"
    
    # Copy files
    cp -R "$APP" "$TEMP_DIR/"
    ln -s /Applications "$TEMP_DIR/Applications"
    
    if [[ -f "$BACKGROUND" ]]; then
        cp "$BACKGROUND" "$TEMP_DIR/.background/background.png"
    fi
    
    # Create DMG directly from temp directory
    rm -f "$DMG_PATH"
    hdiutil create -volname "$VOLUME_NAME" -srcfolder "$TEMP_DIR" -ov -format UDZO "$DMG_PATH"
    
    # Clean up
    rm -rf "$TEMP_DIR"
fi

# Show result
if [[ -f "$DMG_PATH" ]]; then
    SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo ""
    echo -e "${GREEN}✨ Success!${NC}"
    echo -e "📦 Created: ${BLUE}Gemi.dmg${NC} (${SIZE})"
    echo ""
    echo "DMG contains:"
    echo "  • Gemi.app"
    echo "  • Applications shortcut (drag & drop to install)"
    if [[ -f "$BACKGROUND" ]]; then
        echo "  • Beautiful background"
    fi
    echo ""
    echo "Opening DMG..."
    open "$DMG_PATH"
else
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi