# The Sheriff's lasso (E / Z, gamepad Y).
# Throwing aims automatically at the best target in front of you:
#   hook  - an iron ring / branch: you swing from it like a pendulum.
#           Left/right pumps the swing, jump lets go with the momentum.
#   Earl  - yanks him to a stop for a moment (in a showdown he can't dodge
#           for a bit, so you can tackle him)
#   hen   - ropes it for points
#   nothing in range - the loop flies out and comes back
# The rope is drawn by this node, which lives in the level's world space.
class_name Lasso
extends Node2D

enum State { IDLE, FLYING, SWINGING, RETURNING, HOLDING }

const RANGE := 175.0
const FLY_SPEED := 1000.0
const RETURN_SPEED := 1400.0
const GRAVITY := 1500.0
const PUMP := 3.2                 # rad/s^2 while pushing in the swing direction
const MAX_ANGLE := 1.35           # never swing over the top
const HAND := Vector2(0, -30)     # rope attaches here, relative to the feet
const COOLDOWN := 18

var player: Player
var level: Node
var state := State.IDLE
var tip := Vector2.ZERO
var target_kind := ""
var target_ref: Node2D = null
var target_pos := Vector2.ZERO
var hook := Vector2.ZERO
var length := 80.0
var length_goal := 80.0
var theta := 0.0
var omega := 0.0
var cooldown := 0
var style := "rope"               # rope (Sheriff), cables (Dewey's jumper cables), hose (Jim's garden hose)
var _t := 0.0
var _fx: Array = []               # [pos, vel, life, color] sparks / water drops


func setup(p: Player, l: Node) -> void:
	player = p
	level = l
	z_index = 6


func hand() -> Vector2:
	return player.global_position + HAND + Vector2(player.facing * 6, 0)


func busy() -> bool:
	return state != State.IDLE


func swinging() -> bool:
	return state == State.SWINGING


# --- throwing -------------------------------------------------------------------
func fire() -> void:
	if state == State.SWINGING:
		drop()
		return
	if state != State.IDLE or cooldown > 0:
		return
	_pick_target()
	tip = hand()
	state = State.FLYING
	Audio.sfx("throw", 0.8)


func _pick_target() -> void:
	var h := hand()
	var f: float = player.facing
	# 1) hooks above and in front (or just behind)
	var best := INF
	target_kind = "miss"
	target_ref = null
	for hk in level.hooks:
		var d: Vector2 = hk - h
		var score := d.length() + (120.0 if d.x * f < 0.0 else 0.0)   # prefer hooks in front
		if d.y < -20.0 and d.x * f > -40.0 and d.length() < RANGE and score < best:
			best = score
			target_kind = "hook"
			target_pos = hk
	# 1b) things like the fire bell
	for obj in level.lasso_targets:
		var d: Vector2 = obj.lasso_point() - h
		if d.x * f > -20.0 and d.length() < RANGE and d.length() < best:
			best = d.length()
			target_kind = "object"
			target_ref = obj
			target_pos = obj.lasso_point()
	if target_kind == "hook" or target_kind == "object":
		return
	# 2) Earl, 3) hens, roughly level with us and in front
	var cands: Array = []
	if level.earl and level.data.get("earl_ai", {}).get("lasso_ok", true):
		cands.append(level.earl)
	for a in level.actors.get_children():
		if a is Hen and not a.tumbling and a.kind != Hen.Kind.FLAP and a.kind != Hen.Kind.HERD:
			cands.append(a)
	for c in cands:
		var d: Vector2 = (c.global_position + Vector2(0, -16)) - h
		if d.x * f > 0.0 and absf(d.y) < 70.0 and d.length() < RANGE and d.length() < best:
			best = d.length()
			target_kind = "earl" if c is Earl else "hen"
			target_ref = c
	if target_ref == null:
		target_pos = h + Vector2(f * 120.0, -50.0)


# --- per frame -------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	cooldown = maxi(cooldown - 1, 0)
	_t += delta
	_step_fx(delta)
	match state:
		State.FLYING:
			if target_kind == "object":
				target_pos = target_ref.lasso_point()
			elif target_ref and is_instance_valid(target_ref):
				target_pos = target_ref.global_position + Vector2(0, -16)
			tip = tip.move_toward(target_pos, FLY_SPEED * delta)
			if tip.distance_to(target_pos) < 2.0:
				_arrive()
			elif tip.distance_to(hand()) > RANGE + 40.0:
				state = State.RETURNING
		State.RETURNING:
			tip = tip.move_toward(hand(), RETURN_SPEED * delta)
			if tip.distance_to(hand()) < 6.0:
				state = State.IDLE
				cooldown = COOLDOWN
		State.SWINGING:
			tip = hook
		State.HOLDING:
			var e = target_ref
			if not is_instance_valid(e) or e.roped_t <= 0:
				state = State.RETURNING
			else:
				tip = e.global_position + Vector2(0, -22)
	queue_redraw()


