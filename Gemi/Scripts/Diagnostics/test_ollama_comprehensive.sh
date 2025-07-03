#!/bin/bash

echo "=== Comprehensive Ollama Diagnostic Test ==="
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Check if Ollama is installed
echo "1. Checking Ollama installation..."
if command_exists ollama; then
    echo "✅ Ollama is installed"
    echo "   Version: $(ollama --version 2>/dev/null || echo 'version command not available')"
else
    echo "❌ Ollama is NOT installed"
    echo "   Please install from: https://ollama.ai"
    exit 1
fi
echo ""

# 2. Check if Ollama service is running
echo "2. Checking Ollama service..."
if curl -s -f http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "✅ Ollama service is running on port 11434"
else
    echo "❌ Ollama service is NOT running"
    echo "   Attempting to start Ollama..."
    
    # Try to start Ollama in background
    nohup ollama serve >/tmp/ollama.log 2>&1 &
    OLLAMA_PID=$!
    echo "   Started Ollama with PID: $OLLAMA_PID"
    
    # Wait for service to start
    echo -n "   Waiting for service to start"
    for i in {1..10}; do
        sleep 1
        echo -n "."
        if curl -s -f http://localhost:11434/api/tags >/dev/null 2>&1; then
            echo ""
            echo "✅ Ollama service started successfully!"
            break
        fi
    done
    echo ""
fi
echo ""

# 3. List installed models
echo "3. Checking installed models..."
MODELS=$(curl -s http://localhost:11434/api/tags | jq -r '.models[]?.name' 2>/dev/null)
if [ -z "$MODELS" ]; then
    echo "❌ No models found or unable to list models"
else
    echo "✅ Installed models:"
    echo "$MODELS" | while read -r model; do
        echo "   - $model"
    done
fi
echo ""

# 4. Check for required models
echo "4. Checking required models for Gemi..."
REQUIRED_MODELS=("gemma:2b" "nomic-embed-text")
MISSING_MODELS=()

for model in "${REQUIRED_MODELS[@]}"; do
    if echo "$MODELS" | grep -q "^$model"; then
        echo "✅ $model is installed"
    else
        echo "❌ $model is NOT installed"
        MISSING_MODELS+=("$model")
    fi
done
echo ""

# 5. Install missing models
if [ ${#MISSING_MODELS[@]} -gt 0 ]; then
    echo "5. Installing missing models..."
    for model in "${MISSING_MODELS[@]}"; do
        echo "Installing $model..."
        ollama pull "$model"
        if [ $? -eq 0 ]; then
            echo "✅ Successfully installed $model"
        else
            echo "❌ Failed to install $model"
        fi
    done
else
    echo "5. All required models are installed ✅"
fi
echo ""

# 6. Test API endpoints
echo "6. Testing Ollama API endpoints..."

# Test /api/tags
echo -n "   Testing /api/tags endpoint... "
if curl -s -f http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED"
fi

# Test /api/generate with a simple prompt
echo -n "   Testing /api/generate endpoint... "
RESPONSE=$(curl -s -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gemma:2b",
        "prompt": "Hello",
        "stream": false,
        "options": {"temperature": 0.1, "num_predict": 10}
    }' 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
    echo "✅ OK"
    echo "      Sample response: $(echo "$RESPONSE" | jq -r '.response' 2>/dev/null | head -c 50)..."
else
    echo "❌ FAILED"
fi
echo ""

# 7. Test from Swift
echo "7. Testing connection from Swift..."
if [ -f "/Users/chaeho/Documents/project-Gemi/Gemi/Scripts/Diagnostics/debug_ollama_connection.swift" ]; then
    swift /Users/chaeho/Documents/project-Gemi/Gemi/Scripts/Diagnostics/debug_ollama_connection.swift
else
    echo "❌ Swift test script not found"
fi
echo ""

# 8. Summary
echo "=== SUMMARY ==="
if curl -s -f http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "✅ Ollama is properly configured and running"
    echo ""
    echo "If Gemi still shows 'server not running' error:"
    echo "1. Restart the Gemi app"
    echo "2. Make sure no firewall is blocking localhost:11434"
    echo "3. Check Console.app for any Swift/Network errors"
else
    echo "❌ Ollama is NOT properly configured"
    echo ""
    echo "Please:"
    echo "1. Run 'ollama serve' in Terminal"
    echo "2. Keep the Terminal window open"
    echo "3. Restart Gemi app"
fi
echo ""
echo "Log file: /tmp/ollama.log (if service was started by this script)"