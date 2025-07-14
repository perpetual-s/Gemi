#!/usr/bin/env python3
"""
Minimal test server to verify PyInstaller bundle works
"""
import sys
import os

print(f"Python: {sys.version}")
print(f"Executable: {sys.executable}")
print(f"Path: {sys.path}")

try:
    from fastapi import FastAPI
    import uvicorn
    
    app = FastAPI()
    
    @app.get("/api/health")
    def health():
        return {
            "status": "healthy",
            "model_loaded": False,
            "message": "Test server running"
        }
    
    if __name__ == "__main__":
        print("Starting test server on port 11435...")
        uvicorn.run(app, host="127.0.0.1", port=11435)
        
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)