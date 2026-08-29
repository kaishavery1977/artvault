#!/usr/bin/env python3
"""Generate ArtVault launcher icons with purple gradient + white palette icon."""

import math
import os
from PIL import Image, ImageDraw

# Splash screen colors
VIOLET700 = (109, 40, 217)  # #6D28D9 - secondary
VIOLET500 = (139, 92, 246)  # #8B5CF6 - accent
WHITE = (255, 255, 255)

# Density bucket sizes (regular + round)
DENSITIES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

RES_DIR = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res')


def make_gradient(size, color_start=VIOLET700, color_end=VIOLET500, angle=135):
    """Create a diagonal gradient image."""
    img = Image.new('RGB', (size, size))
    pixels = img.load()

    rad = math.radians(angle)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)

    # Project each pixel onto the gradient axis
    max_proj = abs(size * cos_a) + abs(size * sin_a) if max(abs(cos_a), abs(sin_a)) > 0 else 1

    for y in range(size):
        for x in range(size):
            # Project position onto gradient axis
            proj = (x * cos_a + y * sin_a)
            t = max(0.0, min(1.0, (proj + max_proj / 2) / max_proj))

            r = int(color_start[0] + (color_end[0] - color_start[0]) * t)
            g = int(color_start[1] + (color_end[1] - color_start[1]) * t)
            b = int(color_start[2] + (color_end[2] - color_start[2]) * t)
            pixels[x, y] = (r, g, b)

    return img


def draw_palette_icon(draw, cx, cy, icon_size, color=WHITE):
    """Draw a simplified palette icon (circle with 4 color dots + thumb hole)."""
    r = icon_size // 2

    # Main palette circle (slightly oval like the Material icon)
    palette_w = int(r * 1.8)
    palette_h = int(r * 1.5)
    draw.ellipse(
        [cx - palette_w, cy - palette_h, cx + palette_w, cy + palette_h],
        fill=color,
    )

    # Thumb hole (cutout) - bottom right area
    hole_r = int(r * 0.55)
    hole_cx = cx + int(r * 0.7)
    hole_cy = cy + int(r * 0.4)
    # Use background color to create cutout effect
    draw.ellipse(
        [hole_cx - hole_r, hole_cy - hole_r, hole_cx + hole_r, hole_cy + hole_r],
        fill=VIOLET700,  # Will be covered by gradient, but for round icons we use background
    )

    # 4 small color dots on the palette
    dot_r = int(r * 0.35)
    dot_positions = [
        (cx - int(r * 0.5), cy - int(r * 0.7)),  # top-left
        (cx + int(r * 0.3), cy - int(r * 0.8)),   # top-right
        (cx - int(r * 0.8), cy + int(r * 0.1)),   # mid-left
        (cx - int(r * 0.3), cy - int(r * 0.1)),   # center
    ]
    # The dots are same color as the palette (white on gradient) - they're just decorative bumps
    for dx, dy in dot_positions:
        draw.ellipse(
            [dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r],
            fill=color,
        )

    return img


def draw_palette_icon_v2(draw, size):
    """Draw the Material palette icon path scaled to the given size."""
    # Scale factor from the 108dp viewport to actual pixel size
    scale = size / 108.0

    # Material Icons "palette" path data, scaled and translated
    # Original path is in a 108dp viewport, icon starts at roughly (6,12) to (52,52)
    # We center it in the canvas

    # Simpler approach: draw the palette as basic shapes
    cx, cy = size // 2, size // 2

    # Main palette body - teardrop/circle shape
    body_r = int(size * 0.30)
    body_cx = cx - int(size * 0.02)
    body_cy = cy + int(size * 0.02)

    # Outer palette shape (rounded, organic)
    draw.ellipse(
        [body_cx - body_r, body_cy - body_r, body_cx + body_r, body_cy + body_r],
        fill=WHITE,
    )

    # Additional bulge on top-right for the palette shape
    bulge_r = int(size * 0.20)
    bulge_cx = body_cx + int(size * 0.12)
    bulge_cy = body_cy - int(size * 0.15)
    draw.ellipse(
        [bulge_cx - bulge_r, bulge_cy - bulge_r, bulge_cx + bulge_r, bulge_cy + bulge_r],
        fill=WHITE,
    )

    # Thumb hole (cutout) - bottom right
    hole_r = int(size * 0.08)
    hole_cx = body_cx + int(size * 0.12)
    hole_cy = body_cy + int(size * 0.10)

    # For regular icons, we paint the hole with the gradient center color
    # For a cleaner look, we'll skip the hole since it's small at these sizes
    # and the gradient shows through at the edges anyway

    # 3-4 small paint dots on the palette
    dot_r = int(size * 0.04)
    dots = [
        (body_cx - int(size * 0.12), body_cy - int(size * 0.15)),
        (body_cx + int(size * 0.02), body_cy - int(size * 0.20)),
        (body_cx - int(size * 0.05), body_cy - int(size * 0.03)),
    ]
    for dx, dy in dots:
        draw.ellipse(
            [dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r],
            fill=WHITE,
        )


