# A checkpoint post. Run past it and its flag goes up: if you lose after
# that, pressing jump puts you back here (R still starts the whole level over).
#   {"type": "checkpoint", "x": 94}
extends LevelObject

var reached := false
var flag := 0.0                    # 0 = down, 1 = at the top
var _t := 0.0


func _setup() -> void:
	add_to_group("checkpoint")


func step(delta: float) -> void:
	_t += delta
	if not reached and player().global_position.x >= global_position.x:
		reached = true
		level.save_checkpoint("post", global_position.x)
	flag = move_toward(flag, 1.0 if reached else 0.0, delta * 2.0)
	queue_redraw()


func _draw() -> void:
	outlined_rect(Rect2(-1, -56, 3, 56), Color("d8d0c0"))
	outlined_rect(Rect2(-5, -4, 11, 4), Color("7a6a5a"))
	draw_circle(Vector2(0.5, -58), 2.5, OUTLINE)
	draw_circle(Vector2(0.5, -58), 1.5, Color("ffd23f"))
	var y := lerpf(-14.0, -54.0, flag)
	var wave := sin(_t * 6.0) * (1.0 if reached else 0.3)
	var col := Color("6ac06a") if reached else Color("c05a4a")
	var pts := PackedVector2Array([Vector2(2, y), Vector2(18, y + 5 + wave), Vector2(2, y + 11)])
	draw_colored_polygon(pts, OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(3, y + 1.5), Vector2(15, y + 5.5 + wave), Vector2(3, y + 9.5)]), col)
