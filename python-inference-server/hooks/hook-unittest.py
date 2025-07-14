"""
PyInstaller hook for unittest module
Ensures all unittest submodules are collected
"""

from PyInstaller.utils.hooks import collect_submodules

# Collect all unittest submodules
hiddenimports = collect_submodules('unittest')