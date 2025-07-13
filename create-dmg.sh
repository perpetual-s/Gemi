#!/bin/bash
# Gemi DMG Creation Script
# Creates a professional .dmg installer for Gemi

set -e  # Exit on any error

# Configuration
VERSION="1.0.0"
DMG_NAME="Gemi-$VERSION.dmg"
DMG_VOLUME_NAME="Gemi"
SOURCE_DIR="gemi-release"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌟 Creating Gemi DMG Installer v$VERSION${NC}"
echo "=========================================="

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo -e "${RED}❌ Error: create-dmg is not installed${NC}"
    echo "Install it with: brew install create-dmg"
    exit 1
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}❌ Error: Source directory '$SOURCE_DIR' not found${NC}"
    exit 1
fi

# Check if both apps exist
if [ ! -d "$SOURCE_DIR/Gemi.app" ]; then
    echo -e "${RED}❌ Error: Gemi.app not found in $SOURCE_DIR${NC}"
    echo "Please build Gemi.app first with:"
    echo "  cd Gemi && xcodebuild -scheme Gemi -configuration Release"
    echo "  cp -R build/Build/Products/Release/Gemi.app ../gemi-release/"
    exit 1
fi

if [ ! -d "$SOURCE_DIR/GemiServer.app" ]; then
    echo -e "${RED}❌ Error: GemiServer.app not found in $SOURCE_DIR${NC}"
    echo "Please build GemiServer.app first"
    exit 1
fi

# Remove any existing DMG
if [ -f "$DMG_NAME" ]; then
    echo -e "${YELLOW}⚠️  Removing existing DMG...${NC}"
    rm -f "$DMG_NAME"
fi

# Create DMG
echo -e "${GREEN}✨ Creating DMG...${NC}"
echo ""

# Use create-dmg with minimal options for reliability
create-dmg \
  --volname "$DMG_VOLUME_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Gemi.app" 150 150 \
  --hide-extension "Gemi.app" \
  --icon "GemiServer.app" 150 250 \
  --hide-extension "GemiServer.app" \
  --icon "Install-Gemi.command" 300 200 \
  --app-drop-link 450 150 \
  --skip-jenkins \
  "$DMG_NAME" \
  "$SOURCE_DIR/"

# Check if DMG was created successfully
if [ -f "$DMG_NAME" ]; then
    # Get file size
    SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo ""
    echo -e "${GREEN}✅ DMG created successfully!${NC}"
    echo -e "${BLUE}📦 File: $DMG_NAME${NC}"
    echo -e "${BLUE}📏 Size: $SIZE${NC}"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "1. Test the DMG on a clean system"
    echo "2. Code sign if you have a Developer ID:"
    echo "   codesign --force --sign \"Developer ID Application: Your Name\" $DMG_NAME"
    echo "3. Notarize for distribution (optional):"
    echo "   xcrun notarytool submit $DMG_NAME --keychain-profile \"AC_PASSWORD\" --wait"
    echo ""
    echo -e "${BLUE}🎉 Ready for hackathon submission!${NC}"
else
    echo -e "${RED}❌ Error: DMG creation failed${NC}"
    exit 1
fi