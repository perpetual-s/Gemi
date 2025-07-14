#!/bin/bash
# Copy GemiServer.app to Resources if it exists
SERVER_SOURCE="${PROJECT_DIR}/../python-inference-server/dist/GemiServer.app"
SERVER_DEST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GemiServer.app"

if [ -d "$SERVER_SOURCE" ]; then
    echo "Copying GemiServer.app to bundle..."
    rm -rf "$SERVER_DEST"
    cp -R "$SERVER_SOURCE" "$SERVER_DEST"
    echo "GemiServer.app bundled successfully"
else
    echo "Warning: GemiServer.app not found at $SERVER_SOURCE"
fi
