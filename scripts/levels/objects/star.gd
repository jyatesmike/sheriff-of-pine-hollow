# One of the 3 hidden sheriff stars in each level. Tucked away somewhere
# off the main path: up high, behind things, over the water...
#   {"type": "star", "x": 105, "h": 15}
extends LevelObject

var taken := false
var _t := 0.0


func _setup() -> void:
	position.y = level.GROUND_Y - o.get("h", 1.0) * TILE
	level.stars_total += 1
	add_to_group("stars")


func step(delta: float) -> void:
	_t += delta
	if taken:
		return
	var r := Rect2(global_position - Vector2(10, 10), Vector2(20, 20))
	if r.intersects(player().body_rect()):
		take(true)
	queue_redraw()


func take(fanfare: bool) -> void:
	taken = true
	level.stars_got += 1
	if fanfare:
		level.score += 500
		level.popup(global_position + Vector2(0, -14), GameText.UI.star % [level.stars_got, level.stars_total], Color("ffd23f"))
		level.dust(global_position, 14, Color("ffd23f"))
		Audio.sfx("golden_pie", 1.2)
	queue_redraw()


func _draw() -> void:
	if taken:
		return
	var s := 1.0 + sin(_t * 4.0) * 0.08
	var pts := PackedVector2Array()
	for k in 10:
		var r := (8.0 if k % 2 == 0 else 3.6) * s
		var a := -PI / 2.0 + k * PI / 5.0 + sin(_t * 1.5) * 0.15
		pts.append(Vector2(cos(a), sin(a)) * r)
	var out := PackedVector2Array()
	for q in pts:
		out.append(q * 1.25)
	draw_colored_polygon(out, OUTLINE)
	draw_colored_polygon(pts, Color("ffd23f"))
	draw_circle(Vector2.ZERO, 1.6, Color("fff6dc"))
	if int(_t * 5.0) % 7 == 0:
		draw_circle(Vector2(5, -6), 1.0, Color.WHITE)
