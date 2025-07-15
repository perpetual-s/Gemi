# Gemi Build Scripts

Clean, organized scripts for building and packaging Gemi.

## 📁 Script Organization

```
scripts/
├── build_and_package.sh    # Main build orchestrator
├── create_dmg.sh          # DMG creator (beautiful installer)
├── test_deployment.sh     # Installation tester
├── clean_gemma_cache.sh   # Model cache cleaner
├── fix_sandbox.sh         # Sandbox permission fixer
└── README.md             # This file
```

## 🚀 Quick Start

```bash
# Build everything and create DMG
./build_and_package.sh

# Just create DMG from existing build
./create_dmg.sh

# Test the installation
./test_deployment.sh
```

## Scripts Overview

### `build_and_package.sh`
The master build orchestrator that creates a complete, self-contained Gemi installation:
- Builds GemiServer.app with UV (no Python required by users)
- Builds Gemi.app with Xcode
- Bundles server inside app for single-file deployment
- Creates professional DMG using advanced script

**Usage:**
```bash
./build_and_package.sh [Release|Debug] [yes|no]

# Examples:
./build_and_package.sh              # Release + DMG (default)
./build_and_package.sh Debug no     # Debug build, no DMG
./build_and_package.sh Release yes  # Release + DMG (explicit)
```

### `create_dmg.sh`
The one true DMG creator - beautiful, simple, and professional:
- Smart app detection (finds Gemi.app automatically)
- Custom drag-to-install interface with visual guide
- Beautiful 600x400 window with 128px icons
- Background image and volume icon support
- Maximum compression (zlib-level=9)
- Automatic code signing if available
- Clear progress indicators

**Usage:**
```bash
# Create DMG (auto-detects Gemi.app)
./create_dmg.sh

# Create DMG from specific app
./create_dmg.sh /path/to/Gemi.app
```

### `test_deployment.sh` 
Comprehensive zero-friction deployment validator:
- Simulates complete user installation flow
- Verifies server auto-start
- Tests port conflict handling
- Validates model download process
- Ensures truly zero manual setup

**Usage:**
```bash
# Run after building to verify deployment
./test_deployment.sh
```

## 🎯 Zero-Friction Deployment

Our scripts ensure users experience:
1. **Download** Gemi.dmg
2. **Drag** to Applications
3. **Launch** and use immediately

No manual installation of:
- ❌ Python/Conda/UV
- ❌ Dependencies  
- ❌ HuggingFace tokens
- ❌ Terminal commands

Everything is bundled and configured automatically!

## 📁 Output Locations

- **Gemi.app**: Xcode DerivedData or `gemi-release/`
- **GemiServer.app**: `python-inference-server/dist/`
- **Gemi.dmg**: Project root (gitignored)
- **Server logs**: `~/Library/Logs/GemiServer.log`

Note: DMG files are automatically gitignored to keep the repository clean.

## 🛠 Requirements

- **Xcode** with command line tools
- **UV** installed (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- **~2GB** free space for build
- **~20GB** free space for model (first run only)

## 🔧 Advanced Usage

### Development Workflow
```bash
# Quick iteration during development
./build_and_package.sh Debug no
open ~/Library/Developer/Xcode/DerivedData/Gemi-*/Build/Products/Debug/Gemi.app
```

### Production Release
```bash
# Clean build for distribution
./build_and_package.sh Release yes
./test_deployment.sh  # Verify before shipping
```

### Server-Only Build
```bash
cd ../python-inference-server
./create_bundle_uv.sh
# Test server standalone
open dist/GemiServer.app
```

## 🐛 Troubleshooting

### Build Failures
```bash
# Verify Xcode tools
xcode-select --install

# Check UV installation  
which uv || curl -LsSf https://astral.sh/uv/install.sh | sh

# Clean build artifacts
rm -rf ~/Library/Developer/Xcode/DerivedData/Gemi-*
```

### Server Issues
```bash
# Check server logs
tail -f ~/Library/Logs/GemiServer.log

# Kill stuck processes
pkill -f GemiServer
pkill -f inference_server
```

### DMG Problems
- Ensure 2GB+ free space
- Close any mounted Gemi volumes
- Check for existing Gemi.dmg and remove

## 🏆 The Result

These scripts deliver the $10 million vision:
- **Professional** installation experience
- **Zero** technical knowledge required
- **Instant** functionality after install
- **Reliable** even in edge cases

Your grandmother can install and use Gemi. That's our standard.