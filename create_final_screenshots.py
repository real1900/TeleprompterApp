#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
import math

# Exact App Store dimensions
PORTRAIT_W, PORTRAIT_H = 1284, 2778
LANDSCAPE_W, LANDSCAPE_H = 2778, 1284

input_dir = "/Users/sulemanimdad/.gemini/antigravity/brain/2d35d19b-6dc1-4061-8212-caf4aca8ca8e"
output_dir = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/fastlane/metadata/en-US/screenshots"

configs = [
    {
        "input": "uploaded_image_2_1767827086179.png",
        "output": "01_record.png",
        "headline": "Record Like a Pro",
        "subtitle": "Teleprompter while recording",
        "colors": [(60, 30, 120), (100, 40, 160)],  # Purple
        "landscape": False
    },
    {
        "input": "uploaded_image_1_1767827086179.png",
        "output": "02_scripts.png",
        "headline": "Organize Scripts",
        "subtitle": "Manage your content",
        "colors": [(180, 40, 100), (220, 60, 140)],  # Pink
        "landscape": False
    },
    {
        "input": "uploaded_image_0_1767827086179.png",
        "output": "03_editor.png",
        "headline": "Write Scripts",
        "subtitle": "Easy editing",
        "colors": [(20, 120, 140), (40, 160, 180)],  # Teal
        "landscape": False
    },
    {
        "input": "uploaded_image_3_1767827086179.png",
        "output": "04_landscape.png",
        "headline": "Landscape Mode",
        "subtitle": "Professional recording",
        "colors": [(220, 100, 40), (200, 60, 40)],  # Orange
        "landscape": True
    }
]

def create_gradient(width, height, color1, color2):
    """Create vertical gradient"""
    img = Image.new('RGB', (width, height))
    for y in range(height):
        ratio = y / height
        r = int(color1[0] + (color2[0] - color1[0]) * ratio)
        g = int(color1[1] + (color2[1] - color1[1]) * ratio)
        b = int(color1[2] + (color2[2] - color1[2]) * ratio)
        for x in range(width):
            img.putpixel((x, y), (r, g, b))
    return img

def draw_device_frame(canvas, screenshot, x, y, width, height, frame_color=(200, 160, 100), radius=50, bezel=20):
    """Draw orange/gold iPhone frame around screenshot"""
    draw = ImageDraw.Draw(canvas)
    
    # Outer frame (orange/gold titanium)
    outer_x = x - bezel
    outer_y = y - bezel
    outer_w = width + 2 * bezel
    outer_h = height + 2 * bezel
    outer_radius = radius + bezel
    
    # Draw phone body
    draw.rounded_rectangle(
        [outer_x, outer_y, outer_x + outer_w, outer_y + outer_h],
        radius=outer_radius,
        fill=frame_color
    )
    
    # Inner screen cutout (slightly darker)
    inner_frame = (frame_color[0]-30, frame_color[1]-30, frame_color[2]-30)
    draw.rounded_rectangle(
        [x-4, y-4, x + width+4, y + height+4],
        radius=radius,
        fill=inner_frame
    )
    
    # Screen background
    draw.rounded_rectangle(
        [x, y, x + width, y + height],
        radius=radius-4,
        fill=(0, 0, 0)
    )
    
    # Paste screenshot with rounded corners mask
    mask = Image.new('L', (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, width, height], radius=radius-8, fill=255)
    
    # Resize screenshot to fit
    screenshot = screenshot.resize((width, height), Image.Resampling.LANCZOS)
    canvas.paste(screenshot, (x, y), mask)
    
    # Draw Dynamic Island
    notch_w = int(width * 0.28)
    notch_h = 35
    notch_x = x + (width - notch_w) // 2
    notch_y = y + 18
    draw.rounded_rectangle(
        [notch_x, notch_y, notch_x + notch_w, notch_y + notch_h],
        radius=17,
        fill=(15, 15, 15)
    )
    
    # Side button (right side)
    btn_x = outer_x + outer_w - 3
    btn_y = outer_y + 200
    draw.rounded_rectangle([btn_x, btn_y, btn_x + 6, btn_y + 100], radius=3, fill=(180, 140, 80))
    
    return canvas

def add_text(draw, text, y, canvas_w, size, bold=True):
    """Add centered text with shadow"""
    try:
        # Try to load Helvetica Bold
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)
    except:
        font = ImageFont.load_default()
    
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    x = (canvas_w - text_w) // 2
    
    # Shadow
    draw.text((x+3, y+3), text, font=font, fill=(0, 0, 0, 80))
    # Main text
    draw.text((x, y), text, font=font, fill=(255, 255, 255))

for cfg in configs:
    print(f"Creating {cfg['output']}...")
    
    if cfg["landscape"]:
        canvas = create_gradient(LANDSCAPE_W, LANDSCAPE_H, cfg["colors"][0], cfg["colors"][1])
        
        # Load and process screenshot
        screenshot = Image.open(os.path.join(input_dir, cfg["input"])).convert("RGB")
        
        # Phone dimensions for landscape (horizontal phone)
        phone_h = int(LANDSCAPE_H * 0.75)
        phone_w = int(phone_h * (screenshot.width / screenshot.height))
        
        # Position phone on right side
        phone_x = LANDSCAPE_W - phone_w - 100
        phone_y = (LANDSCAPE_H - phone_h) // 2 + 50
        
        draw_device_frame(canvas, screenshot, phone_x, phone_y, phone_w, phone_h, 
                         frame_color=(200, 150, 90), radius=35, bezel=15)
        
        # Add text on left
        draw = ImageDraw.Draw(canvas)
        add_text(draw, cfg["headline"], 150, LANDSCAPE_W // 2, 100)
        add_text(draw, cfg["subtitle"], 280, LANDSCAPE_W // 2, 50)
        
    else:
        canvas = create_gradient(PORTRAIT_W, PORTRAIT_H, cfg["colors"][0], cfg["colors"][1])
        draw = ImageDraw.Draw(canvas)
        
        # Add text at top
        add_text(draw, cfg["headline"], 120, PORTRAIT_W, 100)
        add_text(draw, cfg["subtitle"], 250, PORTRAIT_W, 50)
        
        # Load screenshot
        screenshot = Image.open(os.path.join(input_dir, cfg["input"])).convert("RGB")
        
        # Phone dimensions (large, filling most of screen)
        phone_h = int(PORTRAIT_H * 0.72)
        phone_w = int(phone_h * (screenshot.width / screenshot.height))
        
        # Center phone below text
        phone_x = (PORTRAIT_W - phone_w) // 2
        phone_y = 380
        
        draw_device_frame(canvas, screenshot, phone_x, phone_y, phone_w, phone_h,
                         frame_color=(200, 150, 90), radius=55, bezel=18)
    
    # Save
    canvas.save(os.path.join(output_dir, cfg["output"]), "PNG")
    print(f"  ✓ {cfg['output']} saved at {canvas.width}x{canvas.height}")

print("\n✅ All screenshots created at exact App Store dimensions!")
