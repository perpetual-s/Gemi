#!/bin/bash
# Build script for GemiServer.app

set -e

echo "🚀 Building GemiServer.app..."
echo "=============================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "inference_server.py" ]; then
    echo -e "${RED}Error: inference_server.py not found!${NC}"
    echo "Please run this script from the python-inference-server directory"
    exit 1
fi

# Check for required icon
ICON_PATH="../Gemi/Gemi/Assets.xcassets/AppIcon.iconset/icon_512x512@2x.png"
if [ ! -f "$ICON_PATH" ]; then
    echo -e "${YELLOW}Warning: Icon not found at $ICON_PATH${NC}"
    echo "Using default icon..."
    # Create a simple default icon if needed
    mkdir -p temp_icon
    # We'll update the spec to handle missing icon
fi

# Install PyInstaller if not present
echo -e "${YELLOW}Checking PyInstaller...${NC}"
if ! pip show pyinstaller >/dev/null 2>&1; then
    echo "Installing PyInstaller..."
    pip install pyinstaller
fi

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf build dist __pycache__
rm -f *.log

# Build the app
echo -e "${YELLOW}Building with PyInstaller...${NC}"
pyinstaller gemi-server.spec --clean --noconfirm

# Check if build succeeded
if [ -d "dist/GemiServer.app" ]; then
    echo -e "${GREEN}✓ Build successful!${NC}"

# Sign the app with ad-hoc signature to prevent macOS from killing it
echo -e "${YELLOW}Signing app with ad-hoc signature...${NC}"
codesign --force --deep --sign - "dist/GemiServer.app"
echo -e "${GREEN}✓ App signed!${NC}"
    
    # Optimize the bundle
    echo -e "${YELLOW}Optimizing bundle size...${NC}"
    
    # Remove unnecessary files
    find dist/GemiServer.app -name "*.pyc" -delete 2>/dev/null || true
    find dist/GemiServer.app -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find dist/GemiServer.app -name "*.pyo" -delete 2>/dev/null || true
    find dist/GemiServer.app -name "test_*" -delete 2>/dev/null || true
    find dist/GemiServer.app -name "*_test.py" -delete 2>/dev/null || true
    
    # Strip debug symbols
    if [ -f "dist/GemiServer.app/Contents/MacOS/GemiServer" ]; then
        strip -S dist/GemiServer.app/Contents/MacOS/GemiServer
    fi
    
    # Show bundle info
    echo -e "${GREEN}Bundle Information:${NC}"
    echo "Location: $(pwd)/dist/GemiServer.app"
    echo "Size: $(du -sh dist/GemiServer.app | cut -f1)"
    
    # Test if it can launch
    echo -e "${YELLOW}Testing launch...${NC}"
    if dist/GemiServer.app/Contents/MacOS/GemiServer --version 2>/dev/null; then
        echo -e "${GREEN}✓ Binary launches successfully${NC}"
    else
        echo -e "${YELLOW}Note: Server may need environment setup to run${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 GemiServer.app built successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test the server: ./dist/GemiServer.app/Contents/MacOS/GemiServer"
    echo "2. Copy to Gemi project for testing"
    echo "3. Include in DMG creation"
    
else
    echo -e "${RED}❌ Build failed!${NC}"
    echo "Check the build/GemiServer/warn-GemiServer.txt for errors"
    exit 1
fi