# County Fair finale: Earl hides out in the bumper cars. Hop in a car at the
# entrance. LEFT/RIGHT to drive, UP/DOWN to switch between the back and
# front rows. Ram Earl's car 3 times (hit him fast!) and he's caught.
# The other cars get in the way.
#   {"type": "bumper_cars", "x": 182, "w": 48}
extends LevelObject

const ROWS := [-16.0, 0.0]   # back row, front row (local y)
const HALF := 20.0
const MAX_V := 210.0
const CEIL := -128.0         # the spark grid overhead

var w := 0.0
var cars: Array = []         # {x, v, row, ry, kind, col, t}
var state := 0               # 0 waiting, 1 driving, 2 caught
var bumps := 0
var bump_cd := 0
var msg := ""
var msg_t := 0
var keep_rider := true
var front: Node2D
var jolt := {}               # car index -> frames of bump jolt
var sparks: Array = []       # [pos, life] little ceiling sparks
var _t := 0.0


func _setup() -> void:
	w = o.get("w", 48) * TILE
	level.truck_x = global_position.x - 10.0
	cars = [
		{"x": 30.0, "v": 0.0, "row": 1, "ry": ROWS[1], "kind": "player", "col": Color("2a6ad8"), "t": 0},
		{"x": w - 60.0, "v": 0.0, "row": 0, "ry": ROWS[0], "kind": "earl", "col": Color("d83a3a"), "t": 0},
		{"x": w * 0.45, "v": 60.0, "row": 0, "ry": ROWS[0], "kind": "other", "driver": "dewey", "col": Color("3aa05a"), "t": 0},
		{"x": w * 0.6, "v": -50.0, "row": 1, "ry": ROWS[1], "kind": "other", "driver": "hen", "col": Color("e8a020"), "t": 0},
	]
	if Lighting.enabled():
		for k in 3:
			add_child(Lighting.radial(Vector2(w * (0.2 + 0.3 * k), CEIL + 20), Color(1, 0.8, 0.6), 1.3, 0.75))
	front = Node2D.new()
	front.z_index = 3                       # the car bodies, drawn in front of the drivers
	front.draw.connect(_draw_front)
	add_child(front)


func _me() -> Dictionary:
	return cars[0]


func _earl() -> Dictionary:
	return cars[1]


func step(delta: float) -> void:
	_t += delta
	msg_t = maxi(msg_t - 1, 0)
	bump_cd = maxi(bump_cd - 1, 0)
	var p := player()
	var e: Node2D = level.earl
	if state == 0:
		if e and e.state == Earl.State.WAIT and absf(p.global_position.x - (global_position.x + 30.0)) < 30.0 and p.is_on_floor():
			state = 1
			p.start_ride(self)
			_flash(GameText.CF_BUMP_HELP)
			Audio.sfx("dash", 0.6)
	if state == 1:
		_drive_others(delta)
	for k in jolt.keys():
		jolt[k] -= 1
		if jolt[k] <= 0:
			jolt.erase(k)
	# sparks where the poles touch the ceiling grid
	for c in cars:
		if absf(c.v) > 60.0 and randf() < 0.25:
			sparks.append([Vector2(c.x - 16.0 * signf(c.v) + randf_range(-3, 3), CEIL + randf_range(-2, 2)), 6])
	for sp in sparks:
		sp[1] -= 1
	sparks = sparks.filter(func(sp): return sp[1] > 0)
	queue_redraw()
	front.queue_redraw()


func _flash(t: String) -> void:
	msg = Names.fmt(t)
	msg_t = 120


## Player.ride callback: drive the player's car.
func ride_step(p: Player, delta: float) -> bool:
	if level.finished or state != 1:
		return false
	var me := _me()
	var dir := Input.get_axis("left", "right")
	me.v = move_toward(me.v, dir * MAX_V, (420.0 if dir != 0.0 else 160.0) * delta)
	if Input.is_action_just_pressed("up"):
		me.row = 0
	if Input.is_action_just_pressed("down"):
		me.row = 1
	_collide()
	p.global_position = global_position + Vector2(me.x + _jolt(0), me.ry + 6.0)   # sitting in the seat
	p.velocity = Vector2(me.v, 0)
	p.facing = 1 if me.v >= 0.0 else -1
	p.anim = "idle"
	return true


