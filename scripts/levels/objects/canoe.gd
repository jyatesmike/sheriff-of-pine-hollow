# A canoe across Pine Lake. Earl paddles off in one and you follow in
# another. Hold RIGHT to paddle hard (you'll need it in the whirlpool
# current), LEFT to slow down. JUMP gives the canoe a hop over rocks, hold
# DOWN to duck under the willow branches. Hit a rock and you're swimming
# back to the dock.
#   {"type": "canoe", "x": 50, "to": 128, "rocks": [70], "branches": [86], "current": [[96, 106]]}
extends LevelObject

const START := 40.0
const WATER := 10.0          # local y of the lake surface

var length := 0.0
var rocks: Array = []
var branches: Array = []
var currents: Array = []
var state := 0               # 0 at the dock, 1 paddling, 2 across
var cx := START
var cy := 0.0                # hop height (negative = up)
var vy := 0.0
var speed := 0.0
var ducking := false
var ex := START + 110.0      # Earl's canoe
var ey := 0.0
var earl_in := false
var keep_rider := true
var stroke := 0.0
var _t := 0.0


func _setup() -> void:
	length = (o.to - o.x) * TILE
	for r in o.get("rocks", []):
		rocks.append((r - o.x) * TILE)
	for b in o.get("branches", []):
		branches.append((b - o.x) * TILE)
	for c in o.get("current", []):
		currents.append(Vector2((c[0] - o.x) * TILE, (c[1] - o.x) * TILE))
	level.truck_x = global_position.x + START - 20.0
	z_index = 2


func _in_current(x: float) -> bool:
	for c in currents:
		if x > c.x and x < c.y:
			return true
	return false


func step(delta: float) -> void:
	_t += delta
	var p := player()
	var e: Node2D = level.earl
	earl_in = e != null and e.state == Earl.State.WAIT and level.truck_x > 0.0
	if state == 0:
		if p.global_position.x > global_position.x + length:
			_finish(false)
		elif p.ride == null and p.is_on_floor() and absf(p.global_position.x - (global_position.x + cx)) < 30.0:
			state = 1
			speed = 50.0
			if e and e.state != Earl.State.WAIT:
				e.state = Earl.State.WAIT
				e.visible = false
			p.start_ride(self)
			Audio.sfx("splash", 1.4)
	queue_redraw()


func ride_step(p: Player, delta: float) -> bool:
	if level.finished:
		return false
	var goal := 95.0
	if Input.is_action_pressed("right"):
		goal = 175.0
	elif Input.is_action_pressed("left"):
		goal = 25.0
	speed = move_toward(speed, goal, 160.0 * delta)
	var drift := -115.0 if _in_current(cx) else 0.0
	cx = maxf(cx + (speed + drift) * delta, START)
	stroke += delta * (speed / 22.0)
	if cy < 0.0 or vy < 0.0:
		vy += 900.0 * delta
		cy += vy * delta
		if cy >= 0.0:
			cy = 0.0
			vy = 0.0
			Audio.sfx("splash", 1.6)
	elif Input.is_action_just_pressed("jump"):
		vy = -300.0
		Audio.sfx("jump", 0.8)
	ducking = Input.is_action_pressed("down") and cy >= -4.0
	for bx in branches:
		if absf(cx - bx) < 12.0 and not ducking and p.invuln == 0:
			p.hurt(global_position.x + bx + 20.0)
			level.popup(global_position + Vector2(bx, -70), GameText.GF_DUCK, Color("ff9a3a"))
	for rx in rocks:
		if absf(cx - rx) < 16.0 and cy > -16.0:
			_crash(p)
			return false
	# Earl paddles on ahead
	ex = maxf(ex, cx + 130.0)
	ex = minf(ex + 110.0 * delta, length - 30.0)
	ey = 0.0
	for rx in rocks:
		if absf(ex - rx) < 40.0:
			ey = -sin((ex - rx + 40.0) / 80.0 * PI) * 36.0
	p.global_position = global_position + Vector2(cx, cy + 15.0)        # sitting low in the canoe
	p.velocity = Vector2(speed + drift, vy)
	p.facing = 1
	p.anim = "slide" if ducking else ("jump" if cy < -2.0 else "idle")
	if cx >= length - 20.0:
		_finish(true)
		p.velocity = Vector2(160.0, -340.0)
		return false
	return true


func _crash(p: Player) -> void:
	Audio.sfx("splash", 0.8)
	level.dust(p.global_position, 16, Color("9ad0f0"))
	level.popup(p.global_position + Vector2(0, -60), GameText.GF_ROCK, Color("ff9a3a"))
	p.hurt(p.global_position.x)
	state = 0
	cx = START
	cy = 0.0
	vy = 0.0
	speed = 0.0
	ex = START + 110.0
	p.global_position = global_position + Vector2(START - 36.0, 0)
	p.velocity = Vector2.ZERO
	p.invuln = Player.INVULN_FRAMES
	pass  # (4.3 physics interpolation not in 4.1)
	level.camera.snap_to_target()


func _finish(ride_done: bool) -> void:
	state = 2
	cx = length - 20.0
	ex = length - 30.0
	var e: Node2D = level.earl
	if e and (e.state == Earl.State.WAIT or level.truck_x > 0.0):
		e.after_chase(global_position + Vector2(length + 16.0 * TILE, 0))
	level.truck_x = -1.0
	if ride_done:
		Audio.sfx("land", 0.8)


