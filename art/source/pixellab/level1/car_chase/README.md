# Car chase assets

All transparent background except `chase_roadside.png` (a scrolling backdrop
strip, opaque like the existing background layers).

| Asset | Static | Animation | Frames | Loop? |
|---|---|---|---|---|
| Milk truck | `milk_truck.png` | `milk_truck_bounce/` | 5 | **yes** |
| Patrol car | `patrol_car.png` | `patrol_siren/` | 5 | **yes** |
| Milk bottle | `milk_bottle.png` | `bottle_spin/` | 5 | no — thrown arc |
| Milk puddle | — | `milk_splat/` | 5 | no — one-shot impact |
| Railroad crossing | `railroad_crossing.png` | `crossing_lower/` | 7 | no — gate stays down |
| Cow | `cow.png` | `cow_walk/` | 7 | **yes** |
| Roadside backdrop | `chase_roadside.png` (400x140) | — | — | opaque, replaces/extends `data/chases/main_street.json`'s road backdrop |

Note: `chase_roadside.png` has a converging-perspective road (vanishing
point), not a flat orthographic strip like the town backgrounds — gorgeous on
its own, but check how it reads once tiled/scrolled; it may need a flatter
redo if the perspective makes the seam visible.
