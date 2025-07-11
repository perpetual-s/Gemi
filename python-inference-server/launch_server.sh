#!/bin/bash
# Gemi Inference Server Launcher - UV Edition
# This script uses UV for ultra-fast Python package management

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🚀 Gemi AI Server (UV Edition)"
echo "=============================="

# Check if UV is installed
check_uv() {
    # Add UV's default installation directory to PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    # Check common UV installation paths
    UV_PATHS=(
        "$HOME/.local/bin/uv"
        "/usr/local/bin/uv"
        "/opt/homebrew/bin/uv"
        "$HOME/.cargo/bin/uv"
        "/usr/bin/uv"
    )
    
    # Check if UV is in PATH
    if command -v uv &> /dev/null; then
        UV_CMD="uv"
        echo "✓ Found UV in PATH: $(which uv)"
        return 0
    fi
    
    # Check known locations
    for path in "${UV_PATHS[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            UV_CMD="$path"
            echo "✓ Found UV at: $path"
            return 0
        fi
    done
    
    echo "❌ UV not found!"
    echo ""
    echo "Please install UV first:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo ""
    echo "After installation, run this script again."
    exit 1
}

# Sync dependencies with UV
sync_dependencies() {
    echo "📦 Syncing dependencies with UV..."
    echo "   This is MUCH faster than pip!"
    
    cd "$SCRIPT_DIR"
    
    # UV automatically manages the virtual environment
    $UV_CMD sync
    
    echo "✓ Dependencies synced successfully"
}

# Check hardware acceleration
check_hardware() {
    echo "🖥️ Checking hardware acceleration..."
    
    $UV_CMD run python -c "
import torch
if torch.backends.mps.is_available():
    print('✓ Metal Performance Shaders (MPS) available - GPU acceleration enabled')
elif torch.cuda.is_available():
    print('✓ CUDA available - GPU acceleration enabled')
else:
    print('⚠️  No GPU acceleration available - using CPU (slower performance)')
"
}

# Model information
model_info() {
    echo ""
    echo "📊 Model Information"
    echo "===================="
    echo "Model: google/gemma-3n-e4b-it"
    echo "Parameters: 4B (runs like 2B thanks to MatFormer)"
    echo "Features: Text + Images + Audio + Video"
    echo ""
    
    # Check if model is cached
    CACHE_DIR="$HOME/.cache/huggingface/hub"
    if [ -d "$CACHE_DIR" ] && find "$CACHE_DIR" -name "*gemma-3n-e4b*" -type d | grep -q .; then
        echo "✓ Model appears to be cached locally"
    else
        echo "⚠️  First run will download the model (~8GB)"
        echo "   This is a one-time download (10-30 minutes)"
        echo "   Subsequent launches will be instant!"
    fi
    echo ""
}

# Launch the server
launch_server() {
    echo "🚀 Starting Gemi Inference Server..."
    echo "===================================="
    echo "Server URL: http://127.0.0.1:11435"
    echo "Press Ctrl+C to stop the server"
    echo ""
    
    # Set environment variables
    export PYTORCH_ENABLE_MPS_FALLBACK=1
    export TOKENIZERS_PARALLELISM=false
    export HF_HUB_DISABLE_SYMLINKS_WARNING=1
    export HF_HOME="${HF_HOME:-$HOME/.cache/huggingface}"
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    # Run with UV - no activation needed!
    echo "Starting server with UV..."
    $UV_CMD run python inference_server.py
}

# Cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down Gemi AI Server..."
    echo "Thank you for using Gemi!"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main execution flow
main() {
    echo "UV-powered setup - 10-100x faster than pip! 🚄"
    echo ""
    
    check_uv
    sync_dependencies
    check_hardware
    model_info
    launch_server
}

# Run main function
main