## Test bot: walk to the canoe; paddle hard, hop rocks, duck branches.
func bot_hint(p: Player) -> Dictionary:
	if state == 2:
		return {}
	if state == 0:
		var dx := global_position.x + cx - p.global_position.x
		if dx > -40.0 and dx < 300.0:
			return {"dir": 1.0}
		return {}
	for rx in rocks:
		var d: float = rx - cx
		if d > 0.0 and d < 40.0:
			return {"jump": true, "dir": 1.0}
	for bx in branches:
		var d: float = bx - cx
		if d > -14.0 and d < 60.0:
			return {"duck": true, "dir": 1.0}
	return {"dir": 1.0}


func _draw() -> void:
	# whirlpool current: swirls on the water
	for c in currents:
		for k in range(int(c.x), int(c.y), 22):
			var a := _t * -4.0 + k
			draw_arc(Vector2(k + 8, WATER + 5), 6.0, a, a + 4.0, 8, Color(0.75, 0.9, 1.0, 0.7), 1.0)
		PixelFont.draw_centered(self, GameText.GF_CURRENT, (c.x + c.y) / 2.0, WATER + 14, Color(0.8, 0.95, 1.0, 0.8))
	# rocks sticking out of the lake
	for rx in rocks:
		draw_colored_polygon(PackedVector2Array([Vector2(rx - 14, WATER + 2), Vector2(rx - 8, -10), Vector2(rx + 2, -16), Vector2(rx + 12, -6), Vector2(rx + 15, WATER + 2)]), OUTLINE)
		draw_colored_polygon(PackedVector2Array([Vector2(rx - 12, WATER + 1), Vector2(rx - 7, -8), Vector2(rx + 2, -14), Vector2(rx + 11, -5), Vector2(rx + 13, WATER + 1)]), Color("7a7a84"))
		draw_line(Vector2(rx - 6, -6), Vector2(rx + 2, -12), Color("a8a8b0"), 1.0)
	# willow branches hanging low over the water
	for b in branches:
		var bx: float = b
		draw_line(Vector2(bx - 40, -150), Vector2(bx + 30, -110), Color("5a3a22"), 4.0)
		for k in 9:
			var sx: float = bx - 26.0 + k * 7.0
			var hang: float = 60.0 + (k % 3) * 12.0 + sin(_t * 2.0 + k) * 2.0
			var top: float = -146.0 + k * 4.0
			draw_line(Vector2(sx, top), Vector2(sx + 2, minf(top + hang, -38.0)), Color("4a7a3a"), 2.0)
	_canoe(Vector2(ex, ey), earl_in or state == 1, true)
	_canoe(Vector2(cx, cy), false, false)
	if state == 0 and int(_t * 3.0) % 2 == 0:
		PixelFont.draw_centered(self, GameText.CAR_HINT, cx, -54, Color("ffd23f"))


func _canoe(at: Vector2, with_earl: bool, earls: bool) -> void:
	var bob := roundf(sin(_t * 3.0 + at.x * 0.05))
	var base := at + Vector2(0, WATER + bob)
	if with_earl:
		var tex := SpriteLib.frames("earl").get_frame_texture("taunt", 0)
		if tex:
			var sz := SpriteLib.draw_size("earl", tex)
			draw_texture_rect(tex, Rect2(base + Vector2(-sz.x / 2.0, -sz.y + 2), sz), false)
	var hull := Color("b06030") if not earls else Color("4a6a9a")
	# reflection and ripples under the hull
	for k in 3:
		var rx := fmod(_t * 14.0 + k * 13.0, 40.0)
		draw_line(base + Vector2(-30 - rx * 0.4, 1 + k), base + Vector2(-24 - rx * 0.4, 1 + k), Color(0.85, 0.95, 1.0, 0.5 - k * 0.12), 1.0)
		draw_line(base + Vector2(24 + rx * 0.4, 1 + k), base + Vector2(30 + rx * 0.4, 1 + k), Color(0.85, 0.95, 1.0, 0.5 - k * 0.12), 1.0)
	# curved hull with upswept bow and stern
	var top := []
	var bot := []
	for i in 13:
		var u := -1.0 + i / 6.0
		var x := u * 28.0
		top.append(base + Vector2(x, -9.0 - pow(absf(u), 4.0) * 7.0))
		bot.append(base + Vector2(x * 0.82, -1.0 - (1.0 - u * u) * 1.5))
	var pts := PackedVector2Array(top)
	for i in range(12, -1, -1):
		pts.append(bot[i])
	var out := PackedVector2Array()
	for q in pts:
		out.append(base + (q - base) * Vector2(1.06, 1.14))
	draw_colored_polygon(out, OUTLINE)
	draw_colored_polygon(pts, hull)
	# shaded lower half and a lit gunwale
	var low := PackedVector2Array()
	for i in 13:
		var u := -1.0 + i / 6.0
		low.append(base + Vector2(u * 26.0, -5.0 - pow(absf(u), 4.0) * 3.0))
	for i in range(12, -1, -1):
		low.append(bot[i])
	draw_colored_polygon(low, hull.darkened(0.25))
	for i in 12:
		draw_line(top[i], top[i + 1], hull.lightened(0.4), 1.0)
	# ribs and a painted stripe
	for rx in [-14.0, -5.0, 5.0, 14.0]:
		draw_line(base + Vector2(rx, -8), base + Vector2(rx * 0.9, -3), hull.darkened(0.35), 1.0)
	draw_line(base + Vector2(-22, -6), base + Vector2(22, -6), Color("f0e8d0") if not earls else Color("e8c040"), 1.0)
	# paddle
	if not earls and state == 1 and not ducking:
		var a := sin(stroke) * 0.7
		var hand := base + Vector2(4, -28)
		var blade := hand + Vector2(sin(a) * 20.0, cos(a) * 26.0)
		draw_line(hand, blade, Color("7a5230"), 2.0)
		draw_rect(Rect2(blade - Vector2(2, 4), Vector2(4, 8)), Color("c8a060"))
