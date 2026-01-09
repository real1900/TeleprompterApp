#!/usr/bin/env python3
"""Resize iPad AI screenshots to exact App Store dimensions"""
from PIL import Image
import os

IPAD_PORTRAIT_W, IPAD_PORTRAIT_H = 2048, 2732
IPAD_LANDSCAPE_W, IPAD_LANDSCAPE_H = 2732, 2048

input_dir = "/Users/sulemanimdad/.gemini/antigravity/brain/2d35d19b-6dc1-4061-8212-caf4aca8ca8e"
output_dir = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/fastlane/metadata/en-US/screenshots"

screenshots = [
    ("ipad_record_1767833357508.png", "ipad_01_record.png", False),
    ("ipad_scripts_1767833370905.png", "ipad_02_scripts.png", False),
    ("ipad_editor_1767833384964.png", "ipad_03_editor.png", False),
    ("ipad_landscape_1767833400971.png", "ipad_04_landscape.png", True),
    ("ipad_cinematic_1767833415341.png", "ipad_05_cinematic.png", False),
]

def resize_to_fill(img, target_w, target_h, crop_from_top=True):
    """Resize and crop to fill target dimensions"""
    scale = max(target_w / img.width, target_h / img.height)
    new_w = int(img.width * scale)
    new_h = int(img.height * scale)
    img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    left = (new_w - target_w) // 2
    if crop_from_top:
        top = 0
    else:
        top = (new_h - target_h) // 2
    img = img.crop((left, top, left + target_w, top + target_h))
    return img

for input_name, output_name, is_landscape in screenshots:
    print(f"Processing {output_name}...")
    
    img = Image.open(os.path.join(input_dir, input_name)).convert("RGB")
    
    if is_landscape:
        resized = resize_to_fill(img, IPAD_LANDSCAPE_W, IPAD_LANDSCAPE_H, crop_from_top=False)
    else:
        resized = resize_to_fill(img, IPAD_PORTRAIT_W, IPAD_PORTRAIT_H, crop_from_top=True)
    
    resized.save(os.path.join(output_dir, output_name), "PNG")
    print(f"  ✓ Saved {output_name} at {resized.width}x{resized.height}")

print("\n✅ All iPad screenshots ready!")
