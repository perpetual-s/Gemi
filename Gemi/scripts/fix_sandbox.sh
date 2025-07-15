#!/bin/bash
# Fix sandbox issues for Gemi production build

echo "Fixing Gemi sandbox permissions..."

# Remove quarantine attributes
xattr -cr /Applications/Gemi.app

# Re-sign with proper entitlements
codesign --force --deep --sign - /Applications/Gemi.app

echo "Done! Please restart Gemi."