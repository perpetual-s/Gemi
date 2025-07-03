#!/bin/bash

# Ollama Connectivity Diagnostic Script for Gemi
# This script helps diagnose Ollama connectivity issues

echo "🔍 Ollama Connectivity Diagnostic for Gemi"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_API="http://localhost:11434"
EXPECTED_MODELS=("gemma2:2b" "gemma3n:latest" "nomic-embed-text")

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Test 1: Check if Ollama is installed
echo -e "${BLUE}1. Checking Ollama installation...${NC}"
if command_exists ollama; then
    echo -e "   ${GREEN}✅ Ollama is installed${NC}"
    OLLAMA_VERSION=$(ollama --version 2>/dev/null || echo "unknown")
    echo "   Version: $OLLAMA_VERSION"
else
    echo -e "   ${RED}❌ Ollama is not installed${NC}"
    echo "   💡 Install Ollama from: https://ollama.ai"
    echo ""
    exit 1
fi
echo ""

# Test 2: Check if Ollama server is running
echo -e "${BLUE}2. Checking if Ollama server is running...${NC}"
if curl -s -f "${OLLAMA_API}/api/tags" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Ollama server is running on ${OLLAMA_API}${NC}"
else
    echo -e "   ${RED}❌ Ollama server is not responding${NC}"
    echo "   💡 Start Ollama with: ollama serve"
    echo ""
    
    # Check if process is running but not responding
    if pgrep -x "ollama" > /dev/null; then
        echo -e "   ${YELLOW}⚠️  Ollama process found but API not responding${NC}"
        echo "   Try restarting Ollama:"
        echo "   1. Kill existing process: pkill ollama"
        echo "   2. Start fresh: ollama serve"
    fi
    exit 1
fi
echo ""

# Test 3: List installed models
echo -e "${BLUE}3. Checking installed models...${NC}"
INSTALLED_MODELS=$(curl -s "${OLLAMA_API}/api/tags" 2>/dev/null | jq -r '.models[]?.name' 2>/dev/null || echo "")

if [ -z "$INSTALLED_MODELS" ]; then
    echo -e "   ${YELLOW}⚠️  No models installed${NC}"
else
    echo "   📦 Installed models:"
    echo "$INSTALLED_MODELS" | while read -r model; do
        echo "      - $model"
    done
fi
echo ""

# Test 4: Check for required models
echo -e "${BLUE}4. Checking for required Gemi models...${NC}"
for model in "${EXPECTED_MODELS[@]}"; do
    # Check if model or base model is installed
    BASE_MODEL=$(echo "$model" | cut -d: -f1)
    if echo "$INSTALLED_MODELS" | grep -q "^${model}$\|^${BASE_MODEL}"; then
        echo -e "   ${GREEN}✅ $model - Found${NC}"
    else
        echo -e "   ${RED}❌ $model - Not found${NC}"
        echo "      💡 Install with: ollama pull $model"
    fi
done
echo ""

# Test 5: Test model generation
echo -e "${BLUE}5. Testing model generation...${NC}"
TEST_MODEL=""
for model in "gemma2:2b" "gemma3n:latest" "gemma:2b" "llama2"; do
    if echo "$INSTALLED_MODELS" | grep -q "$model"; then
        TEST_MODEL="$model"
        break
    fi
done

if [ -n "$TEST_MODEL" ]; then
    echo "   Testing with model: $TEST_MODEL"
    RESPONSE=$(curl -s -X POST "${OLLAMA_API}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$TEST_MODEL\", \"prompt\": \"Hello\", \"stream\": false}" \
        2>/dev/null | jq -r '.response' 2>/dev/null || echo "")
    
    if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ]; then
        echo -e "   ${GREEN}✅ Model generation successful${NC}"
        echo "   Response preview: ${RESPONSE:0:50}..."
    else
        echo -e "   ${RED}❌ Model generation failed${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️  No compatible model found for testing${NC}"
fi
echo ""

# Test 6: Check embeddings API
echo -e "${BLUE}6. Testing embeddings API...${NC}"
if echo "$INSTALLED_MODELS" | grep -q "nomic-embed-text"; then
    EMBED_RESPONSE=$(curl -s -X POST "${OLLAMA_API}/api/embeddings" \
        -H "Content-Type: application/json" \
        -d '{"model": "nomic-embed-text", "prompt": "test"}' \
        2>/dev/null | jq '.embedding' 2>/dev/null || echo "")
    
    if [ -n "$EMBED_RESPONSE" ] && [ "$EMBED_RESPONSE" != "null" ]; then
        echo -e "   ${GREEN}✅ Embeddings API working${NC}"
    else
        echo -e "   ${RED}❌ Embeddings API failed${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️  Embedding model not installed${NC}"
    echo "   💡 Install with: ollama pull nomic-embed-text"
fi
echo ""

# Test 7: Check port availability
echo -e "${BLUE}7. Checking port 11434...${NC}"
if lsof -i :11434 > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Port 11434 is in use (expected)${NC}"
    PROCESS_INFO=$(lsof -i :11434 | grep LISTEN | head -1)
    echo "   Process: $PROCESS_INFO"
else
    echo -e "   ${YELLOW}⚠️  Port 11434 is not in use${NC}"
fi
echo ""

# Summary and recommendations
echo -e "${BLUE}📊 Summary & Recommendations${NC}"
echo "=============================="

# Check overall status
ISSUES=0

if ! curl -s -f "${OLLAMA_API}/api/tags" > /dev/null 2>&1; then
    echo -e "${RED}❌ Critical: Ollama server not running${NC}"
    echo "   Run: ollama serve"
    ISSUES=$((ISSUES + 1))
fi

# Check for missing models
MISSING_MODELS=()
for model in "${EXPECTED_MODELS[@]}"; do
    BASE_MODEL=$(echo "$model" | cut -d: -f1)
    if ! echo "$INSTALLED_MODELS" | grep -q "^${model}$\|^${BASE_MODEL}"; then
        MISSING_MODELS+=("$model")
        ISSUES=$((ISSUES + 1))
    fi
done

if [ ${#MISSING_MODELS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Missing required models:${NC}"
    for model in "${MISSING_MODELS[@]}"; do
        echo "   - $model"
    done
    echo ""
    echo "   Install all with:"
    echo "   ollama pull gemma2:2b"
    echo "   ollama pull nomic-embed-text"
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ Everything looks good! Gemi should be able to connect to Ollama.${NC}"
else
    echo ""
    echo -e "${YELLOW}Quick fix commands:${NC}"
    echo "1. Start Ollama server:"
    echo "   ollama serve"
    echo ""
    echo "2. Install required models:"
    echo "   ollama pull gemma2:2b"
    echo "   ollama pull nomic-embed-text"
    echo ""
    echo "3. Verify installation:"
    echo "   ollama list"
    echo ""
    echo "4. Test manually:"
    echo "   curl -X POST http://localhost:11434/api/generate -d '{\"model\": \"gemma2:2b\", \"prompt\": \"Hello\", \"stream\": false}'"
fi

echo ""
echo "📝 Note: The app expects either 'gemma3n:latest' or 'gemma2:2b' as the main model"
echo "         and 'nomic-embed-text' for embeddings. gemma2:2b is recommended."