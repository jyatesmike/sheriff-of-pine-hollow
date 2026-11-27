# A chimney on a rooftop that puffs a hot updraft every few seconds,
# launching you high into the air.   {"type": "chimney", "x": 104, "h": 7}
extends LevelObject

const PERIOD := 150          # frames between puffs
const PUFF := 40             # frames the updraft lasts
const LIFT := -560.0

# PixelLab art: the chimney and its smoke are one sheet per frame (the smoke
# is drawn emanating from this specific chimney), so puffing just swaps which
# whole frame is shown. TEX_OFFSET anchors the sheet's roof contact to `top`
# (not verified in a live editor — no Godot binary in this sandbox).
const CHIMNEY_TEX := preload("res://art/sprites/props/chimney.png")
const SMOKE_FRAMES := [
	preload("res://art/sprites/props/chimney_smoke/frame_1.png"),
	preload("res://art/sprites/props/chimney_smoke/frame_2.png"),
	preload("res://art/sprites/props/chimney_smoke/frame_3.png"),
	preload("res://art/sprites/props/chimney_smoke/frame_4.png"),
	preload("res://art/sprites/props/chimney_smoke/frame_5.png"),
	preload("res://art/sprites/props/chimney_smoke/frame_6.png"),
	preload("res://art/sprites/props/chimney_smoke/frame_7.png"),
	preload("res://art/sprites/props/chimney_smoke/frame_8.png"),
]
const TEX_OFFSET := Vector2(-16, -42)

var t := 0
var top := 0.0


func _setup() -> void:
	top = tiles_up(o.get("h", 7)) - 22.0
	t = int(o.get("x", 0) * 7) % PERIOD


func step(_delta: float) -> void:
	t = (t + 1) % PERIOD
	if t < PUFF:
		var col := Rect2(global_position + Vector2(-9, top - 70), Vector2(18, 72))
		var p := player()
		if col.intersects(p.body_rect()) and p.velocity.y > LIFT * 0.6:
			p.velocity.y = LIFT
			p.jumping = false
			if t == 0 or p.velocity.y == LIFT:
				Audio.sfx("dash", 0.5)
	queue_redraw()


func _draw() -> void:
	var tex := CHIMNEY_TEX
	if t < PUFF:
		tex = SMOKE_FRAMES[clampi(t * SMOKE_FRAMES.size() / PUFF, 0, SMOKE_FRAMES.size() - 1)]
	draw_texture(tex, Vector2(0, top) + TEX_OFFSET)
