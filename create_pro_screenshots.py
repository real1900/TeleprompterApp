#!/usr/bin/env python3
"""Create App Store screenshots with perspective-transformed screenshots to match angled phone"""
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import os

PORTRAIT_W, PORTRAIT_H = 1284, 2778
LANDSCAPE_W, LANDSCAPE_H = 2778, 1284

frame_path = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/iphone17_frame.png"
input_dir = "/Users/sulemanimdad/.gemini/antigravity/brain/2d35d19b-6dc1-4061-8212-caf4aca8ca8e"
output_dir = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/fastlane/metadata/en-US/screenshots"

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
    img = Image.new('RGBA', (width, height))
    for y in range(height):
        ratio = y / height
        r = int(color1[0] + (color2[0] - color1[0]) * ratio)
        g = int(color1[1] + (color2[1] - color1[1]) * ratio)
        b = int(color1[2] + (color2[2] - color1[2]) * ratio)
        for x in range(width):
            img.putpixel((x, y), (r, g, b, 255))
    return img

def add_text(draw, text, y, canvas_w, size):
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)
    except:
        font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    x = (canvas_w - text_w) // 2
    draw.text((x+4, y+4), text, font=font, fill=(0, 0, 0, 100))
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))

def find_perspective_coeffs(src_coords, dst_coords):
    """Calculate perspective transform coefficients"""
    matrix = []
    for s, d in zip(src_coords, dst_coords):
        matrix.append([d[0], d[1], 1, 0, 0, 0, -s[0]*d[0], -s[0]*d[1]])
        matrix.append([0, 0, 0, d[0], d[1], 1, -s[1]*d[0], -s[1]*d[1]])
    A = np.matrix(matrix, dtype=float)
    B = np.array(src_coords).reshape(8)
    res = np.dot(np.linalg.inv(A.T * A) * A.T, B)
    return np.array(res).reshape(8)

def make_screen_transparent(img):
    """Make black/near-black pixels transparent"""
    data = np.array(img)
    black_mask = (data[:,:,0] < 25) & (data[:,:,1] < 25) & (data[:,:,2] < 25)
    data[black_mask, 3] = 0
    return Image.fromarray(data)

# Load device frame
print("Loading device frame...")
frame_orig = Image.open(frame_path).convert("RGBA")
frame_transparent = make_screen_transparent(frame_orig)
print(f"Frame size: {frame_orig.size}")

# Screen corners in the original 1868x2427 frame 
# Adjusted for better fit - pushing corners inward slightly
# Top-left, Top-right, Bottom-right, Bottom-left (clockwise)
SCREEN_CORNERS_ORIG = [
    (75, 60),      # Top-left (moved right and down)
    (690, 25),     # Top-right  
    (708, 2048),   # Bottom-right
    (30, 2090),    # Bottom-left
]

