#!/bin/bash

# Gemi DMG Creator - The Perfect One
# Usage: Build in Xcode (Cmd+B), then run ./scripts/create-dmg.sh

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🎨 Gemi DMG Creator${NC}"
echo "===================="

# Setup paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FINAL_DMG="$PROJECT_ROOT/Gemi.dmg"
BACKGROUND="$PROJECT_ROOT/Documentation/assets/dmg-background-clean-premium.png"

# Find Gemi.app
echo -e "${BLUE}Looking for Gemi.app...${NC}"
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Gemi.app" -type d 2>/dev/null | head -1)

if [[ ! -d "$APP/Contents" ]]; then
    echo -e "${RED}❌ Gemi.app not found!${NC}"
    echo "Please build in Xcode first (Cmd+B)"
    exit 1
fi

echo -e "${GREEN}✓ Found${NC}"

# Create DMG
echo -e "${BLUE}Creating DMG...${NC}"
rm -f "$FINAL_DMG"

# Simple method that always works
hdiutil create -volname "Gemi" \
    -srcfolder "$APP" \
    -ov \
    -format UDZO \
    "$FINAL_DMG"

# Show result
if [[ -f "$FINAL_DMG" ]]; then
    SIZE=$(du -h "$FINAL_DMG" | cut -f1)
    echo ""
    echo -e "${GREEN}✨ Success!${NC}"
    echo -e "📦 Created: ${BLUE}Gemi.dmg${NC} (${SIZE})"
    echo ""
    echo "To create a DMG with background image:"
    echo "1. Install: brew install create-dmg"
    echo "2. Run: create-dmg --volname Gemi --background $BACKGROUND --window-size 600 400 --icon-size 100 --icon Gemi.app 150 200 --app-drop-link 450 200 $FINAL_DMG $APP"
    echo ""
    open -R "$FINAL_DMG"
else
    echo -e "${RED}❌ Failed${NC}"
    exit 1
fi