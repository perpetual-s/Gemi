#!/bin/bash
# Build script for minimal test server
# This helps verify PyInstaller bundle works before adding ML dependencies

set -e  # Exit on error

echo "Building Gemi Minimal Test Server..."
echo "=================================="

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build dist __pycache__ *.pyc

# Create minimal mode flag
touch minimal_mode.flag

# Build with PyInstaller
echo "Running PyInstaller..."
pyinstaller gemi-server-fixed.spec --clean --log-level=INFO

# Remove minimal mode flag
rm -f minimal_mode.flag

# Check if build succeeded
if [ -d "dist/GemiServer.app" ]; then
    echo ""
    echo "Build succeeded! App bundle created at: dist/GemiServer.app"
    echo ""
    
    # Check bundle contents
    echo "Checking bundle contents..."
    echo "- Checking for base_library.zip..."
    if [ -f "dist/GemiServer.app/Contents/Resources/base_library.zip" ]; then
        echo "  ✓ base_library.zip found"
        # Check size
        size=$(du -h "dist/GemiServer.app/Contents/Resources/base_library.zip" | cut -f1)
        echo "  Size: $size"
        
        # Check for encodings module
        if unzip -l "dist/GemiServer.app/Contents/Resources/base_library.zip" | grep -q "encodings/__init__"; then
            echo "  ✓ encodings module found in base_library.zip"
        else
            echo "  ✗ WARNING: encodings module NOT found in base_library.zip"
        fi
    else
        echo "  ✗ ERROR: base_library.zip NOT found!"
    fi
    
    echo ""
    echo "Testing the minimal server..."
    echo "============================="
    
    # Test the executable
    echo "1. Testing direct execution..."
    "./dist/GemiServer.app/Contents/MacOS/GemiServer" --version 2>&1 | head -5 || true
    
    echo ""
    echo "To test the server:"
    echo "  1. Run: ./dist/GemiServer.app/Contents/MacOS/GemiServer"
    echo "  2. In another terminal: curl http://127.0.0.1:11435/api/health"
    echo "  3. Check imports: curl http://127.0.0.1:11435/api/test-imports"
    
else
    echo "ERROR: Build failed! Check the output above for errors."
    exit 1
fi