"""Build a game sprite sheet from PixelLab animation GIFs.

    python3 tools/pixellab_gifs.py <sheet> <out.png> anim=file.gif[:first-last] ...

e.g. python3 tools/pixellab_gifs.py sheriff art/sprites/sheriff.png \
        idle=idle.gif run=run.gif climb=climb.gif:3-7 ...

Frames are used at their real size (no scaling, so the pixels stay crisp):
the centre of each GIF's canvas goes to the centre of the 48 x 64 cell and
its ground line (lowest foot in that animation) to the bottom of the cell.
Rows with no GIF are faked from the first idle frame. Needs Pillow.
Option --fix-navy recolours navy trousers back to the khaki uniform (some
PixelLab templates ignore the character's colours).
"""
import sys
from PIL import Image, ImageSequence

ROWS = [("idle", 4), ("run", 8), ("jump", 1), ("fall", 1), ("land", 2), ("skid", 2), ("throw", 4),
        ("hurt", 2), ("victory", 6), ("slide", 3), ("tiphat", 4), ("taunt", 4), ("stunned", 2),
        ("cuffed", 2), ("aim", 3), ("fumble", 4), ("climb", 4), ("climb_idle", 1)]
W, H, COLS = 48, 64, 8
KHAKI, KHAKI_DARK = (239, 182, 129), (173, 118, 79)


def load(spec, fix_navy):
    path, _, rng = spec.partition(":")
    fr = [f.convert("RGBA") for f in ImageSequence.Iterator(Image.open(path))]
    if rng:
        a, b = (int(v) for v in rng.split("-"))
        fr = fr[a:b + 1]
    if fix_navy:
        fr = [recolour(f) for f in fr]
    return fr


def recolour(im):
    im = im.copy()
    px = im.load()
    top = (im.getbbox() or (0, 0, 0, 0))[1]
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a <= 128:
                continue
            if b > r + 20 and b > g + 10 and b > 30:            # navy / blue cloth
                px[x, y] = (KHAKI if b > 55 else KHAKI_DARK) + (255,)
            elif y > top + 16 and r > 240 and g > 222 and b > 210:   # white shirt (not the eyes)
                px[x, y] = (247, 196, 145, 255)
    # solid black trouser fill: dark pixels that aren't outline (no transparent
    # neighbour) below the belt line
    src = im.copy().load()
    for y in range(top + 30, im.height - 1):
        for x in range(1, im.width - 1):
            r, g, b, a = src[x, y]
            if a > 128 and r + g + b < 40:
                if all(src[x + dx, y + dy][3] > 128 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    near_dark = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if sum(src[x + dx, y + dy][:3]) < 40)
                    if near_dark >= 2:
                        px[x, y] = KHAKI + (255,) if near_dark >= 3 else KHAKI_DARK + (255,)
    return im


def pick(fr, n, which=None):
    if which is not None:
        return [fr[min(which, len(fr) - 1)]]
    return [fr[i * len(fr) // n] for i in range(n)]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    fixes = set(a[2:] for a in sys.argv[1:] if a.startswith("--"))
    sheet_name, out = args[0], args[1]
    anims = {}
    for a in args[2:]:
        k, _, v = a.partition("=")
        fix = "fix-navy" in fixes and k in ("jumpall", "jump", "fall", "land", "throw", "aim")
        anims[k] = load(v, fix)
    base = anims["idle"][0]
    sheet = Image.new("RGBA", (W * COLS, H * len(ROWS)), (0, 0, 0, 0))
    for row, (name, n) in enumerate(ROWS):
        src = anims.get(name)
        if name in ("jump", "fall", "land") and src is None and "jumpall" in anims:
            src = anims["jumpall"]
        if src is None:
            frames = [base] * n
            fake = True
        else:
            fake = False
            if name == "jump" and "jump" not in anims:
                frames = pick(src, n, len(src) // 3)
            elif name == "fall" and "fall" not in anims:
                frames = pick(src, n, len(src) * 2 // 3)
            elif name == "land" and "land" not in anims:
                frames = [src[-1]] * n
            else:
                frames = pick(src, n)
        ground = max(f.getbbox()[3] for f in (src or [base]))
        for i, f in enumerate(frames):
            dx, dy = 0, 0
            if fake:
                dy = {"run": [0, -1, -2, -1] * 2, "idle": [0, -1] * 2}.get(name, [0] * 8)[i % 8]
                dx = [-1, 1][i % 2] if name in ("hurt", "stunned", "fumble") else 0
            x = i * W + W // 2 - f.width // 2 + dx
            y = row * H + H - ground + dy
            cell = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
            cell.paste(f, (x, y), f)
            # keep each frame inside its own cell
            box = (i * W, row * H, i * W + W, row * H + H)
            sheet.paste(cell.crop(box), box[:2], cell.crop(box))
        print(f"{name:11s} {'faked' if fake else 'pixellab'}")
    sheet.save(out)
    print("wrote", out)


main()
