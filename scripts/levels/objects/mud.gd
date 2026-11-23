# A stretch of mud. "deep" slows you to a slog (and Earl too);
# "slick" (the pig pen) makes your feet slide about.
#   {"type": "mud", "x": 72, "w": 40, "kind": "deep"}
extends LevelObject

var w := 0.0
var bubbles: Array = []
var _t := 0.0


func _setup() -> void:
	w = o.get("w", 10) * TILE
	level.mud_zones.append([global_position.x, global_position.x + w, o.get("kind", "deep")])
	for k in int(w / 40.0):
		bubbles.append(Vector2(randf_range(4, w - 4), randf_range(0, TAU)))


func step(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var slick: bool = o.get("kind", "deep") == "slick"
	var c := Color("5a3a22") if not slick else Color("6a4a2a")
	draw_rect(Rect2(0, -3, w, 7), c)
	draw_rect(Rect2(0, -3, w, 1), c.lightened(0.25))
	for x in range(6, int(w) - 6, 23):
		draw_rect(Rect2(x, -1, 9, 1), c.darkened(0.3))
		if slick:
			draw_rect(Rect2(x + 4, -2, 6, 1), Color(1, 1, 1, 0.25))
	for b in bubbles:
		var k := fmod(_t * 0.6 + b.y, 2.0)
		if k < 0.5:
			draw_circle(Vector2(b.x, -3), 1.0 + k * 4.0, c.lightened(0.15))
