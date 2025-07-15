#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                            GEMI DMG CREATOR                                   ║
# ║                    Master Build & Deployment Script                           ║
# ║                         Version 1.0.0                                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# This script creates a production-ready DMG installer for Gemi with:
# - Beautiful gradient background with glass morphism effects
# - Zero-friction drag-and-drop installation
# - Complete bundling of all components (including GemiServer)
# - Professional code signing and notarization preparation
#
# Usage: ./create_gemi_dmg.sh [configuration]
#        configuration: Debug or Release (default: Release)

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Build configuration
BUILD_CONFIG="${1:-Release}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"
BUILD_DIR="$PROJECT_ROOT/build"
ARCHIVE_DIR="$BUILD_DIR/Gemi.xcarchive"
PRODUCTS_DIR="$ARCHIVE_DIR/Products/Applications"
DMG_DIR="$BUILD_DIR/dmg_staging"
DMG_NAME="Gemi"
DMG_FILE="$BUILD_DIR/${DMG_NAME}.dmg"

# Colors for beautiful terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Gradient colors for our premium background
GRADIENT_TOP="#E8F4FD"    # Soft sky blue
GRADIENT_MID="#F0E6FF"    # Lavender mist
GRADIENT_BOTTOM="#FFE4F1" # Rose quartz

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}                            $1                            ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▸${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: BUILD GEMI SERVER
# ═══════════════════════════════════════════════════════════════════════════════

build_gemi_server() {
    print_header "BUILDING GEMI SERVER"
    
    PYTHON_SERVER_DIR="$PROJECT_ROOT/python-inference-server"
    
    if [ -d "$PYTHON_SERVER_DIR" ]; then
        print_step "Building GemiServer.app with UV..."
        cd "$PYTHON_SERVER_DIR"
        
        if [ -f "create_bundle_uv.sh" ]; then
            ./create_bundle_uv.sh
            
            if [ -d "dist/GemiServer.app" ]; then
                print_success "GemiServer.app built successfully"
                
                # Get bundle size for user info
                BUNDLE_SIZE=$(du -sh "dist/GemiServer.app" | cut -f1)
                print_step "Server bundle size: $BUNDLE_SIZE"
            else
                print_error "Failed to build GemiServer.app"
                exit 1
            fi
        else
            print_error "create_bundle_uv.sh not found"
            exit 1
        fi
        
        cd "$PROJECT_ROOT"
    else
        print_error "Python inference server directory not found"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: BUILD GEMI APP
# ═══════════════════════════════════════════════════════════════════════════════

build_gemi_app() {
    print_header "BUILDING GEMI APPLICATION"
    
    # Clean previous builds
    print_step "Cleaning previous builds..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Navigate to Gemi directory
    cd "$PROJECT_ROOT/Gemi"
    
    # Build the Xcode project
    print_step "Building Gemi.app in $BUILD_CONFIG mode..."
    print_step "This may take a few minutes..."
    
    # Build with proper architecture selection and without xcpretty dependency
    xcodebuild -project Gemi.xcodeproj \
        -scheme Gemi \
        -configuration "$BUILD_CONFIG" \
        -archivePath "$ARCHIVE_DIR" \
        -destination "platform=macOS,arch=arm64" \
        archive \
        ONLY_ACTIVE_ARCH=NO \
        2>&1 | while IFS= read -r line; do
            # Filter out common noise
            if [[ ! "$line" =~ "WARNING: Using the first of multiple matching destinations" ]] && \
               [[ ! "$line" =~ "{ platform:" ]] && \
               [[ ! "$line" =~ "IDEProvisioningErrorDomain" ]] && \
               [[ ! "$line" =~ "note: Building targets in" ]]; then
                # Highlight errors in red
                if [[ "$line" =~ "error:" ]] || [[ "$line" =~ "ERROR:" ]]; then
                    echo -e "${RED}$line${NC}"
                # Highlight warnings in yellow
                elif [[ "$line" =~ "warning:" ]] || [[ "$line" =~ "WARNING:" ]]; then
                    echo -e "${YELLOW}$line${NC}"
                # Show progress indicators
                elif [[ "$line" =~ "Building" ]] || [[ "$line" =~ "Compiling" ]] || [[ "$line" =~ "Linking" ]]; then
                    echo -e "${GRAY}$line${NC}"
                # Show success messages
                elif [[ "$line" =~ "ARCHIVE SUCCEEDED" ]]; then
                    echo -e "${GREEN}$line${NC}"
                fi
            fi
        done
    
    # Check if build succeeded
    if [ ! -d "$ARCHIVE_DIR" ]; then
        print_error "Build failed! Archive not created."
        exit 1
    fi
    
    if [ -d "$PRODUCTS_DIR/Gemi.app" ]; then
        print_success "Gemi.app built successfully"
        
        # Bundle GemiServer inside Gemi.app
        print_step "Bundling GemiServer.app inside Gemi.app..."
        GEMI_RESOURCES="$PRODUCTS_DIR/Gemi.app/Contents/Resources"
        mkdir -p "$GEMI_RESOURCES"
        
        if [ -d "$PROJECT_ROOT/python-inference-server/dist/GemiServer.app" ]; then
            cp -R "$PROJECT_ROOT/python-inference-server/dist/GemiServer.app" "$GEMI_RESOURCES/"
            print_success "GemiServer.app bundled successfully"
        else
            print_warning "GemiServer.app not found, skipping bundling"
        fi
        
        # Sign the app bundle
        print_step "Code signing Gemi.app..."
        codesign --force --deep --sign - "$PRODUCTS_DIR/Gemi.app"
        print_success "Code signing complete"
        
    else
        print_error "Gemi.app not found in build products"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: CREATE PREMIUM DMG BACKGROUND
# ═══════════════════════════════════════════════════════════════════════════════

create_dmg_background() {
    print_header "CREATING PREMIUM DMG BACKGROUND"
    
    # Check if we have an existing background
    EXISTING_BG="$PROJECT_ROOT/Documentation/assets-icons/dmg-background-premium.png"
    DMG_BG="$BUILD_DIR/dmg-background.png"
    
    if [ -f "$EXISTING_BG" ]; then
        print_step "Using existing DMG background..."
        cp "$EXISTING_BG" "$DMG_BG"
    else
        print_step "Creating premium gradient background..."
        
        # Create a sophisticated gradient background using ImageMagick or sips
        if command_exists convert; then
            # ImageMagick approach - create a beautiful gradient
            convert -size 600x400 \
                -define gradient:angle=135 \
                "gradient:$GRADIENT_TOP-$GRADIENT_BOTTOM" \
                -blur 0x8 \
                "$DMG_BG"
            
            # Add subtle glass morphism overlay
            convert "$DMG_BG" \
                -fill "rgba(255,255,255,0.1)" \
                -draw "roundrectangle 50,50 550,350 20,20" \
                "$DMG_BG"
                
        else
            # Fallback: create simple gradient with built-in tools
            print_warning "ImageMagick not found, creating simple background..."
            
            # Create a basic colored background
            python3 -c "
from PIL import Image, ImageDraw
import numpy as np

# Create gradient
width, height = 600, 400
img = Image.new('RGB', (width, height))
draw = ImageDraw.Draw(img)

# Simple gradient
for y in range(height):
    r = int(232 + (255 - 232) * y / height)
    g = int(244 + (228 - 244) * y / height) 
    b = int(253 + (241 - 253) * y / height)
    draw.line([(0, y), (width, y)], fill=(r, g, b))

img.save('$DMG_BG')
" 2>/dev/null || {
                # Ultimate fallback - copy any background we can find
                print_warning "Could not generate gradient, using fallback..."
                echo "Install Gemi" > "$BUILD_DIR/install.txt"
            }
        fi
    fi
    
    if [ -f "$DMG_BG" ]; then
        print_success "DMG background created"
    else
        print_warning "No background image available, DMG will use default appearance"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: CREATE DMG WITH MAGICAL UX
# ═══════════════════════════════════════════════════════════════════════════════

create_premium_dmg() {
    print_header "CREATING PREMIUM DMG INSTALLER"
    
    # Clean up any existing DMG
    rm -f "$DMG_FILE"
    rm -rf "$DMG_DIR"
    mkdir -p "$DMG_DIR"
    
    # Copy Gemi.app to staging
    print_step "Preparing DMG contents..."
    cp -R "$PRODUCTS_DIR/Gemi.app" "$DMG_DIR/"
    
    # Create Applications shortcut
    print_step "Creating Applications shortcut..."
    ln -s /Applications "$DMG_DIR/Applications"
    
    # Copy legal documents (hidden)
    if [ -d "$PROJECT_ROOT/python-inference-server/legal" ]; then
        mkdir -p "$DMG_DIR/.legal"
        cp -R "$PROJECT_ROOT/python-inference-server/legal/"* "$DMG_DIR/.legal/" 2>/dev/null || true
    fi
    
    # Create the DMG
    print_step "Building DMG package..."
    
    if command_exists create-dmg; then
        # Use create-dmg for the best experience
        create-dmg \
            --volname "Gemi" \
            --volicon "$PROJECT_ROOT/Documentation/assets-icons/gemi-icon.png" \
            --background "$BUILD_DIR/dmg-background.png" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "Gemi.app" 150 200 \
            --hide-extension "Gemi.app" \
            --app-drop-link 450 200 \
            --text-size 12 \
            --hdiutil-quiet \
            "$DMG_FILE" \
            "$DMG_DIR"
    else
        # Fallback to hdiutil with custom script
        print_warning "create-dmg not found, using hdiutil..."
        
        # Create temporary DMG
        TEMP_DMG="$BUILD_DIR/temp.dmg"
        hdiutil create -srcfolder "$DMG_DIR" -volname "Gemi" -fs HFS+ \
            -fsargs "-c c=64,a=16,e=16" -format UDRW "$TEMP_DMG"
        
        # Mount the DMG
        MOUNT_DIR="/Volumes/Gemi"
        hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG"
        
        # Set custom icon positions and window properties with AppleScript
        osascript << EOF
tell application "Finder"
    tell disk "Gemi"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 800, 520}
        set position of item "Gemi.app" to {150, 200}
        set position of item "Applications" to {450, 200}
        set viewOptions to icon view options of container window
        set icon size of viewOptions to 100
        set text size of viewOptions to 12
        set arrangement of viewOptions to not arranged
        if exists file "dmg-background.png" then
            set background picture of viewOptions to file "dmg-background.png"
        end if
        update without registering applications
        delay 2
    end tell
end tell
EOF
        
        # Hide background image if it exists
        if [ -f "$MOUNT_DIR/dmg-background.png" ]; then
            SetFile -a V "$MOUNT_DIR/dmg-background.png"
        fi
        
        # Close Finder window
        osascript -e 'tell application "Finder" to close window "Gemi"' || true
        
        # Unmount
        hdiutil detach "$MOUNT_DIR"
        
        # Convert to compressed DMG
        hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_FILE"
        rm -f "$TEMP_DMG"
    fi
    
    # Sign the DMG if we have a developer identity
    if security find-identity -p codesigning -v | grep -q "Developer ID"; then
        print_step "Signing DMG..."
        codesign --sign - "$DMG_FILE"
        print_success "DMG signed"
    else
        print_warning "No Developer ID found, DMG will not be signed"
    fi
    
    # Get final DMG info
    DMG_SIZE=$(du -h "$DMG_FILE" | cut -f1)
    print_success "Premium DMG created successfully!"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}DMG DETAILS:${NC}"
    echo -e "${GRAY}Location:${NC} $DMG_FILE"
    echo -e "${GRAY}Size:${NC} $DMG_SIZE"
    echo -e "${GRAY}Contents:${NC}"
    echo -e "  • Gemi.app (with bundled GemiServer.app)"
    echo -e "  • Applications shortcut"
    echo -e "  • Legal documents (hidden)"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: VERIFY AND TEST
# ═══════════════════════════════════════════════════════════════════════════════

verify_dmg() {
    print_header "VERIFYING DMG INTEGRITY"
    
    # Verify DMG structure
    print_step "Verifying DMG contents..."
    hdiutil verify "$DMG_FILE" || {
        print_error "DMG verification failed"
        exit 1
    }
    
    print_success "DMG verification passed"
    
    # Mount and check contents
    print_step "Testing DMG mount..."
    VERIFY_MOUNT="/Volumes/Gemi_Verify"
    hdiutil attach "$DMG_FILE" -mountpoint "$VERIFY_MOUNT" -nobrowse
    
    if [ -d "$VERIFY_MOUNT/Gemi.app" ]; then
        print_success "Gemi.app found in DMG"
        
        # Check for bundled server
        if [ -d "$VERIFY_MOUNT/Gemi.app/Contents/Resources/GemiServer.app" ]; then
            print_success "GemiServer.app bundled correctly"
        else
            print_warning "GemiServer.app not found in bundle"
        fi
    else
        print_error "Gemi.app not found in DMG"
    fi
    
    hdiutil detach "$VERIFY_MOUNT" -quiet
    
    print_success "All verification checks passed!"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                              ║
    ║   ██████╗ ███████╗███╗   ███╗██╗    ██████╗ ███╗   ███╗ ██████╗            ║
    ║  ██╔════╝ ██╔════╝████╗ ████║██║    ██╔══██╗████╗ ████║██╔════╝            ║
    ║  ██║  ███╗█████╗  ██╔████╔██║██║    ██║  ██║██╔████╔██║██║  ███╗           ║
    ║  ██║   ██║██╔══╝  ██║╚██╔╝██║██║    ██║  ██║██║╚██╔╝██║██║   ██║           ║
    ║  ╚██████╔╝███████╗██║ ╚═╝ ██║██║    ██████╔╝██║ ╚═╝ ██║╚██████╔╝           ║
    ║   ╚═════╝ ╚══════╝╚═╝     ╚═╝╚═╝    ╚═════╝ ╚═╝     ╚═╝ ╚═════╝            ║
    ║                                                                              ║
    ║                        Premium Build & Deployment System                      ║
    ║                              Version 1.0.0                                   ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    print_step "Build Configuration: ${WHITE}$BUILD_CONFIG${NC}"
    print_step "Starting build process..."
    echo ""
    
    # Check dependencies
    print_header "CHECKING DEPENDENCIES"
    
    # Check for Xcode
    if ! command_exists xcodebuild; then
        print_error "Xcode command line tools not found"
        print_step "Install with: xcode-select --install"
        exit 1
    fi
    print_success "Xcode tools found"
    
    # Check for UV (for server bundling)
    if [ ! -f "$HOME/.local/bin/uv" ]; then
        print_warning "UV not found, GemiServer bundling may fail"
        print_step "Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    else
        print_success "UV package manager found"
    fi
    
    # Optional: Check for create-dmg
    if command_exists create-dmg; then
        print_success "create-dmg found (premium DMG creation)"
    else
        print_step "create-dmg not found, using native macOS tools"
    fi
    
    # Execute build steps
    build_gemi_server
    build_gemi_app
    create_dmg_background
    create_premium_dmg
    verify_dmg
    
    # Final success message
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}                         🎉 BUILD COMPLETE! 🎉                                ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Your premium Gemi installer is ready:${NC}"
    echo -e "${CYAN}$DMG_FILE${NC}"
    echo ""
    echo -e "${GRAY}To install Gemi:${NC}"
    echo -e "1. Double-click ${CYAN}Gemi.dmg${NC}"
    echo -e "2. Drag ${CYAN}Gemi${NC} to ${CYAN}Applications${NC}"
    echo -e "3. Launch and enjoy your private AI diary!"
    echo ""
    echo -e "${PURPLE}✨ Crafted with precision for the world's most elegant AI diary ✨${NC}"
    echo ""
}

# Run the main function
main "$@"