func _drive_others(delta: float) -> void:
	var me := _me()
	for c in cars:
		c.t = maxi(c.t - 1, 0)
		if c.kind == "earl":
			var dx: float = c.x - me.x
			var flee := 1.0 if dx > 0.0 else -1.0
			if c.x < 40.0:
				flee = 1.0
			elif c.x > w - 40.0:
				flee = -1.0
			c.v = move_toward(c.v, flee * 170.0, 260.0 * delta)
			if c.row == me.row and absf(dx) < 110.0 and c.t == 0:
				c.row = 1 - c.row                   # dodge into the other row
				c.t = 50 + randi() % 40
		elif c.kind == "other":
			if c.t == 0:
				c.t = 60 + randi() % 90
				c.v = randf_range(-120.0, 120.0)
				if randf() < 0.4:
					c.row = 1 - c.row
		c.x += c.v * delta
		c.ry = move_toward(c.ry, ROWS[c.row], 70.0 * delta)
		if c.x < HALF + 4.0:
			c.x = HALF + 4.0
			c.v = absf(c.v) * 0.6
		elif c.x > w - HALF - 4.0:
			c.x = w - HALF - 4.0
			c.v = -absf(c.v) * 0.6


func _collide() -> void:
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var a: Dictionary = cars[i]
			var b: Dictionary = cars[j]
			if absf(a.ry - b.ry) > 6.0 or absf(a.x - b.x) > HALF * 2.0:
				continue
			var rel: float = absf(a.v - b.v)
			var va: float = a.v
			a.v = b.v * 0.9
			b.v = va * 0.9
			var push := (HALF * 2.0 - absf(a.x - b.x)) * 0.5 + 0.5
			if a.x < b.x:
				a.x -= push
				b.x += push
			else:
				a.x += push
				b.x -= push
			if rel > 40.0:
				Audio.sfx("bonk", 1.3)
				jolt[i] = 8
				jolt[j] = 8
				var at: Vector2 = global_position + Vector2((a.x + b.x) * 0.5, a.ry - 10.0)
				level.dust(at, 10, Color("ffe060"))
			if a.kind == "player" and b.kind == "earl" and rel > 90.0 and bump_cd == 0:
				_bump()


func _bump() -> void:
	bumps += 1
	bump_cd = 40
	level.score += 300
	level.dust(global_position + Vector2(_earl().x, -10), 10, Color("ffd23f"))
	Game.hit_stop(4)
	if bumps >= 3:
		_caught()
		return
	_flash(GameText.CHASE_BUMP % bumps)
	var e: Node2D = level.earl
	if e:
		var k := mini(bumps - 1, GameText.CHASE_EARL_BUMPED.size() - 1)
		e.say(GameText.CHASE_EARL_BUMPED[k], 70, "bumped_%d" % (k + 1))


func _caught() -> void:
	state = 2
	var e: Earl = level.earl
	if e == null:
		return
	e.global_position = global_position + Vector2(_earl().x, 0)
	e.visible = true
	pass  # (4.3 physics interpolation not in 4.1)
	e.tackles = Earl.TACKLES_NEEDED - 1
	e.state = Earl.State.IDLE
	e.on_contact()


## Test bot: line up with Earl's row and ram him.
func bot_hint(p: Player) -> Dictionary:
	if state == 0:
		var dx := global_position.x + 30.0 - p.global_position.x
		if absf(dx) < 160.0:
			return {"dir": signf(dx) if absf(dx) > 8.0 else 0.0}
		return {}
	if state != 1:
		return {}
	var me := _me()
	var er := _earl()
	var h := {"dir": signf(er.x - me.x)}
	if er.row != me.row and frames_ok():
		h["lane"] = er.row
	return h


func frames_ok() -> bool:
	return Engine.get_physics_frames() % 6 == 0




func _jolt(i: int) -> float:
	return sin(jolt.get(i, 0) * 1.7) * 2.0 if jolt.has(i) else 0.0


