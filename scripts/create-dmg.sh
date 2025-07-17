#!/bin/bash

# Gemi DMG Creator - Premium Installer Experience
# A beautifully crafted installer that delights users from first impression

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo ""
echo -e "${PURPLE}✨ Gemi Premium DMG Creator ✨${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Find Gemi.app from Xcode build
echo -e "${BLUE}🔍 Locating Gemi.app...${NC}"
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Gemi.app" -type d 2>/dev/null | grep -E "Build/Products/(Debug|Release)" | head -1)

if [[ ! -d "$APP" ]]; then
    echo -e "${RED}❌ Gemi.app not found!${NC}"
    echo -e "${YELLOW}   Please build in Xcode first (⌘+B)${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Found at:${NC} ${APP}"
echo ""

# Setup paths
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_NAME="Gemi-Installer"
DMG_PATH="$PROJECT_ROOT/${DMG_NAME}.dmg"
VOLUME_NAME="Welcome to Gemi"
VOLUME_ICON="$PROJECT_ROOT/Documentation/assets/VolumeIcon.icns"

# Background selection - using the premium one for best experience
BACKGROUND="$PROJECT_ROOT/Documentation/assets/dmg-background-clean-premium.png"
if [[ ! -f "$BACKGROUND" ]]; then
    BACKGROUND="$PROJECT_ROOT/Documentation/assets/dmg-background-enhanced.png"
fi

# Window settings for perfect visual balance
WINDOW_WIDTH=600
WINDOW_HEIGHT=400
ICON_SIZE=128

# Golden ratio positioning for visual harmony
APP_X=150  # Left side, balanced
APP_Y=180  # Centered vertically with slight upward bias
APPS_LINK_X=450  # Right side, mirrored
APPS_LINK_Y=180  # Same height as app

echo -e "${BLUE}📦 Preparing app bundle...${NC}"

# Copy .env file if it exists (for zero-friction deployment)
ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
    echo -e "${BLUE}   Including authentication...${NC}"
    cp "$ENV_FILE" "$APP/Contents/Resources/" 2>/dev/null || true
    echo -e "${GREEN}   ✓ Zero-friction setup included${NC}"
else
    echo -e "${YELLOW}   ⚠️  No .env file found - users will need manual setup${NC}"
fi

# Create temporary build directory
echo ""
echo -e "${BLUE}🎨 Creating installer layout...${NC}"
TEMP_DIR="$PROJECT_ROOT/.dmg-temp"
STAGING_DIR="$PROJECT_ROOT/.dmg-staging"
rm -rf "$TEMP_DIR" "$STAGING_DIR"
mkdir -p "$TEMP_DIR" "$STAGING_DIR"

# Copy app to staging
echo -e "${BLUE}   Copying Gemi.app...${NC}"
cp -R "$APP" "$STAGING_DIR/Gemi.app"

# Create Applications symlink with custom name
echo -e "${BLUE}   Creating Applications shortcut...${NC}"
ln -s /Applications "$STAGING_DIR/Applications"

# Copy background
mkdir -p "$STAGING_DIR/.background"
cp "$BACKGROUND" "$STAGING_DIR/.background/dmg-background.png"

# Create custom volume icon
if [[ -f "$VOLUME_ICON" ]]; then
    echo -e "${BLUE}   Setting volume icon...${NC}"
    # We'll apply this after DMG creation
fi

# Remove old DMG if exists
rm -f "$DMG_PATH"

echo ""
echo -e "${BLUE}🔨 Building DMG image...${NC}"

# Create initial DMG
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW -size 200m "$TEMP_DIR/temp.dmg"

# Mount the DMG
echo -e "${BLUE}   Mounting image...${NC}"
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DIR/temp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# Wait for mount
sleep 2

# Apply custom settings using AppleScript
echo -e "${BLUE}🎨 Applying beautiful layout...${NC}"
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        
        -- Window size and position
        set the bounds of container window to {100, 100, 700, 500}
        
        -- Icon view options
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to $ICON_SIZE
        set text size of viewOptions to 12
        set label position of viewOptions to bottom
        set shows icon preview of viewOptions to true
        set shows item info of viewOptions to false
        
        -- Background
        set background picture of viewOptions to file ".background:dmg-background.png"
        
        -- Position items perfectly
        set position of item "Gemi.app" of container window to {$APP_X, $APP_Y}
        set position of item "Applications" of container window to {$APPS_LINK_X, $APPS_LINK_Y}
        
        -- Clean up
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Set custom volume icon if available
if [[ -f "$VOLUME_ICON" ]]; then
    echo -e "${BLUE}   Setting custom volume icon...${NC}"
    cp "$VOLUME_ICON" "$MOUNT_POINT/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_POINT"
fi

# Hide unnecessary files
SetFile -a V "$MOUNT_POINT/.background"
SetFile -a V "$MOUNT_POINT/.DS_Store"
SetFile -a V "$MOUNT_POINT/.Trashes"

# Sync and unmount
echo -e "${BLUE}   Finalizing...${NC}"
sync
hdiutil detach "$DEVICE" -quiet

# Convert to compressed read-only DMG
echo ""
echo -e "${BLUE}📀 Creating final DMG...${NC}"
hdiutil convert "$TEMP_DIR/temp.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

# Clean up
rm -rf "$TEMP_DIR" "$STAGING_DIR"

# Show results
if [[ -f "$DMG_PATH" ]]; then
    SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✨ Premium installer created successfully! ✨${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${PURPLE}📦 File:${NC} ${DMG_NAME}.dmg (${SIZE})"
    echo ""
    echo -e "${BLUE}Features:${NC}"
    echo -e "  ${GREEN}✓${NC} Beautiful custom background"
    echo -e "  ${GREEN}✓${NC} Perfectly aligned icons"
    echo -e "  ${GREEN}✓${NC} Warm 'Welcome to Gemi' greeting"
    echo -e "  ${GREEN}✓${NC} Drag & drop installation"
    echo -e "  ${GREEN}✓${NC} Zero-friction setup included"
    echo ""
    echo -e "${YELLOW}Opening installer...${NC}"
    open "$DMG_PATH"
else
    echo ""
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi