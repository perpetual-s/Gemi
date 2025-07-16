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
readonly DMG_NAME="Gemi-Installer"
readonly BACKGROUND_IMAGE="$PROJECT_ROOT/Documentation/assets/dmg-background-clean-premium.png"

# Build paths
readonly BUILD_DIR="$SCRIPT_DIR/build"
readonly STAGING_DIR="$BUILD_DIR/dmg-staging"
readonly TEMP_DMG="$BUILD_DIR/temp.dmg"
readonly FINAL_DMG="$BUILD_DIR/${DMG_NAME}.dmg"

# Window configuration (optimized for 600x400 background)
readonly WINDOW_WIDTH=600
readonly WINDOW_HEIGHT=400
readonly ICON_SIZE=80
readonly TEXT_SIZE=12
# Icon positioning for premium background
# Adjusted for visual balance with the gradient design
readonly APP_X=150    # Left side
readonly APP_Y=185    # Slightly below center for visual balance
readonly APPS_X=450   # Right side  
readonly APPS_Y=185   # Match app position

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}                    ${BOLD}Gemi DMG Creator v3.0${NC}                      ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}║${NC}              ${DIM}Professional macOS Installer Builder${NC}              ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶ ${BOLD}$1${NC}"
}

print_substep() {
    echo -e "  ${DIM}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ ${BOLD}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  ${BOLD}$1${NC}"
}

print_error() {
    echo -e "${RED}❌ ${BOLD}$1${NC}"
}

print_info() {
    echo -e "${MAGENTA}ℹ️  $1${NC}"
}

show_help() {
    cat << EOF
${BOLD}Usage:${NC} $(basename "$0") [OPTIONS]

${BOLD}Create a professional DMG installer for Gemi.${NC}

${BOLD}OPTIONS:${NC}
    ${CYAN}--skip-build${NC}        Skip the Xcode build step
    ${CYAN}--app-path${NC} PATH     Use app at specific path (implies --skip-build)
    ${CYAN}--sign${NC}              Code sign the DMG (requires Developer ID)
    ${CYAN}--notarize${NC}          Notarize the DMG (requires --sign)
    ${CYAN}--open${NC}              Open DMG in Finder when complete
    ${CYAN}--help${NC}              Show this help message

${BOLD}EXAMPLES:${NC}
    $(basename "$0")                           # Build and create DMG
    $(basename "$0") --skip-build              # Create DMG from existing build
    $(basename "$0") --sign --notarize         # Create signed & notarized DMG

${BOLD}REQUIREMENTS:${NC}
    • Xcode Command Line Tools
    • macOS 10.15 or later
    • 1GB free disk space

EOF
}

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

