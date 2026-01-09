#!/usr/bin/env python3
"""Extract device frame and create App Store screenshots"""
from psd_tools import PSDImage
from PIL import Image, ImageDraw, ImageFont
import os

PORTRAIT_W, PORTRAIT_H = 1284, 2778
LANDSCAPE_W, LANDSCAPE_H = 2778, 1284

psd_path = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/iphone17_mockup/29 Free iPhone 17 Pro Mockup PSD Orange Color.psd"
input_dir = "/Users/sulemanimdad/.gemini/antigravity/brain/2d35d19b-6dc1-4061-8212-caf4aca8ca8e"
output_dir = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/fastlane/metadata/en-US/screenshots"

# Load PSD and extract base image
print("Loading PSD...")
psd = PSDImage.open(psd_path)

# Find the Mockup group and Base Image layer
mockup_group = None
base_image = None
for layer in psd:
    if layer.name == "Mockup":
        mockup_group = layer
        for sublayer in layer:
            if sublayer.name == "Base Image":
                base_image = sublayer
                break
        break

if base_image:
    print(f"Found Base Image: {base_image.size}")
    # Export base image (device frame)
    frame_img = base_image.composite()
    frame_path = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/iphone17_frame.png"
    frame_img.save(frame_path)
    print(f"Saved device frame: {frame_path}")
else:
    print("Could not find Base Image layer")
    # Try rendering the full composite
    frame_img = psd.composite()
    frame_path = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/iphone17_full.png"
    frame_img.save(frame_path)
    print(f"Saved full composite: {frame_path}")

print("\nDone extracting!")
