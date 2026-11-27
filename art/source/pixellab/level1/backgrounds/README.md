# Parallax layers — Main Street + town square

Raw pieces, not yet tiled/assembled to the engine's full layer widths
(sky 480x270 fixed, far/mid/main/near 1024+ px scrolling strips — see the
game repo's `art/README.md`).

| File | Size | Replaces | Note |
|---|---|---|---|
| `sky.png` | 480x272 | `art/backgrounds/town/sky.png` | 2px taller than the engine's 270 (Pixen's height must be a multiple of 4); crop or pad. Came out as a dramatic golden-hour sky rather than "clear morning" — gorgeous, but confirm the mood before swapping in: it sets the tone for the whole level. |
| `far_hills.png` | 400x120 | `art/backgrounds/town/far.png` | Church + water tower silhouette on rolling hills, matches brief closely. |
| `mid_rooftops.png` | 400x140 | `art/backgrounds/town/mid.png` | Retuned warm/golden to match the sky above (brief asked for blue-tinted, but that clashed once the sky came out gold — judgment call, flag if you want the cooler version instead). |
| `town_square.png` | 288x232 | new — the town-square beat | Made with Pro (10 generations) after two Pixflux passes came out flat-clipart instead of matching the buildings' pixel-art style. This one matches. |

None of these are tiled into the existing 1024px-wide scrolling strips yet —
that assembly (plus the sky's 2px height mismatch) is the "support for
backgrounds" engine work.
