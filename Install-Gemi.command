#!/bin/bash
# Gemi Installation Script
# Professional installer for seamless setup

# Enable strict error handling
set -e

# Colors for beautiful output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Animated spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    printf " "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Clear screen for clean start
clear

# Header
echo -e "${BLUE}${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║          🌟 Gemi Installer 🌟           ║"
echo "║    Your Private AI Journal Companion     ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if running from mounted DMG
if [[ "$SCRIPT_DIR" == /Volumes/Gemi* ]]; then
    echo -e "${GREEN}✓${NC} Running from Gemi installer"
else
    echo -e "${RED}❌ Error:${NC} Please run this installer from the mounted Gemi.dmg"
    echo "   1. Open Gemi.dmg"
    echo "   2. Double-click Install-Gemi"
    exit 1
fi

echo ""
echo -e "${BLUE}Starting installation...${NC}"
echo ""

# Step 1: Check for existing installation
echo -e "${BOLD}1. Checking for existing installation${NC}"
if [ -d "/Applications/Gemi.app" ] || [ -d "$HOME/Applications/Gemi.app" ]; then
    echo -e "${YELLOW}⚠️  Existing Gemi installation found${NC}"
    read -p "Replace existing installation? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled${NC}"
        exit 0
    fi
fi
echo -e "${GREEN}✓${NC} Ready to install"

# Step 2: Create Applications directory if needed
echo ""
echo -e "${BOLD}2. Preparing installation directory${NC}"
if [ -w "/Applications" ]; then
    INSTALL_DIR="/Applications"
    echo -e "${GREEN}✓${NC} Installing to /Applications"
else
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
    echo -e "${GREEN}✓${NC} Installing to ~/Applications"
fi

# Step 3: Copy Gemi.app
echo ""
echo -e "${BOLD}3. Installing Gemi.app${NC}"
(
    rm -rf "$INSTALL_DIR/Gemi.app" 2>/dev/null || true
    cp -R "$SCRIPT_DIR/Gemi.app" "$INSTALL_DIR/" 2>/dev/null || 
    cp -R "$SCRIPT_DIR/Gemi.app" "$INSTALL_DIR/"
) & spinner $!
echo -e "${GREEN}✓${NC} Gemi.app installed"

# Step 4: Copy GemiServer.app
echo ""
echo -e "${BOLD}4. Installing AI Server${NC}"
(
    rm -rf "$INSTALL_DIR/GemiServer.app" 2>/dev/null || true
    cp -R "$SCRIPT_DIR/GemiServer.app" "$INSTALL_DIR/" 2>/dev/null || 
    cp -R "$SCRIPT_DIR/GemiServer.app" "$INSTALL_DIR/"
) & spinner $!
echo -e "${GREEN}✓${NC} GemiServer.app installed"

# Step 5: Remove quarantine attributes
echo ""
echo -e "${BOLD}5. Configuring security settings${NC}"
(
    xattr -cr "$INSTALL_DIR/Gemi.app" 2>/dev/null || true
    xattr -cr "$INSTALL_DIR/GemiServer.app" 2>/dev/null || true
) & spinner $!
echo -e "${GREEN}✓${NC} Security settings configured"

# Step 6: Create support directories
echo ""
echo -e "${BOLD}6. Creating support directories${NC}"
mkdir -p "$HOME/Library/Application Support/Gemi/Models"
mkdir -p "$HOME/Library/Application Support/Gemi/Data"
mkdir -p "$HOME/Library/Logs/Gemi"
echo -e "${GREEN}✓${NC} Support directories created"

# Step 7: Verify installation
echo ""
echo -e "${BOLD}7. Verifying installation${NC}"
if [ -f "$INSTALL_DIR/Gemi.app/Contents/MacOS/Gemi" ] && 
   [ -f "$INSTALL_DIR/GemiServer.app/Contents/MacOS/GemiServer" ]; then
    echo -e "${GREEN}✓${NC} Installation verified successfully"
else
    echo -e "${RED}❌ Installation verification failed${NC}"
    echo "   Please try installing manually by dragging the apps to Applications"
    exit 1
fi

# Success!
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗"
echo -e "║        ✅ Installation Complete! ✅       ║"
echo -e "╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}What happens next:${NC}"
echo "• First launch will download the AI model (~8GB)"
echo "• This is a one-time download"
echo "• Everything runs locally on your Mac"
echo ""
echo -e "${BOLD}Ready to start journaling?${NC}"
echo "1. Close this window"
echo "2. Eject the Gemi disk image" 
echo "3. Launch Gemi from $INSTALL_DIR"
echo ""
echo -e "${BLUE}Thank you for choosing Gemi! 🎉${NC}"
echo ""

# Optional: Launch Gemi
read -p "Would you like to launch Gemi now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Launching Gemi..."
    open "$INSTALL_DIR/Gemi.app"
fi

# Keep window open
echo ""
read -p "Press Enter to close this window..."