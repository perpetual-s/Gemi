"""
Runtime hook to fix Python initialization in PyInstaller bundles
This ensures Python can find its standard library modules
"""

import sys
import os
import site
import locale

# Fix for "No module named encodings" error
if hasattr(sys, '_MEIPASS'):
    # We're running in a PyInstaller bundle
    bundle_dir = sys._MEIPASS
    
    # Set PYTHONHOME to the bundle directory
    os.environ['PYTHONHOME'] = bundle_dir
    
    # Ensure proper encoding is set
    if sys.platform == 'darwin':
        # macOS specific locale settings
        try:
            locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')
        except:
            try:
                locale.setlocale(locale.LC_ALL, 'C.UTF-8')
            except:
                pass
    
    # Force UTF-8 encoding
    os.environ['PYTHONIOENCODING'] = 'utf-8'
    os.environ['LANG'] = 'en_US.UTF-8'
    os.environ['LC_ALL'] = 'en_US.UTF-8'
    
    # Add standard library paths
    stdlib_paths = [
        bundle_dir,
        os.path.join(bundle_dir, 'lib'),
        os.path.join(bundle_dir, 'lib', 'python3.11'),
        os.path.join(bundle_dir, 'lib', 'python3.11', 'lib-dynload'),
        os.path.join(bundle_dir, 'lib', 'python3.11', 'site-packages'),
    ]
    
    # Update sys.path with valid paths
    for path in stdlib_paths:
        if os.path.exists(path) and path not in sys.path:
            sys.path.insert(0, path)
    
    # Set up site packages
    site.main()
    
    # Pre-import critical modules to ensure they're available
    critical_modules = [
        'encodings',
        'encodings.utf_8',
        'encodings.ascii',
        'encodings.latin_1',
        'codecs',
        'io',
        'abc',
        '_collections_abc',
        'os',
        'posixpath',  # Required on macOS
        'genericpath',
        'stat',
        '_thread',
        'threading',
        'types',
        'functools',
        'contextlib',
        'warnings',
        'importlib',
        'importlib.machinery',
        'importlib.util',
        'unittest',  # Required by PyTorch
        'unittest.mock',
        'unittest.case',
        'unittest.loader',
        'unittest.main',
        'unittest.runner',
        'unittest.result',
        'unittest.util',
    ]
    
    # Import critical modules
    for module_name in critical_modules:
        try:
            __import__(module_name)
        except ImportError as e:
            print(f"Warning: Could not import {module_name}: {e}")

# Multiprocessing support for macOS
if sys.platform == 'darwin':
    import multiprocessing
    multiprocessing.freeze_support()

print(f"Runtime hook executed. Python {sys.version}")
print(f"Executable: {sys.executable}")