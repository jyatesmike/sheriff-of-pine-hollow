# The Ferris wheel. Its gondolas are platforms that stay level as the
# wheel turns. The rides fence beside it is too tall to jump: ride a
# gondola up over the top and hop off on the far side.
#   {"type": "ferris_wheel", "x": 84, "h": 9.5, "r": 7, "cars": 8}
extends LevelObject

const SPIN := 0.32
const HANG := 14.0

var hub := Vector2.ZERO
var r := 0.0
var angle := 0.0
var cars: Array = []
var _t := 0.0


func _setup() -> void:
	hub = Vector2(0, tiles_up(o.get("h", 9.5)))
	r = o.get("r", 7.0) * TILE
	for k in int(o.get("cars", 8)):
		var b := AnimatableBody2D.new()
		b.sync_to_physics = true
		b.collision_layer = 2
		b.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(28, 6)
		cs.shape = sh
		cs.position = Vector2(0, 3)
		cs.one_way_collision = true
		b.add_child(cs)
		add_child(b)
		cars.append(b)
	_place()
	if Lighting.enabled():
		add_child(Lighting.radial(hub, Color(1, 0.75, 0.55), r / 40.0, 0.55))


func _rim(k: int) -> Vector2:
	var a := angle + k * TAU / cars.size()
	return hub + Vector2(cos(a), sin(a)) * r


func _place() -> void:
	for k in cars.size():
		cars[k].position = (_rim(k) + Vector2(0, HANG)).round()


func step(delta: float) -> void:
	_t += delta
	angle = fmod(angle + SPIN * delta, TAU)
	_place()
	queue_redraw()


## Test bot: board a low gondola on the left, ride over the fence, hop off on the right.
func bot_hint(p: Player) -> Dictionary:
	var fence_x: float = global_position.x + o.get("fence", 4) * TILE
	var px := p.global_position.x
	if px > fence_x + 24.0 or px < global_position.x - r - 80.0:
		return {}
	var riding := p.is_on_floor() and p.global_position.y < global_position.y - 10.0
	if riding:
		# ride until we're past the fence and low enough, then step off to the right
		var low: bool = p.global_position.y > global_position.y - 4.5 * TILE
		if px > fence_x + 8.0 and low:
			return {"dir": 1.0}
		return {"dir": 0.0}
	if not p.is_on_floor():
		# steer onto the nearest gondola below
		var best := INF
		var tx := px
		for c in cars:
			var cp: Vector2 = global_position + c.position
			if cp.y > p.global_position.y - 4.0 and absf(cp.x - px) < absf(best):
				best = cp.x - px
				tx = cp.x
		return {"dir": 0.0 if absf(tx - px) < 4.0 else signf(tx - px)}
	if px > fence_x:
		return {}
	# on the ground left of the fence: wait under the low point for a gondola to come by
	var board_x := global_position.x - 1.2 * TILE
	if absf(px - board_x) > 6.0:
		return {"dir": signf(board_x - px)}
	for c in cars:
		var cp: Vector2 = global_position + c.position
		var h: float = global_position.y - cp.y
		if h > 20.0 and h < 70.0 and cp.x > px - 6.0 and cp.x < px + 26.0:
			return {"dir": 1.0, "jump": true}
	return {"dir": 0.0}


func _draw() -> void:
	var steel := Color("d8d0c0")
	var dark := Color("8a8070")
	# A-frame legs
	draw_line(hub, Vector2(-r * 0.55, 0), OUTLINE, 6.0)
	draw_line(hub, Vector2(r * 0.55, 0), OUTLINE, 6.0)
	draw_line(hub, Vector2(-r * 0.55, 0), dark, 4.0)
	draw_line(hub, Vector2(r * 0.55, 0), dark, 4.0)
	# rim and spokes, with light bulbs
	draw_arc(hub, r, 0, TAU, 48, OUTLINE, 4.0)
	draw_arc(hub, r, 0, TAU, 48, steel, 2.0)
	draw_arc(hub, r * 0.72, 0, TAU, 40, steel.darkened(0.2), 1.0)
	for k in 16:
		var a := angle + k * TAU / 16.0
		var e := hub + Vector2(cos(a), sin(a)) * r
		draw_line(hub, e, steel.darkened(0.15), 1.0)
		var lit := (k + int(_t * 4.0)) % 3 == 0
		draw_circle(e, 2.0, Color("ffe080") if lit else Color("b08a50"))
	# gondolas
	var cols := [Color("e84a4a"), Color("4a8ae8"), Color("f0c040"), Color("6ac06a")]
	for k in cars.size():
		var rim := _rim(k)
		var c: Vector2 = cars[k].position
		draw_line(rim, c + Vector2(0, -16), dark, 1.0)
		var col: Color = cols[k % cols.size()]
		_gondola(c, col, dark)
	draw_circle(hub, 7.0, OUTLINE)
	draw_circle(hub, 5.0, Color("c83a3a"))


## A swinging bench car: striped canopy, scalloped trim, seat and a curved tub.
func _gondola(c: Vector2, col: Color, dark: Color) -> void:
	# canopy posts
	draw_line(c + Vector2(-11, -17), c + Vector2(-12, 0), OUTLINE, 3.0)
	draw_line(c + Vector2(11, -17), c + Vector2(12, 0), OUTLINE, 3.0)
	draw_line(c + Vector2(-11, -17), c + Vector2(-12, 0), Color("c8c0b0"), 1.0)
	draw_line(c + Vector2(11, -17), c + Vector2(12, 0), Color("c8c0b0"), 1.0)
	# striped canopy
	var roof := PackedVector2Array([c + Vector2(-15, -16), c + Vector2(0, -25), c + Vector2(15, -16)])
	draw_colored_polygon(PackedVector2Array([c + Vector2(-17, -15), c + Vector2(0, -27), c + Vector2(17, -15)]), OUTLINE)
	draw_colored_polygon(roof, Color("f4ecd8"))
	for k in 3:
		var x0 := -15.0 + k * 10.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -25), c + Vector2(x0, -16), c + Vector2(x0 + 5, -16)]), col)
	for k in 6:
		draw_circle(c + Vector2(-12.5 + k * 5.0, -15), 2.0, col.darkened(0.15))
	draw_circle(c + Vector2(0, -26), 1.5, Color("f0c848"))
	# tub
	var tub := PackedVector2Array()
	for i in 9:
		var u := -1.0 + i / 4.0
		tub.append(c + Vector2(u * 14.0, 12.0 - (1.0 - u * u) * 0.0 - absf(u) * 3.0))
	tub.append(c + Vector2(15, 0))
	tub.append(c + Vector2(-15, 0))
	var tub_o := PackedVector2Array()
	for q in tub:
		tub_o.append(c + (q - c) * 1.1)
	draw_colored_polygon(tub_o, OUTLINE)
	draw_colored_polygon(tub, col)
	draw_rect(Rect2(c + Vector2(-14, 1), Vector2(28, 2)), col.lightened(0.35))
	draw_rect(Rect2(c + Vector2(-12, 8), Vector2(24, 2)), col.darkened(0.25))
	# gold trim and a number badge
	draw_line(c + Vector2(-15, 4), c + Vector2(15, 4), Color("f0c848"), 1.0)
	draw_circle(c + Vector2(0, 6), 2.5, Color("f4ecd8"))
	draw_circle(c + Vector2(0, 6), 1.0, col.darkened(0.3))
	# seat back peeking over the rim
	draw_rect(Rect2(c + Vector2(-9, -4), Vector2(18, 4)), OUTLINE)
	draw_rect(Rect2(c + Vector2(-8, -3), Vector2(16, 2)), dark)
