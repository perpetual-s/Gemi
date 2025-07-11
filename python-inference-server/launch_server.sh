#!/bin/bash
# Gemi Inference Server Launcher
# This script sets up the Python environment and launches the inference server

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VENV_DIR="$SCRIPT_DIR/venv"
PYTHON_VERSION="3.9"

echo "🚀 Gemi Inference Server Launcher"
echo "================================"

# Check Python version
check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        echo "❌ Error: Python not found. Please install Python $PYTHON_VERSION or later."
        exit 1
    fi
    
    # Verify Python version
    PYTHON_VERSION_CHECK=$($PYTHON_CMD -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    echo "✓ Found Python $PYTHON_VERSION_CHECK"
}

# Create virtual environment if it doesn't exist
setup_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        echo "📦 Creating virtual environment..."
        $PYTHON_CMD -m venv "$VENV_DIR"
        echo "✓ Virtual environment created"
    else
        echo "✓ Virtual environment already exists"
    fi
}

# Activate virtual environment
activate_venv() {
    echo "🔧 Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
    echo "✓ Virtual environment activated"
}

# Install/update dependencies
install_dependencies() {
    echo "📥 Checking dependencies..."
    
    # Upgrade pip first
    pip install --upgrade pip > /dev/null 2>&1
    
    # Check if requirements are already installed
    if pip show torch transformers fastapi > /dev/null 2>&1; then
        echo "✓ Core dependencies already installed"
        
        # Check if we need to update
        if [ -f "$SCRIPT_DIR/.last_requirements_hash" ]; then
            CURRENT_HASH=$(shasum -a 256 "$SCRIPT_DIR/requirements.txt" | cut -d' ' -f1)
            LAST_HASH=$(cat "$SCRIPT_DIR/.last_requirements_hash" 2>/dev/null || echo "")
            
            if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
                echo "📦 Requirements changed, updating..."
                pip install -r "$SCRIPT_DIR/requirements.txt"
                echo "$CURRENT_HASH" > "$SCRIPT_DIR/.last_requirements_hash"
            fi
        else
            # First run, save hash
            shasum -a 256 "$SCRIPT_DIR/requirements.txt" | cut -d' ' -f1 > "$SCRIPT_DIR/.last_requirements_hash"
        fi
    else
        echo "📦 Installing dependencies (this may take a few minutes)..."
        pip install -r "$SCRIPT_DIR/requirements.txt"
        shasum -a 256 "$SCRIPT_DIR/requirements.txt" | cut -d' ' -f1 > "$SCRIPT_DIR/.last_requirements_hash"
        echo "✓ Dependencies installed"
    fi
}

# Check MPS availability
check_mps() {
    echo "🖥️ Checking hardware acceleration..."
    python -c "
import torch
if torch.backends.mps.is_available():
    print('✓ Metal Performance Shaders (MPS) available - GPU acceleration enabled')
elif torch.cuda.is_available():
    print('✓ CUDA available - GPU acceleration enabled')
else:
    print('⚠️  No GPU acceleration available - using CPU (slower performance)')
"
}

# Model download notice
model_notice() {
    echo ""
    echo "📊 Model Information"
    echo "===================="
    echo "Model: google/gemma-3n-e4b-it (4B parameters)"
    echo "Size: ~8GB download on first run"
    echo ""
    
    # Check if model is already cached
    CACHE_DIR="$HOME/.cache/huggingface/hub"
    if [ -d "$CACHE_DIR" ] && find "$CACHE_DIR" -name "*gemma-3n-e4b*" -type d | grep -q .; then
        echo "✓ Model appears to be cached"
    else
        echo "⚠️  First run will download the model (~8GB)"
        echo "   This is a one-time download that may take 10-30 minutes"
        echo "   The model will be cached for future use"
    fi
    echo ""
}

# Launch server
launch_server() {
    echo "🚀 Starting Gemi Inference Server..."
    echo "===================================="
    echo "Server will be available at: http://127.0.0.1:11435"
    echo "Press Ctrl+C to stop the server"
    echo ""
    
    # Set environment variables
    export PYTORCH_ENABLE_MPS_FALLBACK=1
    export TOKENIZERS_PARALLELISM=false
    export HF_HUB_DISABLE_SYMLINKS_WARNING=1
    
    # Run the server
    cd "$SCRIPT_DIR"
    python inference_server.py
}

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Shutting down server..."
    # Deactivate virtual environment if active
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        deactivate 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    check_python
    setup_venv
    activate_venv
    install_dependencies
    check_mps
    model_notice
    launch_server
}

# Run main function
main