#!/usr/bin/env python3
"""Test streaming chat API to see what's actually returned"""

import requests
import json

def test_streaming_chat():
    print("Testing Ollama streaming chat response...")
    
    # Minimal test without system prompt
    request_data = {
        "model": "gemma3n:latest",
        "messages": [
            {"role": "user", "content": "hi"}
        ],
        "stream": True,
        "options": {
            "temperature": 0.7,
            "num_predict": 100  # Limit response for testing
        }
    }
    
    try:
        response = requests.post(
            'http://localhost:11434/api/chat',
            json=request_data,
            stream=True,
            timeout=30
        )
        
        print(f"Status code: {response.status_code}")
        
        if response.status_code == 200:
            full_response = ""
            chunk_count = 0
            
            for line in response.iter_lines():
                if line:
                    chunk_count += 1
                    try:
                        data = json.loads(line)
                        content = data.get('message', {}).get('content', '')
                        full_response += content
                        
                        # Show first 10 chunks in detail
                        if chunk_count <= 10:
                            print(f"Chunk {chunk_count}: '{content}' (done: {data.get('done', False)})")
                        
                        if data.get('done', False):
                            break
                            
                    except json.JSONDecodeError as e:
                        print(f"JSON decode error: {e}")
                        print(f"Raw line: {line}")
                        
            print(f"\nTotal chunks: {chunk_count}")
            print(f"Full response: '{full_response}'")
            
        else:
            print(f"Error: {response.text}")
            
    except Exception as e:
        print(f"Exception: {e}")

if __name__ == "__main__":
    test_streaming_chat()