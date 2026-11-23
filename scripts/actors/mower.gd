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
const RED := Color("c8302a")
const RED_LIT := Color("e85a4a")
const RED_DARK := Color("8a1e1a")


## Seat back and roll bar (drawn behind the rider).
static func draw_back(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_line(c + Vector2(-12, -6), c + Vector2(-12, -40), OUTLINE, 4.0)
	ci.draw_line(c + Vector2(-12, -6), c + Vector2(-12, -40), Color("3a3a40"), 2.0)
	ci.draw_line(c + Vector2(-14, -40), c + Vector2(-6, -40), OUTLINE, 4.0)
	ci.draw_line(c + Vector2(-14, -40), c + Vector2(-6, -40), Color("3a3a40"), 2.0)
	ci.draw_rect(Rect2(c + Vector2(-11, -30), Vector2(7, 18)).grow(1), OUTLINE)
	ci.draw_rect(Rect2(c + Vector2(-11, -30), Vector2(7, 18)), Color("2a2a30"))
	ci.draw_rect(Rect2(c + Vector2(-10, -29), Vector2(2, 16)), Color("4a4a54"))


## The mower body (in front of the rider). `full` adds lap bars and clippings.
static func draw_mower(ci: CanvasItem, c: Vector2, s: float, t: float, full := false) -> void:
	var bob := roundf(sin(t * 40.0) * 0.6) if full else 0.0
	var o := c + Vector2(0, bob)
	# big rear drive wheel, small front caster
	var rw := o + Vector2(-10, -6) * s
	ci.draw_circle(rw, 7.0 * s + 1.0, OUTLINE)
	ci.draw_circle(rw, 7.0 * s, Color("1e1e22"))
	ci.draw_circle(rw, 3.0 * s, Color("8a8a94"))
	var spoke := Vector2.from_angle(t * 18.0) * 3.0 * s
	ci.draw_line(rw - spoke, rw + spoke, Color("4a4a54"), 1.0)
	var fw := o + Vector2(13, -3) * s
	ci.draw_circle(fw, 3.0 * s + 1.0, OUTLINE)
	ci.draw_circle(fw, 3.0 * s, Color("1e1e22"))
	# mowing deck
	ci.draw_rect(Rect2(o + Vector2(-8, -7) * s, Vector2(24, 4) * s).grow(1), OUTLINE)
	ci.draw_rect(Rect2(o + Vector2(-8, -7) * s, Vector2(24, 4) * s), Color("3a3a40"))
	ci.draw_rect(Rect2(o + Vector2(-8, -7) * s, Vector2(24, 1) * s), Color("6a6a74"))
	# body / engine hood
	var body := PackedVector2Array([o + Vector2(-16, -10) * s, o + Vector2(10, -10) * s, o + Vector2(16, -16) * s,
		o + Vector2(14, -22) * s, o + Vector2(-4, -22) * s, o + Vector2(-16, -18) * s])
	var outl := PackedVector2Array()
	for p in body:
		outl.append(o + (p - o) * 1.08)
	ci.draw_colored_polygon(outl, OUTLINE)
	ci.draw_colored_polygon(body, RED)
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-4, -22) * s, o + Vector2(14, -22) * s, o + Vector2(15, -19) * s, o + Vector2(-6, -19) * s]), RED_LIT)
	ci.draw_rect(Rect2(o + Vector2(-16, -12) * s, Vector2(26, 2) * s), RED_DARK)
	# grille stripes and a little logo badge
	for k in 3:
		ci.draw_rect(Rect2(o + Vector2(8 + k * 2, -18) * s, Vector2(1, 5) * s), RED_DARK)
	ci.draw_rect(Rect2(o + Vector2(-2, -17) * s, Vector2(5, 3) * s), Color("f0d040"))
	if full:
		# lap bars up to his hands
		ci.draw_line(o + Vector2(4, -22), o + Vector2(8, -32), OUTLINE, 3.0)
		ci.draw_line(o + Vector2(4, -22), o + Vector2(8, -32), Color("2a2a30"), 1.0)
		ci.draw_rect(Rect2(o + Vector2(6, -34), Vector2(5, 2)), Color("1e1e22"))
		# grass clippings spitting out the side
		for k in 4:
			var q := fmod(t * 60.0 + k * 9.0, 30.0)
			ci.draw_rect(Rect2(o + Vector2(-14 - q * 0.7, -6 - sin(q * 0.2) * 6.0), Vector2(1, 1)), Color("6ab04a") if k % 2 == 0 else Color("9ad06a"))
