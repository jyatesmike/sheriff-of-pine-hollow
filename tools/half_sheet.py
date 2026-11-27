"""Make a normal-size sprite sheet from a double-resolution one.

    python3 tools/half_sheet.py art/sprites/jim@2x.png art/sprites/jim.png

Each 2x2 block of pixels becomes one pixel: the colour most of its opaque pixels
share (transparent if fewer than 2 are opaque), so the result keeps crisp pixel
art colours instead of blurring. Used when a character only has PixelLab art at
double size. Needs Pillow.
"""
import sys
from collections import Counter
from PIL import Image


def half(src: Image.Image) -> Image.Image:
    src = src.convert("RGBA")
    w, h = src.width // 2, src.height // 2
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    for y in range(h):
        for x in range(w):
            px = [sp[2 * x + i, 2 * y + j] for j in (0, 1) for i in (0, 1)]
            solid = [p[:3] for p in px if p[3] > 128]
            if len(solid) >= 2:
                op[x, y] = Counter(solid).most_common(1)[0][0] + (255,)
    return out


if __name__ == "__main__":
    half(Image.open(sys.argv[1])).save(sys.argv[2])
    print("wrote", sys.argv[2])
