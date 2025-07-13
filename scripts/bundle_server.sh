#!/bin/bash

# Bundle GemiServer.app into Gemi.app during Xcode build
# This script is called from Xcode's Run Script build phase

set -e

# Configuration - Support both Xcode and manual execution
if [ -n "${BUILT_PRODUCTS_DIR}" ]; then
    # Running from Xcode
    GEMI_APP="${BUILT_PRODUCTS_DIR}/Gemi.app"
    PROJECT_ROOT="${PROJECT_DIR}/.."
else
    # Running manually - expect Gemi.app path as first argument
    if [ -z "$1" ]; then
        echo "Usage: $0 <path-to-Gemi.app>"
        exit 1
    fi
    GEMI_APP="$1"
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Paths
RESOURCES_DIR="${GEMI_APP}/Contents/Resources"
SERVER_SOURCE="${PROJECT_ROOT}/python-inference-server/dist/GemiServer.app"
SERVER_DEST="${RESOURCES_DIR}/GemiServer.app"

echo "Bundling GemiServer.app into Gemi.app..."
echo "Source: ${SERVER_SOURCE}"
echo "Destination: ${SERVER_DEST}"

# Create Resources directory if it doesn't exist
mkdir -p "${RESOURCES_DIR}"

# Check if GemiServer.app exists
if [ ! -d "${SERVER_SOURCE}" ]; then
    echo "Error: GemiServer.app not found at ${SERVER_SOURCE}"
    echo "Please build GemiServer.app first using:"
    echo "  cd python-inference-server && ./build_app.sh"
    exit 1
fi

# Remove old server if exists
if [ -d "${SERVER_DEST}" ]; then
    echo "Removing old GemiServer.app..."
    rm -rf "${SERVER_DEST}"
fi

# Copy GemiServer.app to Resources
echo "Copying GemiServer.app to Resources..."
cp -R "${SERVER_SOURCE}" "${SERVER_DEST}"

# Verify the copy
if [ -d "${SERVER_DEST}" ]; then
    echo "Successfully bundled GemiServer.app"
    # Check size for verification
    SERVER_SIZE=$(du -sh "${SERVER_DEST}" | cut -f1)
    echo "Bundled server size: ${SERVER_SIZE}"
else
    echo "Error: Failed to bundle GemiServer.app"
    exit 1
fi

echo "GemiServer.app bundling complete!"