# The old mine railway across the chasm. Earl jumps in one cart and you
# follow in another: it rolls by itself. Press JUMP to hop the cart over
# broken track, hold DOWN to duck under the low timbers. Fall through a
# gap and you're back at the start of the line.
#   {"type": "mine_cart", "x": 100, "to": 170, "breaks": [[120, 124]], "beams": [132]}
extends LevelObject

const START := 10.0          # px: where the cart sits at the start of the line
const MAX_SPEED := 230.0
const JUMP_V := -330.0

var length := 0.0
var breaks: Array = []       # local [a, b]
var beams: Array = []        # local x
var state := 0               # 0 parked, 1 riding, 2 at the end of the line
var cx := START              # cart position along the rails
var cy := 0.0                # cart height offset (negative = up)
var vy := 0.0
var speed := 0.0
var ducking := false
var ex := START + 90.0       # Earl's cart
var ey := 0.0
var earl_in := false
var falling := false         # missed a jump: going down
var keep_rider := true       # a bump from a timber hurts, but you stay in the cart
var _t := 0.0


func _setup() -> void:
	length = (o.to - o.x) * TILE
	for br in o.get("breaks", []):
		breaks.append(Vector2((br[0] - o.x) * TILE, (br[1] - o.x) * TILE))
	for bm in o.get("beams", []):
		beams.append((bm - o.x) * TILE)
	level.truck_x = global_position.x + START + 20.0       # Earl hops in his cart here
	z_index = 2                                             # carts in front of the riders


func _in_break(x: float) -> bool:
	for br in breaks:
		if x > br.x + 4.0 and x < br.y - 4.0:
			return true
	return false


func step(delta: float) -> void:
	_t += delta
	var p := player()
	var e: Node2D = level.earl
	earl_in = e != null and e.state == Earl.State.WAIT and level.truck_x > 0.0
	if state == 0:
		if p.global_position.x > global_position.x + length:
			_finish(false)                                   # resumed past the railway
		elif p.ride == null and p.is_on_floor() and absf(p.global_position.x - (global_position.x + cx)) < 20.0:
			state = 1
			speed = 60.0
			if e and e.state != Earl.State.WAIT:
				e.state = Earl.State.WAIT
				e.visible = false
			p.start_ride(self)
			Audio.sfx("dash", 0.5)
	queue_redraw()


## Player.ride callback while in the cart.
func ride_step(p: Player, delta: float) -> bool:
	if level.finished:
		return false
	speed = minf(speed + 170.0 * delta, MAX_SPEED)
	cx += speed * delta
	if falling:
		vy += 900.0 * delta
		cy += vy * delta
	elif cy >= 0.0 and vy >= 0.0 and _in_break(cx):
		falling = true                                       # rolled straight into a gap
		vy = 140.0
		Audio.sfx("screech", 1.2)
	elif cy < 0.0 or vy < 0.0:
		vy += 900.0 * delta                                  # in the air from a jump
		cy += vy * delta
		if cy >= 0.0:
			if _in_break(cx):
				falling = true
			else:
				cy = 0.0                                     # landed on the far side
				vy = 0.0
				Audio.sfx("land", 1.2)
	else:
		cy = 0.0
		vy = 0.0
		if Input.is_action_just_pressed("jump"):
			vy = JUMP_V
			Audio.sfx("jump", 0.8)
	ducking = Input.is_action_pressed("down") and cy >= -4.0
	# low timbers
	for bx in beams:
		if absf(cx - bx) < 10.0 and not ducking and cy > -70.0 and p.invuln == 0:
			p.hurt(global_position.x + bx + 20.0)
			level.popup(global_position + Vector2(bx, -70), GameText.RC_DUCK, Color("ff9a3a"))
	# Earl's cart keeps ahead, hopping the gaps
	ex = maxf(ex, cx + 150.0)
	ex = minf(ex + speed * delta, length - 30.0)
	ey = 0.0
	for br in breaks:
		if ex > br.x - 20.0 and ex < br.y + 20.0:
			var k: float = (ex - br.x + 20.0) / (br.y - br.x + 40.0)
			ey = -sin(k * PI) * 46.0
	p.global_position = global_position + Vector2(cx, cy + 3.0)         # crouched in the cart
	p.velocity = Vector2(speed, vy)
	p.facing = 1
	p.anim = "slide" if ducking else ("jump" if cy < -2.0 else "idle")
	if cy > 60.0:
		_crash(p)
		return false
	if cx >= length - 24.0:
		_finish(true)
		p.velocity = Vector2(170.0, -330.0)
		return false
	return true


