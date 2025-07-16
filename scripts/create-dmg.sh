#!/bin/bash

# Create Beautiful DMG for Gemi
# This script creates a premium DMG installer with drag-and-drop UI

set -e

echo "🎨 Creating beautiful DMG for Gemi..."

# Configuration
APP_NAME="Gemi"
APP_PATH="../Gemi/build/Release/Gemi.app"
DMG_NAME="Gemi-Installer"
DMG_FINAL="Gemi-Installer.dmg"
VOLUME_NAME="Gemi"
BACKGROUND_IMAGE="../Documentation/assets/dmg-background-clean-premium.png"

# Create directories
BUILD_DIR="build"
DMG_DIR="$BUILD_DIR/dmg"
TEMP_DMG="$BUILD_DIR/${DMG_NAME}-temp.dmg"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Clean up any existing build
echo "🧹 Cleaning up previous builds..."
rm -rf "$DMG_DIR"
rm -f "$BUILD_DIR"/*.dmg
mkdir -p "$DMG_DIR"

# Build the app in Release mode first
echo -e "${BLUE}🔨 Building Gemi in Release mode...${NC}"
cd ../Gemi
xcodebuild -project Gemi.xcodeproj -scheme Gemi -configuration Release build
cd ../scripts

# Verify the app was built
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Gemi.app not found at $APP_PATH"
    echo "Please build the app first with: xcodebuild -project Gemi.xcodeproj -scheme Gemi -configuration Release build"
    exit 1
fi

# Copy app to DMG staging directory
echo "📦 Copying Gemi.app..."
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink
echo "🔗 Creating Applications symlink..."
ln -s /Applications "$DMG_DIR/Applications"

# Copy background image
echo "🎨 Setting up background image..."
mkdir -p "$DMG_DIR/.background"
cp "$BACKGROUND_IMAGE" "$DMG_DIR/.background/dmg-background.png"

# Create temporary DMG
echo "💿 Creating temporary DMG..."
hdiutil create -srcfolder "$DMG_DIR" -volname "$VOLUME_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW "$TEMP_DMG"

# Mount the temporary DMG
echo "🔧 Mounting temporary DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# Wait for mount
sleep 2

# Set up the DMG window properties
echo -e "${BLUE}✨ Configuring DMG appearance...${NC}"
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        
        -- Window settings
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        
        -- Icon size and grid
        set icon size of viewOptions to 72
        set text size of viewOptions to 12
        set arrangement of viewOptions to not arranged
        
        -- Background
        set background picture of viewOptions to file ".background:dmg-background.png"
        
        -- Icon positions (centered for drag and drop)
        set position of item "Gemi.app" of container window to {150, 170}
        set position of item "Applications" of container window to {350, 170}
        
        -- Update and close
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Ensure window settings are saved
sync

# Make DMG read-only
echo "🔒 Finalizing DMG..."
hdiutil detach "$DEVICE"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$BUILD_DIR/$DMG_FINAL"
rm -f "$TEMP_DMG"

# Verify final DMG
if [ -f "$BUILD_DIR/$DMG_FINAL" ]; then
    DMG_SIZE=$(du -h "$BUILD_DIR/$DMG_FINAL" | cut -f1)
    echo -e "${GREEN}✅ Success! Created $DMG_FINAL ($DMG_SIZE)${NC}"
    echo -e "${GREEN}📍 Location: $(pwd)/$BUILD_DIR/$DMG_FINAL${NC}"
    
    # Optional: Open in Finder
    echo -e "\n${BLUE}Would you like to reveal the DMG in Finder? (y/n)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open -R "$BUILD_DIR/$DMG_FINAL"
    fi
else
    echo "❌ Error: Failed to create DMG"
    exit 1
fi

echo -e "\n🎉 DMG creation complete!"
echo "Next steps:"
echo "1. Test the DMG by double-clicking it"
echo "2. Drag Gemi to Applications folder"
echo "3. Eject the DMG"
echo "4. Run Gemi from Applications"