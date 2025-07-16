#!/bin/bash

# ============================================================================
# Gemi DMG Creator - Beautiful Installer with Premium Background
# ============================================================================
# Creates a professional DMG installer with drag-and-drop installation
# Usage: ./create-dmg.sh [--skip-build]
# ============================================================================

set -e  # Exit on error

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
readonly TEMP_DMG="$PROJECT_ROOT/${DMG_NAME}-temp.dmg"
readonly FINAL_DMG="$PROJECT_ROOT/${DMG_NAME}.dmg"

# Window configuration for 600x400 background
readonly WINDOW_WIDTH=600
readonly WINDOW_HEIGHT=400
readonly ICON_SIZE=80
readonly APP_X=150    # Left side
readonly APP_Y=185    # Vertical center
readonly APPS_X=450   # Right side  
readonly APPS_Y=185   # Vertical center

# Colors for beautiful output
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}                  ${BOLD}✨ Gemi DMG Creator ✨${NC}                       ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}║${NC}              ${CYAN}Beautiful Installer Generator${NC}                     ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

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

cleanup() {
    if [ -n "${device:-}" ]; then
        hdiutil detach "$device" >/dev/null 2>&1 || true
    fi
    rm -rf "$STAGING_DIR"
    # Don't remove temp DMG - it might be our final file
}

find_app() {
    local app_path=""
    
    # Check standard build location
    if [ -d "$PROJECT_ROOT/Gemi/build/Release/Gemi.app" ]; then
        app_path="$PROJECT_ROOT/Gemi/build/Release/Gemi.app"
    else
        # Search in DerivedData
        app_path=$(find ~/Library/Developer/Xcode/DerivedData \
            -name "Gemi.app" -type d 2>/dev/null | grep -E "Release|Debug" | head -1)
    fi
    
    echo "$app_path"
}

create_beautiful_dmg() {
    local staging_dir="$1"
    local volume_name="$2"
    local temp_dmg="$3"
    local final_dmg="$4"
    
    # Create temporary DMG with all attributes preserved
    print_step "Creating DMG structure..."
    # Remove any existing temp DMG first
    rm -f "$temp_dmg"
    
    hdiutil create \
        -srcfolder "$staging_dir" \
        -volname "$volume_name" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        -size 300m \
        "$temp_dmg" || { print_error "Failed to create DMG"; exit 1; }
    
    # Mount the DMG with explicit read-write permissions
    print_step "Mounting and configuring DMG..."
    local device
    device=$(hdiutil attach -readwrite -noverify -noautoopen "$temp_dmg" 2>/dev/null | \
             egrep '^/dev/' | sed 1q | awk '{print $1}')
    
    if [ -z "$device" ]; then
        print_error "Failed to mount DMG"
        exit 1
    fi
    
    # Wait for mount to complete
    sleep 2
    
    # Apply beautiful layout with AppleScript
    print_step "Applying premium design..."
    
    # First attempt with AppleScript
    osascript <<EOF
tell application "Finder"
    tell disk "$volume_name"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 1000, 600}
        
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to $ICON_SIZE
        set text size of viewOptions to 12
        set label position of viewOptions to bottom
        set shows item info of viewOptions to false
        set shows icon preview of viewOptions to true
        
        -- Set background
        set background picture of viewOptions to file ".background:dmg-background.png"
        
        -- Position icons
        set position of item "Gemi.app" of container window to {$APP_X, $APP_Y}
        set position of item "Applications" of container window to {$APPS_X, $APPS_Y}
        
        -- Hide sidebar
        set sidebar width of container window to 0
        
        -- Save the view settings
        close
        open
        delay 1
        close
    end tell
end tell
EOF

    # Ensure .DS_Store is created with the window settings
    sleep 2
    
    # Force .DS_Store creation by opening and closing again
    osascript -e "tell application \"Finder\" to open disk \"$volume_name\"" 2>/dev/null || true
    sleep 1
    osascript -e "tell application \"Finder\" to close window 1" 2>/dev/null || true
    
    # Important: Sync to ensure .DS_Store is written
    sync
    
    # Give Finder time to write .DS_Store
    print_step "Saving window settings..."
    sleep 3
    
    # Force another sync
    sync
    
    print_step "Finalizing DMG..."
    hdiutil detach "$device" >/dev/null 2>&1 || true
    
    # Ask about compression
    echo ""
    echo -e "${YELLOW}The DMG is ready but uncompressed (better for backgrounds).${NC}"
    echo -e "Compression makes the file smaller but may lose the background image."
    echo ""
    read -p "Compress the DMG? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Convert to compressed DMG
        print_step "Compressing DMG (this may remove the background)..."
        rm -f "$final_dmg"
        hdiutil convert "$temp_dmg" \
            -format UDZO \
            -imagekey zlib-level=9 \
            -o "$final_dmg" || { print_error "Failed to compress DMG"; exit 1; }
        rm -f "$temp_dmg"
        print_success "Compressed DMG created!"
    else
        # Just rename the temp DMG
        print_step "Using uncompressed DMG with background..."
        rm -f "$final_dmg"
        mv "$temp_dmg" "$final_dmg"
        print_success "DMG created with background preserved!"
    fi
}

