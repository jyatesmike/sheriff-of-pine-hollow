# The water tower in the town square. Earl climbs it and pelts you with
# buckets; ring the fire bell and the firemen's hose knocks him off into
# the haystack.   {"type": "water_tower", "x": 236, "h": 10}
extends LevelObject

var deck := 0.0              # local y of the walkway Earl stands on
var spray_t := 0
var spray_from := Vector2.ZERO


func _setup() -> void:
	deck = tiles_up(o.get("h", 10))
	level.tower = self


func ladder_x() -> float:
	return global_position.x - 20.0


func deck_y() -> float:
	return global_position.y + deck


func haystack_x() -> float:
	return global_position.x + 70.0


## The fire hose: a jet of water from the fire station up to the deck.
func spray(from_x: float) -> void:
	spray_t = 70
	spray_from = Vector2(from_x - global_position.x - 40.0, -30.0)
	Audio.sfx("splash", 0.7)


func step(_delta: float) -> void:
	if spray_t > 0:
		spray_t -= 1
	queue_redraw()


func _draw() -> void:
	var metal := [Color("5a6a7a"), Color("7a8a9a"), Color("9aaab8"), Color("bccad4")]
	# legs and cross braces
	for lx in [-28.0, -10.0, 10.0, 28.0]:
		var foot: float = lx * 1.25
		draw_line(Vector2(lx, deck), Vector2(foot, 0), OUTLINE, 4.0)
		draw_line(Vector2(lx, deck), Vector2(foot, 0), metal[1], 2.0)
	for k in 3:
		var y := deck + (k + 1) * (-deck) / 4.0
		draw_line(Vector2(-32, y), Vector2(32, y - 14), metal[0], 1.0)
		draw_line(Vector2(32, y), Vector2(-32, y - 14), metal[0], 1.0)
	# ladder up the left leg
	draw_rect(Rect2(-24, deck, 2, -deck), Color("3a3a46"))
	draw_rect(Rect2(-16, deck, 2, -deck), Color("3a3a46"))
	var y2 := deck + 4.0
	while y2 < 0.0:
		draw_rect(Rect2(-24, y2, 10, 1), Color("5a5a66"))
		y2 += 7.0
	# walkway + tank + roof
	outlined_rect(Rect2(-40, deck - 3, 80, 4), metal[0])
	for rx in range(-40, 41, 8):
		draw_rect(Rect2(rx, deck - 10, 1, 7), metal[0])
	draw_rect(Rect2(-40, deck - 10, 80, 1), metal[0])
	var tank := Rect2(-34, deck - 58, 68, 48)
	draw_rect(tank.grow(1), OUTLINE)
	for x in range(int(tank.position.x), int(tank.end.x)):
		var k := float(x - tank.position.x) / tank.size.x
		draw_rect(Rect2(x, tank.position.y, 1, tank.size.y), metal[3] if k < 0.25 else (metal[2] if k < 0.6 else metal[1]))
	var t := Names.fmt("{TOWN}").to_upper()
	PixelFont.draw_centered(self, t, 0, deck - 38, Color("2e3a5a"), 1)
	draw_colored_polygon(PackedVector2Array([Vector2(-38, deck - 58), Vector2(38, deck - 58), Vector2(0, deck - 78)]), metal[0])
	# haystack beside the tower (Earl's soft landing)
	var hx := 70.0
	for k in 5:
		draw_circle(Vector2(hx - 16 + k * 8, -10 - (k % 2) * 4), 9.0, OUTLINE)
	for k in 5:
		draw_circle(Vector2(hx - 16 + k * 8, -10 - (k % 2) * 4), 8.0, Color("e8c860"))
	# the hose jet
	if spray_t > 0:
		var top := Vector2(0, deck - 24)
		for i in 24:
			var s := i / 23.0
			var p := spray_from.lerp(top, s) + Vector2(0, -sin(s * PI) * 50.0)
			draw_circle(p + Vector2(randf_range(-1, 1), randf_range(-1, 1)), 3.0 - s, Color(0.55, 0.8, 1.0, 0.85))
