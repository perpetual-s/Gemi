#!/usr/bin/env python3
"""
Gemi Inference Server - Multimodal AI Backend for Gemma 3n
Direct HuggingFace integration for full multimodal support

This software includes Gemma 3n model support.
Gemma is provided under and subject to the Gemma Terms of Use 
found at ai.google.dev/gemma/terms
"""

import asyncio
import base64
import io
import json
import logging
import os
import sys
import time
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import AsyncGenerator, List, Optional, Dict, Any

import torch
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
from PIL import Image
from pydantic import BaseModel, Field
from transformers import (
    AutoProcessor,
    AutoModelForCausalLM,
    TextIteratorStreamer,
)
from threading import Thread
import uvicorn
from huggingface_hub import login

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('gemi_inference_server.log')
    ]
)
logger = logging.getLogger(__name__)

# Configure HuggingFace authentication
# Using fine-grained token with read-only access to Gemma models
HF_TOKEN = "REDACTED_TOKEN"
os.environ["HF_TOKEN"] = HF_TOKEN

# Login to HuggingFace Hub
try:
    login(token=HF_TOKEN, add_to_git_credential=False)
    logger.info("Successfully authenticated with HuggingFace Hub")
except Exception as e:
    logger.warning(f"HuggingFace authentication warning: {e}")
    # Continue anyway, the token might still work via environment variable

# Global variables
model = None
processor = None
device = None
model_loaded = False
download_progress = 0.0

# Model configuration
MODEL_ID = "google/gemma-3n-e4b-it"
MAX_NEW_TOKENS = 2048
TEMPERATURE = 0.7
TOP_P = 0.9
TOP_K = 40

# API Models for compatibility
class ChatMessage(BaseModel):
    role: str
    content: str
    images: Optional[List[str]] = None  # Base64 encoded images

class ChatRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    stream: bool = True
    options: Optional[Dict[str, Any]] = None

class ChatResponse(BaseModel):
    model: str
    created_at: str
    message: Optional[ChatMessage] = None
    done: bool = False
    total_duration: Optional[int] = None
    eval_count: Optional[int] = None
    prompt_eval_count: Optional[int] = None

class ModelInfo(BaseModel):
    name: str
    modified_at: str
    size: int
    digest: str

class ModelsResponse(BaseModel):
    models: List[ModelInfo]

class PullRequest(BaseModel):
    name: str
    stream: Optional[bool] = True

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    device: str
    mps_available: bool
    download_progress: float

# Lifespan manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage model loading on startup and cleanup on shutdown"""
    logger.info("Starting Gemi Inference Server...")
    
    # Start model loading in background
    asyncio.create_task(load_model_async())
    
    yield
    
    # Cleanup
    logger.info("Shutting down Gemi Inference Server...")
    global model, processor
    model = None
    processor = None
    torch.mps.empty_cache() if torch.backends.mps.is_available() else None

# Initialize FastAPI app
app = FastAPI(
    title="Gemi Inference Server",
    version="1.0.0",
    description="Multimodal AI backend for Gemi using Gemma 3n",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_device():
    """Determine the best available device"""
    if torch.backends.mps.is_available():
        return torch.device("mps")
    elif torch.cuda.is_available():
        return torch.device("cuda")
    else:
        return torch.device("cpu")

async def load_model_async():
    """Load the model asynchronously with progress tracking"""
    global model, processor, device, model_loaded, download_progress
    
    try:
        device = get_device()
        logger.info(f"Using device: {device}")
        
        # Set cache directory
        cache_dir = Path.home() / ".cache" / "huggingface"
        os.environ["HF_HOME"] = str(cache_dir)
        
        logger.info(f"Loading model: {MODEL_ID}")
        download_progress = 0.1
        
        # Load processor first (smaller download)
        processor = AutoProcessor.from_pretrained(
            MODEL_ID,
            cache_dir=cache_dir,
            trust_remote_code=True
        )
        download_progress = 0.2
        logger.info("Processor loaded successfully")
        
        # Configure model loading
        torch_dtype = torch.bfloat16 if device.type in ["mps", "cuda"] else torch.float32
        
        # Load model with optimizations
        logger.info("Loading model weights... This may take several minutes on first run.")
        download_progress = 0.3
        
        model = AutoModelForCausalLM.from_pretrained(
            MODEL_ID,
            cache_dir=cache_dir,
            torch_dtype=torch_dtype,
            device_map="auto" if device.type == "cuda" else None,
            trust_remote_code=True,
            low_cpu_mem_usage=True,
        )
        
        download_progress = 0.8
        
        # Move to device if not using device_map
        if device.type != "cuda":
            model = model.to(device)
        
        model.eval()
        download_progress = 1.0
        model_loaded = True
        
        logger.info(f"Model loaded successfully on {device}")
        
        # Run a test inference to ensure everything works
        await test_model()
        
    except Exception as e:
        logger.error(f"Failed to load model: {str(e)}")
        download_progress = -1.0  # Indicate error
        raise

async def test_model():
    """Run a simple test to ensure model works"""
    try:
        test_messages = [
            {"role": "user", "content": "Hello!"}
        ]
        
        inputs = processor.apply_chat_template(
            test_messages,
            add_generation_prompt=True,
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
        ).to(device)
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=10,
                do_sample=False,
            )
        
        logger.info("Model test passed")
    except Exception as e:
        logger.error(f"Model test failed: {str(e)}")
        raise

