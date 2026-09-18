#!/usr/bin/env python3
"""Generate Material U launcher icons + in-app logo asset.

Takes the Noir Black source artwork (dark canvas + light glyph) and remaps
its luminance ramp onto a Material You palette derived from the app's
Material U seed color (0xFF7EC8FF): a light surface canvas with the seed's
primary-tone glyph, matching the Material You light scheme look.

Outputs:
  assets/images/logo_noctra_material_u.png            (in-app logo, 1254px)
  android/app/src/main/res/mipmap-*/ic_launcher_material_u.png
  android/app/src/main/res/mipmap-*/ic_launcher_round_material_u.png

Idempotent: run again any time the source artwork changes.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'images', 'logo_noctra_noir_black.png')
OUT_LOGO = os.path.join(ROOT, 'assets', 'images', 'logo_noctra_material_u.png')

# Material U seed (matches MaterialUSchemeHolder.seedColor) and the
# Material You light-scheme surface tone for the canvas.
SEED = (0x7E, 0xC8, 0xFF)  # 0xFF7EC8FF

# Luminance anchors from the source artwork:
#   glyph  ~ (255, 255, 255)  -> maps to a mid-tone primary (~tone 40)
#   canvas ~ (7, 7, 9)        -> maps to a light surface (~tone 98)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def build_palette():
    """Map source luminance 0..1 onto canvas->glyph Material U tones."""
    # Glyph tone (40): visibly blue, good contrast on light surface.
    glyph = (0x00, 0x63, 0x8E)          # material blue tone ~40 from seed
    # Accent highlight tone (80): light blue for edges/highlights.
    accent = (0xC4, 0xE7, 0xFF)
    # Canvas tone (98): near-white with a blue cast.
    canvas = (0xF4, 0xF9, 0xFF)
    return canvas, glyph, accent


def remap(img):
    canvas, glyph, accent = build_palette()
    rgba = img.convert('RGBA')
    px = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # normalized luminance within the source ramp
            lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
            if lum < 0.5:
                # canvas range: dark source -> light canvas
                t = lum / 0.5
                out = lerp(canvas, accent, t * 0.15)
            else:
                # glyph range: bright source -> primary glyph
                t = (lum - 0.5) / 0.5
                out = lerp(accent, glyph, t)
            px[x, y] = (out[0], out[1], out[2], a)
    return rgba


def main():
    src = Image.open(SRC)
    mapped = remap(src)

    # In-app logo asset
    os.makedirs(os.path.dirname(OUT_LOGO), exist_ok=True)
    mapped.save(OUT_LOGO)
    print(f'wrote {OUT_LOGO} {mapped.size}')

    # Android mipmaps. The source logo is a full-bleed square; launcher
    # icons use the same full-bleed style as the existing ic_launcher_*.
    sizes = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
    }
    res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
    for dpi, side in sizes.items():
        d = os.path.join(res, f'mipmap-{dpi}')
        os.makedirs(d, exist_ok=True)
        icon = mapped.resize((side, side), Image.LANCZOS)
        icon.save(os.path.join(d, 'ic_launcher_material_u.png'))
        icon.save(os.path.join(d, 'ic_launcher_round_material_u.png'))
        print(f'wrote mipmap-{dpi} ({side}px)')


if __name__ == '__main__':
    main()
