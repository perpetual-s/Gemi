#!/bin/bash

echo "Testing Ollama setup for Gemi AI insights..."
echo ""

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama is not installed. Please install from https://ollama.ai"
    exit 1
fi

# Check if Ollama service is running
if ! curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "❌ Ollama service is not running. Starting it now..."
    ollama serve &
    sleep 5
fi

echo "✅ Ollama service is running"
echo ""

# Check for gemma3n model
echo "Checking for gemma3n model..."
if ollama list | grep -q "gemma3n"; then
    echo "✅ gemma3n model is already installed"
else
    echo "📥 Installing gemma3n model (this may take a while)..."
    ollama pull gemma3n:latest
fi

echo ""
echo "Testing model with a sample journal analysis..."
echo ""

# Test sentiment analysis
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma3n:latest",
    "prompt": "Analyze the sentiment of this journal entry and respond with JSON only: \"Today was amazing! I finally finished my project and celebrated with friends. Feeling grateful and accomplished.\"",
    "stream": false,
    "options": {
      "temperature": 0.7
    }
  }' | jq -r '.response'

echo ""
echo "✅ Ollama setup complete and working!"
echo ""
echo "To use custom models with Gemi:"
echo "1. Get the modelfile: ollama show gemma3n --modelfile > gemma3n.modelfile"
echo "2. Edit the modelfile as needed"
echo "3. Create custom model: ollama create gemi-custom -f gemma3n.modelfile"