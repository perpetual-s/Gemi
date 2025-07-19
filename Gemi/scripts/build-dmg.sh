#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCODEPROJ="$PROJECT_ROOT/Gemi.xcodeproj"

echo -e "${PURPLE}✨ Gemi Premium DMG Creator ✨${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check for .env file (optional for mlx-community models)
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${GREEN}✅ Found .env file${NC}"
else
    echo -e "${YELLOW}ℹ .env file not found at $PROJECT_ROOT/.env${NC}"
    echo -e "${GREEN}  This is OK - mlx-community models don't require authentication${NC}"
fi

# Clean previous build
echo -e "\n${BLUE}🧹 Cleaning previous build...${NC}"
xcodebuild clean -scheme Gemi -configuration Release -project "$XCODEPROJ" > /dev/null 2>&1

# Build the app
echo -e "${BLUE}🔨 Building Gemi.app (this may take a minute)...${NC}"
BUILD_OUTPUT=$(mktemp)
if xcodebuild -scheme Gemi \
    -configuration Release \
    -project "$XCODEPROJ" \
    -derivedDataPath "$PROJECT_ROOT/build/DerivedData" \
    -destination "platform=macOS" \
    build 2>&1 | tee "$BUILD_OUTPUT" | grep -E "^\*\*|error:|warning:" ; then
    echo -e "${GREEN}✓ Build completed successfully${NC}"
else
    echo -e "${RED}❌ Build failed. Check the output above.${NC}"
    rm -f "$BUILD_OUTPUT"
    exit 1
fi
rm -f "$BUILD_OUTPUT"

# Find the built app - check multiple possible locations
echo -e "\n${BLUE}Locating built app...${NC}"
APP_PATH=""
POSSIBLE_PATHS=(
    "$PROJECT_ROOT/build/DerivedData/Build/Products/Release/Gemi.app"
    "$PROJECT_ROOT/build/Build/Products/Release/Gemi.app"
    "$HOME/Library/Developer/Xcode/DerivedData/Gemi-*/Build/Products/Release/Gemi.app"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path" ] || compgen -G "$path" > /dev/null 2>&1; then
        if [ -d "$path" ]; then
            APP_PATH="$path"
        else
            APP_PATH=$(compgen -G "$path" | head -1)
        fi
        echo -e "Found in custom build directory"
        break
    fi
done

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: Gemi.app not found in any expected location${NC}"
    echo -e "${YELLOW}Searched in:${NC}"
    for path in "${POSSIBLE_PATHS[@]}"; do
        echo -e "  - $path"
    done
    exit 1
fi

echo -e "${GREEN}✓ Found app at: $APP_PATH${NC}"

# No need to copy .env for mlx-community models
# They don't require authentication

# Create DMG
DMG_NAME="Gemi-$(date +%Y%m%d).dmg"
echo -e "\n${BLUE}Creating DMG installer...${NC}"
echo

echo -e "${PURPLE}✨ Gemi Premium DMG Creator ✨${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Clean up any existing temp directories
rm -rf "$PROJECT_ROOT/.dmg-temp" 2>/dev/null || true

# Create temporary directory for DMG contents
TEMP_DIR="$PROJECT_ROOT/.dmg-temp"
mkdir -p "$TEMP_DIR"

echo -e "${BLUE}🔍 Using Gemi.app...${NC}"
echo -e "${GREEN}✓ Located at: $APP_PATH${NC}"

echo -e "\n${BLUE}📦 Preparing app bundle...${NC}"
echo -e "   ${GREEN}✓ No authentication required${NC}"
echo -e "   ${GREEN}✓ Models download automatically${NC}"

echo -e "\n${BLUE}🎨 Creating installer layout...${NC}"
echo -e "   Copying Gemi.app..."
cp -R "$APP_PATH" "$TEMP_DIR/"
echo -e "   Creating Applications shortcut..."
ln -sf /Applications "$TEMP_DIR/Applications"

# Create a simple background image or use existing one if available
echo -e "   Setting volume icon..."

echo -e "\n${BLUE}🔨 Building DMG image...${NC}"

# Create initial DMG
TEMP_DMG="$TEMP_DIR/temp.dmg"
hdiutil create -volname "Welcome to Gemi" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDRW \
    "$TEMP_DMG" > /dev/null 2>&1

echo -e "   Mounting image..."

# Mount the DMG
MOUNT_OUTPUT=$(hdiutil attach "$TEMP_DMG" -nobrowse -noverify -noautoopen 2>&1)
DEVICE=$(echo "$MOUNT_OUTPUT" | grep -E '^/dev/' | awk '{print $1}' | head -1)
VOLUME=$(echo "$MOUNT_OUTPUT" | grep 'Volumes' | awk -F'\t' '{print $NF}' | head -1)

if [ -z "$VOLUME" ]; then
    echo -e "${RED}❌ Failed to mount DMG${NC}"
    hdiutil detach "$DEVICE" 2>/dev/null || true
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${BLUE}🎨 Applying beautiful layout...${NC}"

# Set custom icon positions using AppleScript (with error handling)
osascript > /dev/null 2>&1 <<EOF || true
try
    tell application "Finder"
        tell disk "Welcome to Gemi"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {400, 100, 900, 500}
            set viewOptions to the icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 100
            set position of item "Gemi.app" of container window to {150, 200}
            set position of item "Applications" of container window to {350, 200}
            close
            open
            update without registering applications
            delay 1
        end tell
    end tell
on error errMsg
    -- Silently ignore Finder errors
end try
EOF

# Skip SetFile operations entirely to avoid .Trashes errors
# The DMG will work fine without custom volume attributes

# Make sure everything is flushed to disk
sync

echo -e "\n${BLUE}📀 Finalizing DMG...${NC}"

# Unmount
hdiutil detach "$DEVICE" -quiet

# Convert to compressed read-only DMG
FINAL_DMG="$PROJECT_ROOT/$DMG_NAME"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" > /dev/null 2>&1

# Clean up
rm -rf "$TEMP_DIR"

# Final size
DMG_SIZE=$(du -h "$FINAL_DMG" | cut -f1)

echo
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ Success! DMG created${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "📦 ${BLUE}File:${NC} $DMG_NAME"
echo -e "📏 ${BLUE}Size:${NC} $DMG_SIZE"
echo -e "📍 ${BLUE}Location:${NC} $PROJECT_ROOT"
echo

# Optional: Open DMG location
if [ "${1:-}" != "--no-open" ]; then
    echo -e "${BLUE}Opening folder...${NC}"
    open "$PROJECT_ROOT"
fi