# --- drawing: arena + things behind the drivers here; car bodies in _draw_front ---------------
func _draw() -> void:
	var metal := Color("4a4c5a")
	# back wall with padded bumper rail and posters
	draw_rect(Rect2(-8, CEIL, w + 16, -CEIL - 30), Color("2a1e2e"))
	for x in range(0, int(w), 64):
		var col: Color = [Color("e84a4a"), Color("4a8ae8"), Color("f0c040")][(x / 64) % 3]
		draw_rect(Rect2(x + 14, CEIL + 34, 30, 40), col.darkened(0.35))
		draw_rect(Rect2(x + 16, CEIL + 36, 26, 36), col.darkened(0.15))
		draw_circle(Vector2(x + 29, CEIL + 50), 7.0, Color(1, 0.95, 0.8, 0.35))
	draw_rect(Rect2(-8, -44, w + 16, 12), Color("c83a3a"))
	draw_rect(Rect2(-8, -44, w + 16, 3), Color("e86a5a"))
	for x in range(0, int(w), 16):
		draw_rect(Rect2(x, -41, 1, 9), Color("8a2a24"))
	# floor: polished steel plates with reflections
	draw_rect(Rect2(-8, -32, w + 16, 36), metal)
	for x in range(0, int(w), 32):
		draw_rect(Rect2(x, -32, 1, 36), metal.darkened(0.3))
		draw_rect(Rect2(x + 6, -30, 10, 1), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(-8, -18, w + 16, 1), metal.darkened(0.25))
	# end posts and the canopy
	for px in [-10.0, w + 4.0]:
		draw_rect(Rect2(px - 1, CEIL - 20, 8, -CEIL + 20), OUTLINE)
		draw_rect(Rect2(px, CEIL - 20, 6, -CEIL + 20), Color("d8c090"))
	for k in int(w / 24.0) + 2:
		var col := Color("f0c040") if k % 2 == 0 else Color("4a8ae8")
		draw_colored_polygon(PackedVector2Array([Vector2(k * 24.0 - 14, CEIL - 22), Vector2(k * 24.0 + 10, CEIL - 22),
				Vector2(k * 24.0 + 10, CEIL - 6), Vector2(k * 24.0 - 2, CEIL - 1), Vector2(k * 24.0 - 14, CEIL - 6)]), col)
	for k in int(w / 24.0) + 2:
		var lit := (k + int(_t * 5.0)) % 3 == 0
		draw_circle(Vector2(k * 24.0 - 2, CEIL - 24), 2.0, Color("fff0a0") if lit else Color("c08040"))
	var sign_w := PixelFont.width(GameText.CF_BUMPER_SIGN, 2) + 16.0
	var sr := Rect2(w * 0.5 - sign_w / 2.0, CEIL - 46, sign_w, 20)
	draw_rect(sr.grow(1), OUTLINE)
	draw_rect(sr, Color("f4ecd0"))
	PixelFont.draw_centered(self, GameText.CF_BUMPER_SIGN, w * 0.5, CEIL - 40, Color("c83a3a"), 2)
	# the ceiling spark grid
	for x in range(-8, int(w) + 8, 8):
		draw_line(Vector2(x, CEIL), Vector2(x + 4, CEIL + 3), Color("6a6a78"), 1.0)
	draw_line(Vector2(-8, CEIL), Vector2(w + 8, CEIL), Color("8a8a98"), 1.0)
	draw_line(Vector2(-8, CEIL + 3), Vector2(w + 8, CEIL + 3), Color("6a6a78"), 1.0)
	for sp in sparks:
		var c: Vector2 = sp[0]
		var r: float = sp[1] * 0.6
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color("fff6a0"), 1.0)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color("fff6a0"), 1.0)
		draw_circle(c, 1.0, Color.WHITE)
	# behind each driver: the pole up to the grid and the seat back
	for i in _row_order():
		var c: Dictionary = cars[i]
		var at := Vector2(c.x + _jolt(i), c.ry)
		var back := -signf(c.v) if absf(c.v) > 5.0 else -1.0
		var pole_x: float = at.x + back * 15.0
		draw_line(Vector2(pole_x, at.y - 18), Vector2(pole_x + back * 6.0, CEIL + 2), Color("8a8a96"), 1.0)
		draw_rect(Rect2(pole_x - 1, at.y - 22, 3, 6), Color("5a5a66"))
		# seat back
		draw_rect(Rect2(at.x - 13, at.y - 36, 22, 18), OUTLINE)
		draw_rect(Rect2(at.x - 12, at.y - 35, 20, 17), c.col.darkened(0.45))
		draw_rect(Rect2(at.x - 12, at.y - 35, 20, 2), c.col.darkened(0.2))
		# the drivers the game doesn't control as actors: Earl, Dewey, a hen
		if c.kind == "earl" and level.earl and level.earl.state == Earl.State.WAIT:
			_driver("earl", "taunt" if state == 1 else "idle", at)
		elif c.has("driver"):
			_driver(c.driver, "walk" if c.driver == "hen" else "idle", at)
	if state == 0 and int(_t * 3.0) % 2 == 0:
		PixelFont.draw_centered(self, GameText.CAR_HINT, 30, -76, Color("ffd23f"))
	if state == 1:
		PixelFont.draw_centered(self, GameText.CF_BUMPS % bumps, w * 0.5, CEIL + 12, Color("ffd23f"))
	if msg_t > 0:
		PixelFont.draw_centered(self, msg, w * 0.5, CEIL + 24, Color("ff9a3a"))


