#!/usr/bin/env python3
"""
Test to identify model name mismatch issues
"""

import requests
import json

def test_model_variations():
    base_url = "http://localhost:11434"
    
    print("Testing model name variations...")
    print("=" * 50)
    
    # Get installed models
    response = requests.get(f"{base_url}/api/tags")
    models = response.json().get('models', [])
    print("\nInstalled models:")
    for model in models:
        print(f"  - {model['name']}")
    
    # Test different model name variations
    test_names = [
        "gemma3n",
        "gemma3n:latest", 
        "gemma3n:e2b",
        "gemma:3n",
        "gemma:2b"
    ]
    
    print("\nTesting model name variations:")
    for model_name in test_names:
        try:
            data = {
                "model": model_name,
                "prompt": "Hello",
                "stream": False,
                "options": {"temperature": 0.1, "num_predict": 5}
            }
            
            response = requests.post(f"{base_url}/api/generate", 
                                   json=data, timeout=10)
            
            if response.status_code == 200:
                print(f"✅ {model_name}: SUCCESS")
            else:
                error = response.json().get('error', 'Unknown error')
                print(f"❌ {model_name}: FAILED - {error}")
                
        except Exception as e:
            print(f"❌ {model_name}: ERROR - {e}")
    
    # Test chat endpoint
    print("\n\nTesting /api/chat endpoint:")
    try:
        data = {
            "model": "gemma3n:e2b",
            "messages": [
                {"role": "user", "content": "Hello"}
            ],
            "stream": False
        }
        
        response = requests.post(f"{base_url}/api/chat", 
                               json=data, timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Chat endpoint works!")
            print(f"   Response: {result.get('message', {}).get('content', 'No content')}")
        else:
            print(f"❌ Chat endpoint failed: {response.status_code}")
            print(f"   Error: {response.text}")
            
    except Exception as e:
        print(f"❌ Chat endpoint error: {e}")

if __name__ == "__main__":
    test_model_variations()