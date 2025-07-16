#!/bin/bash

# Gemi DMG Creator - Simple and Reliable Version
# This script creates a DMG installer without complex AppleScript automation

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build"
VOLUME_NAME="Gemi"
DMG_NAME="Gemi-Installer.dmg"
FINAL_DMG="$PROJECT_ROOT/$DMG_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}         Gemi DMG Creator (Simple)${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Clean up any existing files
cleanup() {
    print_step "Cleaning up..."
    rm -rf "$BUILD_DIR/dmg"
    rm -f "$BUILD_DIR/temp.dmg"
    rm -f "$FINAL_DMG"
}

# Build the app
build_app() {
    print_step "Building Gemi.app in Release configuration..."
    
    cd "$PROJECT_ROOT/Gemi"
    
    if xcodebuild -project Gemi.xcodeproj \
                  -scheme Gemi \
                  -configuration Release \
                  -derivedDataPath "$BUILD_DIR/DerivedData" \
                  clean build > "$BUILD_DIR/build.log" 2>&1; then
        print_success "Build successful"
    else
        print_error "Build failed. Check $BUILD_DIR/build.log for details"
        exit 1
    fi
}

# Find the built app
find_app() {
    local app_path="$BUILD_DIR/DerivedData/Build/Products/Release/Gemi.app"
    
    if [ ! -d "$app_path" ]; then
        print_error "Could not find built app at: $app_path"
        exit 1
    fi
    
    echo "$app_path"
}

# Create DMG
create_dmg() {
    local app_path="$1"
    
    print_step "Preparing DMG contents..."
    
    # Create DMG directory
    mkdir -p "$BUILD_DIR/dmg"
    
    # Copy app
    print_info "Copying Gemi.app..."
    cp -R "$app_path" "$BUILD_DIR/dmg/"
    
    # Include .env file if it exists
    if [ -f "$PROJECT_ROOT/.env" ]; then
        print_info "Including .env file..."
        cp "$PROJECT_ROOT/.env" "$BUILD_DIR/dmg/Gemi.app/Contents/Resources/"
        print_success "Token included"
    elif [ -f "$PROJECT_ROOT/Gemi/.env" ]; then
        print_info "Including .env file from Gemi directory..."
        cp "$PROJECT_ROOT/Gemi/.env" "$BUILD_DIR/dmg/Gemi.app/Contents/Resources/"
        print_success "Token included"
    else
        print_error "Warning: No .env file found. Users will need to provide their own token."
    fi
    
    # Create Applications symlink
    ln -s /Applications "$BUILD_DIR/dmg/Applications"
    
    # Copy background image if available
    if [ -f "$PROJECT_ROOT/Documentation/assets/dmg-background-clean.png" ]; then
        mkdir -p "$BUILD_DIR/dmg/.background"
        cp "$PROJECT_ROOT/Documentation/assets/dmg-background-clean.png" "$BUILD_DIR/dmg/.background/background.png"
    fi
    
    print_step "Creating DMG..."
    
    # Create DMG using hdiutil (simple approach)
    hdiutil create -volname "$VOLUME_NAME" \
                   -srcfolder "$BUILD_DIR/dmg" \
                   -ov \
                   -format UDZO \
                   "$FINAL_DMG"
    
    if [ $? -eq 0 ]; then
        print_success "DMG created successfully!"
        print_info "Location: $FINAL_DMG"
        print_info "Size: $(du -h "$FINAL_DMG" | cut -f1)"
    else
        print_error "Failed to create DMG"
        exit 1
    fi
}

# Main execution
main() {
    print_header
    
    # Parse arguments
    local skip_build=false
    local app_path=""
    
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
            *)
                shift
                ;;
        esac
    done
    
    # Clean up first
    cleanup
    
    # Build or use provided app
    if [ "$skip_build" = false ]; then
        build_app
        app_path=$(find_app)
    elif [ -z "$app_path" ]; then
        print_error "No app path provided with --app-path"
        exit 1
    fi
    
    # Verify app exists
    if [ ! -d "$app_path" ]; then
        print_error "App not found at: $app_path"
        exit 1
    fi
    
    print_success "Using app: $app_path"
    
    # Create DMG
    create_dmg "$app_path"
    
    print_step "Cleanup..."
    rm -rf "$BUILD_DIR/dmg"
    
    echo
    print_success "DMG creation complete!"
    echo
    echo "To install Gemi:"
    echo "1. Open $DMG_NAME"
    echo "2. Drag Gemi to the Applications folder"
    echo "3. Eject the DMG"
    echo "4. Launch Gemi from Applications"
    echo
}

# Run main
main "$@"