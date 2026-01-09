#!/usr/bin/env python3
from PIL import Image
import os

input_dir = "/Users/sulemanimdad/.gemini/antigravity/brain/2d35d19b-6dc1-4061-8212-caf4aca8ca8e"
output_dir = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/fastlane/metadata/en-US/screenshots"

# Use padding approach to preserve all content
configs = [
    ("orange_record_1767829526326.png", "01_record.png", 1284, 2778),
    ("orange_scripts_1767829539832.png", "02_scripts.png", 1284, 2778),
    ("orange_editor_1767829553133.png", "03_editor.png", 1284, 2778),
    ("orange_landscape_1767829567210.png", "04_landscape.png", 2778, 1284),
]

for input_name, output_name, target_w, target_h in configs:
    print(f"Processing {input_name}...")
    
    img = Image.open(os.path.join(input_dir, input_name)).convert("RGB")
    
    # Create canvas at target size
    canvas = Image.new("RGB", (target_w, target_h))
    
    # Get dominant color from image corners for background
    pixels = list(img.getdata())
    corner_pixels = [pixels[0], pixels[img.width-1], pixels[-img.width], pixels[-1]]
    avg_r = sum(p[0] for p in corner_pixels) // 4
    avg_g = sum(p[1] for p in corner_pixels) // 4
    avg_b = sum(p[2] for p in corner_pixels) // 4
    
    # Fill canvas with gradient approximation
    for y in range(target_h):
        for x in range(target_w):
            canvas.putpixel((x, y), (avg_r, avg_g, avg_b))
    
    # Scale image to fit within canvas (preserving aspect ratio)
    img_ratio = img.width / img.height
    target_ratio = target_w / target_h
    
    if img_ratio > target_ratio:
        # Image is wider - fit to width
        new_w = target_w
        new_h = int(target_w / img_ratio)
    else:
        # Image is taller - fit to height
        new_h = target_h
        new_w = int(target_h * img_ratio)
    
    img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Center on canvas
    x = (target_w - new_w) // 2
    y = (target_h - new_h) // 2
    canvas.paste(img, (x, y))
    
    # Save
    output_path = os.path.join(output_dir, output_name)
    canvas.save(output_path, "PNG")
    print(f"  ✓ Saved {output_name} at {target_w}x{target_h}")

print("\n✅ All screenshots ready!")
