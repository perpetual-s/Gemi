#!/bin/bash

# Setup proper icons for Gemi app and DMG volume

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_SOURCE="$PROJECT_ROOT/Documentation/assets/gemi-icon-resize-2.png"
ICON_SET_PATH="$PROJECT_ROOT/Gemi/Gemi/Assets.xcassets/AppIcon.appiconset"

echo "🎨 Setting up Gemi icons..."

# Check if source icon exists
if [[ ! -f "$ICON_SOURCE" ]]; then
    echo "❌ Source icon not found at: $ICON_SOURCE"
    exit 1
fi

# Create all required icon sizes for macOS
echo "📐 Generating icon sizes..."

# Required sizes for macOS app icon
sizes=(16 32 64 128 256 512 1024)

for size in "${sizes[@]}"; do
    # 1x version
    output_1x="${ICON_SET_PATH}/icon_${size}x${size}.png"
    sips -z $size $size "$ICON_SOURCE" --out "$output_1x" >/dev/null 2>&1
    echo "  ✓ Created ${size}x${size} icon"
    
    # 2x version (except for 1024)
    if [ $size -lt 1024 ]; then
        size_2x=$((size * 2))
        output_2x="${ICON_SET_PATH}/icon_${size}x${size}@2x.png"
        sips -z $size_2x $size_2x "$ICON_SOURCE" --out "$output_2x" >/dev/null 2>&1
        echo "  ✓ Created ${size}x${size}@2x icon"
    fi
done

# Update Contents.json with all icon references
echo "📝 Updating Contents.json..."
cat > "${ICON_SET_PATH}/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Create ICNS file for DMG volume icon
echo "🎯 Creating ICNS for DMG volume..."
TEMP_ICONSET="$PROJECT_ROOT/Gemi.iconset"
mkdir -p "$TEMP_ICONSET"

# Copy icons with proper names for iconutil
cp "${ICON_SET_PATH}/icon_16x16.png" "$TEMP_ICONSET/icon_16x16.png"
cp "${ICON_SET_PATH}/icon_16x16@2x.png" "$TEMP_ICONSET/icon_16x16@2x.png"
cp "${ICON_SET_PATH}/icon_32x32.png" "$TEMP_ICONSET/icon_32x32.png"
cp "${ICON_SET_PATH}/icon_32x32@2x.png" "$TEMP_ICONSET/icon_32x32@2x.png"
cp "${ICON_SET_PATH}/icon_128x128.png" "$TEMP_ICONSET/icon_128x128.png"
cp "${ICON_SET_PATH}/icon_128x128@2x.png" "$TEMP_ICONSET/icon_128x128@2x.png"
cp "${ICON_SET_PATH}/icon_256x256.png" "$TEMP_ICONSET/icon_256x256.png"
cp "${ICON_SET_PATH}/icon_256x256@2x.png" "$TEMP_ICONSET/icon_256x256@2x.png"
cp "${ICON_SET_PATH}/icon_512x512.png" "$TEMP_ICONSET/icon_512x512.png"
cp "${ICON_SET_PATH}/icon_512x512@2x.png" "$TEMP_ICONSET/icon_512x512@2x.png"

# Create ICNS
iconutil -c icns "$TEMP_ICONSET" -o "$PROJECT_ROOT/Documentation/assets/VolumeIcon.icns"
rm -rf "$TEMP_ICONSET"

echo ""
echo "✨ Icon setup complete!"
echo ""
echo "Results:"
echo "  ✓ Generated all required app icon sizes"
echo "  ✓ Updated Assets.xcassets/AppIcon.appiconset"
echo "  ✓ Created VolumeIcon.icns for DMG"
echo ""
echo "Next steps:"
echo "  1. Build in Xcode (⌘+B)"
echo "  2. Run ./scripts/create-dmg.sh"