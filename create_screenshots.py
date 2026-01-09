#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os

# Target dimensions
PORTRAIT_WIDTH = 1284
PORTRAIT_HEIGHT = 2778
LANDSCAPE_WIDTH = 2778
LANDSCAPE_HEIGHT = 1284

input_dir = "/Users/sulemanimdad/.gemini/antigravity/brain/2d35d19b-6dc1-4061-8212-caf4aca8ca8e"
output_dir = os.path.join(input_dir, "appstore_v3")
os.makedirs(output_dir, exist_ok=True)

configs = [
    {
        "input": "uploaded_image_2_1767827086179.png",
        "output": "01_record.png",
        "headline": "Record Like a Pro",
        "subtitle": "Teleprompter overlay while you record",
        "gradient": [(30, 30, 70), (70, 30, 110)],
        "landscape": False
    },
    {
        "input": "uploaded_image_1_1767827086179.png",
        "output": "02_scripts.png",
        "headline": "Organize Scripts",
        "subtitle": "Create and manage your content",
        "gradient": [(90, 30, 90), (140, 50, 110)],
        "landscape": False
    },
    {
        "input": "uploaded_image_0_1767827086179.png",
        "output": "03_editor.png",
        "headline": "Write Your Script",
        "subtitle": "Easy editing with word count",
        "gradient": [(20, 70, 90), (40, 110, 130)],
        "landscape": False
    },
    {
        "input": "uploaded_image_3_1767827086179.png",
        "output": "04_landscape.png",
        "headline": "Landscape Mode",
        "subtitle": "Perfect for professionals",
        "gradient": [(190, 70, 30), (170, 40, 40)],
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

def draw_iphone_frame(canvas, screenshot, x, y, frame_width, frame_height, corner_radius=60, bezel=18):
    """Draw iPhone-style frame around screenshot"""
    draw = ImageDraw.Draw(canvas)
    
    # Outer frame (dark gray/black phone body)
    outer_x = x - bezel
    outer_y = y - bezel
    outer_w = frame_width + 2 * bezel
    outer_h = frame_height + 2 * bezel
    outer_radius = corner_radius + bezel
    
    # Draw phone body (rounded rectangle)
    draw.rounded_rectangle(
        [outer_x, outer_y, outer_x + outer_w, outer_y + outer_h],
        radius=outer_radius,
        fill=(20, 20, 25)
    )
    
    # Draw screen area (slightly rounded)
    draw.rounded_rectangle(
        [x, y, x + frame_width, y + frame_height],
        radius=corner_radius,
        fill=(0, 0, 0)
    )
    
    # Paste screenshot
    canvas.paste(screenshot, (x, y))
    
    # Draw Dynamic Island (notch) at top center
    notch_width = int(frame_width * 0.35)
    notch_height = 38
    notch_x = x + (frame_width - notch_width) // 2
    notch_y = y + 15
    draw.rounded_rectangle(
        [notch_x, notch_y, notch_x + notch_width, notch_y + notch_height],
        radius=19,
        fill=(20, 20, 25)
    )
    
    return canvas

def add_text(draw, text, y_pos, canvas_width, size, bold=False):
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)
    except:
        font = ImageFont.load_default()
    
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    x = (canvas_width - text_width) // 2
    
    draw.text((x+3, y_pos+3), text, font=font, fill=(0, 0, 0, 100))
    draw.text((x, y_pos), text, font=font, fill=(255, 255, 255))
    
    return bbox[3] - bbox[1]

for config in configs:
    print(f"Creating {config['output']}...")
    
    if config["landscape"]:
        canvas_w, canvas_h = LANDSCAPE_WIDTH, LANDSCAPE_HEIGHT
        text_area_height = 160
    else:
        canvas_w, canvas_h = PORTRAIT_WIDTH, PORTRAIT_HEIGHT
        text_area_height = 280
    
    canvas = create_gradient(canvas_w, canvas_h, config["gradient"][0], config["gradient"][1])
    draw = ImageDraw.Draw(canvas)
    
    # Load screenshot
    input_path = os.path.join(input_dir, config["input"])
    screenshot = Image.open(input_path).convert("RGB")
    
    if config["landscape"]:
        # Landscape: phone on right side, text on left
        phone_area_width = int(canvas_w * 0.65)
        available_height = canvas_h - 80
        
        scale_h = available_height / screenshot.height
        scale_w = (phone_area_width - 100) / screenshot.width
        scale = min(scale_w, scale_h) * 0.9
        
        new_w = int(screenshot.width * scale)
        new_h = int(screenshot.height * scale)
        screenshot = screenshot.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        x = canvas_w - new_w - 80
        y = (canvas_h - new_h) // 2
        
        # Add frame
        draw_iphone_frame(canvas, screenshot, x, y, new_w, new_h, corner_radius=30, bezel=12)
        
        # Text on left
        draw = ImageDraw.Draw(canvas)
        add_text(draw, config["headline"], canvas_h // 2 - 80, canvas_w // 2, 70, bold=True)
        add_text(draw, config["subtitle"], canvas_h // 2, canvas_w // 2, 35)
        
    else:
        # Portrait: text at top, large phone below
        available_height = canvas_h - text_area_height - 100
        available_width = canvas_w - 160
        
        scale_w = available_width / screenshot.width
        scale_h = available_height / screenshot.height
        scale = min(scale_w, scale_h)
        
        new_w = int(screenshot.width * scale)
        new_h = int(screenshot.height * scale)
        screenshot = screenshot.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        x = (canvas_w - new_w) // 2
        y = text_area_height + 40
        
        # Add frame
        draw_iphone_frame(canvas, screenshot, x, y, new_w, new_h, corner_radius=50, bezel=16)
        
        # Text at top
        draw = ImageDraw.Draw(canvas)
        add_text(draw, config["headline"], 50, canvas_w, 85, bold=True)
        add_text(draw, config["subtitle"], 155, canvas_w, 42)
    
    # Save
    output_path = os.path.join(output_dir, config["output"])
    canvas.save(output_path, "PNG", quality=95)
    print(f"  ✓ Saved: {config['output']} ({canvas_w}x{canvas_h})")

print("\n✅ All screenshots with device frames saved to:", output_dir)
