#!/usr/bin/env python3
"""
Test script to verify Gemi's chat integration with Ollama is working correctly
"""

import requests
import json
import subprocess
import time

def test_gemi_integration():
    """Test that verifies all components needed for Gemi chat are working"""
    print("🧪 Testing Gemi Chat Integration with Ollama")
    print("=" * 50)
    
    base_url = "http://localhost:11434"
    
    # Test 1: Verify Ollama is running
    print("\n1. Checking Ollama server...")
    try:
        response = requests.get(f"{base_url}/api/tags", timeout=5)
        if response.status_code == 200:
            print("✅ Ollama server is running")
        else:
            print("❌ Ollama server not responding correctly")
            return False
    except Exception as e:
        print(f"❌ Cannot connect to Ollama: {e}")
        print("   Please start Ollama with: ollama serve")
        return False
    
    # Test 2: Verify required models
    print("\n2. Checking required models...")
    models = response.json().get('models', [])
    model_names = [m['name'] for m in models]
    
    required_models = {
        'chat': ['gemma3n:latest', 'gemma3n'],
        'embedding': ['nomic-embed-text', 'nomic-embed-text:latest']
    }
    
    chat_ok = any(model in model_names for model in required_models['chat'])
    embedding_ok = any(model in model_names for model in required_models['embedding'])
    
    if chat_ok:
        print("✅ Chat model (gemma3n) is installed")
    else:
        print("❌ Chat model not found. Install with: ollama pull gemma3n:latest")
        
    if embedding_ok:
        print("✅ Embedding model is installed")
    else:
        print("❌ Embedding model not found. Install with: ollama pull nomic-embed-text")
    
    if not (chat_ok and embedding_ok):
        return False
    
    # Test 3: Test chat generation with Gemi's system prompt
    print("\n3. Testing chat with Gemi personality...")
    test_prompt = """You are Gemi, a warm and empathetic AI diary companion. You help people reflect on their thoughts, feelings, and experiences in a supportive and non-judgmental way.

Your friend writes: "I'm having a great day today! The sun is shining and I feel optimistic."

Respond as Gemi with warmth and empathy, keeping the conversation natural and supportive."""
    
    chat_model = next((m for m in model_names if 'gemma3n' in m), None)
    if chat_model:
        try:
            data = {
                "model": chat_model,
                "prompt": test_prompt,
                "stream": False,
                "options": {
                    "temperature": 0.8,
                    "num_predict": 100
                }
            }
            
            print(f"   Using model: {chat_model}")
            response = requests.post(f"{base_url}/api/generate", 
                                   json=data, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                gemi_response = result.get('response', '')
                print("✅ Gemi responded successfully!")
                print(f"\n   Gemi says: {gemi_response[:200]}...")
                
                # Check if response sounds like Gemi
                if any(word in gemi_response.lower() for word in ['wonderful', 'glad', 'happy', 'feel', 'sunshine', 'joy']):
                    print("\n✅ Response matches Gemi's warm personality")
                else:
                    print("\n⚠️  Response may not match Gemi's personality")
            else:
                print(f"❌ Generation failed: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Error testing chat: {e}")
            return False
    
    # Test 4: Test embedding generation
    print("\n4. Testing embedding generation...")
    try:
        data = {
            "model": "nomic-embed-text",
            "prompt": "Today was a wonderful day"
        }
        
        response = requests.post(f"{base_url}/api/embeddings", 
                               json=data, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            embedding = result.get('embedding', [])
            print(f"✅ Embedding generation works (dimension: {len(embedding)})")
        else:
            print(f"❌ Embedding generation failed: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Error testing embeddings: {e}")
        return False
    
    # Test 5: Summary
    print("\n" + "=" * 50)
    print("📊 INTEGRATION TEST SUMMARY")
    print("=" * 50)
    print("\n✅ All tests passed! Gemi's chat integration is ready.")
    print("\nTo use chat in Gemi:")
    print("1. Ensure Ollama is running: ollama serve")
    print("2. Launch Gemi app")
    print("3. Click 'Chat with Gemi' or press Cmd+T")
    print("4. Start chatting with your AI diary companion!")
    
    return True

if __name__ == "__main__":
    success = test_gemi_integration()
    exit(0 if success else 1)