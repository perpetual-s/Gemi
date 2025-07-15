#!/bin/bash
# Launch script for Gemi Inference Server using UV
# This provides a more reliable alternative to PyInstaller

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set environment variables
export PYTORCH_ENABLE_MPS_FALLBACK=1
export TOKENIZERS_PARALLELISM=false
export HF_HUB_DISABLE_SYMLINKS_WARNING=1
export TRANSFORMERS_OFFLINE=0

# Set model cache directory
export HF_HOME="$HOME/Library/Application Support/Gemi/Models"
export TRANSFORMERS_CACHE="$HF_HOME"
export TORCH_HOME="$HF_HOME"

# Create cache directory if it doesn't exist
mkdir -p "$HF_HOME"

# Change to script directory
cd "$SCRIPT_DIR"

# Check if UV is available
if command -v uv &> /dev/null; then
    echo "Starting Gemi Server with UV..."
    exec uv run python inference_server.py "$@"
else
    echo "UV not found, trying Python directly..."
    exec python3 inference_server.py "$@"
fi