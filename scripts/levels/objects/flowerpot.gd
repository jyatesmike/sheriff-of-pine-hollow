# A window box with a flowerpot that topples off when the Sheriff walks
# underneath. Watch for its shadow!   {"type": "flowerpot", "x": 20, "h": 6}
extends LevelObject

const TRIGGER := 70.0        # px ahead of the pot that sets it off
const GRAVITY := 700.0

# PixelLab art. WINDOW_FRAMES/POT_*_FRAMES play through as the pot wobbles,
# falls and smashes; offsets anchor each sheet to this object's ground-line
# origin and aren't verified in a live editor (no Godot binary in this
# sandbox) — check the window/pot line up with the wall behind it.
const WINDOW_CLOSED := preload("res://art/sprites/props/window_closed.png")
const WINDOW_FRAMES := [
	preload("res://art/sprites/props/window_wave/frame_1.png"),
	preload("res://art/sprites/props/window_wave/frame_2.png"),
	preload("res://art/sprites/props/window_wave/frame_3.png"),
	preload("res://art/sprites/props/window_wave/frame_4.png"),
	preload("res://art/sprites/props/window_wave/frame_5.png"),
	preload("res://art/sprites/props/window_wave/frame_6.png"),
	preload("res://art/sprites/props/window_wave/frame_7.png"),
	preload("res://art/sprites/props/window_wave/frame_8.png"),
]
const POT_TEX := preload("res://art/sprites/props/pot.png")
const POT_FALL_FRAMES := [
	preload("res://art/sprites/props/pot_fall/frame_1.png"),
	preload("res://art/sprites/props/pot_fall/frame_2.png"),
	preload("res://art/sprites/props/pot_fall/frame_3.png"),
	preload("res://art/sprites/props/pot_fall/frame_4.png"),
	preload("res://art/sprites/props/pot_fall/frame_5.png"),
	preload("res://art/sprites/props/pot_fall/frame_6.png"),
	preload("res://art/sprites/props/pot_fall/frame_7.png"),
	preload("res://art/sprites/props/pot_fall/frame_8.png"),
]
const POT_SMASH_FRAMES := [
	preload("res://art/sprites/props/pot_smash/frame_1.png"),
	preload("res://art/sprites/props/pot_smash/frame_2.png"),
	preload("res://art/sprites/props/pot_smash/frame_3.png"),
	preload("res://art/sprites/props/pot_smash/frame_4.png"),
	preload("res://art/sprites/props/pot_smash/frame_5.png"),
	preload("res://art/sprites/props/pot_smash/frame_6.png"),
	preload("res://art/sprites/props/pot_smash/frame_7.png"),
	preload("res://art/sprites/props/pot_smash/frame_8.png"),
]
const WINDOW_OFFSET := Vector2(-32, -96)
const POT_OFFSET := Vector2(-16, -18)

var state := 0               # 0 waiting, 1 wobbling, 2 falling, 3 broken
var t := 0
var fall_t := 0              # frames since the pot started falling (picks POT_FALL_FRAMES)
var close_t := 0             # frames since impact (picks POT_SMASH_FRAMES, closes the shutters)
var y := 0.0
var vy := 0.0


func _setup() -> void:
	y = tiles_up(o.get("h", 6)) - 6.0


func step(delta: float) -> void:
	var p := player()
	match state:
		0:
			var dx := global_position.x - p.global_position.x
			if dx < TRIGGER and dx > -10.0:
				state = 1
				t = 18
		1:
			t -= 1
			if t <= 0:
				state = 2
		2:
			fall_t += 1
			vy += GRAVITY * delta
			y += vy * delta
			var r := Rect2(global_position + Vector2(-6, y - 6), Vector2(12, 12))
			if r.intersects(p.body_rect()):
				p.hurt(global_position.x)
				_break()
			elif y >= -2.0:
				_break()
		3:
			close_t += 1
	queue_redraw()


func _break() -> void:
	state = 3
	level.dust(global_position + Vector2(0, -2), 10, Color("8a5a30"))
	Audio.sfx("break", 1.6)


func _draw() -> void:
	var box_y := tiles_up(o.get("h", 6))
	var window_tex := WINDOW_CLOSED
	match state:
		1:
			window_tex = WINDOW_FRAMES[clampi((18 - t) * 5 / 18, 0, 4)]
		2:
			window_tex = WINDOW_FRAMES[4]
		3:
			window_tex = WINDOW_FRAMES[clampi(5 + close_t / 6, 5, 7)]
	draw_texture(window_tex, Vector2(0, box_y) + WINDOW_OFFSET)
	if state < 3:
		var wob := sin(t * 1.2) * 2.0 if state == 1 else 0.0
		var py := y if state == 2 else box_y - 6.0
		var pot_tex := POT_FALL_FRAMES[clampi(fall_t / 3, 0, 7)] if state == 2 else POT_TEX
		draw_texture(pot_tex, Vector2(wob, py) + POT_OFFSET)
		if state >= 1:
			# shadow on the ground grows as the pot falls
			var k := clampf(1.0 - absf(py) / absf(box_y), 0.2, 1.0)
			draw_rect(Rect2(-8 * k - 2, -2, 16 * k + 4, 3), Color(0, 0, 0, 0.35))
	else:
		var smash_tex := POT_SMASH_FRAMES[clampi(close_t / 3, 0, 7)]
		draw_texture(smash_tex, Vector2(0, box_y - 6.0) + POT_OFFSET)