func _row_order() -> Array:
	var idx := range(cars.size())
	idx.sort_custom(func(a, b): return cars[a].ry < cars[b].ry)
	return idx


func _driver(sheet: String, anim: String, at: Vector2) -> void:
	var sf := SpriteLib.frames(sheet)
	if not sf.has_animation(anim):
		anim = sf.get_animation_names()[0]
	var tex := sf.get_frame_texture(anim, int(_t * 6.0) % sf.get_frame_count(anim))
	if tex == null:
		return
	var feet := at + Vector2(0, 6 if sheet != "hen" else -14)
	draw_texture(tex, feet - Vector2(tex.get_width() / 2.0, tex.get_height()))


## The car bodies, in front of whoever is sitting in them.
func _draw_front() -> void:
	front.position = Vector2.ZERO
	for i in _row_order():
		var c: Dictionary = cars[i]
		_car_body(Vector2(c.x + _jolt(i), c.ry), c.col, i, c.v)


func _car_body(at: Vector2, col: Color, n: int, v: float) -> void:
	var f := front
	var tilt := clampf(v / 400.0, -0.08, 0.08)
	f.draw_set_transform(at, tilt, Vector2.ONE)
	# hull: a rounded tub with a lighter top and a shadowed belly
	var hull := PackedVector2Array([Vector2(-22, -20), Vector2(-14, -24), Vector2(14, -24), Vector2(22, -20),
		Vector2(24, -10), Vector2(20, -4), Vector2(-20, -4), Vector2(-24, -10)])
	var out := PackedVector2Array()
	for q in hull:
		out.append(q * 1.08 + Vector2(0, -0.5))
	f.draw_colored_polygon(out, OUTLINE)
	f.draw_colored_polygon(hull, col)
	f.draw_colored_polygon(PackedVector2Array([Vector2(-20, -20), Vector2(-13, -23), Vector2(13, -23), Vector2(20, -20), Vector2(20, -18), Vector2(-20, -18)]), col.lightened(0.35))
	f.draw_rect(Rect2(-22, -10, 44, 6), col.darkened(0.3))
	# chrome trim and a racing number
	f.draw_line(Vector2(-21, -15), Vector2(21, -15), Color("e8e8f0"), 1.0)
	f.draw_circle(Vector2(12, -11), 4.5, Color("f4ecd0"))
	PixelFont.draw_centered(f, str(n + 1), 12, -13, OUTLINE)
	# steering wheel peeking over the rim
	f.draw_arc(Vector2(-6, -27), 4.0, PI, TAU, 8, OUTLINE, 2.0)
	f.draw_line(Vector2(-6, -27), Vector2(-4, -23), OUTLINE, 1.0)
	# fat black rubber bumper ring around the bottom
	f.draw_rect(Rect2(-26, -7, 52, 7), OUTLINE)
	f.draw_rect(Rect2(-25, -6, 50, 5), Color("2a2a30"))
	f.draw_rect(Rect2(-25, -6, 50, 1), Color("5a5a66"))
	# headlights
	f.draw_circle(Vector2(20, -12), 1.5, Color("fff0a0"))
	f.draw_circle(Vector2(-20, -12), 1.5, Color("c83a3a"))
	f.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
