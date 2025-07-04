#!/usr/bin/env python3
"""Test the chat message structure to ensure system/user separation is working correctly."""

import requests
import json

def test_chat_with_proper_messages():
    """Test chat API with properly structured messages."""
    
    # Test with proper system/user message separation
    proper_request = {
        "model": "gemma3n:latest",
        "messages": [
            {
                "role": "system",
                "content": "You are Gemi, a warm and empathetic AI diary companion. Be supportive and encouraging."
            },
            {
                "role": "user", 
                "content": "I'm feeling a bit down today"
            }
        ],
        "stream": False
    }
    
    # Test with old format (everything as user message)
    old_format_request = {
        "model": "gemma3n:latest",
        "messages": [
            {
                "role": "user",
                "content": """You are Gemi, a warm and empathetic AI diary companion. Be supportive and encouraging.

User: I'm feeling a bit down today

Respond as Gemi with warmth and empathy."""
            }
        ],
        "stream": False
    }
    
    print("🧪 Testing Chat Message Structure")
    print("=" * 50)
    
    try:
        # Test proper format
        print("\n1. Testing with proper system/user separation:")
        response = requests.post("http://localhost:11434/api/chat", json=proper_request)
        if response.status_code == 200:
            result = response.json()
            print("✅ Proper format works!")
            print(f"Response preview: {result['message']['content'][:150]}...")
        else:
            print(f"❌ Error: {response.status_code}")
            
        # Test old format
        print("\n2. Testing with old format (all as user message):")
        response = requests.post("http://localhost:11434/api/chat", json=old_format_request)
        if response.status_code == 200:
            result = response.json()
            print("✅ Old format also works (but may give weird responses)")
            print(f"Response preview: {result['message']['content'][:150]}...")
            
            # Check if response mentions instructions
            if "warm and empathetic" in result['message']['content'].lower() or "diary companion" in result['message']['content'].lower():
                print("⚠️  WARNING: Response contains instruction text - model is confused!")
        else:
            print(f"❌ Error: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Test failed: {e}")
        
    print("\n" + "=" * 50)
    print("📊 CONCLUSION:")
    print("The proper system/user separation should produce more natural responses")
    print("without the model referencing or being confused by the instructions.")

if __name__ == "__main__":
    test_chat_with_proper_messages()