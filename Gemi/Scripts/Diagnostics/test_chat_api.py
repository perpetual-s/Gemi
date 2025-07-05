#!/usr/bin/env python3
"""Test the exact chat API format used by Gemi"""

import requests
import json

def test_chat_api():
    print("Testing Ollama /api/chat endpoint with Gemi's exact format...")
    
    # System prompt used by Gemi
    system_prompt = """You are Gemi, a warm and empathetic AI diary companion. You're having a private conversation with your user in their personal journal app. Everything shared stays completely private on their device.

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
- Reference past conversations naturally when relevant"""
    
    # Test messages
    test_cases = [
        "hi",
        "can you help me",
        "I'm feeling happy today",
        "What should I write about?"
    ]
    
    for user_message in test_cases:
        print(f"\n\nTesting with user message: '{user_message}'")
        
        # Create request exactly as Gemi does
        request_data = {
            "model": "gemma3n:latest",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message}
            ],
            "stream": False,  # Non-streaming for easier testing
            "options": {
                "temperature": 0.7,
                "top_p": 0.9,
                "top_k": 40,
                "repeat_penalty": 1.1,
                "num_predict": 2048,
                "num_ctx": 4096
            }
        }
        
        try:
            response = requests.post(
                'http://localhost:11434/api/chat',
                json=request_data,
                timeout=30
            )
            
            print(f"Status code: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                ai_response = result.get('message', {}).get('content', 'No content')
                print(f"AI Response: {ai_response[:200]}...")  # First 200 chars
            else:
                print(f"Error: {response.text}")
                
        except Exception as e:
            print(f"Exception: {e}")

if __name__ == "__main__":
    test_chat_api()