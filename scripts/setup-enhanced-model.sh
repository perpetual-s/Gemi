#!/bin/bash

# Script to create and use the enhanced Gemi model

echo "🚀 Setting up enhanced Gemi model..."

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/generate > /dev/null 2>&1; then
    echo "❌ Ollama is not running. Please start Ollama first."
    exit 1
fi

# Check if gemma3n:latest exists
if ! ollama list | grep -q "gemma3n:latest"; then
    echo "❌ gemma3n:latest model not found. Please install it first with:"
    echo "   ollama pull gemma3n:latest"
    exit 1
fi

# Create the enhanced model
echo "📦 Creating enhanced Gemi model..."
ollama create gemi-enhanced -f /Users/chaeho/Documents/project-Gemi/Documentation/gemi-enhanced-modelfile.md

if [ $? -eq 0 ]; then
    echo "✅ Enhanced model created successfully!"
    echo ""
    echo "To use the enhanced model in Gemi:"
    echo "1. Update the model name in code to 'gemi-enhanced'"
    echo "2. Or run: ollama cp gemi-enhanced gemma3n:latest"
    echo ""
    echo "Test the model with:"
    echo "   ollama run gemi-enhanced"
else
    echo "❌ Failed to create enhanced model"
    exit 1
fi