def process_multimodal_messages(messages: List[ChatMessage]) -> List[Dict[str, Any]]:
    """Convert our ChatMessage format to HuggingFace format"""
    processed_messages = []
    
    for msg in messages:
        if msg.role == "system":
            processed_messages.append({
                "role": "system",
                "content": [{"type": "text", "text": msg.content}]
            })
        elif msg.role == "user":
            content = []
            
            # Add images if present
            if msg.images:
                for img_base64 in msg.images:
                    try:
                        # Decode base64 image
                        img_data = base64.b64decode(img_base64)
                        img = Image.open(io.BytesIO(img_data))
                        content.append({"type": "image", "image": img})
                    except Exception as e:
                        logger.error(f"Failed to decode image: {str(e)}")
            
            # Add text
            content.append({"type": "text", "text": msg.content})
            
            processed_messages.append({
                "role": "user",
                "content": content
            })
        elif msg.role == "assistant":
            processed_messages.append({
                "role": "assistant",
                "content": [{"type": "text", "text": msg.content}]
            })
    
    return processed_messages

async def generate_stream(messages: List[ChatMessage], options: Dict[str, Any]) -> AsyncGenerator[str, None]:
    """Generate streaming response"""
    try:
        # Process messages for multimodal
        processed_messages = process_multimodal_messages(messages)
        
        # Apply chat template
        inputs = processor.apply_chat_template(
            processed_messages,
            add_generation_prompt=True,
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
        ).to(device)
        
        # Extract generation parameters
        temperature = options.get("temperature", TEMPERATURE)
        max_new_tokens = options.get("num_predict", MAX_NEW_TOKENS)
        top_p = options.get("top_p", TOP_P)
        top_k = options.get("top_k", TOP_K)
        
        # Create streamer
        streamer = TextIteratorStreamer(
            processor.tokenizer,
            skip_prompt=True,
            skip_special_tokens=True
        )
        
        # Generation kwargs
        generation_kwargs = {
            **inputs,
            "max_new_tokens": max_new_tokens,
            "temperature": temperature,
            "top_p": top_p,
            "top_k": top_k,
            "do_sample": temperature > 0,
            "streamer": streamer,
            "pad_token_id": processor.tokenizer.pad_token_id,
            "eos_token_id": processor.tokenizer.eos_token_id,
        }
        
        # Start generation in separate thread
        thread = Thread(target=model.generate, kwargs=generation_kwargs)
        thread.start()
        
        # Stream tokens
        generated_text = ""
        for token in streamer:
            generated_text += token
            
            # Create response in compatible format
            response = ChatResponse(
                model=MODEL_ID,
                created_at=datetime.utcnow().isoformat() + "Z",
                message=ChatMessage(role="assistant", content=token),
                done=False
            )
            
            yield f"data: {response.json()}\n\n"
        
        # Final response
        final_response = ChatResponse(
            model=MODEL_ID,
            created_at=datetime.utcnow().isoformat() + "Z",
            message=ChatMessage(role="assistant", content=""),
            done=True,
            total_duration=int(time.time() * 1e9),  # nanoseconds
            eval_count=len(generated_text.split()),
            prompt_eval_count=inputs["input_ids"].shape[1]
        )
        
        yield f"data: {final_response.json()}\n\n"
        
        # Wait for generation to complete
        thread.join()
        
    except Exception as e:
        logger.error(f"Generation error: {str(e)}")
        error_response = {
            "error": str(e),
            "type": "generation_error"
        }
        yield f"data: {json.dumps(error_response)}\n\n"

