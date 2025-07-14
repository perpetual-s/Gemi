#!/bin/bash

echo "=== Gemi Server Diagnostics ==="
echo ""

# 1. Check if server binary exists and is executable
SERVER="/Applications/Gemi.app/Contents/Resources/GemiServer.app/Contents/MacOS/GemiServer"
echo "1. Checking server binary..."
if [ -f "$SERVER" ]; then
    echo "✅ Server exists at: $SERVER"
    ls -la "$SERVER"
    file "$SERVER"
else
    echo "❌ Server not found!"
    exit 1
fi

# 2. Check if port is already in use
echo ""
echo "2. Checking if port 11435 is already in use..."
if lsof -i :11435 | grep LISTEN; then
    echo "❌ Port 11435 is already in use!"
    echo "Another process is using the port. Kill it first."
else
    echo "✅ Port 11435 is available"
fi

# 3. Try to run the server and capture immediate output
echo ""
echo "3. Running server for 5 seconds to capture output..."
export PYTORCH_ENABLE_MPS_FALLBACK=1
export HF_HOME="$HOME/Library/Application Support/Gemi/Models"

# Run with timeout and capture all output
(timeout 5 "$SERVER" 2>&1 || true) | tee server_output.txt

echo ""
echo "4. Server output:"
cat server_output.txt

# 5. Check for Python/PyInstaller specific issues
echo ""
echo "5. Checking for common PyInstaller issues..."

# Check if it's trying to extract to a temp directory
if grep -i "errno" server_output.txt; then
    echo "⚠️  Found errno - possible permission issue"
fi

if grep -i "modulenotfound" server_output.txt; then
    echo "⚠️  Found module import error"
fi

echo ""
echo "=== Diagnostics Complete ==="