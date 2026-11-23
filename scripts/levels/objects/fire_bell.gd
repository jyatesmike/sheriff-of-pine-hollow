# The fire station's bell. Ring it by jumping into it, lassoing it, or
# hitting it with a rock. When Earl is up the water tower, the firemen's
# hose knocks him down.   {"type": "fire_bell", "x": 212, "h": 5}
extends LevelObject

var ring_t := 0
var bell := Vector2.ZERO


func _setup() -> void:
	bell = Vector2(0, tiles_up(o.get("h", 5)))
	level.lasso_targets.append(self)


func lasso_point() -> Vector2:
	return global_position + bell


func on_lassoed() -> void:
	ring()


func ring() -> void:
	if ring_t > 0:
		return
	ring_t = 50
	Audio.sfx("bell")
	level.on_bell()


func step(_delta: float) -> void:
	ring_t = maxi(ring_t - 1, 0)
	var r := Rect2(global_position + bell + Vector2(-9, -10), Vector2(18, 20))
	if r.intersects(player().body_rect()):
		ring()
	queue_redraw()


func _draw() -> void:
	# fire station front
	outlined_rect(Rect2(-84, -96, 72, 96), Color("b03a28"))
	draw_rect(Rect2(-78, -60, 60, 60), Color("3a2414"))
	for k in 4:
		draw_rect(Rect2(-78, -58 + k * 14, 60, 2), Color("5a3a22"))
	draw_rect(Rect2(-84, -96, 72, 6), Color("7a2418"))
	var sign := GameText.FIRE_SIGN
	draw_rect(Rect2(-80, -86, 64, 11), Color("f4ecd4"))
	PixelFont.draw_centered(self, sign, -48, -83, Color("8a2a1e"))
	# bell post
	outlined_rect(Rect2(-2, bell.y - 12, 4, -bell.y + 12), Color("5a3a22"))
	outlined_rect(Rect2(-2, bell.y - 14, 14, 3), Color("5a3a22"))
	var swing := sin(ring_t * 0.6) * (ring_t / 50.0) * 0.6
	draw_set_transform(bell + Vector2(10, -11), swing, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 1), Vector2(5, 1), Vector2(8, 13), Vector2(-8, 13)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 2), Vector2(4, 2), Vector2(7, 12), Vector2(-7, 12)]), Color("e0b040"))
	draw_rect(Rect2(-3, 3, 2, 8), Color("fff0a0"))
	draw_circle(Vector2(0, 14), 2.0, Color("8a6a20"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(bell + Vector2(10, 2), bell + Vector2(10, 40), Color("c8a060"), 1.0)     # bell rope