func _crash(p: Player) -> void:
	Audio.sfx("crash", 0.8)
	level.popup(p.global_position + Vector2(0, -60), GameText.RC_JUMP, Color("ff9a3a"))
	p.hurt(p.global_position.x)
	state = 0
	falling = false
	cx = START
	cy = 0.0
	vy = 0.0
	speed = 0.0
	ex = START + 90.0
	p.global_position = global_position + Vector2(START - 34.0, 0)
	p.velocity = Vector2.ZERO
	p.invuln = Player.INVULN_FRAMES
	pass  # (4.3 physics interpolation not in 4.1)
	level.camera.snap_to_target()


func _finish(ride_done: bool) -> void:
	state = 2
	cx = length - 24.0
	ex = length - 30.0
	var e: Node2D = level.earl
	if e and (e.state == Earl.State.WAIT or level.truck_x > 0.0):
		e.after_chase(global_position + Vector2(length + 16.0 * TILE, 0))
	level.truck_x = -1.0
	if ride_done:
		Audio.sfx("land", 0.8)


## Test bot: walk to the cart; in it, jump the gaps and duck the timbers.
func bot_hint(p: Player) -> Dictionary:
	if state == 2:
		return {}
	if state == 0:
		var dx := global_position.x + cx - p.global_position.x
		if dx > -40.0 and dx < 300.0:
			return {"dir": 1.0}
		return {}
	for br in breaks:
		var d: float = br.x - cx
		if d > 0.0 and d < 34.0:
			return {"jump": true, "dir": 1.0}
	for bx in beams:
		var d: float = bx - cx
		if d > -12.0 and d < 70.0:
			return {"duck": true, "dir": 1.0}
	return {"dir": 1.0}


func _draw() -> void:
	# rails + ties (the trestle over the chasm)
	var tie := Color("5a3a22")
	var rail := Color("8a8a96")
	for x in range(0, int(length), 10):
		if _in_break(float(x)):
			continue
		draw_rect(Rect2(x, -2, 6, 4), tie)
	for x in range(0, int(length), 2):
		if not _in_break(float(x)):
			draw_rect(Rect2(x, -4, 2, 2), rail)
	# trestle posts down into the chasm
	for x in range(20, int(length) - 20, 48):
		if not _in_break(float(x)):
			draw_line(Vector2(x, 2), Vector2(x - 14, 120), tie, 3.0)
			draw_line(Vector2(x, 2), Vector2(x + 14, 120), tie, 3.0)
	for br in breaks:
		# splintered ends
		draw_line(Vector2(br.x, -3), Vector2(br.x + 6, 4), rail, 2.0)
		draw_line(Vector2(br.y, -3), Vector2(br.y - 6, 5), rail, 2.0)
	# low timbers
	for bx in beams:
		var wood := Color("7a5a36")
		draw_rect(Rect2(bx - 26, -86, 6, 84), OUTLINE)
		draw_rect(Rect2(bx - 25, -86, 4, 84), wood)
		draw_rect(Rect2(bx + 20, -86, 6, 84), OUTLINE)
		draw_rect(Rect2(bx + 21, -86, 4, 84), wood)
		draw_rect(Rect2(bx - 30, -58, 60, 12), OUTLINE)
		draw_rect(Rect2(bx - 29, -57, 58, 10), wood.lightened(0.1))
		draw_rect(Rect2(bx - 29, -57, 58, 2), wood.lightened(0.3))
	# buffer stop at the end
	outlined_rect(Rect2(length - 6, -16, 8, 16), Color("b0442e"))
	# Earl's cart (with Earl in it once he's hopped in)
	_cart(Vector2(ex, ey), earl_in or state == 1)
	# the Sheriff's cart
	_cart(Vector2(cx, cy), false)
	if state == 0 and int(_t * 3.0) % 2 == 0:
		PixelFont.draw_centered(self, GameText.CAR_HINT, cx, -54, Color("ffd23f"))