# API Endpoints

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Gemi Inference Server",
        "version": "1.0.0",
        "model": MODEL_ID,
        "status": "ready" if model_loaded else "loading"
    }

@app.get("/api/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy" if model_loaded else "loading",
        model_loaded=model_loaded,
        device=str(device) if device else "not_initialized",
        mps_available=torch.backends.mps.is_available(),
        download_progress=download_progress
    )

@app.get("/api/tags", response_model=ModelsResponse)
async def list_models():
    """List available models"""
    if not model_loaded:
        return ModelsResponse(models=[])
    
    return ModelsResponse(
        models=[
            ModelInfo(
                name=MODEL_ID,
                modified_at=datetime.utcnow().isoformat() + "Z",
                size=4000000000,  # Approximate 4B parameters
                digest="gemma3n-multimodal-e4b"
            )
        ]
    )

@app.post("/api/chat")
async def chat(request: ChatRequest):
    """Chat endpoint with streaming support"""
    if not model_loaded:
        if download_progress < 0:
            raise HTTPException(status_code=503, detail="Model failed to load")
        else:
            raise HTTPException(
                status_code=503, 
                detail=f"Model loading... Progress: {download_progress:.0%}"
            )
    
    try:
        # Extract options
        options = request.options or {}
        
        if request.stream:
            return StreamingResponse(
                generate_stream(request.messages, options),
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no"  # Disable nginx buffering
                }
            )
        else:
            # Non-streaming response
            processed_messages = process_multimodal_messages(request.messages)
            
            inputs = processor.apply_chat_template(
                processed_messages,
                add_generation_prompt=True,
                tokenize=True,
                return_dict=True,
                return_tensors="pt",
            ).to(device)
            
            with torch.no_grad():
                outputs = model.generate(
                    **inputs,
                    max_new_tokens=options.get("num_predict", MAX_NEW_TOKENS),
                    temperature=options.get("temperature", TEMPERATURE),
                    top_p=options.get("top_p", TOP_P),
                    top_k=options.get("top_k", TOP_K),
                    do_sample=options.get("temperature", TEMPERATURE) > 0,
                )
            
            generated_text = processor.decode(outputs[0], skip_special_tokens=True)
            # Remove the prompt from generated text
            prompt_text = processor.decode(inputs["input_ids"][0], skip_special_tokens=True)
            response_text = generated_text[len(prompt_text):].strip()
            
            return ChatResponse(
                model=MODEL_ID,
                created_at=datetime.utcnow().isoformat() + "Z",
                message=ChatMessage(role="assistant", content=response_text),
                done=True,
                total_duration=int(time.time() * 1e9),
                eval_count=len(response_text.split()),
                prompt_eval_count=inputs["input_ids"].shape[1]
            )
            
    except Exception as e:
        logger.error(f"Chat error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/pull")
async def pull_model(request: PullRequest):
    """Pull model endpoint (for compatibility)"""
    # Since we auto-load on startup, just return success
    if model_loaded:
        return {"status": "Model already loaded"}
    else:
        return {
            "status": "Model loading on startup",
            "progress": download_progress
        }

@app.post("/api/show")
async def show_model(request: Dict[str, str]):
    """Show model details"""
    if not model_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    return {
        "modelfile": f"FROM {MODEL_ID}",
        "parameters": f"temperature {TEMPERATURE}\ntop_p {TOP_P}\ntop_k {TOP_K}",
        "template": "{{ .System }}\n\n{{ .Prompt }}",
        "details": {
            "format": "gemma3n",
            "family": "gemma",
            "parameter_size": "4B",
            "quantization_level": "bfloat16"
        }
    }

# Error handling
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Global error: {exc}")
    return JSONResponse(
        status_code=500,
        content={"error": str(exc), "type": "internal_error"}
    )

def main():
    """Main entry point"""
    # MPS environment setup
    if torch.backends.mps.is_available():
        os.environ["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        logger.info("MPS (Metal Performance Shaders) is available")
    
    # Disable tokenizer parallelism warnings
    os.environ["TOKENIZERS_PARALLELISM"] = "false"
    
    # Run server
    uvicorn.run(
        "inference_server:app",
        host="127.0.0.1",
        port=11435,
        log_level="info",
        reload=False  # Disable reload in production
    )

if __name__ == "__main__":
    main()