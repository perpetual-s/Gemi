#!/usr/bin/env python3

import subprocess
import time
import requests
import json
import sys

# ANSI color codes
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def print_header(text):
    print(f"\n{BLUE}=== {text} ==={RESET}")

def print_success(text):
    print(f"{GREEN}✓ {text}{RESET}")

def print_error(text):
    print(f"{RED}✗ {text}{RESET}")

def print_warning(text):
    print(f"{YELLOW}⚠ {text}{RESET}")

def check_ollama_running():
    """Check if Ollama is running"""
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        return response.status_code == 200
    except:
        return False

def get_running_processes():
    """Get list of running Ollama processes"""
    try:
        result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
        ollama_processes = [line for line in result.stdout.split('\n') if 'ollama' in line.lower() and 'grep' not in line]
        return ollama_processes
    except:
        return []

def test_ollama_api():
    """Test Ollama API endpoints"""
    print_header("Testing Ollama API")
    
    # Test /api/tags
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        if response.status_code == 200:
            data = response.json()
            models = [m['name'] for m in data.get('models', [])]
            print_success(f"API is accessible. Found {len(models)} models:")
            for model in models:
                print(f"  - {model}")
            return True
        else:
            print_error(f"API returned status code: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Failed to connect to API: {e}")
        return False

def test_model_availability():
    """Check if required models are installed"""
    print_header("Checking Required Models")
    
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        if response.status_code == 200:
            data = response.json()
            models = [m['name'] for m in data.get('models', [])]
            
            # Check for Gemma
            has_gemma = any('gemma3n' in model for model in models)
            if has_gemma:
                print_success("Gemma 3n model is installed")
            else:
                print_error("Gemma 3n model is NOT installed")
                print("  Run: ollama pull gemma3n:latest")
            
            # Check for embedding model
            has_embedding = any('nomic-embed-text' in model for model in models)
            if has_embedding:
                print_success("Embedding model is installed")
            else:
                print_error("Embedding model is NOT installed")
                print("  Run: ollama pull nomic-embed-text:latest")
            
            return has_gemma and has_embedding
    except Exception as e:
        print_error(f"Failed to check models: {e}")
        return False

def test_chat_completion():
    """Test chat completion with Gemma"""
    print_header("Testing Chat Completion")
    
    try:
        # Test simple chat
        data = {
            "model": "gemma3n:latest",
            "messages": [
                {"role": "user", "content": "Hello! Please respond with just 'Hi there!'"}
            ],
            "stream": False
        }
        
        response = requests.post("http://localhost:11434/api/chat", json=data, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            message = result.get('message', {}).get('content', '')
            print_success(f"Chat completion successful")
            print(f"  Response: {message[:100]}...")
            return True
        else:
            print_error(f"Chat completion failed with status: {response.status_code}")
            return False
            
    except Exception as e:
        print_error(f"Chat completion error: {e}")
        return False

def test_embedding_generation():
    """Test embedding generation"""
    print_header("Testing Embedding Generation")
    
    try:
        data = {
            "model": "nomic-embed-text:latest",
            "prompt": "Test embedding generation"
        }
        
        response = requests.post("http://localhost:11434/api/embeddings", json=data, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            embedding = result.get('embedding', [])
            print_success(f"Embedding generation successful")
            print(f"  Embedding dimensions: {len(embedding)}")
            return True
        else:
            print_error(f"Embedding generation failed with status: {response.status_code}")
            return False
            
    except Exception as e:
        print_error(f"Embedding generation error: {e}")
        return False

def main():
    print(f"{BLUE}Ollama Integration Test Suite{RESET}")
    print("=" * 40)
    
    # Check if Ollama is running
    print_header("Checking Ollama Status")
    
    if check_ollama_running():
        print_success("Ollama is running")
        
        # Show running processes
        processes = get_running_processes()
        if processes:
            print(f"\n  Running Ollama processes:")
            for proc in processes[:3]:  # Show max 3 processes
                print(f"  {proc[:100]}...")
    else:
        print_error("Ollama is NOT running")
        print("\nTo start Ollama:")
        print("  1. Open Terminal")
        print("  2. Run: ollama serve")
        print("\nOr if you have Ollama.app installed:")
        print("  1. Open Ollama from Applications")
        return
    
    # Run tests
    all_tests_passed = True
    
    if not test_ollama_api():
        all_tests_passed = False
    
    if not test_model_availability():
        all_tests_passed = False
    
    if test_model_availability():  # Only test if models are available
        if not test_chat_completion():
            all_tests_passed = False
        
        if not test_embedding_generation():
            all_tests_passed = False
    
    # Summary
    print_header("Test Summary")
    if all_tests_passed:
        print_success("All tests passed! Ollama is ready for use with Gemi.")
    else:
        print_error("Some tests failed. Please address the issues above.")
        
if __name__ == "__main__":
    main()