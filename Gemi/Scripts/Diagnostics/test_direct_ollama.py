#!/usr/bin/env python3
"""
Direct test of Ollama connectivity
"""

import requests
import json

def test_direct():
    base_url = "http://localhost:11434"
    
    print("Testing direct Ollama connection...")
    
    # Test 1: Basic connectivity
    try:
        response = requests.get(f"{base_url}/api/tags", timeout=5)
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text[:200]}...")
        
        if response.status_code == 200:
            models = response.json().get('models', [])
            print(f"\nFound {len(models)} models:")
            for model in models:
                print(f"  - {model['name']}")
    except Exception as e:
        print(f"Error: {e}")
        return
    
    # Test 2: Test with gemma3n
    print("\nTesting chat with gemma3n:latest...")
    try:
        data = {
            "model": "gemma3n:latest",
            "prompt": "Say hello",
            "stream": False,
            "options": {
                "temperature": 0.1,
                "num_predict": 10
            }
        }
        
        response = requests.post(f"{base_url}/api/generate", 
                               json=data, timeout=30)
        
        print(f"Status code: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"Response: {result.get('response', 'No response')}")
        else:
            print(f"Error: {response.text}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_direct()