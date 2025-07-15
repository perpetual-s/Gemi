#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                       GEMI PREMIUM DMG BACKGROUND CREATOR                     ║
# ║                         Glass Morphism Gradient Design                        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -e

# Configuration
OUTPUT_DIR="Documentation/assets-icons"
OUTPUT_FILE="$OUTPUT_DIR/dmg-background-premium.png"
WIDTH=600
HEIGHT=400

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Create the premium background using Python with more sophisticated effects
python3 << 'EOF'
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

# Configuration
width, height = 600, 400
output_file = "Documentation/assets-icons/dmg-background-premium.png"

# Create base image with smooth gradient
img = Image.new('RGBA', (width, height), (255, 255, 255, 0))
draw = ImageDraw.Draw(img)

# Create sophisticated multi-point gradient
def create_radial_gradient(w, h, colors):
    """Create a smooth radial gradient with multiple color stops"""
    # Create gradient array
    gradient = np.zeros((h, w, 4), dtype=np.uint8)
    
    # Center points for gradient origins
    centers = [
        (0.2, 0.2),      # Top-left: soft blue
        (0.8, 0.2),      # Top-right: lavender
        (0.5, 0.8),      # Bottom-center: rose
        (0.1, 0.9),      # Bottom-left: peach
        (0.9, 0.9),      # Bottom-right: mint
    ]
    
    # Colors for each center (RGBA)
    center_colors = [
        (232, 244, 253, 255),  # Soft sky blue
        (240, 230, 255, 255),  # Lavender mist
        (255, 228, 241, 255),  # Rose quartz
        (255, 243, 224, 255),  # Peach cream
        (224, 255, 243, 255),  # Mint whisper
    ]
    
    # Create mesh grid
    y, x = np.ogrid[:h, :w]
    
    # Initialize with first color
    for i in range(4):
        gradient[:, :, i] = center_colors[0][i]
    
    # Blend colors based on distance from centers
    for center, color in zip(centers, center_colors):
        cx, cy = int(center[0] * w), int(center[1] * h)
        
        # Calculate distance from this center
        dist = np.sqrt((x - cx)**2 + (y - cy)**2)
        max_dist = np.sqrt(w**2 + h**2) * 0.7
        
        # Normalize and invert (closer = stronger influence)
        influence = 1 - np.clip(dist / max_dist, 0, 1)
        influence = influence ** 2  # Smooth falloff
        
        # Blend this color
        for i in range(4):
            gradient[:, :, i] = gradient[:, :, i] * (1 - influence) + color[i] * influence
    
    return Image.fromarray(gradient.astype('uint8'), 'RGBA')

# Create the gradient background
gradient_img = create_radial_gradient(width, height, None)

# Apply subtle blur for smoother transitions
gradient_img = gradient_img.filter(ImageFilter.GaussianBlur(radius=10))

# Create glass morphism overlay
overlay = Image.new('RGBA', (width, height), (0, 0, 0, 0))
overlay_draw = ImageDraw.Draw(overlay)

# Main content area with glass effect
glass_rect = (40, 60, width-40, height-60)
overlay_draw.rounded_rectangle(
    glass_rect,
    radius=20,
    fill=(255, 255, 255, 25),  # Very subtle white
    outline=(255, 255, 255, 40),
    width=1
)

# Apply blur to create glass effect
overlay = overlay.filter(ImageFilter.GaussianBlur(radius=2))

# Add subtle inner glow
glow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
for i in range(5):
    alpha = 10 - i * 2
    inset = i * 2
    glow_draw.rounded_rectangle(
        (glass_rect[0] + inset, glass_rect[1] + inset, 
         glass_rect[2] - inset, glass_rect[3] - inset),
        radius=20 - i,
        outline=(255, 255, 255, alpha),
        width=1
    )

# Composite all layers
final = Image.alpha_composite(gradient_img, overlay)
final = Image.alpha_composite(final, glow)

# Add text elements
text_layer = Image.new('RGBA', (width, height), (0, 0, 0, 0))
text_draw = ImageDraw.Draw(text_layer)

# Title text with subtle styling
try:
    # Try to use system font
    title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
    subtitle_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
except:
    # Fallback to default
    title_font = ImageFont.load_default()
    subtitle_font = ImageFont.load_default()

# Main title
title_text = "Install Gemi"
subtitle_text = "Drag Gemi to Applications folder"