def draw_palette_icon_v3(img, size):
    """Draw palette icon using the actual Material Icons path data, rasterized."""
    # Create a temporary image with the icon path
    # Use the actual SVG path data from the foreground XML, scaled to size
    scale = size / 108.0

    # Create mask for the palette icon path
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)

    cx, cy = size // 2, size // 2

    # Palette body - the main circular/organic shape
    body_r = int(20 * scale)
    body_cx = cx
    body_cy = cy + int(2 * scale)

    mask_draw.ellipse(
        [body_cx - body_r, body_cy - body_r, body_cx + body_r, body_cy + body_r],
        fill=255,
    )

    # Top extension (makes it more palette-shaped, not just a circle)
    ext_w = int(14 * scale)
    ext_h = int(16 * scale)
    ext_cx = body_cx + int(2 * scale)
    ext_cy = body_cy - int(12 * scale)
    mask_draw.ellipse(
        [ext_cx - ext_w, ext_cy - ext_h, ext_cx + ext_w, ext_cy + ext_h],
        fill=255,
    )

    # Small bump on top-left
    bump_r = int(8 * scale)
    bump_cx = body_cx - int(10 * scale)
    bump_cy = body_cy - int(6 * scale)
    mask_draw.ellipse(
        [bump_cx - bump_r, bump_cy - bump_r, bump_cx + bump_r, bump_cy + bump_r],
        fill=255,
    )

    # Thumb hole (subtract)
    hole_r = int(5 * scale)
    hole_cx = body_cx + int(8 * scale)
    hole_cy = body_cy + int(5 * scale)
    mask_draw.ellipse(
        [hole_cx - hole_r, hole_cy - hole_r, hole_cx + hole_r, hole_cy + hole_r],
        fill=0,
    )

    # Paint the white icon onto the gradient
    icon_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    icon_pixels = icon_layer.load()
    mask_pixels = mask.load()

    for y in range(size):
        for x in range(size):
            if mask_pixels[x, y] > 0:
                icon_pixels[x, y] = (255, 255, 255, 255)

    img.paste(Image.alpha_composite(img.convert('RGBA'), icon_layer).convert('RGB'))


def generate_icon(size, is_round=False):
    """Generate a single launcher icon at the given size."""
    img = make_gradient(size)

    if is_round:
        # For round icons, apply a circular mask
        mask = Image.new('L', (size, size), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse([0, 0, size - 1, size - 1], fill=255)

        draw = ImageDraw.Draw(img)
        draw_palette_icon_v2(draw, size)

        # Apply circular mask
        result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        result.paste(img, mask=mask)
        return result.convert('RGB')
    else:
        draw = ImageDraw.Draw(img)
        draw_palette_icon_v2(draw, size)
        return img


def generate_monochrome(size):
    """Generate a monochrome (white on transparent) icon for Android 13 themed icons."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw white palette icon
    cx, cy = size // 2, size // 2

    # Main palette body
    body_r = int(size * 0.30)
    body_cx = cx - int(size * 0.02)
    body_cy = cy + int(size * 0.02)

    draw.ellipse(
        [body_cx - body_r, body_cy - body_r, body_cx + body_r, body_cy + body_r],
        fill=WHITE,
    )

    # Top extension
    bulge_r = int(size * 0.20)
    bulge_cx = body_cx + int(size * 0.12)
    bulge_cy = body_cy - int(size * 0.15)
    draw.ellipse(
        [bulge_cx - bulge_r, bulge_cy - bulge_r, bulge_cx + bulge_r, bulge_cy + bulge_r],
        fill=WHITE,
    )

    # Small bump top-left
    bump_r = int(size * 0.12)
    bump_cx = body_cx - int(size * 0.15)
    bump_cy = body_cy - int(size * 0.08)
    draw.ellipse(
        [bump_cx - bump_r, bump_cy - bump_r, bump_cx + bump_r, bump_cy + bump_r],
        fill=WHITE,
    )

    return img


def main():
    print("Generating ArtVault launcher icons...")

    for folder, size in DENSITIES.items():
        out_dir = os.path.join(RES_DIR, folder)
        os.makedirs(out_dir, exist_ok=True)

        # Regular icon
        icon = generate_icon(size, is_round=False)
        icon_path = os.path.join(out_dir, 'ic_launcher.png')
        icon.save(icon_path, 'PNG')
        print(f"  OK {folder}/ic_launcher.png ({size}x{size})")

        # Round icon
        round_icon = generate_icon(size, is_round=True)
        round_path = os.path.join(out_dir, 'ic_launcher_round.png')
        round_icon.save(round_path, 'PNG')
        print(f"  OK {folder}/ic_launcher_round.png ({size}x{size})")

    # Generate high-res monochrome for the XML to reference
    mono_sizes = {'xxxhdpi': 192, 'xxhdpi': 144, 'xhdpi': 96, 'hdpi': 72, 'mdpi': 48}
    mono_dir = os.path.join(RES_DIR, 'drawable')
    os.makedirs(mono_dir, exist_ok=True)

    # We generate the largest one for the XML vector reference
    mono = generate_monochrome(192)
    mono_path = os.path.join(mono_dir, 'ic_launcher_monochrome.png')
    mono.save(mono_path, 'PNG')
    print(f"  OK drawable/ic_launcher_monochrome.png (192x192)")

    print("\nAll launcher icons generated!")


if __name__ == '__main__':
    main()
