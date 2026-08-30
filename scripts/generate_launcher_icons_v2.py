#!/usr/bin/env python3
"""Generate ArtVault launcher icons from the real logo image."""

import os
from PIL import Image, ImageDraw

RES_DIR = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res')

# The real logo, cropped and squared
LOGO_PATH = r'C:\Users\Lenovo\Desktop\artvault_logo_square.png'

# Density bucket sizes
DENSITIES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}


def make_round(img, size):
    """Apply circular mask for round launcher icons."""
    img = img.resize((size, size), Image.LANCZOS)
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([0, 0, size - 1, size - 1], fill=255)
    result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result.convert('RGB')


def main():
    print("Generating launcher icons from real logo...")

    logo = Image.open(LOGO_PATH)
    print(f"Source logo: {logo.size}")

    for folder, size in DENSITIES.items():
        out_dir = os.path.join(RES_DIR, folder)
        os.makedirs(out_dir, exist_ok=True)

        # Regular icon (square with rounded corners - the logo already has them)
        icon = logo.resize((size, size), Image.LANCZOS)
        icon_path = os.path.join(out_dir, 'ic_launcher.png')
        icon.save(icon_path, 'PNG')
        print(f"  OK {folder}/ic_launcher.png ({size}x{size})")

        # Round icon
        round_icon = make_round(logo, size)
        round_path = os.path.join(out_dir, 'ic_launcher_round.png')
        round_icon.save(round_path, 'PNG')
        print(f"  OK {folder}/ic_launcher_round.png ({size}x{size})")

    print("\nAll launcher icons generated from real logo!")


if __name__ == '__main__':
    main()
