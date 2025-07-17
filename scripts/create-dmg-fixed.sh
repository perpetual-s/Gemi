#!/bin/bash

# Gemi DMG Creator - Fixed Version
# A production-ready DMG creation script that just works™

set -euo pipefail

# ANSI color codes for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ASSETS_DIR="$PROJECT_ROOT/Documentation/assets"
BUILD_DIR="$PROJECT_ROOT/build"
DMG_BUILD_DIR="$BUILD_DIR/dmg"
FINAL_DMG="$PROJECT_ROOT/Gemi-Installer.dmg"

# DMG Configuration
DMG_VOLUME_NAME="Gemi"
DMG_BACKGROUND="dmg-background-clean-premium.png"
DMG_ICON="gemi-icon-resize-2.png"
WINDOW_WIDTH=600
WINDOW_HEIGHT=400
ICON_SIZE=128
APP_X=150
APP_Y=200
ALIAS_X=450
ALIAS_Y=200

# Banner
echo -e "${PURPLE}${BOLD}"
echo "╔═══════════════════════════════════════════════╗"
echo "║          🎨 Gemi DMG Creator Pro 🎨           ║"
echo "║         The One Script to Rule Them All       ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to print styled messages
log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

log_error() {
    echo -e "${RED}✗${NC}  $1"
}

