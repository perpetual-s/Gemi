#!/bin/bash

# Script to code sign Gemi app for development and distribution
# This resolves the "isn't code signed but requires entitlements" warning

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Gemi Code Signing Script${NC}"
echo ""

# Configuration
APP_PATH="/Users/chaeho/Library/Developer/Xcode/DerivedData/Gemi-gzhmrwuzvujrehgmrgxtydkgciay/Build/Products/Debug/Gemi.app"
ENTITLEMENTS_PATH="/Users/chaeho/Documents/project-Gemi/Gemi/Gemi/Gemi.entitlements"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}❌ This script must be run on macOS${NC}"
    exit 1
fi

# Function to find valid signing identity
find_signing_identity() {
    echo -e "${BLUE}Looking for signing identities...${NC}"
    
    # First, try to find a development certificate
    DEV_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk -F'"' '{print $2}')
    
    if [[ -n "$DEV_IDENTITY" ]]; then
        echo -e "${GREEN}✓ Found development identity: $DEV_IDENTITY${NC}"
        SIGNING_IDENTITY="$DEV_IDENTITY"
        return 0
    fi
    
    # Try Mac Developer certificate
    MAC_DEV_IDENTITY=$(security find-identity -v -p codesigning | grep "Mac Developer" | head -1 | awk -F'"' '{print $2}')
    
    if [[ -n "$MAC_DEV_IDENTITY" ]]; then
        echo -e "${GREEN}✓ Found Mac Developer identity: $MAC_DEV_IDENTITY${NC}"
        SIGNING_IDENTITY="$MAC_DEV_IDENTITY"
        return 0
    fi
    
    # Try any valid certificate
    ANY_IDENTITY=$(security find-identity -v -p codesigning | grep -v "CSSMERR" | head -1 | awk -F'"' '{print $2}')
    
    if [[ -n "$ANY_IDENTITY" ]]; then
        echo -e "${YELLOW}⚠️  Using generic identity: $ANY_IDENTITY${NC}"
        SIGNING_IDENTITY="$ANY_IDENTITY"
        return 0
    fi
    
    return 1
}

# Option 1: Sign with certificate (if available)
if find_signing_identity; then
    echo ""
    echo -e "${BLUE}Signing Gemi with identity: $SIGNING_IDENTITY${NC}"
    
    # Sign the app with entitlements
    codesign --force --deep --sign "$SIGNING_IDENTITY" \
        --entitlements "$ENTITLEMENTS_PATH" \
        --timestamp \
        --options runtime \
        "$APP_PATH"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Successfully signed Gemi.app${NC}"
        
        # Verify the signature
        echo ""
        echo -e "${BLUE}Verifying signature...${NC}"
        codesign --verify --deep --strict --verbose=2 "$APP_PATH"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Signature verified successfully${NC}"
        else
            echo -e "${YELLOW}⚠️  Signature verification had warnings${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to sign app${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  No signing identity found${NC}"
    echo ""
    echo "To sign Gemi, you need:"
    echo "1. An Apple Developer account (free or paid)"
    echo "2. A signing certificate in Keychain"
    echo ""
    echo "Steps to create a certificate:"
    echo "1. Open Xcode"
    echo "2. Go to Preferences → Accounts"
    echo "3. Add your Apple ID"
    echo "4. Click 'Manage Certificates'"
    echo "5. Create a new 'Apple Development' certificate"
    echo ""
    echo "Alternative: Ad-hoc signing (less secure but works):"
    echo "  codesign --force --deep -s - \"$APP_PATH\""
fi

echo ""
echo -e "${BLUE}📋 Entitlements Summary:${NC}"
echo "• App Sandbox: Disabled (for MLX/Metal access)"
echo "• Network Client: Enabled (for model downloads)"
echo "• JIT & Memory: Enabled (for MLX inference)"
echo "• File Access: User-selected read/write"

echo ""
echo -e "${GREEN}✨ Done! You can now run Gemi without warnings.${NC}"

# Option to create an ad-hoc signed version
echo ""
echo -e "${BLUE}Want to create an ad-hoc signed version? (y/n)${NC}"
read -r response

if [[ "$response" == "y" || "$response" == "Y" ]]; then
    echo -e "${BLUE}Creating ad-hoc signed copy...${NC}"
    
    ADHOC_APP_PATH="${APP_PATH%.app}-AdHoc.app"
    cp -R "$APP_PATH" "$ADHOC_APP_PATH"
    
    codesign --force --deep -s - "$ADHOC_APP_PATH"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Created ad-hoc signed version at:${NC}"
        echo "   $ADHOC_APP_PATH"
        echo ""
        echo "Note: Ad-hoc signing works for local testing but not for distribution."
    fi
fi