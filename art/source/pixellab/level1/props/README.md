# Street props — "Jailbreak on Main Street"

All transparent-background, side view, matching the buildings' style line.

| Asset | Static | Animation | Frames | Loop? |
|---|---|---|---|---|
| Flowerpot | `pot.png` | `pot_fall/` | 9 (incl. input) | no — one-shot fall |
| Flowerpot (impact) | — | `pot_smash/` | 9 | no — one-shot smash |
| Awning | `awning_raised.png` | — | — | — |
| Jailhouse door | `jail_door_closed.png` | `jail_door/` | 7 | no — one-shot burst |
| Chimney | `chimney.png` | `chimney_smoke/` | 9 | **yes** |
| Fruit cart | `fruit_cart.png` | `fruit_cart/` | 7 | no — one-shot tip |
| Fountain | `fountain.png` | `fountain/` | 9 | **yes** |
| Upstairs window | `window_closed.png` | `window_wave/` | 9 | no — one-shot warn |

## Awning: no animation shipped
Three PixelLab passes (animate_image, then animate_image_pixminimax twice with
escalating squash/trampoline wording) all failed to produce real fabric
deformation — the model kept the awning rigid across every frame. Rather than
keep burning generations chasing it, recommend animating the bounce **in
code**: scale the awning sprite's Y (and maybe X) in a short tween/squash
curve when the Sheriff lands on it, the way trampoline bounces are usually
done in 2D platformers. Looks better than a handful of baked frames would
and costs nothing. `awning_raised.png` is the sprite to scale.

## Numbering note
`pot_fall` and `pot_smash` are both animated from the same static `pot.png`
(there's no natural "mid-fall" frame to chain them from) — in-engine, play
`pot_fall` then cut to `pot_smash`'s last couple of frames on impact.