func _arrive() -> void:
	match target_kind:
		"hook":
			_start_swing()
			_burst(tip, 8)
		"earl":
			state = State.RETURNING
			if is_instance_valid(target_ref) and level.on_lasso_earl(target_ref) and target_ref.roped_t > 0:
				state = State.HOLDING          # keep him tied up until the tackle (or he wriggles free)
				_burst(tip, 18)
				if style != "rope":
					level.popup(tip + Vector2(0, -40), "BZZT!" if style == "cables" else "SPLOOSH!", Color("8ae0ff") if style == "hose" else Color("ffe060"))
					var l: String = level.hero_line("rope_earl")
					if l != "":
						player.get_node("Bubble").show_text(Names.fmt(l), 90, "rope_earl")
		"object":
			target_ref.on_lassoed()
			state = State.RETURNING
		"hen":
			if is_instance_valid(target_ref) and not target_ref.tumbling:
				target_ref.knock(-player.facing)
				level.on_lasso_hen(target_ref)
			state = State.RETURNING
		_:
			state = State.RETURNING


# --- swinging ------------------------------------------------------------------------
func _start_swing() -> void:
	hook = target_pos
	var h := player.global_position + HAND
	var d := h - hook
	length = maxf(d.length(), 30.0)
	# keep the Sheriff's boots clear of the ground at the bottom of the swing
	var max_len: float = level.GROUND_Y - hook.y - 48.0
	length_goal = clampf(length, 40.0, maxf(max_len, 40.0))
	theta = atan2(d.x, d.y)
	var tangent := Vector2(cos(theta), -sin(theta))
	omega = player.velocity.dot(tangent) / length
	if player.is_on_floor():
		# roped from a standing start (e.g. a hayloft edge): yank the Sheriff up
		# a little so the swing clears the ledge he was standing on
		length = maxf(length * 0.7, 30.0)
		length_goal = minf(length_goal, length)
		omega = 1.0 * player.facing
	state = State.SWINGING
	player.on_swing_start()
	Audio.sfx("pickup", 0.7)


## Called by the player instead of its normal movement while swinging.
func swing_step(delta: float, dir: float) -> void:
	length = move_toward(length, length_goal, 160.0 * delta)
	var alpha := -(GRAVITY / length) * sin(theta)
	if dir != 0.0 and (signf(omega) == dir or absf(omega) < 0.4):
		alpha += PUMP * dir
	omega = (omega + alpha * delta) * 0.998
	theta += omega * delta
	if absf(theta) > MAX_ANGLE:
		theta = signf(theta) * MAX_ANGLE
		omega = 0.0
	var feet := hook + Vector2(sin(theta), cos(theta)) * length - HAND
	player.velocity = (feet - player.global_position) / delta
	player.move_and_slide()
	if player.get_slide_collision_count() > 0:
		var d := (player.global_position + HAND) - hook
		theta = atan2(d.x, d.y)
		omega *= -0.25
	if omega != 0.0:
		player.facing = 1 if omega > 0.0 else -1


## Let go, keeping the swing's momentum (plus a little hop when jumping).
func release(hop: bool) -> void:
	if state != State.SWINGING:
		return
	var tangent := Vector2(cos(theta), -sin(theta))
	player.velocity = tangent * omega * length * 1.1
	if hop:
		player.velocity.y = minf(player.velocity.y, 0.0) - 220.0
	state = State.RETURNING
	tip = hook
	cooldown = COOLDOWN


## Drop the rope without a boost (hurt, pressed lasso again...).
func drop() -> void:
	if state == State.SWINGING:
		release(false)
	elif state != State.IDLE:
		state = State.RETURNING     # also lets go of a roped Earl


# --- sparks and water ---------------------------------------------------------------
func _burst(at: Vector2, n: int) -> void:
	if style == "rope":
		return
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(40.0, 140.0) + Vector2(0, -40)
		var c := Color("fff3a0") if style == "cables" else Color("8ad0ff")
		if style == "cables" and i % 3 == 0:
			c = Color("ffffff")
		_fx.append([at, v, randf_range(0.2, 0.45), c])
	Audio.sfx("dash", 2.4) if style == "cables" else Audio.sfx("splash", 1.5)


func _step_fx(delta: float) -> void:
	# a steady trickle while the hose sprays or the cables fizz on a hook / on Earl
	if style != "rope" and (state == State.SWINGING or state == State.HOLDING) and randf() < (0.35 if style == "hose" else 0.2):
		var v := Vector2(randf_range(-30.0, 30.0), randf_range(-60.0, 10.0))
		_fx.append([tip + Vector2(randf_range(-3, 3), 2), v, 0.35, Color("8ad0ff") if style == "hose" else Color("fff3a0")])
	for f in _fx:
		f[1].y += (600.0 if style == "hose" else 150.0) * delta
		f[0] += f[1] * delta
		f[2] -= delta
	_fx = _fx.filter(func(f): return f[2] > 0.0)


func _draw_fx() -> void:
	for f in _fx:
		var c: Color = f[3]
		c.a = clampf(f[2] * 4.0, 0.0, 1.0)
		draw_rect(Rect2(f[0], Vector2(1, 1) if style == "cables" else Vector2(1, 2)), c)


