#!/usr/bin/env python3

"""
Create a beautiful DMG background with arrow and welcome text for Gemi
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

def create_arrow(draw, start_x, start_y, end_x, end_y, color=(100, 100, 100, 180), width=3):
    """Draw a curved arrow between two points"""
    # Calculate control points for bezier curve
    mid_x = (start_x + end_x) / 2
    mid_y = (start_y + end_y) / 2
    
    # Create a subtle curve
    control1_x = mid_x - 20
    control1_y = start_y - 30
    control2_x = mid_x + 20
    control2_y = end_y - 30
    
    # Draw the curved line
    points = []
    for t in np.linspace(0, 1, 100):
        t2 = t * t
        t3 = t2 * t
        mt = 1 - t
        mt2 = mt * mt
        mt3 = mt2 * mt
        
        x = mt3 * start_x + 3 * mt2 * t * control1_x + 3 * mt * t2 * control2_x + t3 * end_x
        y = mt3 * start_y + 3 * mt2 * t * control1_y + 3 * mt * t2 * control2_y + t3 * end_y
        points.append((x, y))
    
    # Draw the line segments
    for i in range(len(points) - 1):
        draw.line([points[i], points[i + 1]], fill=color, width=width)
    
    # Draw arrowhead
    arrow_length = 20
    arrow_angle = 30
    
    # Calculate arrow direction from last segment
    dx = end_x - points[-10][0]
    dy = end_y - points[-10][1]
    angle = np.arctan2(dy, dx)
    
    # Calculate arrowhead points
    x1 = end_x - arrow_length * np.cos(angle - np.radians(arrow_angle))
    y1 = end_y - arrow_length * np.sin(angle - np.radians(arrow_angle))
    x2 = end_x - arrow_length * np.cos(angle + np.radians(arrow_angle))
    y2 = end_y - arrow_length * np.sin(angle + np.radians(arrow_angle))
    
    # Draw arrowhead
    draw.polygon([end_x, end_y, x1, y1, x2, y2], fill=color)

def create_dmg_background(width=600, height=400, output_path="dmg-background.png"):
    """Create a beautiful DMG background"""
    
    # Create base image with gradient
    img = Image.new('RGBA', (width, height), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # Create subtle gradient background
    for y in range(height):
        # Gradient from light purple-gray to white
        ratio = y / height
        r = int(250 - ratio * 5)
        g = int(248 - ratio * 8)
        b = int(252 - ratio * 2)
        draw.rectangle([(0, y), (width, y + 1)], fill=(r, g, b))
    
    # Add subtle texture overlay
    noise = np.random.normal(0, 2, (height, width, 3))
    noise_img = Image.fromarray(np.clip(noise + 250, 0, 255).astype('uint8'), 'RGB')
    noise_img = noise_img.convert('RGBA')
    noise_img.putalpha(20)  # Very subtle
    img = Image.alpha_composite(img, noise_img)
    
    # Redraw for text and graphics
    draw = ImageDraw.Draw(img)
    
    # Try to use system font, fallback to default
    try:
        # Try SF Pro Display or similar
        title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 32)
        subtitle_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
        small_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
    except:
        # Fallback to default
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
        small_font = ImageFont.load_default()
    
    # Welcome text at top
    welcome_text = "Welcome to Gemi"
    text_bbox = draw.textbbox((0, 0), welcome_text, font=title_font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = (width - text_width) // 2
    
    # Draw text with subtle shadow
    draw.text((text_x + 2, 42), welcome_text, fill=(200, 200, 200, 100), font=title_font)
    draw.text((text_x, 40), welcome_text, fill=(80, 80, 80, 255), font=title_font)
    
    # Subtitle
    subtitle = "Your private AI diary, powered by Gemma"
    text_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = (width - text_width) // 2
    draw.text((text_x, 80), subtitle, fill=(120, 120, 120, 255), font=subtitle_font)
    
    # Draw curved arrow from left to right
    # Positions should match the script (150, 180) -> (450, 180)
    create_arrow(draw, 220, 200, 380, 200, color=(140, 140, 140, 180), width=3)
    
    # Installation instruction below icons
    instruction = "Drag Gemi to your Applications folder"
    text_bbox = draw.textbbox((0, 0), instruction, font=small_font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = (width - text_width) // 2
    draw.text((text_x, 320), instruction, fill=(100, 100, 100, 255), font=small_font)
    
    # Add subtle rounded rectangle frame
    padding = 20
    corner_radius = 20
    
    # Draw rounded rectangle border
    for i in range(2):  # Double border for depth
        offset = i * 2
        color = (230, 230, 230, 100 - i * 30)
        
        # Top left corner
        draw.arc([(padding + offset, padding + offset), 
                  (padding + corner_radius * 2 + offset, padding + corner_radius * 2 + offset)], 
                 180, 270, fill=color, width=1)
        
        # Top right corner
        draw.arc([(width - padding - corner_radius * 2 - offset, padding + offset), 
                  (width - padding - offset, padding + corner_radius * 2 + offset)], 
                 270, 0, fill=color, width=1)
        
        # Bottom left corner
        draw.arc([(padding + offset, height - padding - corner_radius * 2 - offset), 
                  (padding + corner_radius * 2 + offset, height - padding - offset)], 
                 90, 180, fill=color, width=1)
        
        # Bottom right corner
        draw.arc([(width - padding - corner_radius * 2 - offset, height - padding - corner_radius * 2 - offset), 
                  (width - padding - offset, height - padding - offset)], 
                 0, 90, fill=color, width=1)
        
        # Lines
        draw.line([(padding + corner_radius + offset, padding + offset), 
                   (width - padding - corner_radius - offset, padding + offset)], fill=color, width=1)
        draw.line([(padding + corner_radius + offset, height - padding - offset), 
                   (width - padding - corner_radius - offset, height - padding - offset)], fill=color, width=1)
        draw.line([(padding + offset, padding + corner_radius + offset), 
                   (padding + offset, height - padding - corner_radius - offset)], fill=color, width=1)
        draw.line([(width - padding - offset, padding + corner_radius + offset), 
                   (width - padding - offset, height - padding - corner_radius - offset)], fill=color, width=1)
    
    # Save the image
    img.save(output_path, 'PNG')
    print(f"Created beautiful DMG background: {output_path}")

if __name__ == "__main__":
    # Get the script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    
    # Output to Documentation/assets
    output_dir = os.path.join(project_root, "Documentation", "assets")
    os.makedirs(output_dir, exist_ok=True)
    
    output_path = os.path.join(output_dir, "dmg-background-premium-auto.png")
    
    # Create the background
    create_dmg_background(output_path=output_path)
    
    # Also create a clean version without arrow
    img_clean = Image.new('RGBA', (600, 400), (255, 255, 255, 255))
    draw_clean = ImageDraw.Draw(img_clean)
    
    # Gradient only version
    for y in range(400):
        ratio = y / 400
        r = int(250 - ratio * 5)
        g = int(248 - ratio * 8)
        b = int(252 - ratio * 2)
        draw_clean.rectangle([(0, y), (600, y + 1)], fill=(r, g, b))
    
    try:
        title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 32)
        subtitle_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    except:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
    
    # Just title and subtitle
    welcome_text = "Welcome to Gemi"
    text_bbox = draw_clean.textbbox((0, 0), welcome_text, font=title_font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = (600 - text_width) // 2
    
    draw_clean.text((text_x + 2, 42), welcome_text, fill=(200, 200, 200, 100), font=title_font)
    draw_clean.text((text_x, 40), welcome_text, fill=(80, 80, 80, 255), font=title_font)
    
    subtitle = "Your private AI diary, powered by Gemma"
    text_bbox = draw_clean.textbbox((0, 0), subtitle, font=subtitle_font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = (600 - text_width) // 2
    draw_clean.text((text_x, 80), subtitle, fill=(120, 120, 120, 255), font=subtitle_font)
    
    clean_path = os.path.join(output_dir, "dmg-background-clean-auto.png")
    img_clean.save(clean_path, 'PNG')
    print(f"Created clean DMG background: {clean_path}")