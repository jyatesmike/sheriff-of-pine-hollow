# The Sheriff's parked patrol car. Walk up to it and the car chase begins
# (Earl has just stolen the milk truck).   {"type": "patrol_car", "x": 182}
extends LevelObject

var used := false


func _setup() -> void:
	add_to_group("patrol_car")
var _t := 0.0


func step(delta: float) -> void:
	_t += delta
	var p := player()
	# walk up to it - or hop right over it: either way Earl's getting away in that milk truck
	if not used and (p.is_on_floor() and absf(p.global_position.x - global_position.x) < 30.0 or p.global_position.x > global_position.x + 30.0):
		used = true
		level.start_chase(o)
	queue_redraw()


func _draw() -> void:
	var tex := SpriteLib.prop("patrol_car")
	draw_texture(tex, Vector2(-38, -30))
	var wheel := SpriteLib.prop("car_wheel")
	for wx in [-22.0, 22.0]:
		draw_texture(wheel, Vector2(wx - 7, -13))
	if not used and int(_t * 3.0) % 2 == 0:
		PixelFont.draw_centered(self, GameText.CAR_HINT, 0, -48, Color("ffd23f"))
