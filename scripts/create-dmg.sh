#!/bin/bash

# ============================================================================
# Gemi DMG Creator - Professional macOS Installer
# ============================================================================
# This script creates a beautiful, professional DMG installer for Gemi
# with proper code signing, notarization support, and a premium look.
#
# Usage:
#   ./create-dmg.sh                    # Build app and create DMG
#   ./create-dmg.sh --skip-build       # Create DMG from existing build
#   ./create-dmg.sh --help             # Show help
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly APP_NAME="Gemi"
readonly VOLUME_NAME="Gemi Installer"
readonly DMG_NAME="Gemi-$(date +%Y%m%d)"
readonly BACKGROUND_IMAGE="$PROJECT_ROOT/Documentation/assets/dmg-background-clean-premium.png"

# Build paths
readonly BUILD_DIR="$SCRIPT_DIR/build"
readonly STAGING_DIR="$BUILD_DIR/dmg-staging"
readonly TEMP_DMG="$BUILD_DIR/temp.dmg"
readonly FINAL_DMG="$BUILD_DIR/${DMG_NAME}.dmg"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    Gemi DMG Creator v2.0                       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Create a professional DMG installer for Gemi.

OPTIONS:
    --skip-build        Skip the Xcode build step
    --app-path PATH     Use app at specific path (implies --skip-build)
    --sign              Code sign the DMG (requires Developer ID)
    --notarize          Notarize the DMG (requires --sign)
    --help              Show this help message

EXAMPLES:
    $(basename "$0")                           # Build and create DMG
    $(basename "$0") --skip-build              # Create DMG from existing build
    $(basename "$0") --sign --notarize         # Create signed & notarized DMG

EOF
}

cleanup() {
    print_step "Cleaning up temporary files..."
    rm -rf "$STAGING_DIR"
    rm -f "$TEMP_DMG"
}

find_app() {
    local app_path=""
    
    # Check standard build location first
    if [ -d "$PROJECT_ROOT/Gemi/build/Release/Gemi.app" ]; then
        app_path="$PROJECT_ROOT/Gemi/build/Release/Gemi.app"
    else
        # Search in DerivedData
        local derived_data_apps
        derived_data_apps=$(find ~/Library/Developer/Xcode/DerivedData \
            -name "Gemi.app" -type d 2>/dev/null | grep -E "Release|Build/Products" | head -1)
        
        if [ -n "$derived_data_apps" ]; then
            app_path="$derived_data_apps"
        fi
    fi
    
    echo "$app_path"
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    local skip_build=false
    local app_path=""
    local sign_dmg=false
    local notarize_dmg=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)
                skip_build=true
                shift
                ;;
            --app-path)
                app_path="$2"
                skip_build=true
                shift 2
                ;;
            --sign)
                sign_dmg=true
                shift
                ;;
            --notarize)
                notarize_dmg=true
                sign_dmg=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_header
    
    # Set up error handling
    trap cleanup EXIT
    
    # Create build directory
    print_step "Preparing build environment..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$STAGING_DIR"
    
    # Build the app if needed
    if [ "$skip_build" = false ]; then
        print_step "Building Gemi in Release configuration..."
        cd "$PROJECT_ROOT/Gemi"
        
        if xcodebuild -project Gemi.xcodeproj \
                     -scheme Gemi \
                     -configuration Release \
                     -derivedDataPath "$BUILD_DIR/DerivedData" \
                     clean build; then
            print_success "Build completed successfully"
            app_path="$BUILD_DIR/DerivedData/Build/Products/Release/Gemi.app"
        else
            print_error "Build failed"
            exit 1
        fi
        
        cd "$SCRIPT_DIR"
    fi
    
    # Find the app if no path provided
    if [ -z "$app_path" ]; then
        print_step "Locating Gemi.app..."
        app_path=$(find_app)
        
        if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
            print_error "Could not find Gemi.app"
            echo "Try building first or specify path with --app-path"
            exit 1
        fi
    fi
    
    print_success "Using app at: $app_path"
    
    # Verify app bundle
    print_step "Verifying app bundle..."
    if ! codesign --verify --deep "$app_path" 2>/dev/null; then
        print_warning "App bundle signature verification failed"
        print_warning "This is normal for unsigned builds"
    fi
    
    # Copy app to staging directory
    print_step "Preparing DMG contents..."
    cp -R "$app_path" "$STAGING_DIR/"
    
    # Include .env file if it exists
    local env_file="$PROJECT_ROOT/Gemi/.env"
    if [ -f "$env_file" ]; then
        print_step "Including HuggingFace token..."
        cp "$env_file" "$STAGING_DIR/Gemi.app/Contents/Resources/.env"
        print_success "Token included in bundle"
    else
        print_warning "No .env file found"
        echo "         Users will need to provide their own HuggingFace token"
    fi
    
    # Create Applications symlink
    ln -s /Applications "$STAGING_DIR/Applications"
    
    # Copy background image
    mkdir -p "$STAGING_DIR/.background"
    if [ -f "$BACKGROUND_IMAGE" ]; then
        cp "$BACKGROUND_IMAGE" "$STAGING_DIR/.background/dmg-background.png"
    else
        print_warning "Background image not found, using default"
    fi
    
    # Create temporary DMG
    print_step "Creating DMG structure..."
    hdiutil create \
        -srcfolder "$STAGING_DIR" \
        -volname "$VOLUME_NAME" \
        -fs HFS+ \
        -format UDRW \
        -size 500m \
        "$TEMP_DMG" >/dev/null 2>&1
    
    # Mount the DMG
    print_step "Configuring DMG appearance..."
    local device
    device=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | \
             egrep '^/dev/' | sed 1q | awk '{print $1}')
    
    sleep 2
    
    # Configure DMG window with AppleScript
    osascript <<EOF >/dev/null 2>&1
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 80
        set text size of viewOptions to 12
        set arrangement of viewOptions to not arranged
        set background picture of viewOptions to file ".background:dmg-background.png"
        set position of item "Gemi.app" of container window to {175, 200}
        set position of item "Applications" of container window to {525, 200}
        close
        open
        update without registering applications
        delay 3
    end tell
