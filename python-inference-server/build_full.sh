#!/bin/bash
# Build script for full Gemi Server with ML dependencies

set -e  # Exit on error

echo "Building Full Gemi Server with ML Support..."
echo "==========================================="

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build dist __pycache__ *.pyc server_output.log

# Make sure minimal mode flag is NOT present
rm -f minimal_mode.flag

# Build with PyInstaller
echo "Running PyInstaller for full server..."
echo "This may take several minutes due to ML dependencies..."
pyinstaller gemi-server-fixed.spec --clean --log-level=INFO

# Check if build succeeded
if [ -d "dist/GemiServer.app" ]; then
    echo ""
    echo "Build succeeded! App bundle created at: dist/GemiServer.app"
    echo ""
    
    # Check bundle size
    echo "Bundle statistics:"
    echo "=================="
    total_size=$(du -sh dist/GemiServer.app | cut -f1)
    echo "Total bundle size: $total_size"
    
    # Check key components
    echo ""
    echo "Checking key components:"
    if [ -f "dist/GemiServer.app/Contents/Resources/base_library.zip" ]; then
        size=$(du -h "dist/GemiServer.app/Contents/Resources/base_library.zip" | cut -f1)
        echo "✓ base_library.zip: $size"
    fi
    
    if [ -d "dist/GemiServer.app/Contents/Frameworks" ]; then
        frameworks_size=$(du -sh dist/GemiServer.app/Contents/Frameworks | cut -f1)
        echo "✓ Frameworks: $frameworks_size"
    fi
    
    # Test PyTorch presence
    if find dist/GemiServer.app -name "libtorch*.dylib" -o -name "libc10*.dylib" | head -1 > /dev/null; then
        echo "✓ PyTorch libraries found"
    else
        echo "⚠️  Warning: PyTorch libraries may be missing"
    fi
    
    # Check for transformers
    if find dist/GemiServer.app -path "*/transformers/*" | head -1 > /dev/null; then
        echo "✓ Transformers package found"
    else
        echo "⚠️  Warning: Transformers package may be missing"
    fi
    
    echo ""
    echo "Next steps:"
    echo "1. Test the server: ./dist/GemiServer.app/Contents/MacOS/GemiServer"
    echo "2. Check health: curl http://127.0.0.1:11435/api/health"
    echo "3. If successful, integrate with Gemi app"
    
else
    echo "ERROR: Build failed! Check the output above for errors."
    exit 1
fi