# A window box with a flowerpot that topples off when the Sheriff walks
# underneath. Watch for its shadow!   {"type": "flowerpot", "x": 20, "h": 6}
extends LevelObject

const TRIGGER := 70.0        # px ahead of the pot that sets it off
const GRAVITY := 700.0

var state := 0               # 0 waiting, 1 wobbling, 2 falling, 3 broken
var t := 0
var y := 0.0
var vy := 0.0


func _setup() -> void:
	y = tiles_up(o.get("h", 6)) - 6.0


func step(delta: float) -> void:
	var p := player()
	match state:
		0:
			var dx := global_position.x - p.global_position.x
			if dx < TRIGGER and dx > -10.0:
				state = 1
				t = 18
		1:
			t -= 1
			if t <= 0:
				state = 2
		2:
			vy += GRAVITY * delta
			y += vy * delta
			var r := Rect2(global_position + Vector2(-6, y - 6), Vector2(12, 12))
			if r.intersects(p.body_rect()):
				p.hurt(global_position.x)
				_break()
			elif y >= -2.0:
				_break()
	queue_redraw()


func _break() -> void:
	state = 3
	level.dust(global_position + Vector2(0, -2), 10, Color("8a5a30"))
	Audio.sfx("break", 1.6)


func _draw() -> void:
	var box_y := tiles_up(o.get("h", 6))
	# window and box on the wall behind
	outlined_rect(Rect2(-14, box_y - 30, 28, 24), Color("e8e0cc"))
	draw_rect(Rect2(-12, box_y - 28, 24, 20), Color("2e4060"))
	draw_rect(Rect2(-12, box_y - 28, 6, 20), Color("6a8ab0"))
	outlined_rect(Rect2(-16, box_y, 32, 6), Color("7a5230"))
	for k in [-11.0, 11.0]:
		draw_circle(Vector2(k, box_y - 2), 4.0, Color("2e6a3e"))
		draw_circle(Vector2(k, box_y - 3), 1.6, Color("e0609a"))
	if state < 3:
		var wob := sin(t * 1.2) * 2.0 if state == 1 else 0.0
		var py := y if state == 2 else box_y - 6.0
		outlined_rect(Rect2(-5 + wob, py - 2, 10, 8), Color("c0603a"))
		draw_circle(Vector2(wob, py - 5), 4.5, Color("2e6a3e"))
		draw_circle(Vector2(wob + 1, py - 7), 2.0, Color("f0c848"))
		if state >= 1:
			# shadow on the ground grows as the pot falls
			var k := clampf(1.0 - absf(py) / absf(box_y), 0.2, 1.0)
			draw_rect(Rect2(-8 * k - 2, -2, 16 * k + 4, 3), Color(0, 0, 0, 0.35))
	else:
		for s in [Vector2(-7, -3), Vector2(4, -2), Vector2(-1, -4)]:
			draw_rect(Rect2(s, Vector2(4, 3)), Color("c0603a"))
