#!/bin/bash

# Gemi DMG Creation Script
# Creates a distributable DMG file with the Gemi app

set -e

echo "🎯 Creating Gemi DMG for distribution..."
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="/Users/chaeho/Library/Developer/Xcode/DerivedData/Gemi-gzhmrwuzvujrehgmrgxtydkgciay/Build/Products/Debug"
APP_PATH="$BUILD_DIR/Gemi.app"
DMG_NAME="Gemi"
DMG_VOLUME_NAME="Gemi - AI Diary"
DMG_PATH="$SCRIPT_DIR/${DMG_NAME}.dmg"
TEMP_DMG_PATH="$SCRIPT_DIR/${DMG_NAME}_temp.dmg"

# Check if Gemi.app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Gemi.app not found at $APP_PATH${NC}"
    echo "Please build the app in Xcode first."
    exit 1
fi

# Check if GemiServer.app is bundled
if [ ! -d "$APP_PATH/Contents/Resources/GemiServer.app" ]; then
    echo -e "${RED}Error: GemiServer.app not found in Gemi.app bundle${NC}"
    echo "Please run bundle_server.sh first to bundle the server."
    exit 1
fi

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

# Create a background image directory (optional)
mkdir -p "$TEMP_DIR/.background"

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

# Wait for volume to mount
sleep 2

# Set custom icon positions and window properties using AppleScript
echo -e "${YELLOW}Setting DMG window properties...${NC}"
osascript <<EOD
tell application "Finder"
    tell disk "$DMG_VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set position of item "Gemi.app" of container window to {150, 150}
        set position of item "Applications" of container window to {350, 150}
        update without registering applications
        delay 2
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