func _draw() -> void:
	_draw_fx()
	if state == State.IDLE:
		return
	match style:
		"cables":
			_draw_cables()
			return
		"hose":
			_draw_hose()
			return
	_draw_rope()


func _sag() -> Vector2:
	return (hand() + tip) * 0.5 + Vector2(0, 6.0 if state != State.SWINGING else 0.0)


## Dewey's jumper cables: a red and a black lead side by side, copper clamps.
func _draw_cables() -> void:
	var a := hand()
	var b := tip
	var mid := _sag()
	var n := (b - a).orthogonal().normalized() * 1.5
	for k in 2:
		var off := n if k == 0 else -n
		var col := Color("d8302a") if k == 0 else Color("2a2a30")
		draw_line(a + off, mid + off * 1.6, Color("100808"), 3.0)
		draw_line(mid + off * 1.6, b + off, Color("100808"), 3.0)
		draw_line(a + off, mid + off * 1.6, col, 1.0)
		draw_line(mid + off * 1.6, b + off, col, 1.0)
	# clamps (open while flying, snapped shut on a hook / Earl)
	var shut := state == State.SWINGING or state == State.HOLDING
	for k in 2:
		var c := b + (n * 2.5 if k == 0 else -n * 2.5)
		var jaw := 1.0 if shut else 3.0
		draw_rect(Rect2(c + Vector2(-2, -jaw - 1), Vector2(4, 2)), Color("c87a3a"))
		draw_rect(Rect2(c + Vector2(-2, jaw - 1), Vector2(4, 2)), Color("a85a2a"))
		draw_rect(Rect2(c + Vector2(-1, -jaw - 2), Vector2(2, 1)), Color("d8302a") if k == 0 else Color("2a2a30"))
	if shut and int(_t * 20.0) % 3 == 0:
		# a little arc of electricity at the clamp
		var z := b + Vector2(randf_range(-4, 4), -3)
		draw_line(b, z, Color("fffbd0"), 1.0)
		draw_line(z, z + Vector2(randf_range(-3, 3), -3), Color("8ae0ff"), 1.0)
	if state == State.HOLDING:
		for k in 2:
			var c2 := b + Vector2(0, -4 + k * 6)
			draw_set_transform(c2, 0.0, Vector2(1.0, 0.35))
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, Color("100808"), 3.0)
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, Color("d8302a") if k == 0 else Color("2a2a30"), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Jim's garden hose: a fat green hose with a brass nozzle that sprays.
func _draw_hose() -> void:
	var a := hand()
	var b := tip
	var mid := _sag() + Vector2(0, 3)
	draw_line(a, mid, Color("0e2a10"), 4.0)
	draw_line(mid, b, Color("0e2a10"), 4.0)
	draw_line(a, mid, Color("3a9a3a"), 2.0)
	draw_line(mid, b, Color("3a9a3a"), 2.0)
	draw_line(a + Vector2(0, -1), mid + Vector2(0, -1), Color("7ad07a"), 1.0)
	draw_line(mid + Vector2(0, -1), b + Vector2(0, -1), Color("7ad07a"), 1.0)
	var d := (b - mid).normalized()
	draw_line(b - d * 4.0, b, Color("5a3a10"), 4.0)
	draw_line(b - d * 4.0, b, Color("e0b040"), 2.0)
	if state == State.FLYING or state == State.RETURNING:
		# spraying ahead of the nozzle
		for k in 4:
			var q := b + d * (3.0 + k * 3.0) + Vector2(0, sin(_t * 30.0 + k) * 1.5)
			draw_rect(Rect2(q, Vector2(1, 1)), Color(0.6, 0.85, 1.0, 0.9 - k * 0.2))
	if state == State.HOLDING:
		for k in 3:
			var c3 := b + Vector2(0, -6 + k * 5)
			draw_set_transform(c3, 0.0, Vector2(1.0, 0.35))
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, Color("0e2a10"), 3.0)
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, Color("3a9a3a"), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rope() -> void:
	var a := hand()
	var b := tip
	var rope := Color("c8a060")
	var shade := Color("7a5230")
	# slight sag while flying / returning
	var mid := (a + b) * 0.5 + Vector2(0, 6.0 if state != State.SWINGING else 0.0)
	draw_line(a, mid, shade, 2.0)
	draw_line(mid, b, shade, 2.0)
	draw_line(a + Vector2(0, -1), mid + Vector2(0, -1), rope, 1.0)
	draw_line(mid + Vector2(0, -1), b + Vector2(0, -1), rope, 1.0)
	if state == State.FLYING or state == State.RETURNING:
		draw_arc(b, 4.0, 0.0, TAU, 12, shade, 2.0)
		draw_arc(b, 4.0, 0.0, TAU, 12, rope, 1.0)
	if state == State.HOLDING:
		# loops of rope around Earl's middle
		for k in 3:
			var c := b + Vector2(0, -6 + k * 5)
			draw_set_transform(c, 0.0, Vector2(1.0, 0.35))
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, shade, 3.0)
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, rope, 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
