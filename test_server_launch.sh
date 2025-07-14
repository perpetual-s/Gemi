#!/bin/bash

echo "Testing GemiServer launch..."
echo "=========================="

# Set up environment
export PYTORCH_ENABLE_MPS_FALLBACK=1
export HF_HOME="$HOME/Library/Application Support/Gemi/Models"

# Path to GemiServer
SERVER_PATH="/Applications/Gemi.app/Contents/Resources/GemiServer.app/Contents/MacOS/GemiServer"

if [ ! -f "$SERVER_PATH" ]; then
    echo "❌ Error: GemiServer not found at $SERVER_PATH"
    exit 1
fi

echo "✅ GemiServer found at: $SERVER_PATH"
echo "File info:"
ls -la "$SERVER_PATH"
echo ""

echo "Checking file type:"
file "$SERVER_PATH"
echo ""

echo "Environment variables:"
echo "PYTORCH_ENABLE_MPS_FALLBACK=$PYTORCH_ENABLE_MPS_FALLBACK"
echo "HF_HOME=$HF_HOME"
echo ""

echo "Attempting to run GemiServer..."
echo "================================"

# Run with timeout to capture any immediate errors
timeout 10 "$SERVER_PATH" 2>&1 | head -50

echo ""
echo "Exit code: $?"