# Half-sunk docks across a cove. Each one sinks while you stand on it, so
# keep hopping. Fish leap out of the gaps: bounce off their backs, but a
# fish in the face costs a heart.
#   {"type": "docks", "x": 150, "to": 186, "at": [153, 159, 165, 171, 177, 182], "w": 3}
extends LevelObject

const SINK := 16.0           # px per second while stood on
const UNDER := 20.0          # this far down and it's under water

var docks: Array = []        # {body, cs, x, w, sink, off}
var fish: Array = []         # {x0, x1, t, period, delay}
var _t := 0.0


func _setup() -> void:
	var w: float = o.get("w", 3) * TILE
	var xs: Array = o.get("at", [])
	for i in xs.size():
		var lx: float = (xs[i] - o.x) * TILE
		var b := AnimatableBody2D.new()
		b.sync_to_physics = true
		b.collision_layer = 2
		b.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 6)
		cs.shape = sh
		cs.position = Vector2(w / 2.0, 3)
		cs.one_way_collision = true
		b.add_child(cs)
		b.position = Vector2(lx, -1)
		add_child(b)
		docks.append({"body": b, "cs": cs, "x": lx, "w": w, "sink": 0.0, "off": 0})
		if i > 0:
			var prev: float = docks[i - 1].x + w
			fish.append({"x0": prev, "x1": lx, "period": 2.6 + 0.4 * (i % 3), "delay": i * 0.9})


func step(delta: float) -> void:
	_t += delta
	var p := player()
	var feet := p.global_position - global_position
	for d in docks:
		var on: bool = p.is_on_floor() and feet.x > d.x - 6.0 and feet.x < d.x + d.w + 6.0 and absf(feet.y - (d.body.position.y - 1.0)) < 4.0
		if d.off > 0:
			d.off -= 1
			if d.off == 0:
				d.cs.set_deferred("disabled", false)
		if on:
			d.sink += SINK * delta
			if d.sink >= UNDER:
				d.cs.set_deferred("disabled", true)
				d.off = 70
				Audio.sfx("splash", 1.2)
		else:
			d.sink = maxf(d.sink - 30.0 * delta, 0.0)
		d.body.position.y = -1.0 + d.sink
	# leaping fish
	var pr := p.body_rect()
	for f in fish:
		var r := _fish_rect(f)
		if r.size.x > 0.0 and r.intersects(pr):
			if p.velocity.y > 0.0 and p.global_position.y - r.position.y < 10.0:
				p.bounce()
				level.score += 50
				level.popup(r.get_center() + Vector2(0, -16), "+50")
				Audio.sfx("stomp", 1.4)
			else:
				p.hurt(r.get_center().x)
	queue_redraw()


## A leaping fish's position: jumps from one gap edge's water to the other in an arc.
func _fish_pos(f: Dictionary) -> Vector3:
	var t := fmod(_t + f.delay, f.period)
	var dur := 1.1
	if t > dur:
		return Vector3(0, 0, -1)
	var k := t / dur
	var x: float = lerpf(f.x0 + 4.0, f.x1 - 4.0, k)
	var y := 14.0 - sin(k * PI) * 90.0
	return Vector3(x, y, k)


func _fish_rect(f: Dictionary) -> Rect2:
	var q := _fish_pos(f)
	if q.z < 0.0:
		return Rect2()
	return Rect2(global_position + Vector2(q.x - 7, q.y - 5), Vector2(14, 10))


## Test bot: hop to the next dock when there's no floor just ahead.
func bot_hint(p: Player) -> Dictionary:
	var lx := p.global_position.x - global_position.x
	var last: float = docks[docks.size() - 1].x + docks[docks.size() - 1].w
	if lx < -40.0 or lx > last + 10.0:
		return {}
	if not p.is_on_floor():
		# in the air: steer for the middle of the next dock ahead
		for d in docks:
			var c: float = d.x + d.w * 0.5
			if d.x + d.w > lx + 6.0 and d.off == 0:
				var dx: float = c - lx
				return {"dir": 0.0 if absf(dx) < 6.0 else signf(dx)}
		return {"dir": 1.0}
	var space := p.get_world_2d().direct_space_state
	var ahead := p.global_position + Vector2(14, -2)
	var floor_ahead := not space.intersect_ray(PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 12), 3)).is_empty()
	return {"dir": 1.0, "jump": not floor_ahead}


func _draw() -> void:
	var wood := Color("8a6a42")
	for d in docks:
		var y: float = d.body.position.y
		if d.off > 0:
			continue
		# posts
		for px in [d.x + 3.0, d.x + d.w - 5.0]:
			draw_rect(Rect2(px, y + 4, 3, 16), wood.darkened(0.3))
		outlined_rect(Rect2(d.x, y, d.w, 5), wood)
		for k in range(int(d.x) + 7, int(d.x + d.w), 8):
			draw_rect(Rect2(k, y + 1, 1, 4), wood.darkened(0.3))
		if d.sink > 6.0:
			draw_rect(Rect2(d.x - 2, 10, d.w + 4, 2), Color(0.8, 0.95, 1.0, 0.7))   # ripples
	for f in fish:
		var q := _fish_pos(f)
		if q.z < 0.0:
			continue
		var a := lerpf(-0.9, 0.9, q.z)
		draw_set_transform(Vector2(q.x, q.y), a, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(-2, -4), Vector2(6, -2), Vector2(8, 0), Vector2(6, 2), Vector2(-2, 4)]), OUTLINE)
		draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(-2, -3), Vector2(6, -1), Vector2(7, 0), Vector2(6, 1), Vector2(-2, 3)]), Color("b8c8d0"))
		draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(-12, -4), Vector2(-12, 4)]), Color("8a9aa8"))
		draw_rect(Rect2(4, -1, 1, 1), OUTLINE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
