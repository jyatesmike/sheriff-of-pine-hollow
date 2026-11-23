# A bunch of bobbing fair balloons over a gap. Land on one to bounce
# (hold JUMP for a big bounce). They never pop, so you can always try again.
#   {"type": "balloons", "x": 40, "at": [[42, 3.5], [46, 4.2], [50, 3.6]]}
extends LevelObject

var balloons: Array = []     # {pos (local), phase, squash}
var _t := 0.0
const COLORS := [Color("e84a4a"), Color("4a8ae8"), Color("f0c040"), Color("6ac06a"), Color("c86ae8")]


func _setup() -> void:
	for i in o.get("at", []).size():
		var b: Array = o.at[i]
		balloons.append({"pos": Vector2((b[0] - o.x) * TILE + 8, -b[1] * TILE), "phase": i * 1.3, "squash": 0})


func _now(b: Dictionary) -> Vector2:
	return b.pos + Vector2(sin(_t * 0.8 + b.phase) * 6.0, sin(_t * 1.7 + b.phase) * 5.0)


func step(delta: float) -> void:
	_t += delta
	var p := player()
	for b in balloons:
		b.squash = maxi(b.squash - 1, 0)
		var c := global_position + _now(b)
		var r := Rect2(c - Vector2(11, 12), Vector2(22, 22))
		if r.intersects(p.body_rect()) and p.velocity.y > 0.0 and p.global_position.y - r.position.y < 14.0:
			p.bounce()
			b.squash = 10
			level.score += 25
			Audio.sfx("stomp", 1.5)
	queue_redraw()


func bot_hint(p: Player) -> Dictionary:
	var lx := p.global_position.x - global_position.x
	var last: float = balloons[balloons.size() - 1].pos.x
	if lx < -30.0 or lx > last + 30.0:
		return {}
	if not p.is_on_floor():
		for b in balloons:
			var bx: float = _now(b).x
			if bx > lx - 6.0:
				return {"dir": 0.0 if absf(bx - lx) < 5.0 else signf(bx - lx)}
	return {}


func _draw() -> void:
	for i in balloons.size():
		var b: Dictionary = balloons[i]
		var c := _now(b)
		var col: Color = COLORS[i % COLORS.size()]
		draw_line(c + Vector2(0, 11), Vector2(c.x - (c.x - b.pos.x) * 0.5, 40.0), Color(0.9, 0.9, 0.9, 0.6), 1.0)
		var sq := Vector2(1.25, 0.75) if b.squash > 0 else Vector2.ONE
		draw_set_transform(c, 0.0, sq)
		draw_circle(Vector2.ZERO, 11.0, OUTLINE)
		draw_circle(Vector2.ZERO, 10.0, col)
		draw_circle(Vector2(-3, -4), 2.5, col.lightened(0.5))
		draw_colored_polygon(PackedVector2Array([Vector2(-2, 10), Vector2(2, 10), Vector2(0, 13)]), col.darkened(0.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
