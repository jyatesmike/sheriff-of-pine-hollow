# Level 1 ("Jailbreak on Main Street") art drop

Raw PixelLab output for the main_street redesign. Not yet wired into the
engine (sprite sheets, sizes, object scripts) — that's the follow-up pass.

Sizing rule: Sheriff ~120px tall, so one storey ~128px. Buildings are on a
320x256 canvas (two storeys + roof), all transparent-background, side view.

## buildings/ (static, 320x256)
- hardware.png, diner.png, barbershop.png, post_office.png, grocery.png,
  jailhouse.png — six distinct storefronts for the shop-row beat. Each has a
  blank sign/plaque area for the game to write shop names onto, as it does
  for the existing backgrounds.

## props/window_wave/ (animation, 64x96, 9 frames incl. input frame 0)
- frame_0..frame_8.png — shutters swing open, neighbour leans out and waves,
  leans back in, shutters close. Loop: false (one-shot "warning" beat).
