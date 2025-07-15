#!/bin/bash
# Gemi DMG Creator - The One True DMG Script
# Creates a beautiful, professional DMG installer with drag-to-install experience

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎨 Creating Gemi DMG Installer${NC}"
echo "================================"

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DMG_NAME="Gemi"
DMG_VOLUME_NAME="Gemi - AI Diary"
DMG_PATH="$PROJECT_ROOT/${DMG_NAME}.dmg"
BACKGROUND_IMAGE="$PROJECT_ROOT/Documentation/assets-icons/dmg-background-clean.png"
# Fall back to original if clean version doesn't exist
if [ ! -f "$BACKGROUND_IMAGE" ]; then
    BACKGROUND_IMAGE="$PROJECT_ROOT/Documentation/assets-icons/dmg-background.png"
fi

# Function to find Gemi.app
find_gemi_app() {
    local SEARCH_PATHS=(
        # Build location passed as argument
        "$1"
        # Release build in project
        "$PROJECT_ROOT/gemi-release/Gemi.app"
        # Xcode DerivedData (most recent)
        "$(find ~/Library/Developer/Xcode/DerivedData/Gemi-*/Build/Products/Release -name "Gemi.app" -type d 2>/dev/null | head -1)"
        # Debug build fallback
        "$(find ~/Library/Developer/Xcode/DerivedData/Gemi-*/Build/Products/Debug -name "Gemi.app" -type d 2>/dev/null | head -1)"
    )
    
    for path in "${SEARCH_PATHS[@]}"; do
        if [ -n "$path" ] && [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Find Gemi.app
APP_PATH=$(find_gemi_app "$1")
if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: Gemi.app not found${NC}"
    echo "Usage: $0 [path-to-Gemi.app]"
    echo "Or run from project root after building"
    exit 1
fi

echo -e "${GREEN}✓ Found Gemi.app at: $APP_PATH${NC}"

# Verify GemiServer is bundled
if [ ! -d "$APP_PATH/Contents/Resources/GemiServer.app" ]; then
    echo -e "${YELLOW}⚠️  Warning: GemiServer.app not bundled${NC}"
    echo "Run build_and_package.sh for complete bundle"
fi

# Get app size
APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
echo -e "${BLUE}App size: $APP_SIZE${NC}"

# Remove old DMG
if [ -f "$DMG_PATH" ]; then
    echo -e "${YELLOW}Removing old DMG...${NC}"
    rm -f "$DMG_PATH"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Creating temporary directory...${NC}"

# Copy app to temp directory
echo -e "${YELLOW}Copying Gemi.app...${NC}"
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$TEMP_DIR/Applications"

# Add background image if available
if [ -f "$BACKGROUND_IMAGE" ]; then
    echo -e "${YELLOW}Adding background image...${NC}"
    mkdir -p "$TEMP_DIR/.background"
    cp "$BACKGROUND_IMAGE" "$TEMP_DIR/.background/background.png"
fi

# Add volume icon if available
ICON_PATH="$PROJECT_ROOT/Documentation/assets-icons/gemi-icon.png"
if [ -f "$ICON_PATH" ]; then
    echo -e "${YELLOW}Creating volume icon...${NC}"
    sips -s format icns "$ICON_PATH" --out "$TEMP_DIR/.VolumeIcon.icns" 2>/dev/null || {
        echo -e "${YELLOW}Note: Could not create volume icon${NC}"
    }
fi

# Calculate DMG size (app size + 20% buffer)
APP_SIZE_MB=$(du -sm "$APP_PATH" | cut -f1)
DMG_SIZE=$((APP_SIZE_MB * 120 / 100))

# Create temporary DMG
echo -e "${YELLOW}Creating DMG...${NC}"
TEMP_DMG_PATH="${DMG_PATH%.dmg}_temp.dmg"
hdiutil create -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "$TEMP_DMG_PATH"

# Mount and configure DMG
echo -e "${YELLOW}Configuring DMG appearance...${NC}"
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG_PATH" | \
         grep '^/dev/' | awk '{print $1}')

# Wait for mount
sleep 2

# Configure with AppleScript
osascript <<EOD
tell application "Finder"
    tell disk "$DMG_VOLUME_NAME"
        open
        
        -- Configure window
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set sidebar width of container window to 0
        set the bounds of container window to {400, 100, 1000, 500}
        
        -- Configure view
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set label position of viewOptions to bottom
        set shows item info of viewOptions to false
        set shows icon preview of viewOptions to true
        
        -- Set background
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        
        -- Position icons
        set position of item "Gemi.app" of container window to {180, 200}
        set position of item "Applications" of container window to {420, 200}
        
        -- Update and close
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOD

# Set volume icon
if [ -f "/Volumes/$DMG_VOLUME_NAME/.VolumeIcon.icns" ]; then
    SetFile -a C "/Volumes/$DMG_VOLUME_NAME" 2>/dev/null || true
fi

# Unmount
echo -e "${YELLOW}Finalizing DMG...${NC}"
sync
hdiutil detach "$DEVICE" -quiet

# Convert to compressed DMG
hdiutil convert "$TEMP_DMG_PATH" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Clean up
rm -f "$TEMP_DMG_PATH"
rm -rf "$TEMP_DIR"

# Sign DMG if identity available
if security find-identity -p codesigning -v | grep -q "Apple Development"; then
    echo -e "${YELLOW}Signing DMG...${NC}"
    IDENTITY=$(security find-identity -p codesigning -v | grep "Apple Development" | head -1 | awk '{print $2}')
    codesign --force --sign "$IDENTITY" "$DMG_PATH" 2>/dev/null || {
        echo -e "${YELLOW}Note: DMG signing optional, continuing...${NC}"
    }
fi

# Final summary
DMG_FINAL_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
echo ""
echo -e "${GREEN}✅ DMG created successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Location:${NC} $DMG_PATH"
echo -e "${BLUE}Size:${NC}     $DMG_FINAL_SIZE"
echo -e "${BLUE}Volume:${NC}   $DMG_VOLUME_NAME"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Installation:"
echo "1. Double-click Gemi.dmg"
echo "2. Drag Gemi to Applications"
echo "3. Eject and enjoy!"