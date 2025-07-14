#!/usr/bin/env python3
"""
Gemi Inference Server with Lazy Loading
Delays PyTorch import to work around PyInstaller issues
"""

import os
import sys
import json
import base64
import logging
import tempfile
import shutil
from pathlib import Path
from typing import Dict, Any, Optional, AsyncIterator
from datetime import datetime

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel
import uvicorn

# Lazy imports for ML libraries
torch = None
transformers = None
Image = None
device = None
model = None
processor = None

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# FastAPI app
app = FastAPI(
    title="Gemi Inference Server",
    description="Local inference server for Gemma 3n model",
    version="1.0.0"
)

# Request/Response models
class ChatRequest(BaseModel):
    model: str
    messages: list[dict[str, Any]]
    stream: bool = False
    temperature: float = 0.7
    max_tokens: int = 2048
    images: Optional[list[str]] = None
    
class ChatResponse(BaseModel):
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: list[dict[str, Any]]

# Configuration
MODEL_ID = "google/gemma-3n-e4b-it"
DEFAULT_MODEL_DIR = Path.home() / "Library" / "Application Support" / "Gemi" / "Models"
HF_TOKEN = os.getenv("HF_TOKEN", "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")

def lazy_load_ml_libraries():
    """Lazy load ML libraries to avoid import issues with PyInstaller"""
    global torch, transformers, Image, device
    
    if torch is None:
        logger.info("Loading ML libraries...")
        try:
            # Import in specific order to avoid issues
            import torch as _torch
            torch = _torch
            
            # Import transformers after torch
            import transformers as _transformers
            transformers = _transformers
            
            # Import PIL
            from PIL import Image as _Image
            Image = _Image
            
            # Set device
            if torch.backends.mps.is_available():
                device = torch.device("mps")
                logger.info("Using MPS (Metal Performance Shaders) for acceleration")
            elif torch.cuda.is_available():
                device = torch.device("cuda")
                logger.info("Using CUDA for acceleration")
            else:
                device = torch.device("cpu")
                logger.info("Using CPU for inference")
                
            logger.info("ML libraries loaded successfully")
            
        except Exception as e:
            logger.error(f"Failed to load ML libraries: {e}")
            raise

def load_model():
    """Load the Gemma model lazily"""
    global model, processor
    
    if model is None:
        logger.info(f"Loading model: {MODEL_ID}")
        try:
            # Ensure ML libraries are loaded
            lazy_load_ml_libraries()
            
            # Set up HuggingFace authentication
            os.environ["HF_TOKEN"] = HF_TOKEN
            from huggingface_hub import login
            login(token=HF_TOKEN, add_to_git_credential=False)
            
            # Create cache directory
            cache_dir = DEFAULT_MODEL_DIR / "hub"
            cache_dir.mkdir(parents=True, exist_ok=True)
            
            # Load processor
            from transformers import AutoProcessor
            processor = AutoProcessor.from_pretrained(
                MODEL_ID,
                cache_dir=cache_dir,
                token=HF_TOKEN
            )
            
            # Load model
            from transformers import AutoModelForCausalLM, BitsAndBytesConfig
            
            # Configure quantization for memory efficiency
            quantization_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_compute_dtype=torch.float16
            ) if device.type != "cpu" else None
            
            model = AutoModelForCausalLM.from_pretrained(
                MODEL_ID,
                cache_dir=cache_dir,
                device_map="auto" if device.type != "cpu" else None,
                quantization_config=quantization_config,
                token=HF_TOKEN,
                torch_dtype=torch.float16 if device.type != "cpu" else torch.float32,
                low_cpu_mem_usage=True
            )
            
            if device.type == "cpu":
                model = model.to(device)
            
            model.eval()
            logger.info("Model loaded successfully")
            
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            model = None
            processor = None
            raise

