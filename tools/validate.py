#!/usr/bin/env python3
"""Check the game's data and art files against the layouts the code expects.

    python3 tools/validate.py          (run from the project folder)

Exits 1 if anything is wrong (ERROR), 0 otherwise. WARN lines don't fail.
Standard library only, so it runs anywhere (CI, a Mac, a worker container).

What it checks:
  - sprite sheets: every sheet in data/sprites.json has a PNG whose size is
    8 frames wide x one row per animation, with transparency, and no
    animation has more frames than fit in a row
  - props atlas: every rectangle in data/props.json lies inside props.png
  - tiles: one 64x64 atlas per area; backgrounds: the five layers per area
    at the sizes in art/README.md
  - levels: every id in Game.LEVELS has data/levels/<id>.json and an entry in
    GameText.LEVELS; theme, music and every object type exist
  - text: {name} slots in game_text.gd are ones Names.fmt() fills in
  - audio: files dropped in audio/sfx, audio/music and audio/voices use names
    the game knows
"""
import json
import pathlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
errors: list[str] = []
warnings: list[str] = []

SHEET_COLS = 8
TILE_ATLAS = (64, 64)
BG_LAYERS = {"sky": (480, 270), "far": (1024, 120), "mid": (1024, 140), "main": (1536, 160), "near": (1024, 200)}
AUDIO_EXT = {".ogg", ".wav", ".mp3"}
NAME_SLOTS = {"town", "sheriff", "earl", "dewey", "deputy", "jim"}


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def rel(p: pathlib.Path) -> str:
    return str(p.relative_to(ROOT))


