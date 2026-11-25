# Art guide

All art in this folder is **generated placeholder art** from `tools/make_placeholders.gd`.
Replace any PNG with hand-drawn or AI-made art of the same size and layout and the game
uses it with no code changes.

Regenerate everything:
- in the editor: open `tools/make_placeholders.gd`, then **File > Run**
- or from a terminal: `godot --headless -s tools/make_placeholders_cli.gd`, then `godot --headless --import`

Regenerating overwrites every PNG here, so keep hand-made replacements somewhere safe.

## Style target
The user's reference screenshot (kept outside the repo) sets the look:
- semi-realistic proportions, shaded limbs and cloth folds, expressive faces
- 1-px dark outline (`#24140e`) around every part, so overlapping limbs stay readable
- 4-step colour ramps per material, light from the top-left
- busy, lived-in storefronts: awnings, display windows, signboards, lamps, benches, planters
- HUD with a character portrait, hearts, a pie counter, a meter and a score

Use only the *style*. Characters, names, signs and places stay this game's own.

## Characters — `art/sprites/<name>.png`
Sheriff, Earl, Dewey, Jim, the deputy and the townsfolk share one layout. Each frame is
**48×64**, with the feet on the bottom row and the body centred. The sheet is **8 frames wide
(384 px) and 18 rows tall (1152 px)**, and each row is one animation, with frames left to right:

| Row | Animation | Frames | | Row | Animation | Frames |
|---|---|---|---|---|---|---|
| 0 | idle | 4 | | 9 | slide (dash) | 3 |
| 1 | run | 8 | | 10 | tiphat | 4 |
| 2 | jump | 1 | | 11 | taunt | 4 |
| 3 | fall | 1 | | 12 | stunned | 2 |
| 4 | land | 2 | | 13 | cuffed | 2 |
| 5 | skid | 2 | | 14 | aim (popgun) | 3 |
| 6 | throw | 4 | | 15 | fumble | 4 |
| 7 | hurt | 2 | | 16 | climb | 4 |
| 8 | victory | 6 | | 17 | climb_idle | 1 |

Frame rates and looping are in `data/sprites.json`. `python3 tools/validate.py` checks every
sheet against that file (size, rows, transparency).

### Double-resolution art (more detail on the handheld) — `art/sprites/<name>@2x.png`
Any character sheet can have a double-resolution twin next to it, e.g. `sheriff@2x.png`:
the same rows and frame counts, with frames of **96×128** (sheet 768×2304), feet on the
bottom edge, facing right. On the handheld display (2 screen pixels per world pixel) the game
draws it at half scale, so the character is the same size and plays the same, and the
extra pixels show as extra detail. Computers keep using the normal sheet. Characters without
an `@2x` sheet keep their normal art, so sheets can be upgraded one at a time.

From PixelLab: make the character about twice as tall (around 112 px, on a 128 px canvas),
put the GIFs in `art/source/pixellab/<name>@2x/` and build with `--scale=2`, e.g.
`python3 tools/pixellab_gifs.py sheriff art/sprites/sheriff@2x.png --scale=2 idle=... run=...`.
`tools/validate.py` checks the size.

## Animals — `art/sprites/hen.png`, `goose.png`
Frames are **32×24** and face right, with the feet on the bottom row. The rows are:
walk (4), peck (3), flap (2), tumble (2).

## Props — `art/sprites/props.png`
This is a packed atlas. Every item's rectangle is listed in `data/props.json`. If you
redraw a prop at a different size, update its rectangle there. The atlas holds:
- the crate, the three awning pieces and the awning post
- the end gate and the blank town signboard
- sidewalk furniture: lamp, bench, planter, hydrant, mailbox, barrel
- pie, golden pie, full and empty hearts, rock, boulder, log, cork
- the 28×28 HUD portraits

## Tiles — `art/tiles/<area>.png`
One **64×64** atlas per area (town, farm, quarry, lake, night), made of 4×4 tiles of 16×16.
Each tile is one combination of neighbours for Godot's "match sides" terrain. The tile at
column `mask % 4`, row `mask / 4` has a neighbour on its top / right / bottom / left side
when bit 1 / 2 / 4 / 8 of `mask` is set.

## Backgrounds — `art/backgrounds/<area>/`
| File | Size | Scroll speed |
|---|---|---|
| `sky.png` | 480×270 | fixed to the screen |
| `far.png` | 1024×120 | 0.15 |
| `mid.png` | 1024×140 | 0.3 |
| `main.png` | 1536×160 | 0.55 |
| `near.png` | 1024×200 | 0.8 |

The scrolling layers tile horizontally, and their bottom edge sits on the ground line.
Shop signboards in `main.png` are left blank: the game writes the player's shop names
onto the rectangles listed in `data/backgrounds.json`.
