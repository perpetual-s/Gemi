# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec file for Gemi Inference Server
Creates a standalone macOS app bundle with all dependencies
"""

import sys
import os
from pathlib import Path
from PyInstaller.utils.hooks import collect_data_files, collect_dynamic_libs, collect_submodules

# Get the absolute path to the project
project_dir = Path(os.path.abspath(SPECPATH))

# Analysis configuration
a = Analysis(
    ['gemi_server_wrapper.py', 'inference_server.py'],
    pathex=[str(project_dir)],
    binaries=[
        # Include dynamic libraries for audio processing
        *collect_dynamic_libs('soundfile'),
        *collect_dynamic_libs('librosa'),
    ],
    datas=[
        # Collect all transformers model files and configs
        *collect_data_files('transformers', include_py_files=True),
        # Include tokenizers data
        *collect_data_files('tokenizers'),
        # Include torch data files
        *collect_data_files('torch', include_py_files=False),
        # Include Pillow data
        *collect_data_files('PIL'),
        # Include legal notices for Gemma
        ('legal/NOTICE.txt', 'legal'),
        ('legal/GEMMA_TERMS_OF_USE.txt', 'legal'),
    ],
    hiddenimports=[
        # Core imports
        'fastapi',
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        
        # Transformers and ML
        'transformers',
        'transformers.models',
        'transformers.models.gemma',
        'transformers.models.gemma.modeling_gemma',
        'transformers.models.gemma.processing_gemma',
        'transformers.generation',
        'transformers.generation.streamers',
        'accelerate',
        'accelerate.utils',
        
        # HuggingFace Hub for authentication
        'huggingface_hub',
        'huggingface_hub.utils',
        'huggingface_hub.hf_api',
        'huggingface_hub.file_download',
        
        # PyTorch
        'torch',
        'torch.nn',
        'torch.nn.functional',
        'torch.utils',
        'torch.utils.data',
        'torchvision',
        'torchvision.transforms',
        'torchaudio',
        
        # Audio processing
        'soundfile',
        'librosa',
        'librosa.core',
        'scipy',
        'scipy.signal',
        'numpy',
        'numba',
        
        # Image processing
        'PIL',
        'PIL.Image',
        'PIL.ImageOps',
        
        # Async and networking
        'asyncio',
        'aiofiles',
        'httpx',
        'websockets',
        
        # Standard library modules that might be missed
        'multiprocessing',
        'concurrent',
        'concurrent.futures',
        'threading',
        'queue',
        'pickle',
        'copyreg',
        'typing_extensions',
        'pydantic',
        'pydantic.main',
        'email',
        'email.mime',
        'email.mime.text',
        'email.mime.multipart',
        'email.mime.base',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Exclude GUI libraries we don't need
        'tkinter',
        'matplotlib',
        'PyQt5',
        'PyQt6',
        'PySide2',
        'PySide6',
        # Exclude test frameworks
        'pytest',
        'unittest',
        # Exclude development tools
        'IPython',
        'jupyter',
        'notebook',
        'sphinx',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
)

# Create PYZ archive
pyz = PYZ(
    a.pure,
    a.zipped_data,
    cipher=None,
)

# Create the executable
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='GemiServer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=True,
    upx=False,  # Don't use UPX compression on macOS
    console=False,  # No console window
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,  # Use native architecture
    codesign_identity=None,  # Will be signed later
    entitlements_file=None,
)

# Collect all files
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=True,
    upx=False,
    upx_exclude=[],
    name='GemiServer',
)

# Create macOS app bundle
app = BUNDLE(
    coll,
    name='GemiServer.app',
    icon=None,  # Icon will be added later if available
    bundle_identifier='com.gemi.inference-server',
    info_plist={
        'CFBundleName': 'Gemi Inference Server',
        'CFBundleDisplayName': 'Gemi Server',
        'CFBundleGetInfoString': 'Gemi Inference Server for Gemma 3n',
        'CFBundleIdentifier': 'com.gemi.inference-server',
        'CFBundleVersion': '1.0.0',
        'CFBundleShortVersionString': '1.0.0',
        'CFBundleSignature': 'GEMI',
        'NSHighResolutionCapable': True,
        'NSRequiresAquaSystemAppearance': False,
        'LSUIElement': True,  # Hide from dock
        'LSBackgroundOnly': True,  # Background app
        'NSAppleEventsUsageDescription': 'Gemi Server needs to process AI requests.',
        # Environment variables
        'LSEnvironment': {
            'PYTORCH_ENABLE_MPS_FALLBACK': '1',
            'TOKENIZERS_PARALLELISM': 'false',
            'HF_HUB_DISABLE_SYMLINKS_WARNING': '1',
            'TRANSFORMERS_OFFLINE': '0',  # Allow model downloads
        }
    },
)