log_step() {
    echo -e "\n${CYAN}▶${NC} ${BOLD}$1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites"
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v xcodebuild &> /dev/null; then
        missing_tools+=("xcodebuild (Xcode)")
    fi
    
    if ! command -v hdiutil &> /dev/null; then
        missing_tools+=("hdiutil")
    fi
    
    if ! command -v osascript &> /dev/null; then
        missing_tools+=("osascript")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Function to find or build Gemi.app
find_or_build_app() {
    log_step "Locating Gemi.app"
    
    # First, try to find existing build
    local APP=""
    
    # Check common locations - properly handle glob expansion
    local search_paths=(
        "$PROJECT_ROOT/build/Release/Gemi.app"
        "$PROJECT_ROOT/build/Debug/Gemi.app"
    )
    
    # Add DerivedData paths using find
    while IFS= read -r -d '' path; do
        search_paths+=("$path")
    done < <(find "$HOME/Library/Developer/Xcode/DerivedData" -name "Gemi.app" -type d -print0 2>/dev/null)
    
    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            APP="$path"
            break
        fi
    done
    
    if [[ -z "$APP" ]] || [[ ! -d "$APP" ]]; then
        log_warning "No existing build found"
        log_info "Building Gemi.app in Release mode..."
        
        cd "$PROJECT_ROOT/Gemi"
        
        # Clean build directory
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
        
        # Build the app
        xcodebuild \
            -project Gemi.xcodeproj \
            -scheme Gemi \
            -configuration Release \
            -derivedDataPath "$BUILD_DIR" \
            clean build \
            CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release" \
            | grep -E '^(Building|▸|✓)' || true
        
        APP="$BUILD_DIR/Release/Gemi.app"
        
        if [[ ! -d "$APP" ]]; then
            log_error "Build failed - Gemi.app not found"
            exit 1
        fi
        
        log_success "Successfully built Gemi.app"
    else
        log_success "Found existing build: $APP"
    fi
    
    echo "$APP"
}

# Function to prepare app bundle
prepare_app_bundle() {
    local APP="$1"
    log_step "Preparing app bundle"
    
    # Copy .env file if it exists
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        log_info "Including .env file for zero-friction deployment"
        cp "$PROJECT_ROOT/.env" "$APP/Contents/Resources/" 2>/dev/null || {
            log_warning "Could not copy .env file"
        }
    else
        log_warning "No .env file found - users will need to configure authentication"
    fi
    
    # Verify app bundle
    if ! codesign --verify --deep "$APP" 2>/dev/null; then
        log_warning "App is not properly signed - DMG may trigger security warnings"
    else
        log_success "App bundle is properly signed"
    fi
    
    # Get app size
    local app_size=$(du -sh "$APP" | cut -f1)
    log_info "App size: $app_size"
}

# Function to create DMG
create_dmg() {
    local APP="$1"
    log_step "Creating DMG"
    
    # Clean up any existing DMG files
    rm -f "$FINAL_DMG"
    rm -rf "$DMG_BUILD_DIR"
    mkdir -p "$DMG_BUILD_DIR"
    
    # Copy app to build directory
    log_info "Preparing DMG contents"
    cp -R "$APP" "$DMG_BUILD_DIR/"
    
    # Create a temporary DMG
    local TEMP_DMG="$DMG_BUILD_DIR/temp.dmg"
    local TEMP_MOUNT="/Volumes/$DMG_VOLUME_NAME"
    
    # Calculate DMG size (app size + 100MB buffer)
    local APP_SIZE_MB=$(du -sm "$APP" | cut -f1)
    local DMG_SIZE_MB=$((APP_SIZE_MB + 100))
    
    log_info "Creating ${DMG_SIZE_MB}MB DMG"
    
    # Create temporary DMG
    hdiutil create \
        -size "${DMG_SIZE_MB}m" \
        -fs HFS+ \
        -volname "$DMG_VOLUME_NAME" \
        -format UDRW \
        "$TEMP_DMG"
    
    # Mount the DMG
    log_info "Mounting temporary DMG"
    hdiutil attach "$TEMP_DMG" -noverify -nobrowse -mountpoint "$TEMP_MOUNT"
    
    # Copy app to DMG
    cp -R "$APP" "$TEMP_MOUNT/"
    
    # Create Applications symlink
    ln -s /Applications "$TEMP_MOUNT/Applications"
    
    # Set up DMG appearance using AppleScript
    log_info "Configuring DMG appearance"
    
    # Copy background image if it exists
    if [[ -f "$ASSETS_DIR/$DMG_BACKGROUND" ]]; then
        mkdir -p "$TEMP_MOUNT/.background"
        cp "$ASSETS_DIR/$DMG_BACKGROUND" "$TEMP_MOUNT/.background/background.png"
        
        # Apply DMG styling
        osascript <<-EOF
            tell application "Finder"
                tell disk "$DMG_VOLUME_NAME"
                    open
                    set current view of container window to icon view
                    set toolbar visible of container window to false
                    set statusbar visible of container window to false
                    set the bounds of container window to {100, 100, $((100 + WINDOW_WIDTH)), $((100 + WINDOW_HEIGHT))}
                    set theViewOptions to the icon view options of container window
                    set arrangement of theViewOptions to not arranged
                    set icon size of theViewOptions to $ICON_SIZE
                    set background picture of theViewOptions to file ".background:background.png"
                    set position of item "Gemi.app" of container window to {$APP_X, $APP_Y}
                    set position of item "Applications" of container window to {$ALIAS_X, $ALIAS_Y}
                    update without registering applications
                    delay 2
                    close
                end tell
            end tell
EOF
    else
        log_warning "Background image not found - using default appearance"
        
        # Simpler styling without background
        osascript <<-EOF
            tell application "Finder"
                tell disk "$DMG_VOLUME_NAME"
                    open
                    set current view of container window to icon view
                    set toolbar visible of container window to false
                    set statusbar visible of container window to false
                    set the bounds of container window to {100, 100, $((100 + WINDOW_WIDTH)), $((100 + WINDOW_HEIGHT))}
                    set theViewOptions to the icon view options of container window
                    set arrangement of theViewOptions to not arranged
                    set icon size of theViewOptions to $ICON_SIZE
                    set position of item "Gemi.app" of container window to {$APP_X, $APP_Y}
                    set position of item "Applications" of container window to {$ALIAS_X, $ALIAS_Y}
                    update without registering applications
                    delay 2
                    close
                end tell
            end tell
EOF
    fi
    
    # Set custom volume icon if available
    if [[ -f "$ASSETS_DIR/$DMG_ICON" ]]; then
        cp "$ASSETS_DIR/$DMG_ICON" "$TEMP_MOUNT/.VolumeIcon.icns"
        SetFile -a C "$TEMP_MOUNT" 2>/dev/null || true
    fi
    
    # Hide background folder
    if [[ -d "$TEMP_MOUNT/.background" ]]; then
        SetFile -a V "$TEMP_MOUNT/.background" 2>/dev/null || true
    fi
    if [[ -f "$TEMP_MOUNT/.VolumeIcon.icns" ]]; then
        SetFile -a V "$TEMP_MOUNT/.VolumeIcon.icns" 2>/dev/null || true
    fi
    
    # Sync and unmount
    log_info "Finalizing DMG"
    sync
    
    # Unmount
    hdiutil detach "$TEMP_MOUNT"
    
    # Convert to compressed read-only DMG
    log_info "Compressing DMG"
    hdiutil convert "$TEMP_DMG" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$FINAL_DMG"
    
    # Clean up
    rm -rf "$DMG_BUILD_DIR"
    
    # Verify final DMG
    if ! hdiutil verify "$FINAL_DMG" &>/dev/null; then
        log_error "DMG verification failed"
        exit 1
    fi
    
    # Get final size
    local dmg_size=$(du -h "$FINAL_DMG" | cut -f1)
    log_success "Created DMG: $dmg_size"
}

# Function to display final summary
show_summary() {
    echo -e "\n${GREEN}${BOLD}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║            ✨ Success! ✨                     ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════╝${NC}"
    echo
    log_success "DMG created successfully!"
    echo -e "   📦 Location: ${CYAN}$FINAL_DMG${NC}"
    echo -e "   📏 Size: ${CYAN}$(du -h "$FINAL_DMG" | cut -f1)${NC}"
    echo -e "   🏷️  Volume: ${CYAN}$DMG_VOLUME_NAME${NC}"
    echo
    echo -e "${PURPLE}${BOLD}Next steps:${NC}"
    echo -e "   1. Test the DMG by double-clicking it"
    echo -e "   2. Drag Gemi.app to Applications"
    echo -e "   3. Distribute to your users!"
    echo
}

# Main execution
main() {
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Run checks
    check_prerequisites
    
    # Find or build app
    APP=$(find_or_build_app)
    
    # Prepare app bundle
    prepare_app_bundle "$APP"
    
    # Create DMG
    create_dmg "$APP"
    
    # Show summary
    show_summary
    
    # Open in Finder
    open -R "$FINAL_DMG"
}

# Error handler
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main function
main