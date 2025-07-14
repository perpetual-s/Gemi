"""
PyInstaller hook for encodings module
Ensures all encoding modules are collected
"""

from PyInstaller.utils.hooks import collect_submodules

# Collect all encodings submodules
hiddenimports = collect_submodules('encodings')

# Ensure critical encodings are included
critical_encodings = [
    'encodings.aliases',
    'encodings.utf_8',
    'encodings.ascii',
    'encodings.latin_1',
    'encodings.cp437',
    'encodings.cp1252',
    'encodings.mac_roman',
    'encodings.idna',
    'encodings.raw_unicode_escape',
    'encodings.unicode_escape',
    'encodings.utf_16',
    'encodings.utf_16_be',
    'encodings.utf_16_le',
    'encodings.utf_32',
    'encodings.utf_32_be',
    'encodings.utf_32_le',
]

# Add any missing critical encodings
for encoding in critical_encodings:
    if encoding not in hiddenimports:
        hiddenimports.append(encoding)