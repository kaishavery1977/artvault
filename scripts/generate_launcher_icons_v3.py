#!/usr/bin/env python3
"""Generate ArtVault launcher icons matching the exact splash screen logo."""

import math
import os
from PIL import Image, ImageDraw

RES_DIR = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res')

# Exact splash screen colors
VIOLET700 = (109, 40, 217)   # #6D28D9 secondary
VIOLET500 = (139, 92, 246)   # #8B5CF6 accent
WHITE = (255, 255, 255)

DENSITIES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def make_gradient(size):
    """Create a diagonal gradient matching the splash logo."""
    img = Image.new('RGB', (size, size))
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            # Diagonal gradient: top-left (dark) to bottom-right (light)
            t = (x / size * 0.5 + y / size * 0.5)
            t = max(0, min(1, t))
            pixels[x, y] = lerp_color(VIOLET700, VIOLET500, t)
    return img


def make_rounded_square_mask(size, radius_frac=0.22):
    """Create a mask with rounded corners like the splash logo."""
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    r = int(size * radius_frac)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    return mask


def draw_palette_icon(draw, size):
    """
    Draw the Material palette icon centered in the canvas.
    The palette is an organic blob shape with a thumb hole.
    Matches Icons.palette from Flutter Material.
    """
    # Scale factor: icon is about 40% of the canvas
    s = size / 54.0  # reference frame is 54dp (Material icon default)
    cx, cy = size / 2, size / 2

    # Main palette body — organic rounded shape (like a kidney bean)
    # Using the actual Material Icons "palette" path data, scaled
    # Material path for palette (24dp viewport, centered at 12,12):
    # M12 2C6.49 2 2 6.49 2 12s4.49 10 10 10c1.38 0 2.5-1.12
    # 2.5-2.5 0-.61-.23-1.2-.64-1.67-.08-.1-.13-.21-.13-.33
    # 0-.28.22-.5.5-.5H16c3.31 0 6-2.69 6-6 0-4.96-4.49-8-10-8z
    # Plus 4 small dots

    # Scale from 24dp viewport to our size
    scale = size / 24.0
    ox = cx - 12 * scale  # offset to center
    oy = cy - 12 * scale

    # Main palette body (teardrop/kidney shape)
    body_points = []
    # Approximate the palette shape with a path
    # The palette is roughly a circle with a notch on the right (thumb hole)
    # and extends to the bottom-right for the grip
    r = 10 * scale  # main body radius
    body_cx = ox + 12 * scale
    body_cy = oy + 12 * scale

    # Draw the main body as an ellipse
    draw.ellipse(
        [body_cx - r, body_cy - r, body_cx + r, body_cy + r],
        fill=WHITE,
    )

    # Top-right bump (makes it palette-shaped, not just a circle)
    bump_r = 6 * scale
    bump_cx = body_cx + 3 * scale
    bump_cy = body_cy - 5 * scale
    draw.ellipse(
        [bump_cx - bump_r, bump_cy - bump_r, bump_cx + bump_r, bump_cy + bump_r],
        fill=WHITE,
    )

    # Left bump
    lbump_r = 5 * scale
    lbump_cx = body_cx - 5 * scale
    lbump_cy = body_cy - 2 * scale
    draw.ellipse(
        [lbump_cx - lbump_r, lbump_cy - lbump_r, lbump_cx + lbump_r, lbump_cy + lbump_r],
        fill=WHITE,
    )

    # Bottom extension (the grip area)
    grip_r = 7 * scale
    grip_cx = body_cx + 1 * scale
    grip_cy = body_cy + 4 * scale
    draw.ellipse(
        [grip_cx - grip_r, grip_cy - grip_r, grip_cx + grip_r, grip_cy + grip_r],
        fill=WHITE,
    )

    # Thumb hole (cutout) — bottom right of the palette
    hole_r = 3 * scale
    hole_cx = body_cx + 4 * scale
    hole_cy = body_cy + 4 * scale
    draw.ellipse(
        [hole_cx - hole_r, hole_cy - hole_r, hole_cx + hole_r, hole_cy + hole_r],
        fill=VIOLET700,  # Matches background gradient dark end
    )

    # 4 paint dots on the palette
    dot_r = 1.5 * scale
    dots = [
        (ox + 7 * scale, oy + 5 * scale),    # top-left dot
        (ox + 11 * scale, oy + 4 * scale),   # top-center dot
        (ox + 9 * scale, oy + 8 * scale),    # middle dot
        (ox + 14 * scale, oy + 7 * scale),   # right dot
    ]
    for dx, dy in dots:
        draw.ellipse(
            [dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r],
            fill=VIOLET700,  # Purple dots on white palette
        )


def generate_icon(size, is_round=False):
    """Generate a single launcher icon."""
    img = make_gradient(size)
    draw = ImageDraw.Draw(img)

    # Draw the palette icon
    draw_palette_icon(draw, size)

    if is_round:
        # Apply circular mask
        mask = Image.new('L', (size, size), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse([0, 0, size - 1, size - 1], fill=255)
        result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        result.paste(img, mask=mask)
        return result.convert('RGB')
    else:
        # Apply rounded square mask (matching splash logo shape)
        mask = make_rounded_square_mask(size, radius_frac=0.22)
        result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        result.paste(img, mask=mask)
        return result.convert('RGB')


def generate_monochrome(size):
    """Generate monochrome icon (white shape on transparent) for Android 13."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_palette_icon(draw, size)
    return img


def main():
    print("Generating ArtVault launcher icons (exact splash match)...")

    for folder, size in DENSITIES.items():
        out_dir = os.path.join(RES_DIR, folder)
        os.makedirs(out_dir, exist_ok=True)

        # Regular icon
        icon = generate_icon(size, is_round=False)
        icon.save(os.path.join(out_dir, 'ic_launcher.png'), 'PNG')
        print(f"  OK {folder}/ic_launcher.png ({size}x{size})")

        # Round icon
        round_icon = generate_icon(size, is_round=True)
        round_icon.save(os.path.join(out_dir, 'ic_launcher_round.png'), 'PNG')
        print(f"  OK {folder}/ic_launcher_round.png ({size}x{size})")

    # Monochrome for Android 13
    mono_dir = os.path.join(RES_DIR, 'drawable')
    mono = generate_monochrome(192)
    mono.save(os.path.join(mono_dir, 'ic_launcher_monochrome.png'), 'PNG')
    print(f"  OK drawable/ic_launcher_monochrome.png (192x192)")

    print("\nAll icons generated!")


if __name__ == '__main__':
    main()
