#!/bin/bash
# Simple DMG Creation Script for Gemi
# Uses built-in macOS tools instead of create-dmg

set -e  # Exit on any error

# Configuration
VERSION="1.0.0"
DMG_NAME="Gemi-$VERSION.dmg"
DMG_VOLUME_NAME="Gemi"
SOURCE_DIR="gemi-release"
TEMP_DMG="/tmp/Gemi-temp.dmg"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌟 Creating Gemi DMG Installer v$VERSION (Simple Method)${NC}"
echo "================================================"

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}❌ Error: Source directory '$SOURCE_DIR' not found${NC}"
    exit 1
fi

# Check if both apps exist
if [ ! -d "$SOURCE_DIR/Gemi.app" ]; then
    echo -e "${RED}❌ Error: Gemi.app not found in $SOURCE_DIR${NC}"
    exit 1
fi

if [ ! -d "$SOURCE_DIR/GemiServer.app" ]; then
    echo -e "${RED}❌ Error: GemiServer.app not found in $SOURCE_DIR${NC}"
    exit 1
fi

# Remove any existing DMG
if [ -f "$DMG_NAME" ]; then
    echo -e "${YELLOW}⚠️  Removing existing DMG...${NC}"
    rm -f "$DMG_NAME"
fi

# Remove any existing temp DMG
if [ -f "$TEMP_DMG" ]; then
    rm -f "$TEMP_DMG"
fi

# Calculate size needed (add 200MB buffer)
SOURCE_SIZE=$(du -sm "$SOURCE_DIR" | cut -f1)
DMG_SIZE=$((SOURCE_SIZE + 200))

echo -e "${GREEN}✨ Creating temporary DMG (${DMG_SIZE}MB)...${NC}"

# Create a temporary read-write DMG
hdiutil create -size ${DMG_SIZE}m -fs HFS+ -volname "$DMG_VOLUME_NAME" "$TEMP_DMG"

# Mount the temporary DMG
echo -e "${GREEN}📦 Mounting temporary DMG...${NC}"
MOUNT_POINT=$(hdiutil attach "$TEMP_DMG" -nobrowse -noverify -noautoopen | grep "/Volumes" | awk '{print $3}')

# Copy files to the mounted DMG
echo -e "${GREEN}📄 Copying files...${NC}"
cp -R "$SOURCE_DIR/"* "$MOUNT_POINT/"

# Create a symbolic link to Applications
echo -e "${GREEN}🔗 Creating Applications link...${NC}"
ln -s /Applications "$MOUNT_POINT/Applications"

# Optional: Set custom icon positions using AppleScript
echo -e "${GREEN}🎨 Setting icon positions...${NC}"
osascript <<EOF
tell application "Finder"
    tell disk "$DMG_VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        
        -- Set positions
        try
            set position of item "Gemi.app" of container window to {150, 150}
            set position of item "GemiServer.app" of container window to {150, 250}
            set position of item "Install-Gemi.command" of container window to {300, 200}
            set position of item "Applications" of container window to {450, 150}
        end try
        
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Unmount the temporary DMG
echo -e "${GREEN}🔧 Unmounting temporary DMG...${NC}"
hdiutil detach "$MOUNT_POINT" -quiet

# Convert to compressed read-only DMG
echo -e "${GREEN}🗜️  Compressing DMG...${NC}"
hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_NAME"

# Clean up
rm -f "$TEMP_DMG"

# Verify the DMG
echo -e "${GREEN}✅ Verifying DMG...${NC}"
hdiutil verify "$DMG_NAME"

# Get final size
if [ -f "$DMG_NAME" ]; then
    SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo ""
    echo -e "${GREEN}✅ DMG created successfully!${NC}"
    echo -e "${BLUE}📦 File: $DMG_NAME${NC}"
    echo -e "${BLUE}📏 Size: $SIZE${NC}"
    echo ""
    echo -e "${GREEN}What's inside:${NC}"
    echo "  • Gemi.app - The main application"
    echo "  • GemiServer.app - Bundled AI inference server (979MB)"
    echo "  • Install-Gemi.command - Professional installer script"
    echo "  • Legal notices - Gemma terms of use"
    echo ""
    echo -e "${GREEN}Testing the DMG:${NC}"
    echo "1. Mount: hdiutil attach $DMG_NAME"
    echo "2. Run installer: /Volumes/Gemi/Install-Gemi.command"
    echo "3. Or drag Gemi to Applications manually"
    echo ""
    echo -e "${BLUE}🎉 Ready for hackathon submission!${NC}"
else
    echo -e "${RED}❌ Error: DMG creation failed${NC}"
    exit 1
fi