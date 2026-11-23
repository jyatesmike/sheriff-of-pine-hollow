# A windmill standing in the duck pond. Its sails turn slowly; the tip of
# each sail is a little platform. Hop on from the bank, ride it up over the
# top for the golden pie, and step off on the far side.
#   {"type": "windmill", "x": 195, "h": 9, "r": 5.5}
extends LevelObject

const SPIN := 0.5            # radians per second

var hub := Vector2.ZERO
var r := 0.0
var angle := 0.0
var tips: Array = []
var pond := Vector2.ZERO     # local x range of the water
var water: Water


func _setup() -> void:
	hub = Vector2(0, tiles_up(o.get("h", 9)))
	r = o.get("r", 5.5) * TILE
	var seg: Array = level.ground_segment_at(global_position.x - 120.0)
	pond = Vector2(seg[1] - global_position.x, level.next_ground_x(seg[1] + 2.0) - 24.0 - global_position.x)
	water = Water.make(level.world, Rect2(global_position.x + pond.x, global_position.y + 2.0, pond.y - pond.x, 70.0))
	for k in 4:
		var b := AnimatableBody2D.new()
		b.sync_to_physics = true
		b.collision_layer = 2
		b.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(30, 6)
		cs.shape = sh
		cs.position = Vector2(0, 3)
		cs.one_way_collision = true
		b.add_child(cs)
		add_child(b)
		tips.append(b)
	_place()


func _tip(k: int) -> Vector2:
	var a := angle + k * PI / 2.0
	return hub + Vector2(cos(a), sin(a)) * r


func _place() -> void:
	for k in 4:
		tips[k].position = _tip(k).round()


func step(delta: float) -> void:
	angle = fmod(angle + SPIN * delta, TAU)
	_place()
	queue_redraw()


## Test bot: the pond is narrow enough to jump, so no help needed.
func bot_hint(_p: Player) -> Dictionary:
	return {}


func _draw() -> void:
	# pond
	if water == null:
		draw_rect(Rect2(pond.x, 2, pond.y - pond.x, 40), Color("3a6a9a"))
		draw_rect(Rect2(pond.x, 2, pond.y - pond.x, 2), Color("8ac0e8"))
	# tower: tapering stone
	var base := 22.0
	var topw := 12.0
	var pts := PackedVector2Array([Vector2(-base, 8), Vector2(base, 8), Vector2(topw, hub.y + 6), Vector2(-topw, hub.y + 6)])
	var outline := PackedVector2Array([Vector2(-base - 1, 9), Vector2(base + 1, 9), Vector2(topw + 1, hub.y + 5), Vector2(-topw - 1, hub.y + 5)])
	draw_colored_polygon(outline, OUTLINE)
	draw_colored_polygon(pts, Color("d8ccb4"))
	# shaded right flank
	draw_colored_polygon(PackedVector2Array([Vector2(base * 0.35, 8), Vector2(base, 8), Vector2(topw, hub.y + 6), Vector2(topw * 0.35, hub.y + 6)]), Color("b8aa90"))
	draw_colored_polygon(PackedVector2Array([Vector2(-base, 8), Vector2(-base * 0.6, 8), Vector2(-topw * 0.6, hub.y + 6), Vector2(-topw, hub.y + 6)]), Color("ece2cc"))
	# stone courses with staggered joints
	var row := 0
	for y in range(int(hub.y) + 12, 8, 7):
		var k := (y - hub.y) / (8.0 - hub.y)
		var hw := lerpf(topw, base, k)
		draw_rect(Rect2(-hw, y, hw * 2, 1), Color("9a8e78"))
		var j := -hw + (4.0 if row % 2 == 0 else 8.0)
		while j < hw - 2:
			draw_rect(Rect2(j, y - 6, 1, 6), Color("a89c84"))
			j += 8.0
		row += 1
	# little arched window with a lit pane
	var wy := hub.y + 30
	draw_rect(Rect2(-4, wy - 1, 8, 10), OUTLINE)
	draw_rect(Rect2(-3, wy, 6, 8), Color("e8c060"))
	draw_rect(Rect2(-3, wy, 1, 8), Color("fff0b0"))
	draw_line(Vector2(0, wy), Vector2(0, wy + 8), Color("5a3a22"), 1.0)
	# door with planks and a latch
	outlined_rect(Rect2(-6, -22, 12, 22), Color("5a3a22"))
	draw_colored_polygon(ellipse(Vector2(0, -22), Vector2(6, 3)), Color("5a3a22"))
	for dx in [-3.0, 0.0, 3.0]:
		draw_line(Vector2(dx, -23), Vector2(dx, 0), Color("3e2814"), 1.0)
	draw_rect(Rect2(3, -12, 2, 2), Color("c8a040"))
	# cap: shingled roof, lit on the left
	draw_colored_polygon(PackedVector2Array([Vector2(-16, hub.y + 6), Vector2(16, hub.y + 6), Vector2(0, hub.y - 14)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, hub.y + 5), Vector2(14, hub.y + 5), Vector2(0, hub.y - 12)]), Color("8a3a2a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, hub.y + 5), Vector2(-2, hub.y + 5), Vector2(0, hub.y - 12)]), Color("a84a34"))
	for r in 3:
		var yy := hub.y + 1 - r * 5
		var w2 := 12.0 - r * 4.0
		draw_line(Vector2(-w2, yy), Vector2(w2, yy), Color("6a2a1e"), 1.0)
	draw_line(Vector2(0, hub.y - 12), Vector2(0, hub.y - 18), OUTLINE, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, hub.y - 18), Vector2(6, hub.y - 16), Vector2(0, hub.y - 14)]), Color("e8c040"))
	# sails
	for k in 4:
		var t := _tip(k)
		var d := (t - hub).normalized()
		var n := Vector2(-d.y, d.x)
		draw_line(hub, t, OUTLINE, 4.0)
		draw_line(hub, t, Color("7a5a36"), 2.0)
		var a := hub + d * 14.0
		var b := t - d * 4.0
		var sail := PackedVector2Array([a, b, b + n * 12.0, a + n * 9.0])
		var sail_o := PackedVector2Array([a - d, b + d, b + n * 13.0 + d, a + n * 10.0 - d])
		draw_colored_polygon(sail_o, OUTLINE)
		draw_colored_polygon(sail, Color(0.95, 0.92, 0.82, 0.95))
		draw_colored_polygon(PackedVector2Array([a + n * 5.0, b + n * 7.0, b + n * 12.0, a + n * 9.0]), Color(0.82, 0.78, 0.68, 0.95))
		for s in 4:
			var u := lerpf(0.15, 0.9, s / 3.0)
			draw_line(a.lerp(b, u), a.lerp(b, u) + n * lerpf(9.0, 12.0, u), Color("7a5a36"), 1.0)
		# the standing platform at the tip
		outlined_rect(Rect2(t.x - 15, t.y, 30, 5), Color("a87a46"))
	draw_circle(hub, 5.0, OUTLINE)
	draw_circle(hub, 3.5, Color("5a5a66"))
