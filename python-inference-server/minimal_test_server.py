"""
Minimal test server to verify PyInstaller bundle works
Tests basic Python functionality and FastAPI
"""

import sys
import os
from fastapi import FastAPI
from fastapi.responses import JSONResponse
import uvicorn
from datetime import datetime

# Create FastAPI app
app = FastAPI(title="Gemi Minimal Test Server")

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "status": "ok",
        "message": "Gemi Minimal Test Server is running",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/health")
async def health():
    """Health check endpoint"""
    return JSONResponse(
        content={
            "status": "healthy",
            "server": "gemi-minimal",
            "python_version": sys.version,
            "executable": sys.executable,
            "platform": sys.platform,
            "pid": os.getpid(),
            "cwd": os.getcwd(),
        }
    )

@app.get("/api/test-imports")
async def test_imports():
    """Test that critical imports work"""
    results = {}
    
    # Test standard library imports
    test_modules = [
        'encodings',
        'codecs',
        'io',
        'json',
        'asyncio',
        'typing',
        'pydantic',
        'multiprocessing',
    ]
    
    for module in test_modules:
        try:
            __import__(module)
            results[module] = "✓ OK"
        except ImportError as e:
            results[module] = f"✗ Failed: {str(e)}"
    
    return {
        "import_test_results": results,
        "total_modules": len(test_modules),
        "successful": sum(1 for v in results.values() if v.startswith("✓"))
    }

def main():
    """Main entry point"""
    print("Starting Gemi Minimal Test Server...")
    print(f"Python: {sys.version}")
    print(f"Executable: {sys.executable}")
    
    # Run the server
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=11435,
        log_level="info",
        access_log=True
    )

if __name__ == "__main__":
    main()