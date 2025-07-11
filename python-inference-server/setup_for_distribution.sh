#!/bin/bash
# Setup script for distributing Gemi with Python inference server
# This script prepares the Python server for bundling with the macOS app

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIST_DIR="$SCRIPT_DIR/dist"

echo "🚀 Gemi Python Server Distribution Setup"
echo "======================================="

# Create distribution directory
echo "📦 Creating distribution directory..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Copy essential files
echo "📋 Copying essential files..."
cp "$SCRIPT_DIR/inference_server.py" "$DIST_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$DIST_DIR/"
cp "$SCRIPT_DIR/launch_server.sh" "$DIST_DIR/"
cp "$SCRIPT_DIR/README.md" "$DIST_DIR/"

# Create minimal setup script for end users
cat > "$DIST_DIR/first_time_setup.sh" << 'EOF'
#!/bin/bash
# First-time setup for Gemi AI Server

echo "🎉 Welcome to Gemi AI Server Setup!"
echo "==================================="
echo ""
echo "This script will:"
echo "1. Check Python installation"
echo "2. Create a virtual environment"
echo "3. Install required dependencies"
echo "4. Download the Gemma 3n model (~8GB)"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed!"
    echo "Please install Python 3.9 or later from https://python.org"
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
echo "✓ Found Python $PYTHON_VERSION"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate and install
echo "🔧 Installing dependencies..."
source venv/bin/activate
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start the server, run:"
echo "  ./launch_server.sh"
echo ""
echo "Note: The first run will download the Gemma 3n model (~8GB)"
echo "This is a one-time download that may take 10-30 minutes."
EOF

chmod +x "$DIST_DIR/first_time_setup.sh"

# Create app integration script
cat > "$DIST_DIR/integrate_with_app.sh" << 'EOF'
#!/bin/bash
# Integrate Python server with Gemi.app

GEMI_APP="/Applications/Gemi.app"
RESOURCES_DIR="$GEMI_APP/Contents/Resources"
SERVER_DIR="$RESOURCES_DIR/python-inference-server"

if [ ! -d "$GEMI_APP" ]; then
    echo "❌ Gemi.app not found in /Applications"
    echo "Please install Gemi.app first"
    exit 1
fi

echo "📦 Installing Python server into Gemi.app..."
sudo mkdir -p "$SERVER_DIR"
sudo cp -r * "$SERVER_DIR/"
sudo chown -R $(whoami) "$SERVER_DIR"

echo "✅ Python server integrated with Gemi.app"
echo ""
echo "The server can now be launched from within Gemi"
echo "or manually from: $SERVER_DIR/launch_server.sh"
EOF

chmod +x "$DIST_DIR/integrate_with_app.sh"

# Create simple test script
cat > "$DIST_DIR/test_server.py" << 'EOF'
#!/usr/bin/env python3
"""Test script to verify server is working"""

import requests
import time
import sys

print("🧪 Testing Gemi AI Server...")

# Wait for server to start
print("⏳ Waiting for server to start (5 seconds)...")
time.sleep(5)

try:
    # Test health endpoint
    response = requests.get("http://localhost:11435/api/health")
    health = response.json()
    
    print(f"✓ Server status: {health['status']}")
    print(f"✓ Model loaded: {health['model_loaded']}")
    print(f"✓ Device: {health['device']}")
    print(f"✓ MPS available: {health['mps_available']}")
    
    if health['model_loaded']:
        print("\n✅ Server is ready for use!")
    else:
        progress = int(health['download_progress'] * 100)
        print(f"\n⏳ Model loading: {progress}%")
        print("Please wait for model download to complete...")
    
except Exception as e:
    print(f"\n❌ Error: {e}")
    print("Make sure the server is running: ./launch_server.sh")
    sys.exit(1)
EOF

chmod +x "$DIST_DIR/test_server.py"

# Create distribution README
cat > "$DIST_DIR/QUICK_START.md" << 'EOF'
# Gemi AI Server - Quick Start Guide

## For Hackathon Judges

### Option 1: Quick Test (Recommended)
1. Open Terminal in this directory
2. Run: `./first_time_setup.sh` (one-time setup)
3. Run: `./launch_server.sh` (starts the server)
4. In another Terminal tab: `python3 test_server.py`

The first run will download the Gemma 3n model (~8GB).

### Option 2: Integrated with Gemi.app
1. Install Gemi.app to /Applications
2. Run: `./integrate_with_app.sh`
3. Launch Gemi.app - it will guide you to start the server

## Technical Details
- Port: 11435 (different from Ollama's 11434)
- Model: google/gemma-3n-e4b-it
- Multimodal: Text + Images (base64 encoded)
- GPU: Metal Performance Shaders on Apple Silicon

## Troubleshooting
- Python not found: Install Python 3.9+ from python.org
- Port in use: Change port in inference_server.py
- Model download stuck: Delete ~/.cache/huggingface and retry

For full documentation, see README.md
EOF

echo ""
echo "✅ Distribution package created in: $DIST_DIR"
echo ""
echo "Files created:"
echo "  - first_time_setup.sh    : One-time setup for end users"
echo "  - integrate_with_app.sh  : Integrate with Gemi.app"
echo "  - test_server.py         : Test script"
echo "  - QUICK_START.md         : Quick start guide"
echo ""
echo "To create a zip for distribution:"
echo "  cd $DIST_DIR && zip -r gemi-ai-server.zip *"