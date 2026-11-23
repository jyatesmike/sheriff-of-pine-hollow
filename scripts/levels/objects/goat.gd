# The billy goat in the pasture. Turn your back on him (face away while
# he's close) and he paws the ground and charges. Get hit and it hurts;
# jump on his back and he bounces you sky-high. If Earl turns his back on
# the goat, Earl gets butted instead!
#   {"type": "goat", "x": 226, "to": 256}
extends LevelObject

enum S { GRAZE, PAW, CHARGE, DAZED }

const CHARGE_SPEED := 260.0
const SEE := 150.0

var s := S.GRAZE
var gx := 0.0                # local x of the goat
var dir := -1.0
var t := 0
var target: Node2D
var range_x := Vector2.ZERO
var squash := 0
var _t := 0.0


func _setup() -> void:
	range_x = Vector2(0, (o.get("to", o.x + 30) - o.x) * TILE)
	gx = range_x.y * 0.5


func _world_x() -> float:
	return global_position.x + gx


func body_rect() -> Rect2:
	return Rect2(_world_x() - 13, global_position.y - 22, 26, 22)


func step(delta: float) -> void:
	_t += delta
	t = maxi(t - 1, 0)
	squash = maxi(squash - 1, 0)
	var p := player()
	match s:
		S.GRAZE:
			if t == 0:
				t = 60 + randi() % 90
				dir = -dir if randf() < 0.5 else dir
			gx += dir * 18.0 * delta
			var who := _victim()
			if who:
				target = who
				dir = signf(who.global_position.x - _world_x())
				s = S.PAW
				t = 28
				Audio.sfx("honk", 0.6)
		S.PAW:
			if t == 0:
				s = S.CHARGE
				t = 70
		S.CHARGE:
			gx += dir * CHARGE_SPEED * delta
			if t == 0:
				s = S.GRAZE
			if level.earl and target == level.earl and level.earl.body_rect().intersects(body_rect()):
				if level.earl.bonk():
					level.earl.velocity = Vector2(dir * 220.0, -260.0)
					level.earl.say(GameText.CR_EARL_GOAT, 90, "cr_goat")
					level.score += 300
					level.popup(level.earl.global_position + Vector2(0, -60), "BUTTED! +300", Color("ff9a3a"))
				s = S.DAZED
				t = 60
		S.DAZED:
			if t == 0:
				s = S.GRAZE
	if gx < range_x.x or gx > range_x.y:
		gx = clampf(gx, range_x.x, range_x.y)
		dir = -dir
		if s == S.CHARGE:
			s = S.DAZED                    # smacked into the fence
			t = 70
			Audio.sfx("bonk", 0.7)
	# the Sheriff
	var r := body_rect()
	if r.intersects(p.body_rect()):
		if p.velocity.y > 0.0 and p.global_position.y - r.position.y < 14.0:
			p.bounce()
			p.velocity.y = -820.0
			squash = 10
			level.score += 100
			level.popup(r.get_center() + Vector2(0, -20), "BOING! +100")
			Audio.sfx("stomp", 0.8)
		elif s == S.CHARGE and p.invuln == 0:
			p.hurt(_world_x())
			s = S.DAZED
			t = 40
	queue_redraw()


## Someone close by with their back to the goat (and on the ground)?
func _victim() -> Node2D:
	var p := player()
	var dx := p.global_position.x - _world_x()
	if absf(dx) < SEE and absf(p.global_position.y - global_position.y) < 30.0 and signf(dx) == float(p.facing):
		return p
	var e: Node2D = level.earl
	if e and e.visible and e.state in [Earl.State.CHASE, Earl.State.TAUNT]:
		var ex := e.global_position.x - _world_x()
		if absf(ex) < SEE and absf(e.global_position.y - global_position.y) < 30.0 and signf(ex) == float(e.facing):
			return e
	return null


## Test bot: hop over the goat (or onto his back) when he's near.
func bot_hint(p: Player) -> Dictionary:
	var dx := _world_x() - p.global_position.x
	if dx > 0.0 and dx < 56.0 and p.is_on_floor():
		return {"dir": 1.0, "jump": true}
	return {}