for cfg in configs:
    print(f"\nCreating {cfg['output']}...")
    
    screenshot = Image.open(os.path.join(input_dir, cfg["screenshot"])).convert("RGBA")
    
    if cfg["landscape"]:
        canvas = create_gradient(LANDSCAPE_W, LANDSCAPE_H, cfg["colors"][0], cfg["colors"][1])
        
        # For landscape: ROTATE the frame 90 degrees counter-clockwise
        frame_rotated = frame_transparent.rotate(90, expand=True)
        
        # Scale rotated frame to fit
        max_frame_w = int(LANDSCAPE_W * 0.55)
        frame_scale = max_frame_w / frame_rotated.width
        frame_w = max_frame_w
        frame_h = int(frame_rotated.height * frame_scale)
        frame = frame_rotated.resize((frame_w, frame_h), Image.Resampling.LANCZOS)
        
        # Position on right
        frame_x = LANDSCAPE_W - frame_w - 40
        frame_y = (LANDSCAPE_H - frame_h) // 2
        
        # Rotated screen corners (transform original corners by 90 CCW rotation)
        # When rotating 90 CCW: (x, y) -> (y, width - x)
        orig_w = frame_orig.width
        rotated_corners_orig = [
            (SCREEN_CORNERS_ORIG[0][1], orig_w - SCREEN_CORNERS_ORIG[0][0]),  # was TL, now BL
            (SCREEN_CORNERS_ORIG[1][1], orig_w - SCREEN_CORNERS_ORIG[1][0]),  # was TR, now TL
            (SCREEN_CORNERS_ORIG[2][1], orig_w - SCREEN_CORNERS_ORIG[2][0]),  # was BR, now TR
            (SCREEN_CORNERS_ORIG[3][1], orig_w - SCREEN_CORNERS_ORIG[3][0]),  # was BL, now BR
        ]
        # Reorder to: TL, TR, BR, BL
        rotated_corners_orig = [rotated_corners_orig[1], rotated_corners_orig[2], 
                                 rotated_corners_orig[3], rotated_corners_orig[0]]
        
        # Scale to current frame size
        orig_rotated_w = frame_orig.height  # After 90 rotation, width becomes height
        orig_rotated_h = frame_orig.width
        screen_corners = [
            (int(x * frame_w / orig_rotated_w), int(y * frame_h / orig_rotated_h)) 
            for x, y in rotated_corners_orig
        ]
        
        # Bounding box
        min_x = min(c[0] for c in screen_corners)
        max_x = max(c[0] for c in screen_corners)
        min_y = min(c[1] for c in screen_corners)
        max_y = max(c[1] for c in screen_corners)
        screen_w = max_x - min_x
        screen_h = max_y - min_y
        
        # Resize screenshot (rotate it for landscape orientation)
        screenshot_rotated = screenshot.rotate(0, expand=True)  # Already landscape
        screenshot_resized = screenshot_rotated.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
        
        # Perspective transform
        relative_corners = [(x - min_x, y - min_y) for x, y in screen_corners]
        coeffs = find_perspective_coeffs(
            [(0, 0), (screen_w, 0), (screen_w, screen_h), (0, screen_h)],
            relative_corners
        )
        screenshot_warped = screenshot_resized.transform(
            (screen_w, screen_h), 
            Image.Transform.PERSPECTIVE, 
            coeffs, 
            Image.Resampling.BICUBIC
        )
        
        # Create frame canvas
        screenshot_canvas = Image.new('RGBA', (frame_w, frame_h), (0, 0, 0, 0))
        screenshot_canvas.paste(screenshot_warped, (min_x, min_y), screenshot_warped)
        
        # Composite
        final_frame = Image.new('RGBA', (frame_w, frame_h), (0, 0, 0, 0))
        final_frame.paste(screenshot_canvas, (0, 0), screenshot_canvas)
        final_frame.paste(frame, (0, 0), frame)
        
        canvas.paste(final_frame, (frame_x, frame_y), final_frame)
        
        # Text on left
        draw = ImageDraw.Draw(canvas)
        try:
            font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 85)
            font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 42)
        except:
            font_large = font_small = ImageFont.load_default()
        
        draw.text((84, LANDSCAPE_H // 2 - 55 + 4), cfg["headline"], font=font_large, fill=(0, 0, 0, 100))
        draw.text((80, LANDSCAPE_H // 2 - 55), cfg["headline"], font=font_large, fill=(255, 255, 255, 255))
        draw.text((83, LANDSCAPE_H // 2 + 45 + 3), cfg["subtitle"], font=font_small, fill=(0, 0, 0, 100))
        draw.text((80, LANDSCAPE_H // 2 + 45), cfg["subtitle"], font=font_small, fill=(255, 255, 255, 255))
        
    else:
        canvas = create_gradient(PORTRAIT_W, PORTRAIT_H, cfg["colors"][0], cfg["colors"][1])
        
        # Text
        draw = ImageDraw.Draw(canvas)
        add_text(draw, cfg["headline"], 80, PORTRAIT_W, 95)
        add_text(draw, cfg["subtitle"], 195, PORTRAIT_W, 48)
        
        # Scale frame
        text_area = 290
        available_h = PORTRAIT_H - text_area - 30
        frame_scale = available_h / frame_orig.height
        frame_w = int(frame_orig.width * frame_scale)
        frame_h = available_h
        frame = frame_transparent.resize((frame_w, frame_h), Image.Resampling.LANCZOS)
        
        # Scale screen corners
        screen_corners = [(int(x * frame_scale), int(y * frame_scale)) for x, y in SCREEN_CORNERS_ORIG]
        
        # Position frame
        frame_x = (PORTRAIT_W - frame_w) // 2
        frame_y = text_area
        
        # Bounding box
        min_x = min(c[0] for c in screen_corners)
        max_x = max(c[0] for c in screen_corners)
        min_y = min(c[1] for c in screen_corners)
        max_y = max(c[1] for c in screen_corners)
        screen_w = max_x - min_x
        screen_h = max_y - min_y
        
        # Resize screenshot
        screenshot_resized = screenshot.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
        
        # Perspective transform
        relative_corners = [(x - min_x, y - min_y) for x, y in screen_corners]
        coeffs = find_perspective_coeffs(
            [(0, 0), (screen_w, 0), (screen_w, screen_h), (0, screen_h)],
            relative_corners
        )
        screenshot_warped = screenshot_resized.transform(
            (screen_w, screen_h), 
            Image.Transform.PERSPECTIVE, 
            coeffs, 
            Image.Resampling.BICUBIC
        )
        
        # Create frame-sized canvas for screenshot
        screenshot_canvas = Image.new('RGBA', (frame_w, frame_h), (0, 0, 0, 0))
        screenshot_canvas.paste(screenshot_warped, (min_x, min_y), screenshot_warped)
        
        # Composite
        final_frame = Image.new('RGBA', (frame_w, frame_h), (0, 0, 0, 0))
        final_frame.paste(screenshot_canvas, (0, 0), screenshot_canvas)
        final_frame.paste(frame, (0, 0), frame)
        
        canvas.paste(final_frame, (frame_x, frame_y), final_frame)
    
    canvas = canvas.convert("RGB")
    canvas.save(os.path.join(output_dir, cfg["output"]), "PNG")
    print(f"  ✓ Saved {cfg['output']} at {canvas.width}x{canvas.height}")

print("\n✅ All screenshots created with perspective transform!")
