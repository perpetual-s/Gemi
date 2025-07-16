#!/bin/bash
# Clean Gemma 3n Model Cache Script
# Removes all cached Gemma models to test first-time user experience

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Gemma 3n Model Cache Cleaner${NC}"
echo "=================================="
echo ""
echo -e "${YELLOW}This will remove all cached Gemma models to simulate first-time installation.${NC}"
echo ""

# Cache locations to clean
CACHE_DIRS=(
    "$HOME/Library/Application Support/Gemi/Models"
    "$HOME/.cache/huggingface/hub/models--google--gemma-3n-e4b-it"
    "$HOME/.cache/huggingface/transformers"
    "$HOME/.cache/torch"
)

# Calculate total size before cleaning
TOTAL_SIZE=0
echo -e "${BLUE}Checking cache sizes...${NC}"
for dir in "${CACHE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "0")
        echo "  $dir: $SIZE"
        TOTAL_SIZE=$((TOTAL_SIZE + $(du -sm "$dir" 2>/dev/null | cut -f1 || echo 0)))
    fi
done

if [ $TOTAL_SIZE -eq 0 ]; then
    echo -e "${YELLOW}No Gemma model cache found. System is already clean.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Total cache size: ${TOTAL_SIZE}MB${NC}"
echo ""

# Confirm with user
read -p "Are you sure you want to remove all Gemma model caches? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

# Kill any running Gemi processes first
echo ""
echo -e "${YELLOW}Stopping any running Gemi processes...${NC}"
pkill -f "Gemi.app" 2>/dev/null || true
pkill -f "GemiServer" 2>/dev/null || true
pkill -f "inference_server" 2>/dev/null || true
sleep 2

# Remove cache directories
echo -e "${YELLOW}Removing cache directories...${NC}"
for dir in "${CACHE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  Removing: $dir"
        rm -rf "$dir"
    fi
done

# Also clean any temporary UV environments
UV_CACHE="$HOME/Library/Application Support/Gemi/ServerRuntime/.venv"
if [ -d "$UV_CACHE" ]; then
    echo "  Removing UV cache: $UV_CACHE"
    rm -rf "$UV_CACHE"
fi

# Clean server logs
LOG_FILE="$HOME/Library/Logs/GemiServer.log"
if [ -f "$LOG_FILE" ]; then
    echo "  Cleaning server log"
    > "$LOG_FILE"
fi

echo ""
echo -e "${GREEN}✅ Cache cleaned successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps to test first-time user experience:${NC}"
echo "1. Build fresh DMG: ./build_and_package.sh"
echo "2. Mount the DMG and install to Applications"
echo "3. Launch Gemi - it will download model (~8GB)"
echo "4. Monitor download progress in the UI"
echo ""
echo -e "${YELLOW}Note: First launch will take 10-30 minutes to download the model.${NC}"