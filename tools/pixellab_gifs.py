"""Build a game sprite sheet from PixelLab animation GIFs.

    python3 tools/pixellab_gifs.py <sheet> <out.png> anim=file.gif[:first-last] ...

e.g. python3 tools/pixellab_gifs.py sheriff art/sprites/sheriff.png \
        idle=idle.gif run=run.gif climb=climb.gif:3-7 ...

Frames are used at their real size (no scaling, so the pixels stay crisp):
the centre of each GIF's canvas goes to the centre of the 48 x 64 cell and
its ground line (lowest foot in that animation) to the bottom of the cell.
Rows with no GIF are faked from the first idle frame. Needs Pillow.
Option --scale=2 builds double-resolution art (96 x 128 frames) for
art/sprites/<sheet>@2x.png: make the character about twice as tall in PixelLab.
Animations can also be PixelLab export folders of PNG frames (anim=path/to/east).
Rows and frame counts come from the sheet's entry in data/sprites.json.
Option --pin-feet sits each jump/fall/land/slide/skid frame on its own feet;
--anchor=body lines frames up by the character's body instead of the canvas centre.
Option --fix-navy recolours navy trousers back to the khaki uniform (some
PixelLab templates ignore the character's colours).
Option --despeckle removes small specks floating free of the character (PixelLab
sometimes leaves a stray dot or a scrap of rope beside him).
"""
import glob
import json
import os
import sys
from PIL import Image, ImageSequence

ROWS = [("idle", 4), ("run", 8), ("jump", 1), ("fall", 1), ("land", 2), ("skid", 2), ("throw", 4),
        ("hurt", 2), ("victory", 6), ("slide", 3), ("tiphat", 4), ("taunt", 4), ("stunned", 2),
        ("cuffed", 2), ("aim", 3), ("fumble", 4), ("climb", 4), ("climb_idle", 1)]
W, H, COLS = 48, 64, 8
S = 1   # --scale=2: double-resolution art (96 x 128 frames), saved as <sheet>@2x.png
KHAKI, KHAKI_DARK = (239, 182, 129), (173, 118, 79)


def load(spec, fix_navy):
    path, _, rng = spec.partition(":")
    if os.path.isdir(path):     # a PixelLab export folder of frame_000.png, frame_001.png ...
        fr = [Image.open(f).convert("RGBA") for f in sorted(glob.glob(os.path.join(path, "*.png")))]
    else:
        fr = [f.convert("RGBA") for f in ImageSequence.Iterator(Image.open(path))]
    if rng:
        a, b = (int(v) for v in rng.split("-"))
        fr = fr[a:b + 1]
    if fix_navy:
        fr = [recolour(f) for f in fr]
    return fr


def despeckle(im, max_px=60):
    """Clear small groups of opaque pixels that don't touch the character."""
    im = im.copy()
    px = im.load()
    w, h = im.size
    seen = set()
    for y0 in range(h):
        for x0 in range(w):
            if (x0, y0) in seen or px[x0, y0][3] <= 32:
                continue
            group, todo = [], [(x0, y0)]
            seen.add((x0, y0))
            while todo:
                x, y = todo.pop()
                group.append((x, y))
                for nx in range(x - 1, x + 2):
                    for ny in range(y - 1, y + 2):
                        if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny][3] > 32:
                            seen.add((nx, ny))
                            todo.append((nx, ny))
            if len(group) <= max_px:
                for x, y in group:
                    px[x, y] = (0, 0, 0, 0)
    return im


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
            elif y > top + 16 * S and r > 240 and g > 222 and b > 210:   # white shirt (not the eyes)
                px[x, y] = (247, 196, 145, 255)
    # solid black trouser fill: dark pixels that aren't outline (no transparent
    # neighbour) below the belt line
    src = im.copy().load()
    for y in range(top + 30 * S, im.height - 1):
        for x in range(1, im.width - 1):
            r, g, b, a = src[x, y]
            if a > 128 and r + g + b < 40:
                if all(src[x + dx, y + dy][3] > 128 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    near_dark = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if sum(src[x + dx, y + dy][:3]) < 40)
                    if near_dark >= 2:
                        px[x, y] = KHAKI + (255,) if near_dark >= 3 else KHAKI_DARK + (255,)
    return im


def layout_rows(sheet_name):
    """The sheet's rows and frame counts from data/sprites.json (falls back to ROWS)."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "sprites.json")
    try:
        lay = json.load(open(path))["sheets"][sheet_name]
        return [(a["name"], int(a["frames"])) for a in lay["anims"]]
    except (OSError, KeyError, ValueError):
        return ROWS


def body_x(frames):
    """Horizontal centre of the character's body: the middle of the opaque pixels in
    the lower part of the first frame (legs and belt, not an outstretched arm or rope)."""
    f = frames[0]
    box = f.getbbox()
    if not box:
        return f.width // 2
    top = box[1] + (box[3] - box[1]) * 55 // 100
    xs = [x for y in range(top, box[3]) for x in range(f.width) if f.getpixel((x, y))[3] > 128]
    return sorted(xs)[len(xs) // 2] if xs else f.width // 2


# Rows whose frames move up and down inside the PixelLab canvas (the game moves
# the character itself): with --pin-feet each frame sits on its own feet.
PIN_ROWS = ("jump", "fall", "land", "slide", "skid")


def pick(fr, n, which=None):
    if which is not None:
        return [fr[min(which, len(fr) - 1)]]
    return [fr[i * len(fr) // n] for i in range(n)]


def main():
    global W, H, S
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    fixes = set(a[2:] for a in sys.argv[1:] if a.startswith("--"))
    for f in list(fixes):
        if f.startswith("scale="):
            S = int(f.split("=", 1)[1])
            W, H = W * S, H * S
            fixes.discard(f)
    sheet_name, out = args[0], args[1]
    anims = {}
    for a in args[2:]:
        k, _, v = a.partition("=")
        fix = "fix-navy" in fixes and k in ("jumpall", "jump", "fall", "land", "throw", "aim")
        anims[k] = load(v, fix)
        if "despeckle" in fixes:
            anims[k] = [despeckle(f, 15 * S * S) for f in anims[k]]
    base = anims["idle"][0]
    rows = layout_rows(sheet_name)
    pin_feet = "pin-feet" in fixes
    anchor_body = "anchor=body" in fixes
    sheet = Image.new("RGBA", (W * COLS, H * len(rows)), (0, 0, 0, 0))
    for row, (name, n) in enumerate(rows):
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
        cx = body_x(src or [base]) if anchor_body else None
        for i, f in enumerate(frames):
            dx, dy = 0, 0
            if fake:
                dy = {"run": [0, -1, -2, -1] * 2, "idle": [0, -1] * 2}.get(name, [0] * 8)[i % 8] * S
                dx = ([-1, 1][i % 2] if name in ("hurt", "stunned", "fumble") else 0) * S
            x = i * W + W // 2 - (cx if cx is not None else f.width // 2) + dx
            feet = f.getbbox()[3] if (pin_feet and name in PIN_ROWS and f.getbbox()) else ground
            y = row * H + H - feet + dy
            cell = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
            cell.paste(f, (x, y), f)
            # keep each frame inside its own cell
            box = (i * W, row * H, i * W + W, row * H + H)
            sheet.paste(cell.crop(box), box[:2], cell.crop(box))
        print(f"{name:11s} {'faked' if fake else 'pixellab'}")
    sheet.save(out)
    print("wrote", out)


main()
