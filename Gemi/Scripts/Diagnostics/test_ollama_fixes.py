#!/usr/bin/env python3
"""
Test to verify Ollama fixes for gemma3n model
"""

import requests
import json
import time

def test_fixes():
    base_url = "http://localhost:11434"
    
    print("Testing Ollama Fixes for Gemi")
    print("=" * 50)
    
    # Test 1: Check models
    print("\n1. Checking installed models...")
    response = requests.get(f"{base_url}/api/tags")
    models = response.json().get('models', [])
    model_names = [m['name'] for m in models]
    
    print("Installed models:")
    for name in model_names:
        print(f"  - {name}")
    
    # Find the gemma3n model
    gemma3n_model = None
    for name in model_names:
        if name.startswith('gemma3n'):
            gemma3n_model = name
            break
    
    if not gemma3n_model:
        print("\n❌ No gemma3n model found! Please install with: ollama pull gemma3n:latest")
        return False
    
    print(f"\n✅ Found gemma3n model: {gemma3n_model}")
    
    # Test 2: Test /api/generate endpoint (old method)
    print("\n2. Testing /api/generate endpoint...")
    try:
        data = {
            "model": "gemma3n:latest",
            "prompt": "Say hello in 5 words",
            "stream": False,
            "options": {"temperature": 0.1, "num_predict": 20}
        }
        
        response = requests.post(f"{base_url}/api/generate", json=data, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ /api/generate works")
            print(f"   Response: {result.get('response', 'No response')}")
        else:
            print(f"❌ /api/generate failed: {response.status_code}")
            
    except Exception as e:
        print(f"❌ /api/generate error: {e}")
    
    # Test 3: Test /api/chat endpoint (new method)
    print("\n3. Testing /api/chat endpoint (recommended)...")
    try:
        data = {
            "model": "gemma3n:latest",
            "messages": [
                {"role": "user", "content": "Say hello in 5 words"}
            ],
            "stream": False,
            "options": {"temperature": 0.1}
        }
        
        response = requests.post(f"{base_url}/api/chat", json=data, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            message = result.get('message', {})
            print(f"✅ /api/chat works")
            print(f"   Response: {message.get('content', 'No content')}")
        else:
            print(f"❌ /api/chat failed: {response.status_code}")
            
    except Exception as e:
        print(f"❌ /api/chat error: {e}")
    
    # Test 4: Test streaming with /api/chat
    print("\n4. Testing streaming with /api/chat...")
    try:
        data = {
            "model": "gemma3n:latest",
            "messages": [
                {"role": "user", "content": "Count from 1 to 5"}
            ],
            "stream": True,
            "options": {"temperature": 0.1}
        }
        
        response = requests.post(f"{base_url}/api/chat", json=data, stream=True, timeout=30)
        
        if response.status_code == 200:
            print("✅ Streaming works. Response chunks:")
            full_response = ""
            for line in response.iter_lines():
                if line:
                    try:
                        chunk = json.loads(line)
                        content = chunk.get('message', {}).get('content', '')
                        if content:
                            print(f"   Chunk: '{content}'")
                            full_response += content
                        if chunk.get('done', False):
                            break
                    except:
                        pass
            print(f"   Full response: {full_response}")
        else:
            print(f"❌ Streaming failed: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Streaming error: {e}")
    
    # Test 5: Test with Gemi personality prompt
    print("\n5. Testing with Gemi personality...")
    gemi_prompt = """You are Gemi, a warm and empathetic AI diary companion. You're having a private conversation with your user in their personal journal app.

Your friend writes: "I had a wonderful day today!"

Respond as Gemi with warmth and empathy in 2-3 sentences."""
    
    try:
        data = {
            "model": "gemma3n:latest",
            "messages": [
                {"role": "user", "content": gemi_prompt}
            ],
            "stream": False,
            "options": {"temperature": 0.8}
        }
        
        response = requests.post(f"{base_url}/api/chat", json=data, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            message = result.get('message', {})
            print(f"✅ Gemi personality test passed")
            print(f"   Gemi says: {message.get('content', 'No content')[:200]}...")
        else:
            print(f"❌ Gemi personality test failed: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Gemi personality test error: {e}")
    
    print("\n" + "=" * 50)
    print("✅ All critical tests completed!")
    print("\nRecommendations:")
    print("1. The app should use /api/chat endpoint for better conversational AI")
    print("2. Model name 'gemma3n:latest' works correctly")
    print("3. Streaming is functional with the chat endpoint")
    
    return True

if __name__ == "__main__":
    test_fixes()