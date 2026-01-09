#!/usr/bin/env python3
"""Find the exact screen area in the device frame by detecting black pixels"""
from PIL import Image
import numpy as np

frame_path = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/iphone17_frame.png"
frame = Image.open(frame_path).convert("RGBA")

# Convert to numpy for easier analysis
data = np.array(frame)

# Find pixels that are black (or near black) - the screen area
# Black pixels have R,G,B all < 30 and high alpha
black_mask = (data[:,:,0] < 30) & (data[:,:,1] < 30) & (data[:,:,2] < 30) & (data[:,:,3] > 200)

# Find the bounding box of black pixels
rows = np.any(black_mask, axis=1)
cols = np.any(black_mask, axis=0)
row_indices = np.where(rows)[0]
col_indices = np.where(cols)[0]

if len(row_indices) > 0 and len(col_indices) > 0:
    top = row_indices[0]
    bottom = row_indices[-1]
    left = col_indices[0]
    right = col_indices[-1]
    
    print(f"Frame size: {frame.width}x{frame.height}")
    print(f"Screen area (black region):")
    print(f"  Top-left: ({left}, {top})")
    print(f"  Bottom-right: ({right}, {bottom})")
    print(f"  Size: {right - left}x{bottom - top}")
    print(f"\nAs percentages of frame:")
    print(f"  Left: {left/frame.width:.2%}")
    print(f"  Top: {top/frame.height:.2%}")
    print(f"  Width: {(right-left)/frame.width:.2%}")
    print(f"  Height: {(bottom-top)/frame.height:.2%}")
else:
    print("Could not find black screen area")
