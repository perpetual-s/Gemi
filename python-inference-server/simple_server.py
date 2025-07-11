import torch
from transformers import AutoProcessor, AutoModelForConditionalGeneration
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel
import base64
import io
from PIL import Image
import asyncio
import json
from typing import List, Optional
import logging
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('gemi_inference_server.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(title="Gemi Inference Server", version="1.0.0")

# Global model variables
model = None
processor = None
device = None
download_progress = 0.0

class ChatMessage(BaseModel):
    role: str
    content: str
    images: Optional[List[str]] = None

class ChatRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    stream: bool = True

def load_model():
    """Load Gemma 3n model with MPS support"""
    global model, processor, device, download_progress
    
    # Check for MPS availability
    if torch.backends.mps.is_available():
        device = torch.device("mps")
        logger.info("Using MPS (Metal Performance Shaders) for acceleration")
    else:
        device = torch.device("cpu")
        logger.info("MPS not available, using CPU")
    
    # Load the model
    logger.info("Loading gemma-3n-E4B-it model...")
    download_progress = 0.1
    
    try:
        model_id = "google/gemma-3n-e4b-it"
        
        # Load processor
        processor = AutoProcessor.from_pretrained(model_id)
        download_progress = 0.3
        
        # Load model
        model = AutoModelForConditionalGeneration.from_pretrained(
            model_id,
            device_map="auto",
            torch_dtype=torch.bfloat16 if device.type == "mps" else torch.float32,
        )
        model.eval()
        download_progress = 1.0
        
        logger.info("Model loaded successfully!")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        download_progress = 0.0
        raise

@app.on_event("startup")
async def startup_event():
    """Load model on server startup"""
    try:
        load_model()
    except Exception as e:
        logger.error(f"Startup failed: {e}")

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy" if model is not None else "loading",
        "model_loaded": model is not None,
        "device": str(device) if device else "unknown",
        "mps_available": torch.backends.mps.is_available(),
        "download_progress": download_progress
    }

@app.post("/api/chat")
async def chat(request: ChatRequest):
    """Chat endpoint with streaming support"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    # Extract the last user message and images
    user_message = None
    images = []
    
    for msg in request.messages:
        if msg.role == "user":
            user_message = msg.content
            if msg.images:
                # Decode base64 images
                for img_base64 in msg.images:
                    img_data = base64.b64decode(img_base64)
                    img = Image.open(io.BytesIO(img_data))
                    images.append(img)
    
    if not user_message:
        raise HTTPException(status_code=400, detail="No user message found")
    
    # Prepare inputs
    inputs = processor(
        text=user_message,
        images=images if images else None,
        return_tensors="pt"
    ).to(device)
    
    # Generate response
    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            max_new_tokens=1024,
            temperature=0.7,
            do_sample=True
        )
    
    generated_text = processor.decode(outputs[0], skip_special_tokens=True)
    
    if request.stream:
        return StreamingResponse(
            generate_stream(generated_text, request.model),
            media_type="text/event-stream"
        )
    else:
        return {
            "model": request.model,
            "message": {
                "role": "assistant",
                "content": generated_text
            },
            "done": True
        }

async def generate_stream(text: str, model_name: str):
    """Generate streaming response"""
    # Simulate streaming by chunking the response
    chunk_size = 10  # characters per chunk
    for i in range(0, len(text), chunk_size):
        chunk = text[i:i + chunk_size]
        response = {
            "model": model_name,
            "message": {
                "role": "assistant",
                "content": chunk
            },
            "done": i + chunk_size >= len(text)
        }
        yield f"data: {json.dumps(response)}\n\n"
        await asyncio.sleep(0.01)  # Small delay for streaming effect

@app.get("/api/tags")
async def list_models():
    """List available models (Ollama compatibility)"""
    return {
        "models": [
            {
                "name": "gemma-3n-e4b-it",
                "modified_at": "2025-07-11T00:00:00Z",
                "size": 8000000000,  # 8B parameters
                "digest": "gemma3n-multimodal"
            }
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=11435)