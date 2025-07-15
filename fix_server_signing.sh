#!/bin/bash
# Fix GemiServer.app signing issues for production deployment

set -e

echo "🔧 Fixing GemiServer.app code signing..."
echo "======================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Find GemiServer.app
SERVER_APP=""
if [ -d "python-inference-server/dist/GemiServer.app" ]; then
    SERVER_APP="python-inference-server/dist/GemiServer.app"
elif [ -d "build/Gemi.xcarchive/Products/Applications/Gemi.app/Contents/Resources/GemiServer.app" ]; then
    SERVER_APP="build/Gemi.xcarchive/Products/Applications/Gemi.app/Contents/Resources/GemiServer.app"
else
    echo -e "${RED}❌ GemiServer.app not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Found server at: $SERVER_APP${NC}"

# Remove quarantine attributes
echo -e "${YELLOW}Removing quarantine attributes...${NC}"
xattr -cr "$SERVER_APP"

# Make all executables actually executable
echo -e "${YELLOW}Setting executable permissions...${NC}"
find "$SERVER_APP" -type f -name "python*" -exec chmod +x {} \;
find "$SERVER_APP" -type f -name "uv" -exec chmod +x {} \;
chmod +x "$SERVER_APP/Contents/MacOS/GemiServer"

# Create entitlements for the server
echo -e "${YELLOW}Creating server entitlements...${NC}"
cat > server-entitlements.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.inherit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.disable-executable-page-protection</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
EOF

# Sign with proper entitlements
echo -e "${YELLOW}Signing GemiServer.app with entitlements...${NC}"

# First sign all internal binaries
find "$SERVER_APP" -name "*.dylib" -o -name "*.so" | while read lib; do
    codesign --force --sign - "$lib" 2>/dev/null || true
done

# Sign UV binary specifically
if [ -f "$SERVER_APP/Contents/Resources/uv" ]; then
    codesign --force --sign - --entitlements server-entitlements.plist "$SERVER_APP/Contents/Resources/uv"
fi

# Sign the main executable
codesign --force --sign - --entitlements server-entitlements.plist "$SERVER_APP/Contents/MacOS/GemiServer"

# Finally sign the entire bundle
codesign --force --deep --sign - --entitlements server-entitlements.plist "$SERVER_APP"

# Verify
echo -e "${YELLOW}Verifying signature...${NC}"
codesign --verify --verbose "$SERVER_APP"

# Clean up
rm -f server-entitlements.plist

echo -e "${GREEN}✅ Server signing fixed!${NC}"
echo ""
echo "Next steps:"
echo "1. Rebuild the DMG with: ./create_gemi_dmg.sh"
echo "2. The server should now work from /Applications"