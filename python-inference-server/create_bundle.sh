#!/bin/bash
# Create a bundled GemiServer.app that uses UV for dependency management
# This approach avoids PyInstaller issues with PyTorch

set -e

echo "Creating GemiServer.app bundle..."
echo "==============================="

# Configuration
APP_NAME="GemiServer"
BUNDLE_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"

# Clean previous build
echo "Cleaning previous builds..."
rm -rf dist
mkdir -p dist

# Create app bundle structure
echo "Creating app bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"

# Create launcher script
echo "Creating launcher script..."
cat > "${MACOS_DIR}/${APP_NAME}" << 'EOF'
#!/bin/bash
# GemiServer launcher script

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$( cd "${SCRIPT_DIR}/.." && pwd )"
RESOURCES_DIR="${APP_DIR}/Resources"

# Set up environment
export PYTHONPATH="${RESOURCES_DIR}:${PYTHONPATH}"
export HF_HOME="${HOME}/Library/Application Support/Gemi/Models"
export TRANSFORMERS_CACHE="${HF_HOME}"
export HF_TOKEN="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"

# Create cache directory
mkdir -p "${HF_HOME}"

# Change to resources directory
cd "${RESOURCES_DIR}"

# Check if UV is available in the bundle
if [ -f "${RESOURCES_DIR}/uv" ]; then
    UV_BIN="${RESOURCES_DIR}/uv"
else
    # Install UV if not present
    echo "Installing UV package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    UV_BIN="${HOME}/.cargo/bin/uv"
fi

# Log output
LOG_FILE="${HOME}/Library/Logs/GemiServer.log"
mkdir -p "$(dirname "${LOG_FILE}")"

# Run the server using UV
echo "Starting Gemi Server..." >> "${LOG_FILE}"
echo "Date: $(date)" >> "${LOG_FILE}"
echo "UV: ${UV_BIN}" >> "${LOG_FILE}"

# Sync dependencies and run
cd "${RESOURCES_DIR}"
"${UV_BIN}" sync --quiet 2>&1 | tee -a "${LOG_FILE}"
"${UV_BIN}" run python inference_server.py 2>&1 | tee -a "${LOG_FILE}"
EOF

# Make launcher executable
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Python server files
echo "Copying server files..."
cp inference_server.py "${RESOURCES_DIR}/"
cp pyproject.toml "${RESOURCES_DIR}/"
cp requirements.txt "${RESOURCES_DIR}/" 2>/dev/null || true
cp -r legal "${RESOURCES_DIR}/" 2>/dev/null || true

# Copy UV binary if available
if command -v uv &> /dev/null; then
    echo "Copying UV binary..."
    cp "$(which uv)" "${RESOURCES_DIR}/" || true
fi

# Create Info.plist
echo "Creating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>GemiServer</string>
    <key>CFBundleDisplayName</key>
    <string>Gemi Inference Server</string>
    <key>CFBundleIdentifier</key>
    <string>com.gemi.inference-server</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>GemiServer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>GEMI</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSBackgroundOnly</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Gemi Server needs to process AI requests.</string>
    <key>LSEnvironment</key>
    <dict>
        <key>PYTORCH_ENABLE_MPS_FALLBACK</key>
        <string>1</string>
        <key>TOKENIZERS_PARALLELISM</key>
        <string>false</string>
        <key>HF_HUB_DISABLE_SYMLINKS_WARNING</key>
        <string>1</string>
    </dict>
</dict>
</plist>
EOF

# Create a simple test script
echo "Creating test script..."
cat > "test_bundle.sh" << 'EOF'
#!/bin/bash
echo "Testing GemiServer.app bundle..."
echo "================================"

# Launch the server
./dist/GemiServer.app/Contents/MacOS/GemiServer &
SERVER_PID=$!

# Wait for server to start
echo "Waiting for server to start..."
sleep 10

# Test health endpoint
echo "Testing health endpoint..."
curl -s http://127.0.0.1:11435/api/health | jq . || echo "Health check failed"

# Kill the server
echo "Stopping server..."
kill $SERVER_PID 2>/dev/null

echo "Test complete!"
EOF
chmod +x test_bundle.sh

# Sign the app bundle (ad-hoc)
echo "Signing app bundle..."
codesign --force --deep --sign - "${BUNDLE_DIR}"

echo ""
echo "Bundle created successfully at: ${BUNDLE_DIR}"
echo ""
echo "To test the bundle:"
echo "  ./test_bundle.sh"
echo ""
echo "To run directly:"
echo "  ./dist/GemiServer.app/Contents/MacOS/GemiServer"
echo ""
echo "This bundle will:"
echo "1. Install UV if needed"
echo "2. Download dependencies on first run"
echo "3. Download the Gemma model on first use"
echo "4. Run completely offline after setup"