def png_info(path: pathlib.Path):
    """(width, height, has_alpha) from the PNG header, or None if not a PNG."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    w, h, _depth, color_type = struct.unpack(">IIBB", data[16:26])
    has_alpha = color_type in (4, 6) or b"tRNS" in data
    return w, h, has_alpha


def load_json(path: pathlib.Path):
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as e:
        err(f"{rel(path)}: can't read JSON ({e})")
        return None


def gd_const_keys(path: pathlib.Path, const: str) -> list[str]:
    """Top-level keys of `const NAME := { ... }` in a GDScript file."""
    text = path.read_text()
    m = re.search(rf"^const {const} := \{{(.*?)^\}}", text, re.S | re.M)
    if not m:
        err(f"{rel(path)}: can't find const {const}")
        return []
    return re.findall(r'^\t"([A-Za-z0-9_]+)":', m.group(1), re.M)


# --- sprite sheets --------------------------------------------------------------
def check_sprites() -> None:
    layout = load_json(ROOT / "data/sprites.json")
    if not layout:
        return
    for name, sheet in layout.get("sheets", {}).items():
        png = ROOT / f"art/sprites/{name}.png"
        if not png.exists():
            err(f"{rel(png)}: missing (listed in data/sprites.json)")
            continue
        info = png_info(png)
        if not info:
            err(f"{rel(png)}: not a PNG")
            continue
        w, h, alpha = info
        fw, fh = sheet["frame"]
        anims = sheet["anims"]
        want = (fw * SHEET_COLS, fh * len(anims))
        if (w, h) != want:
            err(f"{rel(png)}: is {w}x{h}, expected {want[0]}x{want[1]} "
                f"({SHEET_COLS} frames of {fw}x{fh} x {len(anims)} animations)")
        if not alpha:
            err(f"{rel(png)}: has no transparency")
        hires = ROOT / f"art/sprites/{name}@2x.png"     # optional double-resolution art
        if hires.exists():
            hinfo = png_info(hires)
            if not hinfo or hinfo[:2] != (want[0] * 2, want[1] * 2):
                err(f"{rel(hires)}: is {hinfo[0]}x{hinfo[1] if hinfo else '?'}, expected {want[0] * 2}x{want[1] * 2} "
                    f"(double-resolution art: frames of {fw * 2}x{fh * 2}, same rows)")
            elif not hinfo[2]:
                err(f"{rel(hires)}: has no transparency")
        for a in anims:
            if not 1 <= int(a["frames"]) <= SHEET_COLS:
                err(f"data/sprites.json: {name}.{a['name']} has {a['frames']} frames (1-{SHEET_COLS} fit in a row)")
            if a.get("fps", 0) <= 0:
                err(f"data/sprites.json: {name}.{a['name']} fps must be > 0")
    for png in sorted((ROOT / "art/sprites").glob("*.png")):
        if png.stem.removesuffix("@2x") not in layout.get("sheets", {}) and png.stem != "props":
            warn(f"{rel(png)}: not listed in data/sprites.json (unused?)")


def check_props() -> None:
    rects = load_json(ROOT / "data/props.json")
    png = ROOT / "art/sprites/props.png"
    info = png_info(png) if png.exists() else None
    if not rects or not info:
        err("art/sprites/props.png or data/props.json missing")
        return
    w, h, _ = info
    for name, r in rects.items():
        if name.startswith("_"):
            continue
        x, y, rw, rh = r
        if rw <= 0 or rh <= 0 or x < 0 or y < 0 or x + rw > w or y + rh > h:
            err(f"data/props.json: '{name}' {r} is outside props.png ({w}x{h})")


def check_tiles_and_backgrounds() -> set[str]:
    areas = {p.stem for p in (ROOT / "art/tiles").glob("*.png")}
    for area in sorted(areas):
        info = png_info(ROOT / f"art/tiles/{area}.png")
        if not info or info[:2] != TILE_ATLAS:
            err(f"art/tiles/{area}.png: expected {TILE_ATLAS[0]}x{TILE_ATLAS[1]}, got {info[:2] if info else 'not a PNG'}")
        for layer, size in BG_LAYERS.items():
            png = ROOT / f"art/backgrounds/{area}/{layer}.png"
            if not png.exists():
                err(f"{rel(png)}: missing")
                continue
            info = png_info(png)
            if not info or info[:2] != size:
                err(f"{rel(png)}: expected {size[0]}x{size[1]}, got {info[:2] if info else 'not a PNG'}")
    bgs = load_json(ROOT / "data/backgrounds.json") or {}
    for area in bgs:
        if area not in areas:
            err(f"data/backgrounds.json: area '{area}' has no art/tiles/{area}.png")
    return areas


# --- levels ---------------------------------------------------------------------
def check_levels(areas: set[str]) -> None:
    game = (ROOT / "scripts/autoload/game.gd").read_text()
    m = re.search(r"^const LEVELS := \[(.*?)\]", game, re.M)
    level_ids = re.findall(r'"([a-z0-9_]+)"', m.group(1)) if m else []
    if not level_ids:
        err("scripts/autoload/game.gd: can't read const LEVELS")
    text_levels = set(gd_const_keys(ROOT / "scripts/config/game_text.gd", "LEVELS"))
    music = set(gd_const_keys(ROOT / "scripts/config/sound_files.gd", "MUSIC"))
    object_types = {p.stem for p in (ROOT / "scripts/levels/objects").glob("*.gd")}

    for f in sorted((ROOT / "data/levels").glob("*.json")):
        if f.stem not in level_ids:
            warn(f"{rel(f)}: not in Game.LEVELS, so it can't be played")
    for lid in level_ids:
        path = ROOT / f"data/levels/{lid}.json"
        if not path.exists():
            err(f"{rel(path)}: missing (listed in Game.LEVELS)")
            continue
        lv = load_json(path)
        if lv is None:
            continue
        where = rel(path)
        if lv.get("id") != lid:
            err(f"{where}: id is '{lv.get('id')}', expected '{lid}'")
        if lid not in text_levels:
            err(f"{where}: no entry for '{lid}' in GameText.LEVELS (scripts/config/game_text.gd)")
        if lv.get("theme") not in areas:
            err(f"{where}: theme '{lv.get('theme')}' has no art/tiles/<theme>.png")
        if lv.get("music") and lv["music"] not in music:
            err(f"{where}: music '{lv['music']}' is not in SoundFiles.MUSIC")
        width = lv.get("width_tiles")
        if not isinstance(width, (int, float)) or width <= 0:
            err(f"{where}: width_tiles must be a positive number")
            width = None
        for key in ("player_start", "earl_start"):
            v = lv.get(key)
            if not isinstance(v, (int, float)) or (width and not 0 <= v < width):
                err(f"{where}: {key}={v} must be a number inside the level (0-{width})")
        for i, o in enumerate(lv.get("objects", [])):
            t = o.get("type") if isinstance(o, dict) else None
            if t not in object_types:
                err(f"{where}: objects[{i}] type '{t}' has no scripts/levels/objects/{t}.gd")
            x = o.get("x") if isinstance(o, dict) else None
            if not isinstance(x, (int, float)):
                err(f"{where}: objects[{i}] ({t}) needs a numeric x")
            elif width and not 0 <= x <= width:
                warn(f"{where}: objects[{i}] ({t}) x={x} is outside the level width {width}")
    chase = ROOT / "data/chases/main_street.json"
    c = load_json(chase) if chase.exists() else None
    if c is not None and not (0 < c.get("end", 0) <= c.get("length", 0)):
        err(f"{rel(chase)}: end must be between 0 and length")


# --- text -----------------------------------------------------------------------
def check_text() -> None:
    path = ROOT / "scripts/config/game_text.gd"
    signs = len(re.findall(r'"[^"]*"', re.search(r"^const SHOP_SIGNS := \[(.*?)\]", path.read_text(), re.S | re.M).group(1)))
    ok = NAME_SLOTS | {s.upper() for s in NAME_SLOTS} | {f"sign{i}" for i in range(signs)}
    for n, line in enumerate(path.read_text().splitlines(), 1):
        if line.lstrip().startswith("#"):
            continue
        for slot in re.findall(r"\{([A-Za-z0-9_]+)\}", line):
            if slot not in ok:
                err(f"{rel(path)}:{n}: unknown name slot {{{slot}}} (Names.fmt() fills {', '.join(sorted(NAME_SLOTS))}, sign0-{signs - 1})")


# Dict constants whose second-level keys are field names (level -> fields...),
# and those whose first-level keys are field names (menu entries).
FIELDS_AT_DEPTH_2 = ("LEVELS", "HEROES", "FAVORS")
FIELDS_AT_DEPTH_1 = ("MENU", "UI")


def check_text_is_used() -> None:
    """Text the game never reads never appears on screen: every constant in
    game_text.gd must be used as GameText.NAME, and every field name inside
    LEVELS/HEROES/FAVORS/MENU/UI must be read somewhere in the code."""
    path = ROOT / "scripts/config/game_text.gd"
    text = path.read_text()
    code = "\n".join(p.read_text() for d in ("scripts", "tools") for p in sorted((ROOT / d).rglob("*.gd"))
                     if p != path)
    for m in re.finditer(r"^const ([A-Z][A-Z0-9_]*)\b", text, re.M):
        name = m.group(1)
        if not re.search(rf"\bGameText\.{name}\b", code):
            line = text[:m.start()].count("\n") + 1
            err(f"{rel(path)}:{line}: {name} is never used by the game's code, so its text never appears "
                f"(add the lines to an existing list instead, or change the code to read it)")
    # Names the code builds, like m["ctl_" + action]: any field starting with such a prefix counts as read.
    built_prefixes = tuple(re.findall(r"\"([a-z0-9_]+_)\"\s*\+", code))
    for const, depth in [(c, 2) for c in FIELDS_AT_DEPTH_2] + [(c, 1) for c in FIELDS_AT_DEPTH_1]:
        m = re.search(rf"^const {const} := \{{(.*?)^\}}", text, re.S | re.M)
        if not m:
            continue
        start_line = text[:m.start()].count("\n") + 1
        for i, line in enumerate(m.group(1).splitlines()):
            k = re.match(r"^\t{%d}\"([a-z0-9_]+)\":" % depth, line)
            if k and not k.group(1).startswith(built_prefixes) and not re.search(rf"[\"'.]{k.group(1)}\b", code):
                err(f"{rel(path)}:{start_line + i}: field \"{k.group(1)}\" in {const} is never read by the "
                    f"game's code, so its text never appears")


# --- audio ----------------------------------------------------------------------
def check_audio() -> None:
    sound_files = ROOT / "scripts/config/sound_files.gd"
    for folder, const in (("sfx", "SFX"), ("music", "MUSIC")):
        names = set(gd_const_keys(sound_files, const))
        for f in sorted((ROOT / "audio" / folder).iterdir()):
            if f.suffix.lower() in AUDIO_EXT and f.stem not in names:
                err(f"{rel(f)}: no sound called '{f.stem}' in SoundFiles.{const}")
            elif f.suffix.lower() not in AUDIO_EXT | {".txt", ".import"} and not f.name.startswith("."):
                warn(f"{rel(f)}: not an .ogg/.wav/.mp3 file")
    lines_md = (ROOT / "audio/voices/LINES.md").read_text()
    known: dict[str, set[str]] = {}
    folder = None
    for line in lines_md.splitlines():
        m = re.match(r"^## .*`audio/voices/([a-z_]+)/`", line)
        if m:
            folder = m.group(1)
            known.setdefault(folder, set())
        m = re.match(r"^\| `([a-z0-9_]+)\.mp3` \|", line)
        if m and folder:
            known[folder].add(m.group(1))
    for f in sorted((ROOT / "audio/voices").glob("*/*")):
        if f.suffix.lower() not in AUDIO_EXT:
            continue
        who = f.parent.name
        if f.stem not in known.get(who, set()):
            warn(f"{rel(f)}: not a line listed for '{who}' in audio/voices/LINES.md (stale or misnamed?)")


def main() -> int:
    check_sprites()
    check_props()
    areas = check_tiles_and_backgrounds()
    check_levels(areas)
    check_text()
    check_text_is_used()
    check_audio()
    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"validate: {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
