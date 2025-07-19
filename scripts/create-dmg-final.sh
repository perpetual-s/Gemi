#!/bin/bash

# Gemi DMG Creator - Final Production Version
# Creates a DMG with properly preserved background image

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo ""
echo -e "${PURPLE}✨ Gemi Final DMG Creator ✨${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Accept app path as argument
APP="$1"
if [[ -z "$APP" ]] || [[ ! -d "$APP" ]]; then
    echo -e "${RED}❌ Usage: $0 /path/to/Gemi.app${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Using app:${NC} ${APP}"

# Setup paths
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_NAME="Gemi-Installer"
FINAL_DMG="$PROJECT_ROOT/${DMG_NAME}.dmg"
VOLUME_NAME="Welcome to Gemi"

# Find background
BACKGROUND=""
BACKGROUNDS=(
    "$PROJECT_ROOT/Documentation/assets/dmg-background-clean-premium.png"
    "$PROJECT_ROOT/Documentation/assets/dmg-background-premium-auto.png"
    "$PROJECT_ROOT/Documentation/assets/dmg-background-enhanced.png"
)

for bg in "${BACKGROUNDS[@]}"; do
    if [[ -f "$bg" ]]; then
        BACKGROUND="$bg"
        echo -e "${GREEN}✓ Background:${NC} $(basename "$bg")"
        break
    fi
done

if [[ -z "$BACKGROUND" ]]; then
    echo -e "${RED}❌ No background found${NC}"
    exit 1
fi

# Get app size
APP_SIZE=$(du -sm "$APP" | cut -f1)
DMG_SIZE=$((APP_SIZE + 100))  # Add 100MB buffer
echo -e "${GREEN}✓ DMG Size:${NC} ${DMG_SIZE}MB"

# Create staging
echo -e "\n${BLUE}📦 Preparing installer...${NC}"
STAGING="$PROJECT_ROOT/.dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"

# Copy content
cp -R "$APP" "$STAGING/Gemi.app"
ln -s /Applications "$STAGING/Applications"
mkdir -p "$STAGING/.background"
cp "$BACKGROUND" "$STAGING/.background/background.png"

# Clean up any old files
rm -f "$FINAL_DMG" "$PROJECT_ROOT/temp.dmg" "$PROJECT_ROOT/pack.dmg"

# Create R/W DMG
echo -e "${BLUE}🔨 Creating DMG...${NC}"
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    -size ${DMG_SIZE}m \
    "$PROJECT_ROOT/pack.dmg"

# Mount it
echo -e "${BLUE}🎨 Applying styling...${NC}"
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$PROJECT_ROOT/pack.dmg" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')

sleep 2

# Force Finder to create window
osascript <<EOF
tell application "Finder"
    -- Force window creation
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        delay 1
        close
    end tell
end tell
EOF

sleep 1

# Now apply all settings
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        
        set theWindow to container window
        
        -- Window properties
        set current view of theWindow to icon view
        set toolbar visible of theWindow to false
        set statusbar visible of theWindow to false
        set bounds of theWindow to {100, 100, 700, 500}
        
        -- View options
        set viewOptions to icon view options of theWindow
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set shows icon preview of viewOptions to true
        set shows item info of viewOptions to false
        
        -- CRITICAL: Set background with delay
        delay 1
        set background picture of viewOptions to file ".background:background.png"
        
        -- Position icons
        delay 1
        set position of item "Gemi.app" to {150, 200}
        set position of item "Applications" to {450, 200}
        
        -- Force update
        update without registering applications
        delay 2
        
        -- Close to force .DS_Store write
        close
        
        -- Reopen to verify
        delay 1
        open
        delay 1
        close
    end tell
end tell
EOF

# Ensure .DS_Store is written
echo -e "${BLUE}   Ensuring settings persist...${NC}"
sync
sleep 3

# Verify .DS_Store exists
if [[ -f "/Volumes/$VOLUME_NAME/.DS_Store" ]]; then
    echo -e "${GREEN}✓ Window settings saved${NC}"
else
    echo -e "${YELLOW}⚠ Window settings may not persist${NC}"
fi

# Hide background folder
chflags hidden "/Volumes/$VOLUME_NAME/.background"

# Final sync
sync
sleep 1

# Unmount
echo -e "${BLUE}📀 Finalizing...${NC}"
hdiutil detach "$DEVICE" -quiet

# Convert to compressed
hdiutil convert "$PROJECT_ROOT/pack.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG"

# Cleanup
rm -f "$PROJECT_ROOT/pack.dmg"
rm -rf "$STAGING"

# Done
if [[ -f "$FINAL_DMG" ]]; then
    SIZE=$(du -h "$FINAL_DMG" | cut -f1)
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✨ DMG Created Successfully! ✨${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${PURPLE}📦 File:${NC} ${DMG_NAME}.dmg"
    echo -e "${PURPLE}📏 Size:${NC} ${SIZE}"
    echo -e "${PURPLE}📍 Path:${NC} ${FINAL_DMG}"
    echo ""
    echo -e "${BLUE}The DMG includes:${NC}"
    echo -e "  • Beautiful background image"
    echo -e "  • Drag-and-drop installation"
    echo -e "  • No authentication required"
    echo ""
    echo -e "${GREEN}Ready for release!${NC}"
else
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi