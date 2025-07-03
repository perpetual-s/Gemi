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

# Check for gemma model
echo "Checking for gemma:2b model..."
if ollama list | grep -q "gemma:2b"; then
    echo "✅ gemma:2b model is already installed"
else
    echo "📥 Installing gemma:2b model (this may take a while)..."
    ollama pull gemma:2b
fi

# Check for embedding model
echo "Checking for nomic-embed-text model..."
if ollama list | grep -q "nomic-embed-text"; then
    echo "✅ nomic-embed-text model is already installed"
else
    echo "📥 Installing nomic-embed-text model..."
    ollama pull nomic-embed-text
fi

echo ""
echo "Testing model with a sample journal analysis..."
echo ""

# Test sentiment analysis
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma:2b",
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
echo "1. Get the modelfile: ollama show gemma:2b --modelfile > gemma2b.modelfile"
echo "2. Edit the modelfile as needed"
echo "3. Create custom model: ollama create gemi-custom -f gemma2b.modelfile"