#!/usr/bin/env python3
"""Resize the compact-text AI screenshots to exact App Store dimensions"""
from PIL import Image
import os

PORTRAIT_W, PORTRAIT_H = 1284, 2778
LANDSCAPE_W, LANDSCAPE_H = 2778, 1284

input_dir = "/Users/sulemanimdad/.gemini/antigravity/brain/2d35d19b-6dc1-4061-8212-caf4aca8ca8e"
output_dir = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/fastlane/metadata/en-US/screenshots"

# Use the compact text AI images
screenshots = [
    ("final_scripts_1767832604592.png", "02_scripts.png", False),
    ("final_editor_1767832618401.png", "03_editor.png", False),
    ("final_landscape_1767832635198.png", "04_landscape.png", True),
]

def resize_portrait(img, target_w, target_h):
    """Resize to fill, then crop from BOTTOM to preserve text at top"""
    scale_w = target_w / img.width
    scale_h = target_h / img.height
    scale = max(scale_w, scale_h)
    
    new_w = int(img.width * scale)
    new_h = int(img.height * scale)
    img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    left = (new_w - target_w) // 2
    top = 0
    img = img.crop((left, top, left + target_w, top + target_h))
    
    return img

def resize_landscape(img, target_w, target_h):
    """Resize to fill, center crop"""
    scale_w = target_w / img.width
    scale_h = target_h / img.height
    scale = max(scale_w, scale_h)
    
    new_w = int(img.width * scale)
    new_h = int(img.height * scale)
    img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    left = (new_w - target_w) // 2
    top = (new_h - target_h) // 2
    img = img.crop((left, top, left + target_w, top + target_h))
    
    return img

for input_name, output_name, is_landscape in screenshots:
    print(f"Processing {output_name}...")
    
    img = Image.open(os.path.join(input_dir, input_name)).convert("RGB")
    
    if is_landscape:
        resized = resize_landscape(img, LANDSCAPE_W, LANDSCAPE_H)
    else:
        resized = resize_portrait(img, PORTRAIT_W, PORTRAIT_H)
    
    resized.save(os.path.join(output_dir, output_name), "PNG")
    print(f"  ✓ Saved {output_name} at {resized.width}x{resized.height}")

print("\n✅ Screenshots 02-04 ready!")
