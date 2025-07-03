#!/usr/bin/env python3
"""
Comprehensive Ollama Connectivity Diagnostic Script for Gemi
This script tests all aspects of Ollama integration to identify connection issues.
"""

import json
import requests
import subprocess
import sys
import time
from typing import Dict, List, Optional, Tuple

class OllamaDiagnostic:
    def __init__(self):
        self.base_url = "http://localhost:11434"
        self.expected_models = {
            "chat": ["gemma3n:latest", "gemi-custom"],  # gemi-custom is optional
            "embedding": ["nomic-embed-text"]
        }
        self.issues_found = []
        self.fixes_suggested = []
        
    def run_all_tests(self):
        """Run comprehensive diagnostic tests"""
        print("=" * 60)
        print("🔍 Gemi Ollama Connectivity Diagnostic")
        print("=" * 60)
        
        # Test 1: Check if Ollama is installed
        print("\n1️⃣ Checking Ollama installation...")
        ollama_installed = self.check_ollama_installed()
        
        # Test 2: Check if Ollama server is running
        print("\n2️⃣ Checking Ollama server status...")
        server_running = self.check_server_running()
        
        # Test 3: List installed models
        print("\n3️⃣ Checking installed models...")
        models = self.list_installed_models() if server_running else []
        
        # Test 4: Check required models
        print("\n4️⃣ Verifying required models...")
        self.check_required_models(models)
        
        # Test 5: Test model generation
        print("\n5️⃣ Testing model generation...")
        if server_running and models:
            self.test_model_generation()
        
        # Test 6: Test embedding generation
        print("\n6️⃣ Testing embedding generation...")
        if server_running:
            self.test_embedding_generation()
            
        # Test 7: Check for common issues
        print("\n7️⃣ Checking for common issues...")
        self.check_common_issues()
        
        # Summary
        self.print_summary()
        
    def check_ollama_installed(self) -> bool:
        """Check if Ollama is installed"""
        try:
            result = subprocess.run(['which', 'ollama'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                print("✅ Ollama is installed at:", result.stdout.strip())
                
                # Get version
                version_result = subprocess.run(['ollama', '--version'], 
                                              capture_output=True, text=True)
                if version_result.returncode == 0:
                    print("   Version:", version_result.stdout.strip())
                return True
            else:
                print("❌ Ollama is not installed")
                self.issues_found.append("Ollama not installed")
                self.fixes_suggested.append("Install Ollama from https://ollama.ai")
                return False
        except Exception as e:
            print(f"❌ Error checking Ollama installation: {e}")
            return False
            
    def check_server_running(self) -> bool:
        """Check if Ollama server is running"""
        try:
            response = requests.get(f"{self.base_url}/api/tags", timeout=5)
            if response.status_code == 200:
                print("✅ Ollama server is running")
                return True
            else:
                print(f"❌ Ollama server returned status {response.status_code}")
                self.issues_found.append("Ollama server not responding correctly")
                return False
        except requests.exceptions.ConnectionError:
            print("❌ Cannot connect to Ollama server")
            self.issues_found.append("Ollama server not running")
            self.fixes_suggested.append("Start Ollama with: ollama serve")
            
            # Check if port is in use
            self.check_port_availability()
            return False
        except Exception as e:
            print(f"❌ Error connecting to server: {e}")
            self.issues_found.append(f"Connection error: {str(e)}")
            return False
            
    def check_port_availability(self):
        """Check if port 11434 is available or in use"""
        try:
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('localhost', 11434))
            sock.close()
            
            if result == 0:
                # Port is in use, check by what
                lsof_result = subprocess.run(['lsof', '-i', ':11434'], 
                                           capture_output=True, text=True)
                if lsof_result.returncode == 0:
                    print("   ⚠️  Port 11434 is in use by:")
                    print(lsof_result.stdout)
            else:
                print("   ℹ️  Port 11434 is available")
        except:
            pass
            
    def list_installed_models(self) -> List[Dict]:
        """List all installed models"""
        try:
            response = requests.get(f"{self.base_url}/api/tags")
            if response.status_code == 200:
                data = response.json()
                models = data.get('models', [])
                
                if models:
                    print("✅ Found installed models:")
                    for model in models:
                        size_gb = model['size'] / (1024**3)
                        print(f"   - {model['name']} ({size_gb:.2f} GB)")
                    return models
                else:
                    print("⚠️  No models installed")
                    self.issues_found.append("No models installed")
                    return []
            else:
                print(f"❌ Failed to list models: {response.status_code}")
                return []
        except Exception as e:
            print(f"❌ Error listing models: {e}")
            return []
            
    def check_required_models(self, installed_models: List[Dict]):
        """Check if required models are installed"""
        installed_names = [m['name'] for m in installed_models]
        # Also check without :latest suffix
        installed_base_names = [name.split(':')[0] for name in installed_names]
        
        # Check chat models
        chat_model_found = False
        for model in self.expected_models['chat']:
            if model in installed_names:
                print(f"✅ Chat model '{model}' is installed")
                chat_model_found = True
                break
        
        if not chat_model_found:
            print("❌ No chat model found")
            self.issues_found.append("Chat model not installed")
            self.fixes_suggested.append("Install with: ollama pull gemma3n:latest")
            
        # Check embedding model
        embedding_model = self.expected_models['embedding'][0]
        if embedding_model in installed_names or embedding_model in installed_base_names:
            print(f"✅ Embedding model '{embedding_model}' is installed")
        else:
            print(f"❌ Embedding model '{embedding_model}' not found")
            self.issues_found.append("Embedding model not installed")
            self.fixes_suggested.append("Install with: ollama pull nomic-embed-text")
            
    def test_model_generation(self):
        """Test model generation"""
        # Find an available model
        try:
            response = requests.get(f"{self.base_url}/api/tags")
            if response.status_code != 200:
                return
                
            models = response.json().get('models', [])
            if not models:
                return
                
            # Try to find a chat model
            test_model = None
            for model in models:
                if any(name in model['name'] for name in ['gemma', 'llama', 'mistral']):
                    test_model = model['name']
                    break
                    
            if not test_model and models:
                test_model = models[0]['name']
                
            if not test_model:
                print("❌ No model available for testing")
                return
                
            print(f"   Testing with model: {test_model}")
            
            # Test generation
            data = {
                "model": test_model,
                "prompt": "Hello, respond with just 'Hi'",
                "stream": False,
                "options": {
                    "temperature": 0.1,
                    "num_predict": 10
                }
            }
            
            response = requests.post(f"{self.base_url}/api/generate", 
                                   json=data, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Model generation successful")
                print(f"   Response: {result.get('response', '')[:50]}...")
            else:
                print(f"❌ Model generation failed: {response.status_code}")
                print(f"   Error: {response.text}")
                self.issues_found.append(f"Model generation failed: {response.text}")
                
        except Exception as e:
            print(f"❌ Error testing generation: {e}")
            self.issues_found.append(f"Generation test error: {str(e)}")
            
    def test_embedding_generation(self):
        """Test embedding generation"""
        try:
            # Check if embedding model is installed
            response = requests.get(f"{self.base_url}/api/tags")
            if response.status_code != 200:
                return
                
            models = response.json().get('models', [])
            model_names = [m['name'] for m in models]
            model_base_names = [name.split(':')[0] for name in model_names]
            
            if 'nomic-embed-text' not in model_names and 'nomic-embed-text' not in model_base_names:
                print("⚠️  Skipping embedding test - model not installed")
                return
                
            # Test embedding
            data = {
                "model": "nomic-embed-text",
                "prompt": "Hello world"
            }
            
            response = requests.post(f"{self.base_url}/api/embeddings", 
                                   json=data, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                embedding = result.get('embedding', [])
                print(f"✅ Embedding generation successful")
                print(f"   Embedding dimension: {len(embedding)}")
            else:
                print(f"❌ Embedding generation failed: {response.status_code}")
                print(f"   Error: {response.text}")
                self.issues_found.append("Embedding generation failed")
                
        except Exception as e:
            print(f"❌ Error testing embeddings: {e}")
            self.issues_found.append(f"Embedding test error: {str(e)}")
            
    def check_common_issues(self):
        """Check for common configuration issues"""
        # Check if gemi-custom model exists
        try:
            response = requests.get(f"{self.base_url}/api/tags")
            if response.status_code == 200:
                models = response.json().get('models', [])
                model_names = [m['name'] for m in models]
                
                if 'gemi-custom' not in model_names:
                    print("ℹ️  Custom 'gemi-custom' model not created yet")
                    print("   This will be created on first app use")
                else:
                    print("✅ Custom 'gemi-custom' model exists")
        except:
            pass
            
    def print_summary(self):
        """Print diagnostic summary"""
        print("\n" + "=" * 60)
        print("📊 DIAGNOSTIC SUMMARY")
        print("=" * 60)
        
        if not self.issues_found:
            print("\n✅ All tests passed! Ollama is properly configured for Gemi.")
        else:
            print(f"\n❌ Found {len(self.issues_found)} issue(s):")
            for i, issue in enumerate(self.issues_found, 1):
                print(f"   {i}. {issue}")
                
            print(f"\n🔧 Suggested fixes:")
            for i, fix in enumerate(self.fixes_suggested, 1):
                print(f"   {i}. {fix}")
                
        print("\n📝 Quick Setup Commands:")
        print("   1. Install Ollama: https://ollama.ai")
        print("   2. Start server: ollama serve")
        print("   3. Install chat model: ollama pull gemma3n:latest")
        print("   4. Install embedding model: ollama pull nomic-embed-text")
        print("   5. Restart Gemi app")
        
        print("\n💡 Tips:")
        print("   - Ensure Ollama is running before starting Gemi")
        print("   - The app will create a custom 'gemi-custom' model on first use")
        print("   - Check logs in Console.app for detailed error messages")

if __name__ == "__main__":
    diagnostic = OllamaDiagnostic()
    diagnostic.run_all_tests()