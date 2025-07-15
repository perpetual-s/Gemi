#!/bin/bash
# Create a UV-based bundle for GemiServer
# This bundles UV and the Python server into a macOS app

set -e

echo "🚀 Creating UV-based GemiServer.app bundle..."
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUNDLE_DIR="$SCRIPT_DIR/dist/GemiServer.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf "$BUNDLE_DIR"

# Create bundle structure
echo -e "${YELLOW}Creating bundle structure...${NC}"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy UV and create virtual environment
echo -e "${YELLOW}Setting up UV environment...${NC}"
cp -r "$HOME/.local/bin/uv" "$RESOURCES_DIR/" || {
    echo -e "${RED}Error: UV not found at ~/.local/bin/uv${NC}"
    echo "Please install UV first: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
}

# Copy Python server files
echo -e "${YELLOW}Copying server files...${NC}"
cp "$SCRIPT_DIR/inference_server.py" "$RESOURCES_DIR/"
cp "$SCRIPT_DIR/inference_server_lazy.py" "$RESOURCES_DIR/"
cp "$SCRIPT_DIR/pyproject.toml" "$RESOURCES_DIR/"
cp "$SCRIPT_DIR/hf_token.txt" "$RESOURCES_DIR/"

# Copy legal files
mkdir -p "$RESOURCES_DIR/legal"
cp -r "$SCRIPT_DIR/legal/"* "$RESOURCES_DIR/legal/" 2>/dev/null || true

# Create launcher script
echo -e "${YELLOW}Creating launcher script...${NC}"
cat > "$MACOS_DIR/GemiServer" << 'EOF'
#!/bin/bash
# GemiServer launcher script

# Get the directory of this script
BUNDLE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
RESOURCES_DIR="$BUNDLE_DIR/Resources"

# Set up environment
export PYTORCH_ENABLE_MPS_FALLBACK=1
export TOKENIZERS_PARALLELISM=false
export HF_HUB_DISABLE_SYMLINKS_WARNING=1
export TRANSFORMERS_OFFLINE=0

# Set model cache directory
export HF_HOME="$HOME/Library/Application Support/Gemi/Models"
export TRANSFORMERS_CACHE="$HF_HOME"
export TORCH_HOME="$HF_HOME"

# Create cache directory if it doesn't exist
mkdir -p "$HF_HOME"

# Log output
LOG_DIR="$HOME/Library/Logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/GemiServer.log"

# Change to resources directory
cd "$RESOURCES_DIR"

# Function to check if server is already running
check_server() {
    curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11435/api/health 2>/dev/null
}

# Check if server is already running
if [ "$(check_server)" = "200" ]; then
    echo "Server already running" >> "$LOG_FILE"
    exit 0
fi

# Start the server with UV
echo "Starting Gemi Server..." >> "$LOG_FILE"
echo "Date: $(date)" >> "$LOG_FILE"
echo "UV: $RESOURCES_DIR/uv" >> "$LOG_FILE"

# Create a working directory in user space
WORK_DIR="$HOME/Library/Application Support/Gemi/ServerRuntime"
mkdir -p "$WORK_DIR"

# Copy necessary files to working directory if not already there
if [ ! -f "$WORK_DIR/pyproject.toml" ]; then
    echo "Setting up working directory..." >> "$LOG_FILE"
    cp "$RESOURCES_DIR/pyproject.toml" "$WORK_DIR/"
    cp "$RESOURCES_DIR/inference_server.py" "$WORK_DIR/"
    cp "$RESOURCES_DIR/hf_token.txt" "$WORK_DIR/" 2>/dev/null || true
fi

# Change to working directory
cd "$WORK_DIR"

# Create virtual environment if it doesn't exist
if [ ! -d "$WORK_DIR/.venv" ]; then
    echo "Creating virtual environment..." >> "$LOG_FILE"
    "$RESOURCES_DIR/uv" venv "$WORK_DIR/.venv" >> "$LOG_FILE" 2>&1
fi

# Run the server from working directory
exec "$RESOURCES_DIR/uv" run python "$WORK_DIR/inference_server.py" 2>&1 | tee -a "$LOG_FILE"
EOF

chmod +x "$MACOS_DIR/GemiServer"

# Create Info.plist
echo -e "${YELLOW}Creating Info.plist...${NC}"
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GemiServer</string>
    <key>CFBundleName</key>
    <string>Gemi Inference Server</string>
    <key>CFBundleDisplayName</key>
    <string>Gemi Server</string>
    <key>CFBundleIdentifier</key>
    <string>com.gemi.inference-server</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleSignature</key>
    <string>GEMI</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>LSBackgroundOnly</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Gemi Server needs to process AI requests.</string>
</dict>
</plist>
EOF

# Add icon if available
ICON_PATH="../Documentation/assets-icons/gemi-icon.png"
if [ -f "$ICON_PATH" ]; then
    echo -e "${YELLOW}Adding icon...${NC}"
    mkdir -p "$RESOURCES_DIR"
    # Convert PNG to ICNS
    sips -s format icns "$ICON_PATH" --out "$RESOURCES_DIR/GemiServer.icns" 2>/dev/null || {
        echo -e "${YELLOW}Warning: Could not convert icon to ICNS format${NC}"
        cp "$ICON_PATH" "$RESOURCES_DIR/"
    }
fi

# Sign the bundle with ad-hoc signature
echo -e "${YELLOW}Signing bundle...${NC}"
# First sign the UV binary
codesign --force --sign - "$RESOURCES_DIR/uv"
# Then sign the entire bundle
codesign --force --deep --sign - "$BUNDLE_DIR"
# Verify the signature
echo -e "${YELLOW}Verifying signature...${NC}"
codesign --verify --verbose "$BUNDLE_DIR"

# Don't create virtual environment during bundling
# It will be created at runtime in the correct location
echo -e "${YELLOW}Bundle setup complete...${NC}"

# Get bundle size
BUNDLE_SIZE=$(du -sh "$BUNDLE_DIR" | cut -f1)

echo -e "${GREEN}✅ GemiServer.app created successfully!${NC}"
echo ""
echo "Bundle Information:"
echo "Location: $BUNDLE_DIR"
echo "Size: $BUNDLE_SIZE"
echo ""
echo "The bundle includes:"
echo "- UV package manager"
echo "- Python server scripts"
echo "- Automatic dependency installation"
echo "- HuggingFace authentication"
echo ""
echo "Next steps:"
echo "1. Test: open $BUNDLE_DIR"
echo "2. Check logs: tail -f ~/Library/Logs/GemiServer.log"