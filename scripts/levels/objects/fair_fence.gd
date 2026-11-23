# The tall fence around the rides. Too high to jump: go over it on the
# Ferris wheel. (Earl ducks under the turnstile, the rascal.)
#   {"type": "fair_fence", "x": 88, "h": 8}
extends LevelObject

var h := 0.0


func _setup() -> void:
	h = o.get("h", 8) * TILE
	add_box(Rect2(-4, -h, 10, h), 64)          # the Sheriff collides; Earl slips through


func _draw() -> void:
	var wood := Color("e8e0d0")
	for k in 3:
		var x := -10.0 + k * 9.0
		draw_rect(Rect2(x - 1, -h - 1, 6, h + 1), OUTLINE)
		draw_rect(Rect2(x, -h, 4, h), wood)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1, -h), Vector2(x + 5, -h), Vector2(x + 2, -h - 5)]), wood)
	for y in [-h + 10.0, -h * 0.5, -14.0]:
		draw_rect(Rect2(-12, y, 26, 3), Color("c83a3a"))
	# turnstile at the bottom
	draw_rect(Rect2(12, -22, 4, 22), Color("6a6a74"))
	draw_line(Vector2(14, -14), Vector2(24, -18), Color("8a8a96"), 2.0)
	var s: String = GameText.CF_FENCE_SIGN
	var w := PixelFont.width(s) + 8
	var r := Rect2(-w / 2.0 + 2, -h * 0.5 - 18, w, 11)
	draw_rect(r.grow(1), OUTLINE)
	draw_rect(r, Color("f0e4c4"))
	PixelFont.draw_centered(self, s, r.get_center().x, r.position.y + 3, Color("3a2414"))