@app.get("/")
async def root():
    return {
        "message": "Gemi Inference Server",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/api/health")
async def health():
    """Health check endpoint"""
    ml_status = "not_loaded"
    model_status = "not_loaded"
    
    try:
        if torch is not None:
            ml_status = "loaded"
        if model is not None:
            model_status = "loaded"
    except:
        pass
    
    return JSONResponse(
        content={
            "status": "healthy",
            "server": "gemi-inference",
            "ml_libraries": ml_status,
            "model": model_status,
            "timestamp": datetime.now().isoformat()
        }
    )

@app.get("/api/models")
async def list_models():
    """List available models"""
    return JSONResponse(
        content={
            "object": "list",
            "data": [
                {
                    "id": MODEL_ID,
                    "object": "model",
                    "created": 1677610602,
                    "owned_by": "google"
                }
            ]
        }
    )

async def generate_stream(prompt: str, images: Optional[list] = None, **kwargs) -> AsyncIterator[str]:
    """Generate streaming response"""
    try:
        # Ensure model is loaded
        load_model()
        
        # Process inputs
        if images:
            # Handle multimodal input
            pil_images = []
            for img_data in images:
                if img_data.startswith('data:'):
                    img_data = img_data.split(',', 1)[1]
                img_bytes = base64.b64decode(img_data)
                img = Image.open(tempfile.NamedTemporaryFile(delete=False, suffix='.png'))
                img.save(img.name)
                pil_images.append(Image.open(img.name))
            
            inputs = processor(text=prompt, images=pil_images, return_tensors="pt").to(device)
        else:
            inputs = processor(text=prompt, return_tensors="pt").to(device)
        
        # Generate with streaming
        from transformers import TextIteratorStreamer
        from threading import Thread
        
        streamer = TextIteratorStreamer(processor.tokenizer, skip_prompt=True)
        
        generation_kwargs = dict(
            inputs,
            streamer=streamer,
            max_new_tokens=kwargs.get('max_tokens', 2048),
            temperature=kwargs.get('temperature', 0.7),
            do_sample=True,
        )
        
        thread = Thread(target=model.generate, kwargs=generation_kwargs)
        thread.start()
        
        # Stream tokens
        for token in streamer:
            chunk = {
                "id": f"chatcmpl-{datetime.now().timestamp()}",
                "object": "chat.completion.chunk",
                "created": int(datetime.now().timestamp()),
                "model": MODEL_ID,
                "choices": [{
                    "index": 0,
                    "delta": {"content": token},
                    "finish_reason": None
                }]
            }
            yield f"data: {json.dumps(chunk)}\n\n"
        
        # Final chunk
        final_chunk = {
            "id": f"chatcmpl-{datetime.now().timestamp()}",
            "object": "chat.completion.chunk",
            "created": int(datetime.now().timestamp()),
            "model": MODEL_ID,
            "choices": [{
                "index": 0,
                "delta": {},
                "finish_reason": "stop"
            }]
        }
        yield f"data: {json.dumps(final_chunk)}\n\n"
        yield "data: [DONE]\n\n"
        
    except Exception as e:
        logger.error(f"Streaming generation error: {e}")
        error_chunk = {"error": str(e)}
        yield f"data: {json.dumps(error_chunk)}\n\n"

@app.post("/api/chat")
async def chat(request: ChatRequest):
    """Chat completion endpoint"""
    try:
        # Extract prompt from messages
        prompt = ""
        for msg in request.messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            if role == "system":
                prompt += f"System: {content}\n"
            elif role == "user":
                prompt += f"User: {content}\n"
            elif role == "assistant":
                prompt += f"Assistant: {content}\n"
        prompt += "Assistant: "
        
        if request.stream:
            return StreamingResponse(
                generate_stream(
                    prompt,
                    images=request.images,
                    temperature=request.temperature,
                    max_tokens=request.max_tokens
                ),
                media_type="text/event-stream"
            )
        else:
            # Non-streaming response
            load_model()
            
            # Process inputs
            if request.images:
                pil_images = []
                for img_data in request.images:
                    if img_data.startswith('data:'):
                        img_data = img_data.split(',', 1)[1]
                    img_bytes = base64.b64decode(img_data)
                    with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp:
                        tmp.write(img_bytes)
                        pil_images.append(Image.open(tmp.name))
                
                inputs = processor(text=prompt, images=pil_images, return_tensors="pt").to(device)
            else:
                inputs = processor(text=prompt, return_tensors="pt").to(device)
            
            # Generate
            with torch.no_grad():
                outputs = model.generate(
                    **inputs,
                    max_new_tokens=request.max_tokens,
                    temperature=request.temperature,
                    do_sample=True
                )
            
            # Decode response
            response_text = processor.decode(outputs[0], skip_special_tokens=True)
            response_text = response_text.split("Assistant: ")[-1].strip()
            
            return ChatResponse(
                id=f"chatcmpl-{int(datetime.now().timestamp())}",
                created=int(datetime.now().timestamp()),
                model=MODEL_ID,
                choices=[{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": response_text
                    },
                    "finish_reason": "stop"
                }]
            )
            
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def main():
    """Main entry point"""
    logger.info("Starting Gemi Inference Server with lazy loading...")
    logger.info(f"Python: {sys.version}")
    logger.info(f"Model will be loaded on first request")
    
    # Don't load ML libraries at startup
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=11435,
        log_level="info"
    )

if __name__ == "__main__":
    main()