#!/usr/bin/env python3
"""
Test script to verify Ollama chat functionality works after fixes
"""

import requests
import json

def test_chat():
    """Test the chat functionality with various model names"""
    base_url = "http://localhost:11434"
    
    print("🧪 Testing Ollama Chat Functionality")
    print("=" * 40)
    
    # Test 1: List models
    print("\n1. Listing available models...")
    try:
        response = requests.get(f"{base_url}/api/tags")
        if response.status_code == 200:
            models = response.json().get('models', [])
            print("✅ Available models:")
            for model in models:
                print(f"   - {model['name']}")
        else:
            print(f"❌ Failed to list models: {response.status_code}")
            return
    except Exception as e:
        print(f"❌ Error: {e}")
        return
    
    # Test 2: Test with gemma3n:latest
    print("\n2. Testing chat with gemma3n:latest...")
    test_model_chat("gemma3n:latest")
    
    # Test 3: Test with gemma3n (without :latest)
    print("\n3. Testing chat with gemma3n (no tag)...")
    test_model_chat("gemma3n")
    
    # Test 4: Test embedding with both formats
    print("\n4. Testing embeddings...")
    test_embeddings("nomic-embed-text:latest")
    test_embeddings("nomic-embed-text")
    
    print("\n✅ All tests completed!")

def test_model_chat(model_name):
    """Test chat generation with a specific model"""
    try:
        data = {
            "model": model_name,
            "prompt": "Hello! Please respond with just 'Hi there!'",
            "stream": False,
            "options": {
                "temperature": 0.1,
                "num_predict": 20
            }
        }
        
        response = requests.post("http://localhost:11434/api/generate", 
                               json=data, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Model '{model_name}' works!")
            print(f"   Response: {result.get('response', '')[:50]}")
        else:
            print(f"❌ Model '{model_name}' failed: {response.status_code}")
            print(f"   Error: {response.text[:200]}")
    except Exception as e:
        print(f"❌ Error testing '{model_name}': {e}")

def test_embeddings(model_name):
    """Test embedding generation"""
    try:
        data = {
            "model": model_name,
            "prompt": "Hello world"
        }
        
        response = requests.post("http://localhost:11434/api/embeddings", 
                               json=data, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            embedding = result.get('embedding', [])
            print(f"✅ Embedding model '{model_name}' works!")
            print(f"   Dimension: {len(embedding)}")
        else:
            print(f"❌ Embedding '{model_name}' failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Error testing embeddings: {e}")

if __name__ == "__main__":
    test_chat()