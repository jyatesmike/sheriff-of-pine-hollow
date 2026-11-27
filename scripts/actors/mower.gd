# Jim's zero-turn mower, drawn around his legs while the power-up lasts.
# Two layers: the seat back / roll bar behind him (z -1) and the body,
# wheels and lap bars in front (z +1), so he looks like he's sitting in it.
class_name Mower
extends Node2D

var front := true
var facing := 1
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	if front:
		draw_mower(self, Vector2(0, 0), 1.0, _t, true)
	else:
		draw_back(self, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


const OUTLINE := Color("24140e")

# PixelLab art (John Deere-style zero-turn): FRONT_TEX is the body, deck and
# wheels (drawn in front of the rider); BACK_TEX is the seat back and roll
# bar (drawn behind). Offsets anchor each texture's wheel/seat-base contact
# point to the ground line at c; check them in the editor and nudge if the
# rider doesn't look seated.
const FRONT_TEX := preload("res://art/sprites/mower_front.png")
const BACK_TEX := preload("res://art/sprites/mower_back.png")
const FRONT_OFFSET := Vector2(-24, -30)
const BACK_OFFSET := Vector2(-19, -46)


## Seat back and roll bar (drawn behind the rider).
static func draw_back(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_texture(BACK_TEX, c + BACK_OFFSET)


## The mower body (in front of the rider). `full` adds lap bars and clippings.
static func draw_mower(ci: CanvasItem, c: Vector2, s: float, t: float, full := false) -> void:
	var bob := roundf(sin(t * 40.0) * 0.6) if full else 0.0
	var o := c + Vector2(0, bob)
	ci.draw_texture_rect(FRONT_TEX, Rect2(o + FRONT_OFFSET * s, FRONT_TEX.get_size() * s), false)
	if full:
		# lap bars up to his hands
		ci.draw_line(o + Vector2(4, -22), o + Vector2(8, -32), OUTLINE, 3.0)
		ci.draw_line(o + Vector2(4, -22), o + Vector2(8, -32), Color("2a2a30"), 1.0)
		ci.draw_rect(Rect2(o + Vector2(6, -34), Vector2(5, 2)), Color("1e1e22"))
		# grass clippings spitting out the side
		for k in 4:
			var q := fmod(t * 60.0 + k * 9.0, 30.0)
			ci.draw_rect(Rect2(o + Vector2(-14 - q * 0.7, -6 - sin(q * 0.2) * 6.0), Vector2(1, 1)), Color("6ab04a") if k % 2 == 0 else Color("9ad06a"))
