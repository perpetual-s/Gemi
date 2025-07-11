#!/usr/bin/env python3
"""
Test multimodal capabilities of the Gemi AI Server
Demonstrates sending text + image to the server
"""

import requests
import base64
import json
from PIL import Image
import io

def create_test_image():
    """Create a simple test image"""
    img = Image.new('RGB', (200, 200), color='red')
    # Add some variation
    pixels = img.load()
    for x in range(100):
        for y in range(100):
            pixels[x, y] = (255, 255, 0)  # Yellow square
    
    # Convert to base64
    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    img_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
    
    return img_base64

def test_text_only():
    """Test text-only request"""
    print("🧪 Testing text-only request...")
    
    request_data = {
        "model": "google/gemma-3n-e4b-it",
        "messages": [
            {
                "role": "user",
                "content": "Hello! Can you see images?"
            }
        ],
        "stream": False
    }
    
    try:
        response = requests.post(
            "http://localhost:11435/api/chat",
            json=request_data,
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Text response:", data['message']['content'][:100] + "...")
            return True
        else:
            print(f"❌ Error: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return False

def test_multimodal():
    """Test multimodal (text + image) request"""
    print("\n🧪 Testing multimodal request...")
    
    # Create test image
    img_base64 = create_test_image()
    print("✓ Created test image (red background with yellow square)")
    
    request_data = {
        "model": "google/gemma-3n-e4b-it",
        "messages": [
            {
                "role": "user",
                "content": "What colors do you see in this image? Please describe what you see.",
                "images": [img_base64]
            }
        ],
        "stream": False
    }
    
    try:
        response = requests.post(
            "http://localhost:11435/api/chat",
            json=request_data,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Multimodal response:", data['message']['content'])
            return True
        else:
            print(f"❌ Error: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_streaming():
    """Test streaming response"""
    print("\n🧪 Testing streaming response...")
    
    request_data = {
        "model": "google/gemma-3n-e4b-it",
        "messages": [
            {
                "role": "user",
                "content": "Count from 1 to 5 slowly."
            }
        ],
        "stream": True
    }
    
    try:
        response = requests.post(
            "http://localhost:11435/api/chat",
            json=request_data,
            headers={"Content-Type": "application/json"},
            stream=True
        )
        
        if response.status_code == 200:
            print("✅ Streaming response:")
            full_response = ""
            
            for line in response.iter_lines():
                if line:
                    line_str = line.decode('utf-8')
                    if line_str.startswith('data: '):
                        try:
                            data = json.loads(line_str[6:])
                            if data.get('message') and data['message'].get('content'):
                                content = data['message']['content']
                                print(content, end='', flush=True)
                                full_response += content
                            if data.get('done'):
                                print("\n✓ Stream completed")
                                break
                        except json.JSONDecodeError:
                            pass
            
            return True
        else:
            print(f"❌ Error: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 Gemi AI Server Test Suite")
    print("============================")
    print("Server URL: http://localhost:11435")
    print()
    
    # Check if server is running
    print("🔍 Checking server health...")
    try:
        health_response = requests.get("http://localhost:11435/api/health")
        health_data = health_response.json()
        
        print(f"✓ Server status: {health_data['status']}")
        print(f"✓ Model loaded: {health_data['model_loaded']}")
        print(f"✓ Device: {health_data['device']}")
        print(f"✓ MPS available: {health_data['mps_available']}")
        
        if not health_data['model_loaded']:
            progress = int(health_data['download_progress'] * 100)
            print(f"\n⏳ Model is loading: {progress}%")
            print("Please wait for model download to complete and try again.")
            return
        
    except Exception as e:
        print(f"❌ Server not running: {e}")
        print("\nPlease start the server with: ./launch_server.sh")
        return
    
    print("\nRunning tests...\n")
    
    # Run tests
    results = []
    results.append(("Text-only", test_text_only()))
    results.append(("Multimodal", test_multimodal()))
    results.append(("Streaming", test_streaming()))
    
    # Summary
    print("\n📊 Test Summary")
    print("===============")
    for test_name, passed in results:
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"{test_name}: {status}")
    
    total_passed = sum(1 for _, passed in results if passed)
    print(f"\nTotal: {total_passed}/{len(results)} tests passed")
    
    if total_passed == len(results):
        print("\n🎉 All tests passed! The server is working correctly.")
    else:
        print("\n⚠️  Some tests failed. Check the server logs for details.")

if __name__ == "__main__":
    main()