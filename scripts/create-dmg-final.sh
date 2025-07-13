#!/bin/bash
# Final DMG Creation Script for Gemi
# Creates a clean, professional installer with just Gemi.app and Applications

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

echo -e "${BLUE}🌟 Creating Final Gemi DMG Installer v$VERSION${NC}"
echo "============================================="

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}❌ Error: Source directory '$SOURCE_DIR' not found${NC}"
    exit 1
fi

# Check if Gemi.app exists
if [ ! -d "$SOURCE_DIR/Gemi.app" ]; then
    echo -e "${RED}❌ Error: Gemi.app not found in $SOURCE_DIR${NC}"
    exit 1
fi

if [ ! -d "$SOURCE_DIR/GemiServer.app" ]; then
    echo -e "${RED}❌ Error: GemiServer.app not found in $SOURCE_DIR${NC}"
    exit 1
fi

# Create new background with fixed alignment
echo -e "${GREEN}🎨 Creating background with proper alignment...${NC}"
python3 create_dmg_background_fixed.py

# Remove any existing DMG
if [ -f "$DMG_NAME" ]; then
    echo -e "${YELLOW}⚠️  Removing existing DMG...${NC}"
    rm -f "$DMG_NAME"
fi

# Remove any existing temp DMG
if [ -f "$TEMP_DMG" ]; then
    rm -f "$TEMP_DMG"
fi

# Unmount any existing volumes with same name
hdiutil detach "/Volumes/$DMG_VOLUME_NAME" 2>/dev/null || true
hdiutil detach "/Volumes/$DMG_VOLUME_NAME 2" 2>/dev/null || true

# Remove .DS_Store to ensure clean layout
rm -f "$SOURCE_DIR/.DS_Store"

# Calculate size needed (add 200MB buffer)
SOURCE_SIZE=$(du -sm "$SOURCE_DIR" | cut -f1)
DMG_SIZE=$((SOURCE_SIZE + 200))

echo -e "${GREEN}✨ Creating temporary DMG (${DMG_SIZE}MB)...${NC}"

# Create a temporary read-write DMG
hdiutil create -size ${DMG_SIZE}m -fs HFS+ -volname "$DMG_VOLUME_NAME" "$TEMP_DMG" -quiet

# Mount the temporary DMG
echo -e "${GREEN}📦 Mounting temporary DMG...${NC}"
MOUNT_OUTPUT=$(hdiutil attach "$TEMP_DMG" -nobrowse -noverify -noautoopen -quiet)
MOUNT_POINT="/Volumes/$DMG_VOLUME_NAME"

# Copy files to the mounted DMG (only what users need to see)
echo -e "${GREEN}📄 Copying files...${NC}"
cp -R "$SOURCE_DIR/Gemi.app" "$MOUNT_POINT/"
cp -R "$SOURCE_DIR/GemiServer.app" "$MOUNT_POINT/"
cp "$SOURCE_DIR/NOTICE.txt" "$MOUNT_POINT/"
cp "$SOURCE_DIR/GEMMA_TERMS_OF_USE.txt" "$MOUNT_POINT/"

# Copy background
mkdir -p "$MOUNT_POINT/.background"
cp "$SOURCE_DIR/.background/installer-bg.png" "$MOUNT_POINT/.background/"

# Create Applications symlink
ln -s /Applications "$MOUNT_POINT/Applications"

# Hide unnecessary files
SetFile -a V "$MOUNT_POINT/NOTICE.txt" 2>/dev/null || true
SetFile -a V "$MOUNT_POINT/GEMMA_TERMS_OF_USE.txt" 2>/dev/null || true
SetFile -a V "$MOUNT_POINT/GemiServer.app" 2>/dev/null || true
SetFile -a V "$MOUNT_POINT/.background" 2>/dev/null || true

# Set custom icon positions using AppleScript
echo -e "${GREEN}🎨 Configuring DMG window...${NC}"
osascript <<EOF
tell application "Finder"
    tell disk "$DMG_VOLUME_NAME"
        open
        
        -- Configure window
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 520}
        
        -- Configure view options
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set background picture of viewOptions to file ".background:installer-bg.png"
        
        -- Position visible items (only 2 now)
        delay 1
        
        -- Gemi.app on the left
        set position of item "Gemi.app" of container window to {150, 150}
        
        -- Applications folder on the right
        set position of item "Applications" of container window to {450, 150}
        
        -- Update and close
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Force Finder to save the view settings
echo -e "${GREEN}💾 Saving window settings...${NC}"
sync
sleep 2

# Unmount the temporary DMG
echo -e "${GREEN}🔧 Finalizing DMG...${NC}"
hdiutil detach "$MOUNT_POINT" -quiet

# Convert to compressed read-only DMG
echo -e "${GREEN}🗜️  Compressing DMG...${NC}"
hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_NAME" -quiet

# Clean up
rm -f "$TEMP_DMG"
rm -f create_dmg_background_fixed.py

# Verify the DMG
echo -e "${GREEN}✅ Verifying DMG...${NC}"
hdiutil verify "$DMG_NAME" -quiet

# Get final size
if [ -f "$DMG_NAME" ]; then
    SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo ""
    echo -e "${GREEN}✅ Clean DMG created successfully!${NC}"
    echo -e "${BLUE}📦 File: $DMG_NAME${NC}"
    echo -e "${BLUE}📏 Size: $SIZE${NC}"
    echo ""
    echo -e "${GREEN}What users see:${NC}"
    echo "  • Gemi.app - Drag this to Applications"
    echo "  • Applications - Drop target"
    echo ""
    echo -e "${GREEN}Hidden components:${NC}"
    echo "  • GemiServer.app - Bundled AI engine"
    echo "  • Legal notices - Terms of use"
    echo ""
    echo -e "${BLUE}🎉 Professional DMG ready for distribution!${NC}"
else
    echo -e "${RED}❌ Error: DMG creation failed${NC}"
    exit 1
fi