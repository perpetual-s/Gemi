#!/usr/bin/env python3
"""Test GemiServer startup with detailed diagnostics"""

import subprocess
import time
import requests
import os

def test_server():
    server_path = "/Applications/Gemi.app/Contents/Resources/GemiServer.app/Contents/MacOS/GemiServer"
    
    # Set up environment
    env = os.environ.copy()
    env['PYTORCH_ENABLE_MPS_FALLBACK'] = '1'
    env['HF_HOME'] = os.path.expanduser('~/Library/Application Support/Gemi/Models')
    
    print("Starting GemiServer...")
    print(f"Server path: {server_path}")
    print(f"HF_HOME: {env['HF_HOME']}")
    
    # Start the server process
    process = subprocess.Popen(
        [server_path],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1
    )
    
    print("\nMonitoring server output for 30 seconds...")
    print("=" * 60)
    
    start_time = time.time()
    server_ready = False
    
    while time.time() - start_time < 30:
        # Check if process is still running
        if process.poll() is not None:
            print(f"\n❌ Server exited with code: {process.returncode}")
            stdout, stderr = process.communicate()
            print("\nSTDOUT:")
            print(stdout)
            print("\nSTDERR:")
            print(stderr)
            return
        
        # Read any available output
        try:
            # Non-blocking read from stdout
            for line in iter(process.stdout.readline, ''):
                if line:
                    print(f"[STDOUT] {line.strip()}")
                    if 'error' in line.lower():
                        print(f"⚠️  Error detected: {line.strip()}")
                break
                
            # Try to connect to the server
            if not server_ready:
                try:
                    response = requests.get('http://127.0.0.1:11435/api/health', timeout=1)
                    if response.status_code == 200:
                        print("\n✅ Server is responding!")
                        print(f"Health check response: {response.json()}")
                        server_ready = True
                except requests.exceptions.RequestException:
                    pass
                    
        except Exception as e:
            print(f"Error reading output: {e}")
            
        time.sleep(0.5)
    
    if not server_ready:
        print("\n⏱️  Server did not become ready within 30 seconds")
        
    # Clean up
    process.terminate()
    process.wait()
    print("\nServer stopped.")

if __name__ == "__main__":
    test_server()