#!/bin/bash
# Script to copy .env file to app bundle during build
# This ensures HuggingFace token is available for model downloads

set -e

echo "🔧 Copying .env file to app bundle..."

# Get the path to the .env file (one level up from Gemi directory)
ENV_FILE="${PROJECT_DIR}/../.env"

# Check if .env file exists
if [ -f "$ENV_FILE" ]; then
    # Copy to the app bundle's Resources folder
    cp "$ENV_FILE" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/"
    echo "✅ .env file copied successfully to app bundle"
    
    # Verify the copy
    if [ -f "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/.env" ]; then
        echo "✅ Verified: .env file is in the app bundle"
    else
        echo "❌ Warning: .env file copy verification failed"
        exit 1
    fi
else
    echo "⚠️ Warning: .env file not found at $ENV_FILE"
    echo "⚠️ Model downloads may fail without HuggingFace token"
    # Don't fail the build, but warn the developer
fi

echo "🔧 .env build phase completed"