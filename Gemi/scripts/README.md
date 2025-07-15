# Gemi Build Scripts

Production-ready build and deployment scripts for Gemi's zero-friction installation.

## 🚀 Quick Start

```bash
# Full release build with professional DMG
./build_and_package.sh

# Test the deployment experience
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

### `create_dmg_advanced.sh`
Creates a beautiful, professional DMG installer with:
- Custom drag-to-install interface
- Perfectly positioned app and Applications icons
- Optimized compression (zlib-level=9)
- Automatic code signing if certificates available
- Professional window styling

**Usage:**
```bash
# Create DMG from existing build
./create_dmg_advanced.sh
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

- **Gemi.app**: Xcode DerivedData
- **GemiServer.app**: `../python-inference-server/dist/`
- **Gemi.dmg**: Project root
- **Server logs**: `~/Library/Logs/GemiServer.log`

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