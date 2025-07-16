#!/bin/bash

# ============================================================================
# Gemi DMG Creator - Enhanced Premium Edition
# ============================================================================
# Creates a beautiful DMG with guaranteed background image display
# Uses alternative methods to ensure the background appears correctly
# ============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly APP_NAME="Gemi"
readonly VOLUME_NAME="Gemi Installer"
readonly DMG_NAME="Gemi-Installer"
readonly BACKGROUND_IMAGE="$PROJECT_ROOT/Documentation/assets/dmg-background-clean-premium.png"

# Build paths
readonly BUILD_DIR="$SCRIPT_DIR/build"
readonly STAGING_DIR="$BUILD_DIR/dmg-staging"
readonly TEMP_DMG="$BUILD_DIR/temp.dmg"
readonly FINAL_DMG="$PROJECT_ROOT/${DMG_NAME}.dmg"

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

print_step() {
    echo -e "${BLUE}▶ ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ ${BOLD}$1${NC}"
}

print_error() {
    echo -e "${RED}❌ ${BOLD}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  ${BOLD}$1${NC}"
}

# Enhanced DMG creation with multiple methods to ensure background
create_premium_dmg() {
    local app_path="$1"
    
    print_step "Creating premium DMG installer..."
    
    # Clean up any existing files
    rm -rf "$BUILD_DIR"
    mkdir -p "$STAGING_DIR"
    
    # Copy app
    print_step "Copying Gemi.app..."
    cp -R "$app_path" "$STAGING_DIR/Gemi.app"
    
    # Include .env if exists
    if [ -f "$PROJECT_ROOT/.env" ]; then
        mkdir -p "$STAGING_DIR/Gemi.app/Contents/Resources"
        cp "$PROJECT_ROOT/.env" "$STAGING_DIR/Gemi.app/Contents/Resources/.env"
        print_success "HuggingFace token included"
    fi
    
    # Create Applications symlink
    ln -s /Applications "$STAGING_DIR/Applications"
    
    # Copy background
    mkdir -p "$STAGING_DIR/.background"
    cp "$BACKGROUND_IMAGE" "$STAGING_DIR/.background/background.png"
    
    # Create DS_Store with background settings
    print_step "Creating .DS_Store with premium layout..."
    
    # Method 1: Create DMG with hdiutil
    hdiutil create -volname "$VOLUME_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov -format UDRW \
        "$TEMP_DMG"
    
    # Mount the DMG
    print_step "Mounting and configuring DMG..."
    local device=$(hdiutil attach -readwrite -noverify "$TEMP_DMG" | \
                   egrep '^/dev/' | sed 1q | awk '{print $1}')
    
    local mount_point="/Volumes/$VOLUME_NAME"
    
    # Wait for mount
    sleep 2
    
    # Method 2: Use Python script for more reliable .DS_Store creation
    print_step "Applying premium window settings..."
    
    /usr/bin/python3 - <<EOF
import os
import subprocess
import time

volume = "$mount_point"

# AppleScript to set window properties
applescript = '''
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set background picture of viewOptions to file ".background:background.png"
        set position of item "Gemi.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
'''

# Execute AppleScript
subprocess.run(['osascript', '-e', applescript], capture_output=True)
time.sleep(2)

# Alternative: Set icon positions using SetFile if available
try:
    subprocess.run(['SetFile', '-a', 'V', os.path.join(volume, '.background')], capture_output=True)
except:
    pass
EOF
    
    # Sync and wait
    sync
    sleep 2
    
    # Unmount
    print_step "Finalizing DMG..."
    hdiutil detach "$device" -quiet
    
    # Convert to compressed read-only DMG
    rm -f "$FINAL_DMG"
    hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"
    
    # Clean up
    rm -f "$TEMP_DMG"
    rm -rf "$BUILD_DIR"
    
    # Verify
    local dmg_size=$(du -h "$FINAL_DMG" | cut -f1)
    
    print_success "DMG created successfully!"
    echo ""
    echo -e "${BOLD}📦 File: $(basename "$FINAL_DMG")${NC}"
    echo -e "${BOLD}📏 Size: $dmg_size${NC}"
    echo -e "${BOLD}📍 Location: $FINAL_DMG${NC}"
    echo ""
    
    # Offer to open
    read -p "Open DMG in Finder? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$FINAL_DMG"
    fi
}

# Main execution
main() {
    echo -e "${BOLD}🎨 Gemi Premium DMG Creator${NC}"
    echo ""
    
    # Find app
    local app_path=""
    
    # Check if app path provided
    if [ $# -eq 1 ]; then
        app_path="$1"
    else
        # Try to find app
        if [ -d "$PROJECT_ROOT/Gemi/build/Release/Gemi.app" ]; then
            app_path="$PROJECT_ROOT/Gemi/build/Release/Gemi.app"
        else
            # Search in DerivedData
            app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "Gemi.app" -type d | grep Release | head -1)
        fi
    fi
    
    if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
        print_error "Gemi.app not found!"
        echo "Please build the app first or provide the path:"
        echo "  $0 /path/to/Gemi.app"
        exit 1
    fi
    
    print_success "Found app: $app_path"
    
    # Verify background exists
    if [ ! -f "$BACKGROUND_IMAGE" ]; then
        print_error "Background image not found!"
        echo "Expected at: $BACKGROUND_IMAGE"
        exit 1
    fi
    
    # Create the DMG
    create_premium_dmg "$app_path"
}

# Run
main "$@"