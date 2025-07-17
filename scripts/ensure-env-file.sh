#!/bin/bash

# Script to ensure .env file is properly included in the app bundle
# Add this as a Build Phase script in Xcode

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Ensuring .env file is included in app bundle..."

# Paths
PROJECT_ROOT="${PROJECT_DIR}/.."
ENV_FILE="${PROJECT_ROOT}/.env"
ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"
RESOURCES_DIR="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

# Function to create .env if missing
create_env_file() {
    echo -e "${YELLOW}⚠️  .env file not found. Creating from template...${NC}"
    
    # Check if we have a token in the environment (CI/CD)
    if [[ -n "${HUGGINGFACE_TOKEN}" ]]; then
        echo "HUGGINGFACE_TOKEN=${HUGGINGFACE_TOKEN}" > "${ENV_FILE}"
        echo -e "${GREEN}✅ Created .env from environment variable${NC}"
    elif [[ -f "${ENV_EXAMPLE}" ]]; then
        # Copy from example
        cp "${ENV_EXAMPLE}" "${ENV_FILE}"
        echo -e "${YELLOW}⚠️  Created .env from .env.example - PLEASE ADD YOUR TOKEN${NC}"
    else
        # Create minimal .env
        cat > "${ENV_FILE}" << EOF
# HuggingFace token for model downloads
# Get your token from: https://huggingface.co/settings/tokens
HUGGINGFACE_TOKEN=your_token_here
EOF
        echo -e "${YELLOW}⚠️  Created blank .env - PLEASE ADD YOUR TOKEN${NC}"
    fi
}

# Step 1: Check if .env exists
if [[ ! -f "${ENV_FILE}" ]]; then
    create_env_file
fi

# Step 2: Validate .env has a token
if grep -q "HUGGINGFACE_TOKEN=your_token_here" "${ENV_FILE}" 2>/dev/null; then
    echo -e "${RED}❌ ERROR: .env file has placeholder token!${NC}"
    echo -e "${RED}   Please add your actual HuggingFace token to: ${ENV_FILE}${NC}"
    echo -e "${RED}   Get a token from: https://huggingface.co/settings/tokens${NC}"
    
    # Don't fail the build for debug builds
    if [[ "${CONFIGURATION}" == "Debug" ]]; then
        echo -e "${YELLOW}⚠️  Warning: Continuing with placeholder token (Debug build)${NC}"
    else
        exit 1
    fi
fi

# Step 3: Copy .env to app bundle
echo "📁 Copying .env to app bundle..."
mkdir -p "${RESOURCES_DIR}"
cp -f "${ENV_FILE}" "${RESOURCES_DIR}/"

# Step 4: Verify copy was successful
if [[ -f "${RESOURCES_DIR}/.env" ]]; then
    echo -e "${GREEN}✅ .env file successfully included in app bundle${NC}"
    
    # Show token info (masked)
    if grep -q "HUGGINGFACE_TOKEN=" "${RESOURCES_DIR}/.env"; then
        TOKEN=$(grep "HUGGINGFACE_TOKEN=" "${RESOURCES_DIR}/.env" | cut -d'=' -f2)
        if [[ -n "${TOKEN}" ]] && [[ "${TOKEN}" != "your_token_here" ]]; then
            MASKED_TOKEN="${TOKEN:0:7}...${TOKEN: -4}"
            echo -e "${GREEN}✅ Token found: ${MASKED_TOKEN}${NC}"
        fi
    fi
else
    echo -e "${RED}❌ ERROR: Failed to copy .env to app bundle${NC}"
    exit 1
fi

# Step 5: Create a marker file for runtime verification
echo "GEMI_ENV_INCLUDED=true" > "${RESOURCES_DIR}/.env.marker"

echo -e "${GREEN}✨ .env file setup complete!${NC}"