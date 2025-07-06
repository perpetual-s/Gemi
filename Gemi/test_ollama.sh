#!/bin/bash

echo "Testing Ollama startup..."

# Check if Ollama is installed
echo "1. Checking if Ollama is installed:"
which ollama
if [ $? -eq 0 ]; then
    echo "   ✓ Ollama found at: $(which ollama)"
else
    echo "   ✗ Ollama not found in PATH"
fi

# Check for Ollama.app
echo ""
echo "2. Checking for Ollama.app:"
if [ -d "/Applications/Ollama.app" ]; then
    echo "   ✓ Ollama.app found at /Applications/Ollama.app"
else
    echo "   ✗ Ollama.app not found"
fi

# Check if Ollama is already running
echo ""
echo "3. Checking if Ollama is already running:"
lsof -i :11434 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ Something is already running on port 11434"
else
    echo "   ✗ Port 11434 is free"
fi

# Check Ollama processes
echo ""
echo "4. Checking for existing Ollama processes:"
ps aux | grep -i ollama | grep -v grep

# Try to get Ollama version
echo ""
echo "5. Ollama version:"
ollama --version 2>&1

# Try to run ollama serve with debug
echo ""
echo "6. Testing 'ollama serve' command with debug:"
echo "   Running: OLLAMA_DEBUG=1 ollama serve"
echo "   (Press Ctrl+C to stop)"
echo ""
OLLAMA_DEBUG=1 ollama serve