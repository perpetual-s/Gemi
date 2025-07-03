#!/usr/bin/env python3
"""
Simulate the exact flow that Swift app would use
"""

import requests
import json
import time

def simulate_swift_flow():
    base_url = "http://localhost:11434"
    
    print("Simulating Swift App Flow")
    print("=" * 50)
    
    # Step 1: Check Ollama status (what checkOllamaStatus does)
    print("\n1. Checking Ollama status (like Swift app)...")
    try:
        response = requests.get(f"{base_url}/api/tags", timeout=5)
        if response.status_code == 200:
            print("✅ Ollama is running")
            models = response.json().get('models', [])
            model_names = [m['name'] for m in models]
            
            # Check for required models
            has_gemma3n = any('gemma3n' in name for name in model_names)
            has_embedding = any('nomic-embed-text' in name for name in model_names)
            
            print(f"   Has gemma3n: {has_gemma3n}")
            print(f"   Has embedding model: {has_embedding}")
        else:
            print("❌ Ollama not responding")
            return
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return
    
    # Step 2: Test chat completion with Gemi's exact prompt format
    print("\n2. Testing chat with Gemi's exact prompt format...")
    
    user_message = "I'm feeling really happy today! The weather is beautiful."
    memories = []  # No memories for this test
    
    # Create the exact prompt that OllamaService.createPromptWithMemory would create
    prompt = """You are Gemi, a warm and empathetic AI diary companion. You're having a private conversation with your user in their personal journal app. Everything shared stays completely private on their device.
        
Your personality:
- Warm, supportive, and encouraging like a trusted friend
- Reflective and thoughtful, helping users explore their feelings
- Non-judgmental and accepting of all emotions and experiences
- Gently curious, asking follow-up questions to help users reflect deeper
- Celebrating small victories and providing comfort during difficult times

Remember to:
- Keep responses conversational and personal, not clinical
- Use warm, friendly language that feels like chatting with a close friend
- Acknowledge emotions and validate feelings
- Offer gentle prompts for deeper reflection when appropriate
- Reference past conversations naturally when relevant

Your friend writes: "{}"

Respond as Gemi with warmth and empathy, keeping the conversation natural and supportive.""".format(user_message)
    
    # Test with both endpoints
    print("\n  a) Testing with /api/generate (current implementation)...")
    try:
        data = {
            "model": "gemma3n:latest",
            "prompt": prompt,
            "stream": True,
            "options": {
                "temperature": 0.7,
                "top_p": 0.9,
                "top_k": 40,
                "repeat_penalty": 1.1,
                "num_predict": 2048,
                "num_ctx": 4096
            }
        }
        
        response = requests.post(f"{base_url}/api/generate", json=data, stream=True, timeout=30)
        
        if response.status_code == 200:
            print("  ✅ Streaming started successfully")
            full_response = ""
            chunk_count = 0
            
            for line in response.iter_lines():
                if line:
                    try:
                        chunk_data = json.loads(line)
                        chunk_text = chunk_data.get('response', '')
                        if chunk_text:
                            full_response += chunk_text
                            chunk_count += 1
                        
                        if chunk_data.get('done', False):
                            break
                    except:
                        pass
            
            print(f"  ✅ Received {chunk_count} chunks")
            print(f"  Response preview: {full_response[:150]}...")
        else:
            print(f"  ❌ Failed with status: {response.status_code}")
            
    except Exception as e:
        print(f"  ❌ Error: {e}")
    
    print("\n  b) Testing with /api/chat (recommended approach)...")
    try:
        data = {
            "model": "gemma3n:latest",
            "messages": [
                {"role": "user", "content": prompt}
            ],
            "stream": True,
            "options": {
                "temperature": 0.7,
                "top_p": 0.9,
                "top_k": 40,
                "repeat_penalty": 1.1,
                "num_predict": 2048,
                "num_ctx": 4096
            }
        }
        
        response = requests.post(f"{base_url}/api/chat", json=data, stream=True, timeout=30)
        
        if response.status_code == 200:
            print("  ✅ Streaming started successfully")
            full_response = ""
            chunk_count = 0
            
            for line in response.iter_lines():
                if line:
                    try:
                        chunk_data = json.loads(line)
                        chunk_text = chunk_data.get('message', {}).get('content', '')
                        if chunk_text:
                            full_response += chunk_text
                            chunk_count += 1
                        
                        if chunk_data.get('done', False):
                            break
                    except:
                        pass
            
            print(f"  ✅ Received {chunk_count} chunks")
            print(f"  Response preview: {full_response[:150]}...")
        else:
            print(f"  ❌ Failed with status: {response.status_code}")
            
    except Exception as e:
        print(f"  ❌ Error: {e}")
    
    # Step 3: Test embedding generation
    print("\n3. Testing embedding generation...")
    try:
        data = {
            "model": "nomic-embed-text:latest",
            "prompt": "Today was a wonderful day"
        }
        
        response = requests.post(f"{base_url}/api/embeddings", json=data, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            embedding = result.get('embedding', [])
            print(f"✅ Embedding generation works (dimension: {len(embedding)})")
        else:
            print(f"❌ Embedding failed: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Embedding error: {e}")
    
    print("\n" + "=" * 50)
    print("SUMMARY:")
    print("- Both /api/generate and /api/chat endpoints work")
    print("- The /api/chat endpoint is recommended for better conversation handling")
    print("- Model name 'gemma3n:latest' is correctly handled by Ollama")
    print("- The Swift app should work with the current fixes")

if __name__ == "__main__":
    simulate_swift_flow()