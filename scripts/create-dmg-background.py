#!/usr/bin/env python3

"""
Create an enhanced DMG background with arrow and welcome message for Gemi
"""

import os
import sys

# Check if Pillow is installed
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Installing Pillow for image generation...")
    os.system(f"{sys.executable} -m pip install Pillow")
    from PIL import Image, ImageDraw, ImageFont

def create_dmg_background():
    # Create a new image with a subtle gradient background
    width, height = 660, 400
    img = Image.new('RGB', (width, height), (248, 248, 248))
    draw = ImageDraw.Draw(img)
    
    # Create gradient background
    for y in range(height):
        # Subtle gradient from light gray to white
        color_value = int(248 + (255 - 248) * (y / height))
        draw.rectangle([(0, y), (width, y + 1)], fill=(color_value, color_value, color_value))
    
    # Try to load a system font
    font_size = 24
    welcome_font_size = 16
    try:
        # Try different font paths
        font_paths = [
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/Avenir.ttc",
            "/Library/Fonts/Arial.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf"
        ]
        font = None
        welcome_font = None
        for font_path in font_paths:
            if os.path.exists(font_path):
                try:
                    font = ImageFont.truetype(font_path, font_size)
                    welcome_font = ImageFont.truetype(font_path, welcome_font_size)
                    break
                except:
                    continue
        if not font:
            font = ImageFont.load_default()
            welcome_font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()
        welcome_font = ImageFont.load_default()
    
    # Add welcome message at the top
    welcome_text = "Welcome to Gemi"
    subtitle_text = "Your elegant AI diary, designed for privacy"
    
    # Calculate text positions
    welcome_bbox = draw.textbbox((0, 0), welcome_text, font=font)
    welcome_width = welcome_bbox[2] - welcome_bbox[0]
    welcome_x = (width - welcome_width) // 2
    
    subtitle_bbox = draw.textbbox((0, 0), subtitle_text, font=welcome_font)
    subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
    subtitle_x = (width - subtitle_width) // 2
    
    # Draw welcome text with shadow effect
    shadow_offset = 1
    draw.text((welcome_x + shadow_offset, 25 + shadow_offset), welcome_text, 
              fill=(200, 200, 200), font=font)
    draw.text((welcome_x, 25), welcome_text, fill=(80, 80, 80), font=font)
    
    draw.text((subtitle_x + shadow_offset, 55 + shadow_offset), subtitle_text, 
              fill=(200, 200, 200), font=welcome_font)
    draw.text((subtitle_x, 55), subtitle_text, fill=(120, 120, 120), font=welcome_font)
    
    # Draw arrow from Gemi.app to Applications
    # App icon will be at (180, 185) with size 128
    # Applications icon will be at (480, 185) with size 128
    
    # Arrow start and end points (adjusted for actual DMG layout)
    arrow_start_x = 220  # Right edge of Gemi icon
    arrow_end_x = 380  # Left edge of Applications icon
    arrow_y = 250  # Center Y position
    
    # Draw curved arrow
    arrow_color = (100, 100, 100)
    arrow_width = 3
    
    # Draw arrow shaft
    draw.line([(arrow_start_x, arrow_y), (arrow_end_x - 15, arrow_y)], 
              fill=arrow_color, width=arrow_width)
    
    # Draw arrowhead
    arrowhead_size = 12
    draw.polygon([
        (arrow_end_x, arrow_y),
        (arrow_end_x - arrowhead_size, arrow_y - arrowhead_size//2),
        (arrow_end_x - arrowhead_size, arrow_y + arrowhead_size//2)
    ], fill=arrow_color)
    
    # Add instruction text below the arrow
    instruction_text = "Drag Gemi to Applications folder to install"
    instruction_bbox = draw.textbbox((0, 0), instruction_text, font=welcome_font)
    instruction_width = instruction_bbox[2] - instruction_bbox[0]
    instruction_x = (width - instruction_width) // 2
    
    draw.text((instruction_x + 1, arrow_y + 25 + 1), instruction_text, 
              fill=(200, 200, 200), font=welcome_font)
    draw.text((instruction_x, arrow_y + 25), instruction_text, 
              fill=(100, 100, 100), font=welcome_font)
    
    # Add subtle border
    draw.rectangle([(0, 0), (width-1, height-1)], outline=(230, 230, 230), width=1)
    
    # Save the image
    output_path = "/Users/chaeho/Documents/project-Gemi/Documentation/assets/dmg-background-enhanced.png"
    img.save(output_path, "PNG", optimize=True)
    print(f"Created enhanced DMG background: {output_path}")
    
    return output_path

if __name__ == "__main__":
    create_dmg_background()