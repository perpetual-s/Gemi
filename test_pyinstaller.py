#!/usr/bin/env python3
"""Test if PyInstaller bundle is working at all"""

import subprocess
import sys
import os

server_path = "/Applications/Gemi.app/Contents/Resources/GemiServer.app/Contents/MacOS/GemiServer"

print("Testing PyInstaller bundle...")
print(f"Server: {server_path}")
print(f"Exists: {os.path.exists(server_path)}")

# Create all necessary directories
dirs_to_create = [
    os.path.expanduser("~/Library/Application Support/Gemi"),
    os.path.expanduser("~/Library/Application Support/Gemi/Models"),
    os.path.expanduser("~/Library/Logs/Gemi"),
]

for dir_path in dirs_to_create:
    os.makedirs(dir_path, exist_ok=True)
    print(f"✅ Ensured directory exists: {dir_path}")

# Try running with direct output
print("\nRunning server directly...")
try:
    result = subprocess.run(
        [server_path],
        env={
            "PYTORCH_ENABLE_MPS_FALLBACK": "1",
            "HF_HOME": os.path.expanduser("~/Library/Application Support/Gemi/Models"),
            "PYTHONUNBUFFERED": "1",
        },
        capture_output=True,
        text=True,
        timeout=2
    )
    print(f"Return code: {result.returncode}")
    print(f"STDOUT: {result.stdout}")
    print(f"STDERR: {result.stderr}")
except subprocess.TimeoutExpired:
    print("✅ Server is running (timeout expected)")
except Exception as e:
    print(f"❌ Error: {e}")

# Check logs
log_file = os.path.expanduser("~/Library/Logs/Gemi/gemi_server.log")
if os.path.exists(log_file):
    print(f"\nLog file contents:")
    with open(log_file, 'r') as f:
        print(f.read())