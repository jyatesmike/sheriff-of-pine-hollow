# The grocer's cart. When the Sheriff gets close, it tips over: barrels roll
# down the street at you (jump them, or stomp them for points) and apples
# bounce everywhere (grab them for points).
#   {"type": "grocer", "x": 168, "trigger": 140}
extends LevelObject

const BARREL_SPEED := 120.0

var tipped := false
var barrels: Array = []      # {x, y, vy, spin, dead}
var apples: Array = []       # {x, y, vx, vy, got}
var spawn_t := 0
var to_spawn := 0


func step(delta: float) -> void:
	var p := player()
	if not tipped and p.global_position.x > o.get("trigger", 0) * TILE:
		tipped = true
		to_spawn = 3
		Audio.sfx("break", 0.7)
		if level.earl:
			level.earl.say(GameText.EARL_GROCER, 80, "grocer")
		for k in 7:
			apples.append({"x": randf_range(-10, 10), "y": -30.0, "vx": randf_range(-140, -40), "vy": randf_range(-260, -120), "got": false})
	if to_spawn > 0:
		spawn_t -= 1
		if spawn_t <= 0:
			barrels.append({"x": -10.0, "y": 0.0, "spin": 0.0, "dead": false, "vy": 0.0})
			to_spawn -= 1
			spawn_t = 55
	var pr := p.body_rect()
	for b in barrels:
		if b.dead:
			b.vy += 900.0 * delta
			b.y += b.vy * delta
			continue
		b.x -= BARREL_SPEED * delta
		b.spin -= BARREL_SPEED * delta / 8.0
		var r := Rect2(global_position + Vector2(b.x - 8, -18), Vector2(16, 18))
		if r.intersects(pr):
			if p.velocity.y > 0.0 and p.global_position.y - r.position.y < 12.0:
				p.bounce()
				b.dead = true
				b.vy = -200.0
				level.score += 50
				level.popup(r.get_center() + Vector2(0, -16), "+50")
				Audio.sfx("stomp")
			elif p.sliding:
				b.dead = true
				b.vy = -260.0
			else:
				p.hurt(r.get_center().x)
		if b.x < -720.0:
			b.dead = true
	for a in apples:
		if a.got:
			continue
		a.vy += 800.0 * delta
		a.x += a.vx * delta
		a.y += a.vy * delta
		if a.y > -4.0:
			a.y = -4.0
			a.vy *= -0.55
			a.vx *= 0.8
		if pr.grow(4).has_point(global_position + Vector2(a.x, a.y)):
			a.got = true
			level.score += 25
			level.popup(global_position + Vector2(a.x, a.y - 12), "APPLE +25", Color("ff7a6a"))
			Audio.sfx("pickup", 1.4)
	queue_redraw()


func _draw() -> void:
	# the cart (upright until tipped)
	var wood := Color("a87a46")
	if not tipped:
		outlined_rect(Rect2(-22, -26, 44, 16), wood)
		for k in 5:
			draw_circle(Vector2(-16 + k * 8, -28), 4.0, Color("d8342a"))
		draw_circle(Vector2(-14, -6), 6.0, OUTLINE)
		draw_circle(Vector2(14, -6), 6.0, OUTLINE)
		draw_circle(Vector2(-14, -6), 4.5, Color("5a3a22"))
		draw_circle(Vector2(14, -6), 4.5, Color("5a3a22"))
	else:
		draw_set_transform(Vector2(10, -10), 0.5, Vector2.ONE)
		outlined_rect(Rect2(-22, -10, 44, 16), wood)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2(26, -6), 6.0, OUTLINE)
		draw_circle(Vector2(26, -6), 4.5, Color("5a3a22"))
	var tex := SpriteLib.prop("barrel")
	for b in barrels:
		draw_set_transform(Vector2(b.x, b.y - 9), b.spin, Vector2.ONE)
		draw_texture(tex, -tex.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for a in apples:
		if not a.got:
			draw_circle(Vector2(a.x, a.y), 3.0, OUTLINE)
			draw_circle(Vector2(a.x, a.y), 2.2, Color("d8342a"))
			draw_rect(Rect2(a.x, a.y - 4, 1, 2), Color("3a6a2a"))
