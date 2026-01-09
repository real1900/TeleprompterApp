#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os

PORTRAIT_W, PORTRAIT_H = 1284, 2778
LANDSCAPE_W, LANDSCAPE_H = 2778, 1284

input_dir = "/Users/sulemanimdad/.gemini/antigravity/brain/2d35d19b-6dc1-4061-8212-caf4aca8ca8e"
output_dir = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/fastlane/metadata/en-US/screenshots"

portrait_frame_path = os.path.join(input_dir, "iphone_frame_only_1767829798427.png")
landscape_frame_path = os.path.join(input_dir, "iphone_frame_landscape_1767829811379.png")

configs = [
    {
        "screenshot": "uploaded_image_2_1767827086179.png",
        "output": "01_record.png",
        "headline": "Record Like a Pro",
        "subtitle": "Teleprompter while recording",
        "colors": [(60, 30, 120), (100, 40, 160)],
        "landscape": False
    },
    {
        "screenshot": "uploaded_image_1_1767827086179.png",
        "output": "02_scripts.png",
        "headline": "Organize Scripts",
        "subtitle": "Manage your content",
        "colors": [(180, 40, 100), (220, 60, 140)],
        "landscape": False
    },
    {
        "screenshot": "uploaded_image_0_1767827086179.png",
        "output": "03_editor.png",
        "headline": "Write Scripts",
        "subtitle": "Easy editing",
        "colors": [(20, 120, 140), (40, 160, 180)],
        "landscape": False
    },
    {
        "screenshot": "uploaded_image_3_1767827086179.png",
        "output": "04_landscape.png",
        "headline": "Landscape Mode",
        "subtitle": "Professional recording",
        "colors": [(220, 100, 40), (200, 60, 40)],
        "landscape": True
    }
]

def create_gradient(width, height, color1, color2):
    img = Image.new('RGB', (width, height))
    for y in range(height):
        ratio = y / height
        r = int(color1[0] + (color2[0] - color1[0]) * ratio)
        g = int(color1[1] + (color2[1] - color1[1]) * ratio)
        b = int(color1[2] + (color2[2] - color1[2]) * ratio)
        for x in range(width):
            img.putpixel((x, y), (r, g, b))
    return img

def add_text(draw, text, y, canvas_w, size):
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)
    except:
        font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    x = (canvas_w - text_w) // 2
    draw.text((x+4, y+4), text, font=font, fill=(0, 0, 0, 80))
    draw.text((x, y), text, font=font, fill=(255, 255, 255))

def make_transparent(img):
    """Make white/light gray and green pixels transparent"""
    img = img.convert("RGBA")
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            # Remove white/light gray background
            if r > 230 and g > 230 and b > 230:
                pixels[x, y] = (r, g, b, 0)
            # Remove green background
            elif g > r + 20 and g > b + 20 and g > 80:
                pixels[x, y] = (r, g, b, 0)
            # Remove pure black (screen area) - make semi-transparent to blend
            elif r < 25 and g < 25 and b < 25:
                pixels[x, y] = (r, g, b, 40)  # Very transparent black
    return img

print("Loading and processing device frames...")
portrait_frame_raw = Image.open(portrait_frame_path)
landscape_frame_raw = Image.open(landscape_frame_path)

portrait_frame = make_transparent(portrait_frame_raw)
landscape_frame = make_transparent(landscape_frame_raw)

for cfg in configs:
    print(f"\nCreating {cfg['output']}...")
    
    if cfg["landscape"]:
        canvas_w, canvas_h = LANDSCAPE_W, LANDSCAPE_H
        frame_orig = landscape_frame.copy()
    else:
        canvas_w, canvas_h = PORTRAIT_W, PORTRAIT_H
        frame_orig = portrait_frame.copy()
    
    # Create gradient background
    canvas = create_gradient(canvas_w, canvas_h, cfg["colors"][0], cfg["colors"][1])
    canvas = canvas.convert("RGBA")
    
    # Load app screenshot
    screenshot = Image.open(os.path.join(input_dir, cfg["screenshot"])).convert("RGBA")
    
    if cfg["landscape"]:
        # Scale frame
        frame_scale = min((canvas_w * 0.55) / frame_orig.width, (canvas_h * 0.80) / frame_orig.height)
        frame_w = int(frame_orig.width * frame_scale)
        frame_h = int(frame_orig.height * frame_scale)
        frame = frame_orig.resize((frame_w, frame_h), Image.Resampling.LANCZOS)
        
        frame_x = canvas_w - frame_w - 120
        frame_y = (canvas_h - frame_h) // 2
        
        # Screenshot goes UNDER the frame
        # Estimate screen area (inside the frame bezels)
        bezel = int(frame_w * 0.03)
        screen_x = frame_x + bezel
        screen_y = frame_y + bezel
        screen_w = frame_w - 2 * bezel
        screen_h = frame_h - 2 * bezel
        
        screenshot = screenshot.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
        canvas.paste(screenshot, (screen_x, screen_y), screenshot)
        canvas.paste(frame, (frame_x, frame_y), frame)
        
        # Text on left
        draw = ImageDraw.Draw(canvas)
        add_text(draw, cfg["headline"], canvas_h // 2 - 100, int(canvas_w * 0.38), 85)
        add_text(draw, cfg["subtitle"], canvas_h // 2 + 10, int(canvas_w * 0.38), 42)
        
    else:
        # Scale frame
        text_area = 380
        available_h = canvas_h - text_area - 50
        frame_scale = min((canvas_w * 0.88) / frame_orig.width, available_h / frame_orig.height)
        frame_w = int(frame_orig.width * frame_scale)
        frame_h = int(frame_orig.height * frame_scale)
        frame = frame_orig.resize((frame_w, frame_h), Image.Resampling.LANCZOS)
        
        frame_x = (canvas_w - frame_w) // 2
        frame_y = text_area
        
        # Screenshot under frame
        bezel_x = int(frame_w * 0.045)
        bezel_y = int(frame_h * 0.015)
        screen_x = frame_x + bezel_x
        screen_y = frame_y + bezel_y
        screen_w = frame_w - 2 * bezel_x
        screen_h = frame_h - 2 * bezel_y
        
        screenshot = screenshot.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
        canvas.paste(screenshot, (screen_x, screen_y), screenshot)
        canvas.paste(frame, (frame_x, frame_y), frame)
        
        # Text at top
        draw = ImageDraw.Draw(canvas)
        add_text(draw, cfg["headline"], 100, canvas_w, 110)
        add_text(draw, cfg["subtitle"], 235, canvas_w, 55)
    
    # Save as RGB
    canvas = canvas.convert("RGB")
    canvas.save(os.path.join(output_dir, cfg["output"]), "PNG")
    print(f"  ✓ Saved {cfg['output']} at {canvas_w}x{canvas_h}")

print("\n✅ All screenshots ready!")