# Get text dimensions for centering
title_bbox = text_draw.textbbox((0, 0), title_text, font=title_font)
title_width = title_bbox[2] - title_bbox[0]
title_height = title_bbox[3] - title_bbox[1]

subtitle_bbox = text_draw.textbbox((0, 0), subtitle_text, font=subtitle_font)
subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]

# Draw text with subtle shadow
shadow_offset = 1
text_x = (width - title_width) // 2
text_y = 80

# Shadow
text_draw.text(
    (text_x + shadow_offset, text_y + shadow_offset),
    title_text,
    font=title_font,
    fill=(0, 0, 0, 30)
)

# Main text
text_draw.text(
    (text_x, text_y),
    title_text,
    font=title_font,
    fill=(60, 60, 70, 220)
)

# Subtitle
subtitle_x = (width - subtitle_width) // 2
subtitle_y = text_y + title_height + 10

text_draw.text(
    (subtitle_x, subtitle_y),
    subtitle_text,
    font=subtitle_font,
    fill=(100, 100, 110, 180)
)

# Add subtle app icon placeholders
icon_size = 100
icon_y = (height - icon_size) // 2 + 20

# Left icon area (Gemi)
left_icon_x = 100
icon_bg = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))
icon_draw = ImageDraw.Draw(icon_bg)
icon_draw.ellipse(
    (0, 0, icon_size, icon_size),
    fill=(255, 255, 255, 40),
    outline=(255, 255, 255, 60),
    width=1
)
icon_bg = icon_bg.filter(ImageFilter.GaussianBlur(radius=1))
text_layer.paste(icon_bg, (left_icon_x, icon_y), icon_bg)

# Right icon area (Applications)
right_icon_x = width - 100 - icon_size
text_layer.paste(icon_bg, (right_icon_x, icon_y), icon_bg)

# Add labels under icons
text_draw.text(
    (left_icon_x + icon_size//2 - 20, icon_y + icon_size + 10),
    "Gemi",
    font=subtitle_font,
    fill=(80, 80, 90, 200)
)

text_draw.text(
    (right_icon_x + icon_size//2 - 40, icon_y + icon_size + 10),
    "Applications",
    font=subtitle_font,
    fill=(80, 80, 90, 200)
)

# Arrow between icons
arrow_y = icon_y + icon_size // 2
arrow_start_x = left_icon_x + icon_size + 20
arrow_end_x = right_icon_x - 20
arrow_length = arrow_end_x - arrow_start_x

# Create gradient arrow
for i in range(arrow_length):
    x = arrow_start_x + i
    alpha = int(120 * (1 - abs(i - arrow_length/2) / (arrow_length/2)))
    text_draw.rectangle(
        (x, arrow_y - 1, x + 1, arrow_y + 1),
        fill=(100, 100, 110, alpha)
    )

# Arrow head
arrow_head = [
    (arrow_end_x - 10, arrow_y - 5),
    (arrow_end_x, arrow_y),
    (arrow_end_x - 10, arrow_y + 5)
]
text_draw.polygon(arrow_head, fill=(100, 100, 110, 120))

# Final composition
final = Image.alpha_composite(final, text_layer)

# Add very subtle noise texture for premium feel
noise = np.random.normal(0, 2, (height, width, 4))
noise_img = Image.fromarray(np.clip(final + noise, 0, 255).astype('uint8'), 'RGBA')

# Save the final image
noise_img.save(output_file, 'PNG', optimize=True, quality=95)
print(f"✓ Premium DMG background created: {output_file}")

# Also create a clean version without text
clean_version = Image.alpha_composite(gradient_img, overlay)
clean_version = Image.alpha_composite(clean_version, glow)
clean_noise = np.random.normal(0, 2, (height, width, 4))
clean_final = Image.fromarray(np.clip(clean_version + clean_noise, 0, 255).astype('uint8'), 'RGBA')
clean_final.save(output_file.replace('-premium', '-clean-premium'), 'PNG', optimize=True, quality=95)
print(f"✓ Clean DMG background created: {output_file.replace('-premium', '-clean-premium')}")

EOF

echo ""
echo "✨ Premium DMG backgrounds created successfully!"
echo ""
echo "Files created:"
echo "  • Documentation/assets-icons/dmg-background-premium.png (with text)"
echo "  • Documentation/assets-icons/dmg-background-clean-premium.png (without text)"
echo ""
echo "To use in DMG creation:"
echo "  1. Update create_gemi_dmg.sh to use dmg-background-premium.png"
echo "  2. Run ./create_gemi_dmg.sh"