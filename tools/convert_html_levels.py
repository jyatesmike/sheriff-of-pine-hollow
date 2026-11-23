#!/usr/bin/env python3
"""Convert the LEVELS table from the browser version into data/levels/*.json.

The browser game used a 960x540 screen with 28x44 characters. The Godot version
runs at 480x270 with 32x48 sprites, so the sprites are relatively much bigger.
We therefore scale world distances by 0.75 and snap everything to the 16 px tile
grid. Heights are stored as "tiles above the ground line" so the data stays
readable and independent of where the ground sits on screen.

Usage:  python3 tools/convert_html_levels.py path/to/sheriff-of-pine-hollow.html
Run it once; afterwards the JSON files are the source of truth and can be
hand-edited.
"""
import json, re, sys, pathlib

SCALE = 0.75
TILE = 16
OLD_GY = 460
MAX_GAP = 6          # tiles; keeps every gap jumpable with the new physics


def tx(x):
    return int(round(x * SCALE / TILE))


def th(y):
    """old screen y -> tiles above ground"""
    return max(1, int(round((OLD_GY - y) * SCALE / TILE)))


def js_to_py(src):
    # The LEVELS literal is plain JS; make it parse as JSON.
    s = src.replace("GY-", f"{OLD_GY}-")
    s = re.sub(r"(\d+)-(\d+)", lambda m: str(int(m.group(1)) - int(m.group(2))), s)
    s = re.sub(r"([{,]\s*)([A-Za-z_]\w*)\s*:", r'\1"\2":', s)
    # single-quoted strings -> double-quoted
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c in "'\"":
            q, j, buf = c, i + 1, []
            while s[j] != q:
                if s[j] == "\\":
                    buf.append(s[j + 1]); j += 2; continue
                buf.append(s[j]); j += 1
            out.append(json.dumps("".join(buf))); i = j + 1
        else:
            out.append(c); i += 1
    s = "".join(out)
    s = re.sub(r",\s*([\]}])", r"\1", s)
    s = s.replace("true", "true").replace("false", "false")
    return json.loads(s)


NAME_SWAPS = [("Deputy Plum", "{deputy}"), ("PINE HOLLOW", "{TOWN}"), ("Pine Hollow", "{town}"),
              ("Sheriff", "{sheriff}"), ("Earl", "{earl}"), ("Dewey", "{dewey}")]


def names(obj):
    """Swap original names for {placeholders} so renamed characters flow through."""
    if isinstance(obj, str):
        for a, b in NAME_SWAPS:
            obj = re.sub(r"\b" + re.escape(a) + r"\b", b, obj)
        return obj
    if isinstance(obj, list):
        return [names(o) for o in obj]
    if isinstance(obj, dict):
        return {k: names(v) for k, v in obj.items()}
    return obj


def convert(lv):
    lv = names(lv)
    ground, prev_end = [], None
    for a, b in lv["ground"]:
        ta, tb = tx(a), tx(b)
        if prev_end is not None and ta - prev_end > MAX_GAP:
            ta = prev_end + MAX_GAP
        ground.append([ta, tb]); prev_end = tb
    width = tx(lv["LW"])
    out = {
        "name": lv["name"], "episode": lv["ep"], "theme": lv["theme"],
        "role": lv.get("role", "sheriff"), "width_tiles": width,
        "blurb": lv["blurb"], "start_line": lv["start"], "win_line": lv["win"],
        "town_sign": lv["sign"],
        "player_start": 8 if lv.get("role") != "earl" else 20,
        "earl_start": 26,
        "ground": ground,
        # crates are 2x2 tiles; stack 0 sits on the ground
        "crates": [{"x": tx(x), "stack": s} for x, s in lv["boxes"]],
        # one-way awnings / lofts: x, height above ground, width (tiles)
        "platforms": [{"x": tx(x), "h": th(y), "w": max(4, tx(w))} for x, y, w in lv["plats"]],
        "hens": [[tx(a), tx(b)] for a, b in lv.get("hens", [])],
        "geese": [[tx(a), tx(b)] for a, b in lv.get("geese", [])],
        "flap_hens": [tx(x) for x in lv.get("flaps", [])],
        "pie_arcs": [[tx(a), tx(b)] for a, b in lv.get("arcs", [])],
        "pies": [tx(x) for x in lv["pies"]],
        "golden_pie": [{"x": tx(x), "h": th(y)} for x, y in lv.get("gold", [])],
        "stones": [tx(x) for x in lv.get("stones", [])],
        "dewey": [{"x": tx(x), "line": line} for x, line in lv["deweys"]],
        "flags": {k: True for k in ("rocks", "logs", "gapPies") if lv.get(k)},
        "fence_x": width - 6,
    }
    return out


def main(path):
    html = pathlib.Path(path).read_text(encoding="utf-8")
    m = re.search(r"const LEVELS=(\[.*?\]);\s*\n", html, re.S)
    levels = js_to_py(m.group(1))
    slugs = ["main_street", "chicken_run", "rock_creek", "gone_fishin", "earls_big_break"]
    dest = pathlib.Path(__file__).resolve().parent.parent / "data" / "levels"
    dest.mkdir(parents=True, exist_ok=True)
    for slug, lv in zip(slugs, levels):
        (dest / f"{slug}.json").write_text(json.dumps(convert(lv), indent=1) + "\n")
        print("wrote", slug)


if __name__ == "__main__":
    main(sys.argv[1])
