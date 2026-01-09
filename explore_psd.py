#!/usr/bin/env python3
"""Extract and list layers from the iPhone 17 Pro mockup PSD"""
from psd_tools import PSDImage

psd_path = "/Users/sulemanimdad/Documents/Developer/theman/Teleprompter App/iphone17_mockup/29 Free iPhone 17 Pro Mockup PSD Orange Color.psd"

psd = PSDImage.open(psd_path)
print(f"PSD Size: {psd.width}x{psd.height}")
print(f"\nLayers ({len(psd)}):")

def print_layers(layers, indent=0):
    for layer in layers:
        prefix = "  " * indent
        print(f"{prefix}- {layer.name} ({layer.kind}) visible={layer.visible}")
        if hasattr(layer, '__iter__'):
            print_layers(layer, indent + 1)

print_layers(psd)
