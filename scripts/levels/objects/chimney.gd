# A chimney on a rooftop that puffs a hot updraft every few seconds,
# launching you high into the air.   {"type": "chimney", "x": 104, "h": 7}
extends LevelObject

const PERIOD := 150          # frames between puffs
const PUFF := 40             # frames the updraft lasts
const LIFT := -560.0

var t := 0
var top := 0.0


func _setup() -> void:
	top = tiles_up(o.get("h", 7)) - 22.0
	t = int(o.get("x", 0) * 7) % PERIOD


func step(_delta: float) -> void:
	t = (t + 1) % PERIOD
	if t < PUFF:
		var col := Rect2(global_position + Vector2(-9, top - 70), Vector2(18, 72))
		var p := player()
		if col.intersects(p.body_rect()) and p.velocity.y > LIFT * 0.6:
			p.velocity.y = LIFT
			p.jumping = false
			if t == 0 or p.velocity.y == LIFT:
				Audio.sfx("dash", 0.5)
	queue_redraw()


func _draw() -> void:
	outlined_rect(Rect2(-8, top, 16, 22), Color("8a3a28"))
	for y in [top + 5, top + 11, top + 17]:
		draw_rect(Rect2(-8, y, 16, 1), Color("5a2418"))
	outlined_rect(Rect2(-10, top - 3, 20, 4), Color("5a5048"))
	# smoke: a wisp before, a big column during the puff
	if t < PUFF:
		for k in 6:
			var r := 5.0 + k * 1.5
			var yy := top - 8 - k * 11 - (t % 10)
			draw_circle(Vector2(sin(k * 1.7 + t * 0.2) * 3.0, yy), r, Color(0.85, 0.85, 0.82, 0.75 - k * 0.1))
	elif t > PERIOD - 30:
		draw_circle(Vector2(0, top - 6), 3.0, Color(0.8, 0.8, 0.8, 0.5))
