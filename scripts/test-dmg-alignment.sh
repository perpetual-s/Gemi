#!/bin/bash

# Test script to find perfect icon alignment for DMG

echo "DMG Alignment Tester"
echo "==================="
echo ""
echo "This will help you find the perfect X,Y coordinates for icons."
echo ""

# Get current values from create-dmg.sh
APP_X=${1:-150}
APP_Y=${2:-190}
APPS_X=${3:-450}
APPS_Y=${4:-190}

echo "Current positions:"
echo "  Gemi.app: ($APP_X, $APP_Y)"
echo "  Applications: ($APPS_X, $APPS_Y)"
echo ""
echo "To test different positions, run:"
echo "  $0 <APP_X> <APP_Y> <APPS_X> <APPS_Y>"
echo ""

# Create a quick test DMG
TEMP_DIR="/tmp/dmg-test-$$"
TEMP_DMG="/tmp/test-alignment.dmg"
MOUNTED_NAME="Test Alignment"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
    rm -f "$TEMP_DMG"
    if [ -n "${DEVICE:-}" ]; then
        hdiutil detach "$DEVICE" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

# Create test structure
mkdir -p "$TEMP_DIR/.background"
mkdir -p "$TEMP_DIR/Gemi.app"
ln -s /Applications "$TEMP_DIR/Applications"

# Copy background if available
BG_IMAGE="/Users/chaeho/Documents/project-Gemi/Documentation/assets/dmg-background-clean-premium.png"
if [ -f "$BG_IMAGE" ]; then
    cp "$BG_IMAGE" "$TEMP_DIR/.background/dmg-background.png"
fi

# Create DMG
hdiutil create -srcfolder "$TEMP_DIR" -volname "$MOUNTED_NAME" -fs HFS+ -format UDRW "$TEMP_DMG" >/dev/null 2>&1

# Mount and configure
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 1

# Configure with AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "$MOUNTED_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 1000, 600}
        
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 90
        set text size of viewOptions to 13
        set label position of viewOptions to bottom
        set arrangement of viewOptions to not arranged
        set background picture of viewOptions to file ".background:dmg-background.png"
        
        delay 1
        
        -- Test positions
        set position of item "Gemi.app" of container window to {${APP_X}, ${APP_Y}}
        set position of item "Applications" of container window to {${APPS_X}, ${APPS_Y}}
        
        update without registering applications
        
        -- Show grid reference (in Terminal output)
        get position of item "Gemi.app" of container window
        get position of item "Applications" of container window
    end tell
end tell
EOF

echo ""
echo "DMG window is now open. Adjust icon positions manually if needed."
echo "When done, press Enter to see the final coordinates..."
read

# Get final positions
osascript <<EOF
tell application "Finder"
    tell disk "$MOUNTED_NAME"
        set gemiPos to position of item "Gemi.app" of container window
        set appsPos to position of item "Applications" of container window
        
        log "Final Gemi.app position: " & (item 1 of gemiPos) & ", " & (item 2 of gemiPos)
        log "Final Applications position: " & (item 1 of appsPos) & ", " & (item 2 of appsPos)
    end tell
end tell
EOF

echo ""
echo "Update create-dmg.sh with these values for perfect alignment!"