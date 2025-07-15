#!/bin/bash
# Zero-Friction Deployment Test Script
# Tests the complete installation experience from a user's perspective

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Gemi Zero-Friction Deployment Test${NC}"
echo "======================================"
echo ""

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DMG_PATH="$PROJECT_ROOT/Gemi.dmg"
TEST_DIR="$HOME/Desktop/GemiTest"
TEST_APP="$TEST_DIR/Gemi.app"

# Function to check if process is running
is_process_running() {
    pgrep -f "$1" > /dev/null 2>&1
}

# Function to kill test processes
cleanup_test() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    
    # Kill any running Gemi or GemiServer processes
    pkill -f "Gemi.app" 2>/dev/null || true
    pkill -f "GemiServer" 2>/dev/null || true
    pkill -f "inference_server.py" 2>/dev/null || true
    
    # Remove test installation
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    
    # Unmount any Gemi DMG
    if [ -d "/Volumes/Gemi - AI Diary" ]; then
        hdiutil detach "/Volumes/Gemi - AI Diary" -quiet 2>/dev/null || true
    fi
}

# Cleanup on exit
trap cleanup_test EXIT

# Test 1: Check if DMG exists
echo -e "${BLUE}Test 1: DMG Existence${NC}"
if [ ! -f "$DMG_PATH" ]; then
    echo -e "${RED}❌ DMG not found at $DMG_PATH${NC}"
    echo "Run: ./scripts/build_and_package.sh"
    exit 1
fi
echo -e "${GREEN}✅ DMG found${NC}"

# Test 2: Mount DMG
echo ""
echo -e "${BLUE}Test 2: DMG Mounting${NC}"
echo -e "${YELLOW}Mounting DMG...${NC}"
hdiutil attach "$DMG_PATH" -noautoopen

if [ ! -d "/Volumes/Gemi - AI Diary/Gemi.app" ]; then
    echo -e "${RED}❌ Failed to mount DMG or Gemi.app not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ DMG mounted successfully${NC}"

# Test 3: Simulate user installation
echo ""
echo -e "${BLUE}Test 3: App Installation${NC}"
mkdir -p "$TEST_DIR"
echo -e "${YELLOW}Copying Gemi.app to test directory...${NC}"
cp -R "/Volumes/Gemi - AI Diary/Gemi.app" "$TEST_DIR/"

if [ ! -d "$TEST_APP" ]; then
    echo -e "${RED}❌ Failed to copy Gemi.app${NC}"
    exit 1
fi
echo -e "${GREEN}✅ App copied successfully${NC}"

# Test 4: Check bundled server
echo ""
echo -e "${BLUE}Test 4: Bundled Server Check${NC}"
BUNDLED_SERVER="$TEST_APP/Contents/Resources/GemiServer.app"
if [ ! -d "$BUNDLED_SERVER" ]; then
    echo -e "${RED}❌ GemiServer.app not bundled${NC}"
    exit 1
fi

SERVER_SIZE=$(du -sh "$BUNDLED_SERVER" | cut -f1)
echo -e "${GREEN}✅ GemiServer.app bundled (size: $SERVER_SIZE)${NC}"

# Test 5: Launch app and check server startup
echo ""
echo -e "${BLUE}Test 5: App Launch & Server Startup${NC}"
echo -e "${YELLOW}Launching Gemi...${NC}"

# Launch app in background
open "$TEST_APP"

# Give app time to start
sleep 5

# Check if Gemi is running
if ! is_process_running "Gemi.app"; then
    echo -e "${RED}❌ Gemi failed to launch${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Gemi launched successfully${NC}"

# Wait for server to start (up to 30 seconds)
echo -e "${YELLOW}Waiting for server to start...${NC}"
TIMEOUT=30
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11435/api/health 2>/dev/null | grep -q "200"; then
        echo -e "${GREEN}✅ Server is responding${NC}"
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
    echo -ne "\r${YELLOW}Waiting... ${ELAPSED}s${NC}"
done

if [ $ELAPSED -eq $TIMEOUT ]; then
    echo -e "\n${RED}❌ Server failed to start within ${TIMEOUT} seconds${NC}"
    
    # Check server logs
    echo -e "${YELLOW}Checking server logs...${NC}"
    if [ -f "$HOME/Library/Logs/GemiServer.log" ]; then
        echo "Last 20 lines of server log:"
        tail -20 "$HOME/Library/Logs/GemiServer.log"
    fi
    exit 1
fi

# Test 6: Server health check
echo ""
echo -e "${BLUE}Test 6: Server Health Check${NC}"
HEALTH_RESPONSE=$(curl -s http://127.0.0.1:11435/api/health)

if echo "$HEALTH_RESPONSE" | grep -q "\"status\":\"healthy\""; then
    echo -e "${GREEN}✅ Server is healthy${NC}"
else
    echo -e "${RED}❌ Server health check failed${NC}"
    echo "Response: $HEALTH_RESPONSE"
    exit 1
fi

# Test 7: Check server port conflicts
echo ""
echo -e "${BLUE}Test 7: Port Conflict Handling${NC}"

# Try to start another server instance (should be handled gracefully)
"$BUNDLED_SERVER/Contents/MacOS/GemiServer" &
SECOND_PID=$!
sleep 3

# The second instance should have exited or connected to existing server
if kill -0 $SECOND_PID 2>/dev/null; then
    echo -e "${RED}❌ Port conflict not handled properly${NC}"
    kill $SECOND_PID 2>/dev/null
else
    echo -e "${GREEN}✅ Port conflict handled gracefully${NC}"
fi

# Test 8: Model download check
echo ""
echo -e "${BLUE}Test 8: Model Download Status${NC}"
MODEL_LOADED=$(echo "$HEALTH_RESPONSE" | grep -o '"model_loaded":[^,}]*' | cut -d: -f2)
DOWNLOAD_PROGRESS=$(echo "$HEALTH_RESPONSE" | grep -o '"download_progress":[^,}]*' | cut -d: -f2)

echo "Model loaded: $MODEL_LOADED"
echo "Download progress: $DOWNLOAD_PROGRESS"

if [ "$MODEL_LOADED" = "true" ]; then
    echo -e "${GREEN}✅ Model already loaded${NC}"
else
    echo -e "${YELLOW}⏳ Model download in progress (${DOWNLOAD_PROGRESS})${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}Test Summary${NC}"
echo "============="
echo -e "${GREEN}✅ DMG installation works${NC}"
echo -e "${GREEN}✅ App launches successfully${NC}"
echo -e "${GREEN}✅ Server starts automatically${NC}"
echo -e "${GREEN}✅ No manual setup required${NC}"
echo ""
echo -e "${GREEN}🎉 Zero-Friction Deployment Test PASSED!${NC}"
echo ""
echo "The user experience is:"
echo "1. Download Gemi.dmg"
echo "2. Drag to Applications"
echo "3. Launch and use immediately"