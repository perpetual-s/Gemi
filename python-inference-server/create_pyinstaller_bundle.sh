#!/bin/bash
# Create a self-contained GemiServer bundle using PyInstaller
# This creates a single executable that doesn't need Python installation

set -e

echo "🚀 Creating self-contained GemiServer with PyInstaller..."
echo "=================================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VENV_DIR="$SCRIPT_DIR/.pyinstaller_venv"

# Create a fresh virtual environment
echo -e "${YELLOW}Creating virtual environment...${NC}"
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
pip install --upgrade pip
pip install pyinstaller
pip install -r <(cat << 'EOF'
torch
torchvision
transformers
accelerate
sentencepiece
protobuf
huggingface-hub
fastapi
uvicorn
pydantic
pillow
soundfile
librosa
EOF
)

# Create spec file for PyInstaller
echo -e "${YELLOW}Creating PyInstaller spec file...${NC}"
cat > gemiserver.spec << 'EOF'
# -*- mode: python ; coding: utf-8 -*-
import sys
import os
from PyInstaller.utils.hooks import collect_all, collect_data_files

# Collect all transformers data
datas = []
hiddenimports = []

# Collect transformers
transformers_datas, transformers_binaries, transformers_hiddenimports = collect_all('transformers')
datas += transformers_datas
hiddenimports += transformers_hiddenimports

# Collect torch
torch_datas, torch_binaries, torch_hiddenimports = collect_all('torch')
datas += torch_datas
hiddenimports += torch_hiddenimports

# Add our files
datas += [
    ('hf_token.txt', '.'),
    ('legal', 'legal'),
]

a = Analysis(
    ['inference_server.py'],
    pathex=[],
    binaries=transformers_binaries + torch_binaries,
    datas=datas,
    hiddenimports=hiddenimports + [
        'PIL._tkinter_finder',
        'sklearn.utils._typedefs',
        'sklearn.neighbors._partition_nodes',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter'],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='GemiServer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=True,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

app = BUNDLE(
    exe,
    name='GemiServer.app',
    icon=None,
    bundle_identifier='com.gemi.server',
    info_plist={
        'CFBundleName': 'Gemi Server',
        'CFBundleDisplayName': 'Gemi Server',
        'CFBundleVersion': '1.0.0',
        'CFBundleShortVersionString': '1.0.0',
        'LSUIElement': True,
        'LSBackgroundOnly': True,
    },
)
EOF

# Build with PyInstaller
echo -e "${YELLOW}Building with PyInstaller (this will take several minutes)...${NC}"
pyinstaller --clean --noconfirm gemiserver.spec

# The output will be in dist/GemiServer.app
if [ -d "dist/GemiServer.app" ]; then
    echo -e "${GREEN}✅ Success! GemiServer.app created${NC}"
    echo "Location: $SCRIPT_DIR/dist/GemiServer.app"
    
    # Get bundle size
    BUNDLE_SIZE=$(du -sh "dist/GemiServer.app" | cut -f1)
    echo "Bundle size: $BUNDLE_SIZE"
    
    # Sign the bundle
    echo -e "${YELLOW}Signing bundle...${NC}"
    codesign --force --deep --sign - "dist/GemiServer.app"
    
    echo -e "${GREEN}✅ Bundle is ready for deployment!${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Deactivate virtual environment
deactivate

echo ""
echo "Next steps:"
echo "1. Test the bundle: open dist/GemiServer.app"
echo "2. Copy to Gemi.app/Contents/Resources/"
echo "3. No Python installation needed on user machines!"