func _draw() -> void:
	var x := gx
	var f := dir
	var sq := Vector2(1.15, 0.75) if squash > 0 else Vector2.ONE
	var bob := 0.0 if s != S.CHARGE else roundf(sin(_t * 40.0))
	var lean := 4.0 if s in [S.PAW, S.CHARGE] else 0.0
	var white := Color("ece6da")
	var shade := Color("b8ad98")
	var leg_c := Color("6a5a4a")
	draw_set_transform(Vector2(x, 0), 0.0, Vector2(f, 1) * sq)
	# shadow
	draw_colored_polygon(ellipse(Vector2(0, 0), Vector2(15, 2)), Color(0, 0, 0, 0.25))
	var spd := 30.0 if s == S.CHARGE else 6.0
	var step_k := sin(_t * spd) * (4.0 if s != S.DAZED and s != S.GRAZE else (1.0 if s == S.GRAZE else 0.0))
	if s == S.PAW:
		step_k = absf(sin(_t * 18.0)) * 4.0
	# far legs (darker) then body then near legs
	for k in 2:
		var lx: float = [-8.0, 8.0][k]
		var sw: float = -step_k if k == 0 else step_k
		limb(Vector2(lx + 1, -11 + bob), Vector2(lx + 1 - sw, -2), 2.0, leg_c.darkened(0.3))
	# tail flick
	limb(Vector2(-12, -18 + bob), Vector2(-16, -22 + bob + sin(_t * 9.0)), 2.0, white)
	blob(Vector2(0, -15 + bob), Vector2(13, 7), white)
	# shaggy belly fringe
	for i in 6:
		draw_rect(Rect2(-9 + i * 3.5, -10 + bob, 2, 2 + (i % 2)), shade)
	for k in 2:
		var lx: float = [-10.0, 6.0][k]
		var sw: float = step_k if k == 0 else -step_k
		if s == S.PAW and k == 1:
			sw = step_k
		limb(Vector2(lx, -10 + bob), Vector2(lx + sw, -2), 2.5, leg_c)
		hoof(Vector2(lx + sw, -1))
	# neck and head (lowered when charging)
	var hy := -25.0 + lean + bob
	limb(Vector2(9, -18 + bob), Vector2(13, hy + 3), 5.0, white)
	blob(Vector2(16, hy + 1), Vector2(6, 4.5), white, 0.35 if lean > 0 else 0.15)
	draw_colored_polygon(ellipse(Vector2(21, hy + 3 + lean * 0.3), Vector2(2.5, 2)), Color("d8a8a0"))   # muzzle
	draw_rect(Rect2(22, hy + 2 + lean * 0.3, 1, 1), OUTLINE)
	# eye with a sideways goat pupil
	draw_rect(Rect2(15, hy - 1, 3, 2), Color("f0d060"))
	draw_rect(Rect2(15, hy - 1, 3, 1), OUTLINE)
	draw_rect(Rect2(16, hy, 2, 1), OUTLINE)
	# beard
	draw_colored_polygon(PackedVector2Array([Vector2(16, hy + 4), Vector2(20, hy + 5), Vector2(17, hy + 11)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(17, hy + 5), Vector2(19, hy + 5), Vector2(17, hy + 9)]), shade)
	# ear
	draw_colored_polygon(PackedVector2Array([Vector2(12, hy - 1), Vector2(6, hy + 1), Vector2(11, hy + 2)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(11, hy), Vector2(7, hy + 1), Vector2(11, hy + 1)]), shade)
	# curled horns
	var hc := Color("9a8a62")
	draw_arc(Vector2(11, hy - 3), 4.5, -PI * 0.1, PI * 1.3, 10, OUTLINE, 4.0)
	draw_arc(Vector2(11, hy - 3), 4.5, -PI * 0.1, PI * 1.3, 10, hc, 2.0)
	draw_arc(Vector2(11, hy - 3), 4.5, PI * 0.9, PI * 1.25, 4, hc.lightened(0.35), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if s == S.PAW and t % 8 < 4:
		level_dust_hint(Vector2(x - f * 8, -2))
	if s == S.DAZED:
		for k in 3:
			var a := _t * 5.0 + k * TAU / 3.0
			draw_circle(Vector2(x + f * 14 + cos(a) * 8, -34 + sin(a) * 3), 1.5, Color("ffd23f"))


func level_dust_hint(at: Vector2) -> void:
	draw_circle(at, 2.0, Color(0.8, 0.7, 0.5, 0.7))
	draw_circle(at + Vector2(-3, -2), 1.5, Color(0.8, 0.7, 0.5, 0.5))