func _cart(at: Vector2, with_earl: bool) -> void:
	if with_earl:
		var tex := SpriteLib.frames("earl").get_frame_texture("taunt", 0)
		if tex:
			var sz := SpriteLib.draw_size("earl", tex)
			draw_texture_rect(tex, Rect2(at + Vector2(-sz.x / 2.0, -sz.y - 6), sz), false)
	var metal := Color("6a6e7a")
	var rust := Color("8a4a2a")
	# wheels behind the tub, with spokes that turn with the cart
	var spin := at.x * 0.25
	for wx in [-9.0, 9.0]:
		var wc := at + Vector2(wx, -4)
		draw_circle(wc, 4.5, OUTLINE)
		draw_circle(wc, 3.5, Color("3a3a44"))
		draw_circle(wc, 1.2, Color("9a9aa8"))
		for k in 2:
			var d := Vector2.from_angle(spin + k * PI * 0.5) * 3.0
			draw_line(wc - d, wc + d, Color("5a5a66"), 1.0)
	# riveted, tapered tub with a rolled rim, rust streaks and a load of ore
	var tub := PackedVector2Array([at + Vector2(-16, -21), at + Vector2(16, -21), at + Vector2(13, -6), at + Vector2(-13, -6)])
	var tub_o := PackedVector2Array([at + Vector2(-18, -22), at + Vector2(18, -22), at + Vector2(14, -5), at + Vector2(-14, -5)])
	draw_colored_polygon(tub_o, OUTLINE)
	draw_colored_polygon(tub, metal)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-16, -21), at + Vector2(-8, -21), at + Vector2(-7, -6), at + Vector2(-13, -6)]), metal.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([at + Vector2(9, -21), at + Vector2(16, -21), at + Vector2(13, -6), at + Vector2(8, -6)]), metal.darkened(0.25))
	# banding
	draw_line(at + Vector2(-15, -12), at + Vector2(15, -12), metal.darkened(0.35), 2.0)
	draw_line(at + Vector2(-15, -13), at + Vector2(15, -13), metal.lightened(0.25), 1.0)
	for rx in [-12.0, -4.0, 4.0, 12.0]:
		draw_rect(Rect2(at + Vector2(rx, -12), Vector2(1, 1)), Color("c8c8d4"))
		draw_rect(Rect2(at + Vector2(rx, -18), Vector2(1, 1)), Color("c8c8d4"))
	draw_line(at + Vector2(-5, -11), at + Vector2(-6, -7), rust, 1.0)
	draw_line(at + Vector2(7, -11), at + Vector2(7, -6), rust, 1.0)
	# rolled rim
	draw_rect(Rect2(at + Vector2(-18, -24), Vector2(36, 3)), OUTLINE)
	draw_rect(Rect2(at + Vector2(-17, -23), Vector2(34, 1)), Color("a8acb8"))
	if not with_earl:
		# lumps of ore poking over the rim
		for k in 5:
			var q := at + Vector2(-12 + k * 6, -25 - (k % 2) * 2)
			draw_circle(q, 3.0, OUTLINE)
			draw_circle(q, 2.0, Color("7a6a58") if k % 2 == 0 else Color("9a8a70"))
			draw_rect(Rect2(q + Vector2(-1, -1), Vector2(1, 1)), Color("e8d890") if k == 2 else Color("b8a888"))
