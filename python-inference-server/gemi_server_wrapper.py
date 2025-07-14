#!/usr/bin/env python3
"""
Wrapper script for GemiServer to ensure proper environment setup
This is the entry point for the PyInstaller bundle
"""

import os
import sys
import logging
from pathlib import Path

# Set up environment variables before importing anything else
os.environ['PYTORCH_ENABLE_MPS_FALLBACK'] = '1'
os.environ['TOKENIZERS_PARALLELISM'] = 'false'
os.environ['HF_HUB_DISABLE_SYMLINKS_WARNING'] = '1'
os.environ['TRANSFORMERS_OFFLINE'] = '0'  # Allow model downloads

# Try to load HF token from file if not already in environment
if 'HF_TOKEN' not in os.environ:
    token_paths = [
        Path(__file__).parent / 'hf_token.txt',
        Path(getattr(sys, '_MEIPASS', Path(__file__).parent)) / 'hf_token.txt',
    ]
    for token_path in token_paths:
        if token_path.exists():
            try:
                token = token_path.read_text().strip()
                if token:
                    os.environ['HF_TOKEN'] = token
                    break
            except Exception:
                pass

# Ensure we can find our modules when bundled
if getattr(sys, 'frozen', False):
    # Running in PyInstaller bundle
    bundle_dir = Path(sys._MEIPASS)
    
    # Set up cache directory in user's Application Support
    cache_dir = Path.home() / 'Library' / 'Application Support' / 'Gemi' / 'Models'
    cache_dir.mkdir(parents=True, exist_ok=True)
    
    os.environ['HF_HOME'] = str(cache_dir)
    os.environ['TRANSFORMERS_CACHE'] = str(cache_dir)
    os.environ['TORCH_HOME'] = str(cache_dir)
    
    # Configure logging for bundled app
    log_dir = Path.home() / 'Library' / 'Logs' / 'Gemi'
    log_dir.mkdir(parents=True, exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_dir / 'gemi_server.log'),
            logging.StreamHandler(sys.stdout)
        ]
    )
else:
    # Running in development
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler('gemi_inference_server.log')
        ]
    )

logger = logging.getLogger(__name__)

def main():
    """Main entry point"""
    logger.info("Starting Gemi Inference Server...")
    logger.info(f"Python: {sys.version}")
    logger.info(f"Frozen: {getattr(sys, 'frozen', False)}")
    
    if getattr(sys, 'frozen', False):
        logger.info(f"Bundle directory: {sys._MEIPASS}")
        logger.info(f"Model cache: {os.environ.get('HF_HOME')}")
    
    # Import and run the actual server
    try:
        # Import the main function directly
        from inference_server import main as server_main
        server_main()
    except Exception as e:
        logger.error(f"Failed to start server: {e}")
        raise

if __name__ == '__main__':
    main()