# Main execution
main() {
    local skip_build=false
    
    # Parse arguments
    if [[ "${1:-}" == "--skip-build" ]]; then
        skip_build=true
    fi
    
    print_header
    
    # Set up error handling
    trap cleanup EXIT
    
    # Create build directory
    print_step "Preparing build environment..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$STAGING_DIR"
    
    # Remove any existing DMGs
    if [ -f "$FINAL_DMG" ] || [ -f "$TEMP_DMG" ]; then
        print_warning "Removing existing DMG files..."
        rm -f "$FINAL_DMG" "$TEMP_DMG"
    fi
    
    # Build or find app
    local app_path=""
    if [ "$skip_build" = false ]; then
        print_step "Building Gemi..."
        cd "$PROJECT_ROOT/Gemi"
        xcodebuild -project Gemi.xcodeproj \
                  -scheme Gemi \
                  -configuration Release \
                  -derivedDataPath "$BUILD_DIR/DerivedData" \
                  clean build
        
        app_path="$BUILD_DIR/DerivedData/Build/Products/Release/Gemi.app"
        print_success "Build completed"
    else
        print_step "Finding Gemi.app..."
        app_path=$(find_app)
        
        if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
            print_error "Could not find Gemi.app"
            echo "Build first or run without --skip-build"
            exit 1
        fi
    fi
    
    print_success "Using app: $(basename "$app_path")"
    
    # Prepare DMG contents
    print_step "Preparing DMG contents..."
    
    # Copy app
    ditto "$app_path" "$STAGING_DIR/Gemi.app"
    
    # Include .env if exists
    if [ -f "$PROJECT_ROOT/.env" ]; then
        mkdir -p "$STAGING_DIR/Gemi.app/Contents/Resources"
        cp "$PROJECT_ROOT/.env" "$STAGING_DIR/Gemi.app/Contents/Resources/.env"
        print_success "HuggingFace token included"
    fi
    
    # Create Applications symlink
    ln -s /Applications "$STAGING_DIR/Applications"
    
    # Copy background with proper permissions
    mkdir -p "$STAGING_DIR/.background"
    if [ -f "$BACKGROUND_IMAGE" ]; then
        cp "$BACKGROUND_IMAGE" "$STAGING_DIR/.background/dmg-background.png"
        # Ensure background is readable
        chmod 644 "$STAGING_DIR/.background/dmg-background.png"
        # Hide background folder NOW before creating DMG
        if command -v SetFile &> /dev/null; then
            SetFile -a V "$STAGING_DIR/.background"
        else
            # Alternative: use chflags if SetFile not available
            chflags hidden "$STAGING_DIR/.background" 2>/dev/null || true
        fi
        print_success "Background image added"
    else
        print_warning "Background image not found"
    fi
    
    # Create the DMG
    create_beautiful_dmg "$STAGING_DIR" "$VOLUME_NAME" "$TEMP_DMG" "$FINAL_DMG"
    
    # Get final stats
    local dmg_size=$(du -h "$FINAL_DMG" | cut -f1)
    local dmg_type="Compressed"
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        dmg_type="Uncompressed (with background)"
    fi
    
    # Success message
    echo ""
    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║${NC}                 ${BOLD}✨ DMG Created Successfully! ✨${NC}                ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📦 File:${NC} ${BOLD}Gemi-Installer.dmg${NC}"
    echo -e "${CYAN}📏 Size:${NC} ${BOLD}$dmg_size${NC}"
    echo -e "${CYAN}💿 Type:${NC} ${BOLD}$dmg_type${NC}"
    echo -e "${CYAN}📍 Location:${NC} ${BOLD}$FINAL_DMG${NC}"
    echo -e "${CYAN}🎨 Design:${NC} ${BOLD}Premium gradient background${NC}"
    echo ""
    echo -e "${BOLD}To install Gemi:${NC}"
    echo "  1. Double-click the DMG file"
    echo "  2. Drag Gemi to the Applications folder"
    echo "  3. Eject the DMG"
    echo "  4. Launch Gemi from Applications"
    echo ""
    
    # Open in Finder
    read -p "Open DMG in Finder? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$FINAL_DMG"
    fi
}

# Run main with error handling
if ! main "$@"; then
    print_error "DMG creation failed"
    exit 1
fi