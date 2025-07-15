#!/bin/bash
# Advanced DMG Creation Script for Gemi
# Creates a beautiful DMG with custom layout and drag-to-install experience

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🎨 Creating Advanced Gemi DMG${NC}"
echo "================================"

# Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Try to find Gemi.app in various locations
APP_LOCATIONS=(
    "$HOME/Library/Developer/Xcode/DerivedData/Gemi-*/Build/Products/Debug/Gemi.app"
    "$HOME/Library/Developer/Xcode/DerivedData/Gemi-*/Build/Products/Release/Gemi.app"
    "$PROJECT_ROOT/gemi-release/Gemi.app"
    "$PROJECT_ROOT/build/DerivedData/Build/Products/Release/Gemi.app"
)

APP_PATH=""
for location in "${APP_LOCATIONS[@]}"; do
    found_apps=($(ls -d $location 2>/dev/null || true))
    if [ ${#found_apps[@]} -gt 0 ]; then
        APP_PATH="${found_apps[0]}"
        break
    fi
done

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Gemi.app not found. Please build the app first.${NC}"
    echo "Run: ./scripts/build_and_package.sh"
    exit 1
fi

echo -e "${GREEN}Found Gemi.app at: $APP_PATH${NC}"

# Check if GemiServer.app is bundled
if [ ! -d "$APP_PATH/Contents/Resources/GemiServer.app" ]; then
    echo -e "${RED}Error: GemiServer.app not found in Gemi.app bundle${NC}"
    echo "Please run build_and_package.sh first to bundle the server."
    exit 1
fi

# DMG configuration
DMG_NAME="Gemi"
DMG_VOLUME_NAME="Gemi - AI Diary"
DMG_PATH="$PROJECT_ROOT/${DMG_NAME}.dmg"
TEMP_DMG_PATH="$PROJECT_ROOT/${DMG_NAME}_temp.dmg"

# Remove old DMG if exists
if [ -f "$DMG_PATH" ]; then
    echo -e "${YELLOW}Removing old DMG...${NC}"
    rm -f "$DMG_PATH"
fi

# Create a temporary directory for DMG contents
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Creating temporary directory: $TEMP_DIR${NC}"

# Copy app to temporary directory
echo -e "${YELLOW}Copying Gemi.app...${NC}"
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create symbolic link to Applications folder  
echo -e "${YELLOW}Creating Applications symlink...${NC}"
ln -s /Applications "$TEMP_DIR/Applications"

# Add custom volume icon if available
VOLUME_ICON="$PROJECT_ROOT/Documentation/assets-icons/gemi-icon.icns"
if [ ! -f "$VOLUME_ICON" ]; then
    # Try to create from PNG if ICNS doesn't exist
    PNG_ICON="$PROJECT_ROOT/Documentation/assets-icons/gemi-icon.png"
    if [ -f "$PNG_ICON" ]; then
        echo -e "${YELLOW}Converting PNG icon to ICNS...${NC}"
        VOLUME_ICON="$TEMP_DIR/.VolumeIcon.icns"
        sips -s format icns "$PNG_ICON" --out "$VOLUME_ICON" 2>/dev/null || true
    fi
fi

if [ -f "$VOLUME_ICON" ]; then
    echo -e "${YELLOW}Adding custom volume icon...${NC}"
    cp "$VOLUME_ICON" "$TEMP_DIR/.VolumeIcon.icns"
fi

# Create and set up background image
mkdir -p "$TEMP_DIR/.background"

# Look for background image
BACKGROUND_IMAGE="$PROJECT_ROOT/Documentation/assets-icons/dmg-background.png"
if [ -f "$BACKGROUND_IMAGE" ]; then
    echo -e "${YELLOW}Adding background image...${NC}"
    cp "$BACKGROUND_IMAGE" "$TEMP_DIR/.background/background.png"
else
    echo -e "${YELLOW}No background image found, using default appearance${NC}"
fi

# Get app size
APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
echo -e "${GREEN}App size: $APP_SIZE${NC}"

# Calculate DMG size (app size + 100MB buffer)
APP_SIZE_MB=$(du -sm "$APP_PATH" | cut -f1)
DMG_SIZE=$((APP_SIZE_MB + 100))

# Create temporary DMG
echo -e "${YELLOW}Creating temporary DMG...${NC}"
hdiutil create -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "$TEMP_DMG_PATH"

# Mount the temporary DMG
echo -e "${YELLOW}Mounting temporary DMG...${NC}"
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG_PATH")
DEVICE=$(echo "$MOUNT_OUTPUT" | grep '^/dev/' | awk '{print $1}')
VOLUME="/Volumes/$DMG_VOLUME_NAME"

# Set custom volume icon if it was added
if [ -f "$VOLUME/.VolumeIcon.icns" ]; then
    SetFile -a C "$VOLUME" 2>/dev/null || true
fi

# Wait for volume to mount
sleep 2

# Set custom icon positions and window properties using AppleScript
echo -e "${YELLOW}Setting DMG window properties...${NC}"

# Enhanced AppleScript for beautiful DMG appearance
osascript <<EOD
tell application "Finder"
    tell disk "$DMG_VOLUME_NAME"
        open
        
        -- Window properties
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set sidebar width of container window to 0
        
        -- Window size (matches background image if present)
        set the bounds of container window to {400, 100, 1000, 500}
        
        -- View options
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set label position of viewOptions to bottom
        set shows item info of viewOptions to false
        set shows icon preview of viewOptions to true
        
        -- Set background if image exists
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        
        -- Icon positions for drag-and-drop
        set position of item "Gemi.app" of container window to {180, 200}
        set position of item "Applications" of container window to {420, 200}
        
        -- Apply changes
        close
        open
        update without registering applications
        delay 3
        close
    end tell
end tell
EOD

# Ensure window changes are saved
sync

# Unmount the temporary DMG
echo -e "${YELLOW}Unmounting temporary DMG...${NC}"
hdiutil detach "$DEVICE" -quiet

# Convert to compressed DMG
echo -e "${YELLOW}Creating final compressed DMG...${NC}"
hdiutil convert "$TEMP_DMG_PATH" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
rm -f "$TEMP_DMG_PATH"
rm -rf "$TEMP_DIR"

# Sign the DMG (if code signing identity is available)
if security find-identity -p codesigning -v | grep -q "Developer ID Application"; then
    echo -e "${YELLOW}Signing DMG...${NC}"
    codesign --force --sign "Developer ID Application" "$DMG_PATH" || {
        echo -e "${YELLOW}Warning: Could not sign DMG with Developer ID${NC}"
    }
else
    echo -e "${YELLOW}No Developer ID found, creating unsigned DMG${NC}"
fi

# Get final DMG size
DMG_FINAL_SIZE=$(du -sh "$DMG_PATH" | cut -f1)

echo -e "${GREEN}✅ DMG created successfully!${NC}"
echo ""
echo "DMG Information:"
echo "Location: $DMG_PATH"
echo "Size: $DMG_FINAL_SIZE"
echo "Volume Name: $DMG_VOLUME_NAME"
echo ""
echo "The DMG contains:"
echo "- Gemi.app (with bundled GemiServer.app)"
echo "- Symbolic link to /Applications folder"
echo ""
echo "Users can install by:"
echo "1. Double-clicking the DMG file"
echo "2. Dragging Gemi.app to the Applications folder"
echo "3. Running Gemi from Applications"