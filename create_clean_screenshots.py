#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os

PORTRAIT_W, PORTRAIT_H = 1284, 2778
LANDSCAPE_W, LANDSCAPE_H = 2778, 1284

input_dir = "/Users/sulemanimdad/.gemini/antigravity/brain/2d35d19b-6dc1-4061-8212-caf4aca8ca8e"
output_dir = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/fastlane/metadata/en-US/screenshots"

# Orange/Desert Titanium color
FRAME_COLOR = (205, 155, 95)  # Gold/orange titanium
FRAME_DARK = (165, 125, 75)   # Darker edge
FRAME_LIGHT = (225, 180, 120) # Highlight

configs = [
    {
        "screenshot": "uploaded_image_2_1767827086179.png",
        "output": "01_record.png",
        "headline": "Record Like a Pro",
        "subtitle": "Teleprompter while recording",
        "colors": [(50, 25, 100), (90, 35, 145)],
        "landscape": False
    },
    {
        "screenshot": "uploaded_image_1_1767827086179.png",
        "output": "02_scripts.png",
        "headline": "Organize Scripts",
        "subtitle": "Manage your content",
        "colors": [(170, 35, 90), (210, 55, 130)],
        "landscape": False
    },
    {
        "screenshot": "uploaded_image_0_1767827086179.png",
        "output": "03_editor.png",
        "headline": "Write Scripts",
        "subtitle": "Easy editing",
        "colors": [(15, 110, 130), (35, 150, 170)],
        "landscape": False
    },
    {
        "screenshot": "uploaded_image_3_1767827086179.png",
        "output": "04_landscape.png",
        "headline": "Landscape Mode",
        "subtitle": "Professional recording",
        "colors": [(210, 95, 35), (190, 55, 35)],
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
    # Shadow
    draw.text((x+4, y+4), text, font=font, fill=(0, 0, 0, 100))
    # Main text
    draw.text((x, y), text, font=font, fill=(255, 255, 255))

def draw_iphone_frame(canvas, screenshot, x, y, width, height, corner_radius=55, bezel=20):
    """Draw a clean iPhone frame programmatically"""
    draw = ImageDraw.Draw(canvas)
    
    # Outer frame dimensions
    outer_x = x - bezel
    outer_y = y - bezel
    outer_w = width + 2 * bezel
    outer_h = height + 2 * bezel
    outer_r = corner_radius + bezel
    
    # Draw outer phone body (main titanium color)
    draw.rounded_rectangle(
        [outer_x, outer_y, outer_x + outer_w, outer_y + outer_h],
        radius=outer_r,
        fill=FRAME_COLOR
    )
    
    # Left edge highlight
    draw.rounded_rectangle(
        [outer_x, outer_y, outer_x + 8, outer_y + outer_h],
        radius=4,
        fill=FRAME_LIGHT
    )
    
    # Right edge shadow
    draw.rounded_rectangle(
        [outer_x + outer_w - 8, outer_y, outer_x + outer_w, outer_y + outer_h],
        radius=4,
        fill=FRAME_DARK
    )
    
    # Side button (right side)
    btn_y = outer_y + 180
    draw.rounded_rectangle(
        [outer_x + outer_w - 4, btn_y, outer_x + outer_w + 4, btn_y + 90],
        radius=3,
        fill=FRAME_DARK
    )
    
    # Volume buttons (left side)
    draw.rounded_rectangle(
        [outer_x - 4, outer_y + 150, outer_x + 2, outer_y + 200],
        radius=2,
        fill=FRAME_DARK
    )
    draw.rounded_rectangle(
        [outer_x - 4, outer_y + 220, outer_x + 2, outer_y + 290],
        radius=2,
        fill=FRAME_DARK
    )
    
    # Inner bezel (dark edge around screen)
    draw.rounded_rectangle(
        [x - 4, y - 4, x + width + 4, y + height + 4],
        radius=corner_radius + 2,
        fill=(30, 30, 35)
    )
    
    # Screen background (black)
    draw.rounded_rectangle(
        [x, y, x + width, y + height],
        radius=corner_radius,
        fill=(0, 0, 0)
    )
    
    # Resize and paste screenshot
    screenshot_resized = screenshot.resize((width, height), Image.Resampling.LANCZOS)
    
    # Create rounded mask
    mask = Image.new('L', (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, width, height], radius=corner_radius - 5, fill=255)
    
    canvas.paste(screenshot_resized, (x, y), mask)
    
    # Draw Dynamic Island
    notch_w = int(width * 0.28)
    notch_h = 36
    notch_x = x + (width - notch_w) // 2
    notch_y = y + 18
    draw.rounded_rectangle(
        [notch_x, notch_y, notch_x + notch_w, notch_y + notch_h],
        radius=18,
        fill=(15, 15, 18)
    )
    
    # Camera dot in Dynamic Island
    cam_r = 8
    cam_x = notch_x + notch_w - 35
    cam_y = notch_y + notch_h // 2
    draw.ellipse([cam_x - cam_r, cam_y - cam_r, cam_x + cam_r, cam_y + cam_r], fill=(25, 25, 30))
    draw.ellipse([cam_x - cam_r + 2, cam_y - cam_r + 2, cam_x + cam_r - 2, cam_y + cam_r - 2], fill=(10, 15, 40))

for cfg in configs:
    print(f"\nCreating {cfg['output']}...")
    
    screenshot = Image.open(os.path.join(input_dir, cfg["screenshot"])).convert("RGB")
    
    if cfg["landscape"]:
        canvas = create_gradient(LANDSCAPE_W, LANDSCAPE_H, cfg["colors"][0], cfg["colors"][1])
        
        # Calculate phone dimensions (horizontal)
        phone_h = int(LANDSCAPE_H * 0.72)
        phone_w = int(phone_h * (screenshot.width / screenshot.height))
        
        # Position phone on far right
        phone_x = LANDSCAPE_W - phone_w - 80
        phone_y = (LANDSCAPE_H - phone_h) // 2
        
        draw_iphone_frame(canvas, screenshot, phone_x, phone_y, phone_w, phone_h, 
                         corner_radius=35, bezel=14)
        
        # Text on LEFT side only (not centered across full width)
        draw = ImageDraw.Draw(canvas)
        left_margin = 100
        # Draw text aligned left
        try:
            font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 90)
            font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 45)
        except:
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
        
        y_headline = LANDSCAPE_H // 2 - 60
        y_subtitle = LANDSCAPE_H // 2 + 50
        
        draw.text((left_margin + 4, y_headline + 4), cfg["headline"], font=font_large, fill=(0, 0, 0, 100))
        draw.text((left_margin, y_headline), cfg["headline"], font=font_large, fill=(255, 255, 255))
        draw.text((left_margin + 3, y_subtitle + 3), cfg["subtitle"], font=font_small, fill=(0, 0, 0, 100))
        draw.text((left_margin, y_subtitle), cfg["subtitle"], font=font_small, fill=(255, 255, 255))
        
    else:
        canvas = create_gradient(PORTRAIT_W, PORTRAIT_H, cfg["colors"][0], cfg["colors"][1])
        
        # Text at top
        draw = ImageDraw.Draw(canvas)
        add_text(draw, cfg["headline"], 90, PORTRAIT_W, 105)
        add_text(draw, cfg["subtitle"], 220, PORTRAIT_W, 52)
        
        # Calculate phone dimensions
        text_area = 350
        available_h = PORTRAIT_H - text_area - 80
        phone_h = int(available_h * 0.95)
        phone_w = int(phone_h * (screenshot.width / screenshot.height))
        
        # Center phone
        phone_x = (PORTRAIT_W - phone_w) // 2
        phone_y = text_area + 20
        
        draw_iphone_frame(canvas, screenshot, phone_x, phone_y, phone_w, phone_h,
                         corner_radius=50, bezel=18)
    
    canvas.save(os.path.join(output_dir, cfg["output"]), "PNG")
    print(f"  ✓ Saved {cfg['output']} at {canvas.width}x{canvas.height}")

print("\n✅ All screenshots created with clean device frames!")