cleanup() {
    if [ -n "${device:-}" ]; then
        hdiutil detach "$device" >/dev/null 2>&1 || true
    fi
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

verify_prerequisites() {
    print_step "Verifying prerequisites..."
    
    # Check for Xcode Command Line Tools
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode Command Line Tools not found"
        echo "Install with: xcode-select --install"
        exit 1
    fi
    
    # Check for required commands
    local required_commands=("hdiutil" "osascript" "codesign" "ditto")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    # Check disk space (need at least 1GB)
    local available_space=$(df -k "$SCRIPT_DIR" | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1048576 ]; then
        print_error "Insufficient disk space (need at least 1GB free)"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

create_beautiful_dmg() {
    local staging_dir="$1"
    local volume_name="$2"
    local temp_dmg="$3"
    local final_dmg="$4"
    
    # Create temporary DMG with optimal size
    print_substep "Creating DMG structure..."
    hdiutil create \
        -srcfolder "$staging_dir" \
        -volname "$volume_name" \
        -fs HFS+ \
        -format UDRW \
        -size 250m \
        "$temp_dmg" >/dev/null 2>&1
    
    # Mount the DMG
    print_substep "Mounting DMG for configuration..."
    local device
    device=$(hdiutil attach -readwrite -noverify -noautoopen "$temp_dmg" | \
             egrep '^/dev/' | sed 1q | awk '{print $1}')
    
    # Wait for mount to complete
    sleep 3
    
    # Configure DMG window with AppleScript for perfect alignment
    print_substep "Applying professional layout..."
    
    # Try AppleScript with timeout to prevent hanging
    local applescript_success=false
    
    # Create a temporary AppleScript file to avoid inline issues
    local temp_script="/tmp/dmg_layout_$$.scpt"
    cat > "$temp_script" <<EOF
on run
    with timeout of 10 seconds
        tell application "Finder"
            try
                tell disk "$volume_name"
                    open
                    delay 0.5
                    set current view of container window to icon view
                    set toolbar visible of container window to false
                    set statusbar visible of container window to false
                    
                    -- Set exact window bounds for 600x400 content
                    set the bounds of container window to {400, 200, 1000, 600}
                    
                    -- Force window to front
                    set the position of container window to {400, 200}
                    
                    set viewOptions to the icon view options of container window
                    set icon size of viewOptions to $ICON_SIZE
                    set text size of viewOptions to $TEXT_SIZE
                    set label position of viewOptions to bottom
                    set shows item info of viewOptions to false
                    set shows icon preview of viewOptions to true
                    set arrangement of viewOptions to not arranged
                    
                    -- Apply background image
                    set background picture of viewOptions to file ".background:dmg-background.png"
                    
                    -- Position items centered in visual areas
                    set position of item "Gemi.app" of container window to {$APP_X, $APP_Y}
                    set position of item "Applications" of container window to {$APPS_X, $APPS_Y}
                    
                    -- Hide toolbar and sidebar for cleaner look
                    set sidebar width of container window to 0
                    
                    -- Force refresh to show background
                    update without registering applications
                    delay 1
                    
                    -- Ensure icons stay in position
                    set position of item "Gemi.app" of container window to {$APP_X, $APP_Y}
                    set position of item "Applications" of container window to {$APPS_X, $APPS_Y}
                    
                    update without registering applications
                    delay 0.5
                    
                    -- Close window
                    close
                end tell
                return "success"
            on error errMsg
                return "error: " & errMsg
            end try
        end tell
    end timeout
end run
EOF
    
    # Run AppleScript with timeout
    if timeout 15 osascript "$temp_script" >/dev/null 2>&1; then
        applescript_success=true
        print_success "Applied custom DMG layout"
    else
        print_warning "Could not apply custom layout (this is normal on some systems)"
        print_info "DMG will use default macOS layout"
    fi
    
    # Clean up temporary script
    rm -f "$temp_script"
    
    # Additional sync to ensure all changes are written
    sync
    sleep 2
    
    # Unmount
    print_substep "Finalizing DMG layout..."
    hdiutil detach "$device" >/dev/null 2>&1
    
    # Convert to compressed DMG with maximum compression
    print_substep "Compressing DMG (this may take a moment)..."
    hdiutil convert "$temp_dmg" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$final_dmg" >/dev/null 2>&1
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    local skip_build=false
    local app_path=""
    local sign_dmg=false
    local notarize_dmg=false
    local open_dmg=false
    
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
            --open)
                open_dmg=true
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
    
    # Verify prerequisites
    verify_prerequisites
    
    # Set up error handling
    trap cleanup EXIT
    
    # Create build directory
    print_step "Preparing build environment..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$STAGING_DIR"
    print_success "Build environment ready"
    
    # Build the app if needed
    if [ "$skip_build" = false ]; then
        print_step "Building Gemi in Release configuration..."
        cd "$PROJECT_ROOT/Gemi"
        
        # Build with progress indication
        (
            xcodebuild -project Gemi.xcodeproj \
                      -scheme Gemi \
                      -configuration Release \
                      -derivedDataPath "$BUILD_DIR/DerivedData" \
                      clean build \
                      2>&1 | while read line; do
                          if [[ "$line" =~ "BUILD SUCCEEDED" ]]; then
                              echo "success"
                          elif [[ "$line" =~ "BUILD FAILED" ]]; then
                              echo "failed"
                          fi
                      done
        ) &
        
        local build_pid=$!
        show_spinner $build_pid
        
        wait $build_pid
        local build_result=$?
        
        if [ $build_result -eq 0 ]; then
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
    if codesign --verify --deep "$app_path" 2>/dev/null; then
        print_success "App bundle signature verified"
    else
        print_warning "App bundle is not signed"
        print_info "This is normal for development builds"
    fi
    
    # Get app version
    local app_version="1.0"
    if [ -f "$app_path/Contents/Info.plist" ]; then
        app_version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$app_path/Contents/Info.plist" 2>/dev/null || echo "1.0")
    fi
    print_info "App version: $app_version"
    
    # Copy app to staging directory
    print_step "Preparing DMG contents..."
    print_substep "Copying Gemi.app..."
    ditto "$app_path" "$STAGING_DIR/Gemi.app"
    
    # Include .env file if it exists
    local env_file="$PROJECT_ROOT/.env"
    if [ -f "$env_file" ]; then
        print_substep "Including HuggingFace token..."
        mkdir -p "$STAGING_DIR/Gemi.app/Contents/Resources"
        cp "$env_file" "$STAGING_DIR/Gemi.app/Contents/Resources/.env"
        print_success "Token included in bundle"
    else
        print_warning "No .env file found at project root"
        print_info "Users will need to provide their own HuggingFace token"
    fi
    
    # Create Applications symlink
    print_substep "Creating Applications shortcut..."
    ln -s /Applications "$STAGING_DIR/Applications"
    
    # Copy background image
    mkdir -p "$STAGING_DIR/.background"
    if [ -f "$BACKGROUND_IMAGE" ]; then
        cp "$BACKGROUND_IMAGE" "$STAGING_DIR/.background/dmg-background.png"
        print_success "Custom background applied"
    else
        print_warning "Background image not found at: $BACKGROUND_IMAGE"
    fi
    
    # Create .DS_Store file to hide background folder
    print_substep "Configuring folder visibility..."
    cat > "$STAGING_DIR/.DS_Store_template" <<EOF
# This ensures .background folder is hidden
EOF
    
    # Create the DMG with beautiful layout
    print_step "Creating professional DMG installer..."
    create_beautiful_dmg "$STAGING_DIR" "$VOLUME_NAME" "$TEMP_DMG" "$FINAL_DMG"
    
    # Code sign the DMG if requested
    if [ "$sign_dmg" = true ]; then
        print_step "Code signing DMG..."
        if codesign --force --sign "Developer ID Application" "$FINAL_DMG"; then
            print_success "DMG signed successfully"
        else
            print_error "Failed to sign DMG"
            print_info "Make sure you have a valid Developer ID certificate"
            exit 1
        fi
    fi
    
    # Notarize if requested
    if [ "$notarize_dmg" = true ]; then
        print_step "Preparing for notarization..."
        print_info "To notarize, run:"
        echo "         xcrun notarytool submit \"$FINAL_DMG\" --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID --wait"
    fi
    
    # Verify final DMG
    print_step "Verifying DMG integrity..."
    if hdiutil verify "$FINAL_DMG" >/dev/null 2>&1; then
        print_success "DMG verification passed"
    else
        print_error "DMG verification failed"
        exit 1
    fi
    
    # Copy the final DMG to project root for easy access
    cp "$FINAL_DMG" "$PROJECT_ROOT/Gemi-Installer.dmg"
    
    # Get final stats
    local dmg_size
    dmg_size=$(du -h "$FINAL_DMG" | cut -f1)
    
    # Success!
    echo ""
    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║${NC}                    ${BOLD}✨ DMG Created Successfully! ✨${NC}              ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📦 File:${NC} ${BOLD}$(basename "$FINAL_DMG")${NC}"
    echo -e "${CYAN}📏 Size:${NC} ${BOLD}$dmg_size${NC}"
    echo -e "${CYAN}🏷  Version:${NC} ${BOLD}$app_version${NC}"
    echo -e "${CYAN}📍 Location:${NC} ${DIM}$FINAL_DMG${NC}"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Double-click the DMG to test the installer"
    echo "  2. Drag Gemi to Applications folder"
    echo "  3. Launch Gemi from Applications to verify"
    
    if [ "$sign_dmg" = false ]; then
        echo ""
        echo -e "${BOLD}For distribution:${NC}"
        echo "  • Run with ${CYAN}--sign${NC} to code sign the DMG"
        echo "  • Run with ${CYAN}--notarize${NC} for Mac App Store"
    fi
    
    echo ""
    
    # Open in Finder if requested or ask
    if [ "$open_dmg" = true ]; then
        open -R "$FINAL_DMG"
    else
        read -p "Would you like to open the DMG in Finder? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open -R "$FINAL_DMG"
        fi
    fi
}

# Run the main function
main "$@"