end tell
EOF
    
    # Sync and unmount
    sync
    hdiutil detach "$device" >/dev/null 2>&1
    
    # Convert to compressed DMG
    print_step "Compressing DMG..."
    hdiutil convert "$TEMP_DMG" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$FINAL_DMG" >/dev/null 2>&1
    
    # Code sign the DMG if requested
    if [ "$sign_dmg" = true ]; then
        print_step "Code signing DMG..."
        if codesign --force --sign "Developer ID Application" "$FINAL_DMG"; then
            print_success "DMG signed successfully"
        else
            print_error "Failed to sign DMG"
            exit 1
        fi
    fi
    
    # Notarize if requested
    if [ "$notarize_dmg" = true ]; then
        print_step "Notarizing DMG (this may take several minutes)..."
        # Note: Actual notarization requires additional setup
        print_warning "Notarization not implemented in this script"
        echo "         Please use: xcrun notarytool submit \"$FINAL_DMG\""
    fi
    
    # Verify final DMG
    print_step "Verifying DMG..."
    if hdiutil verify "$FINAL_DMG" >/dev/null 2>&1; then
        print_success "DMG verification passed"
    else
        print_error "DMG verification failed"
        exit 1
    fi
    
    # Get final size
    local dmg_size
    dmg_size=$(du -h "$FINAL_DMG" | cut -f1)
    
    # Success!
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    ✨ DMG Created Successfully! ✨              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📦 File: $(basename "$FINAL_DMG")"
    echo "📏 Size: $dmg_size"
    echo "📍 Path: $FINAL_DMG"
    echo ""
    echo "Next steps:"
    echo "1. Test the installer by double-clicking the DMG"
    echo "2. Verify the drag-and-drop installation works"
    echo "3. Test Gemi launches correctly from Applications"
    
    if [ "$sign_dmg" = false ]; then
        echo ""
        echo "For distribution:"
        echo "• Run with --sign to code sign the DMG"
        echo "• Run with --notarize for Mac App Store distribution"
    fi
    
    echo ""
    read -p "Would you like to open the DMG in Finder? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open -R "$FINAL_DMG"
    fi
}

# Run the main function
main "$@"