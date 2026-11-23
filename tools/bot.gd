# Bot used by tools/test_bot_run.gd (loaded at runtime so autoloads exist).
# Plays any level: runs right, jumps gaps/walls/hens, waits for and rides
# logs, jumps corks, throws rocks at Earl, and dashes into him in showdowns.
#   godot --headless -s tools/test_bot_run.gd -- <level 1-5> [god]
# "god" keeps the bot invulnerable, to prove a level can be finished.
extends Node

var level: Level
var target := 0
var god := false
var frames := 0
var holding_jump := 0
var falls := 0
var hurts := 0
var dash_t := 0
var throw_cd := 0
var last_dir := 1.0
var car_hits := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		target = int(args[0]) - 1
	god = "god" in args


func _physics_process(_delta: float) -> void:
	frames += 1
	if level == null or not is_instance_valid(level):
		var s := get_tree().current_scene
		if s is Level:
			if Game.level_index != target:
				Game.go_to_level(target)
				return
			level = s
			level.player.fell_out.connect(func(): falls += 1)
			level.player.hurt_taken.connect(func(): hurts += 1)
		return
	var p := level.player
	if god:
		p.invuln = maxi(p.invuln, 2)
		if level.in_chase():
			level.chase.invuln = maxi(level.chase.invuln, 2)
	if level.in_chase():
		_drive(level.chase)
		return
	for a in ["lasso", "up"]:
		Input.action_release(a)
	if p.lasso and p.lasso.swinging():
		_swing(p)
		return
	if _lasso_gap(p):
		return
	if level.earl and level.earl.state == Earl.State.TOWER and not level.tower.has_method("bot_hint"):
		_ring_bell(p)
		return
	var dir := 1.0
	if level.phase == Level.Phase.SHOWDOWN:
		if p.is_on_floor():
			last_dir = signf(level.earl.global_position.x - p.global_position.x)
		dir = last_dir
	var want_jump := false
	var hold_still := false
	# set-piece objects can steer the bot (bot_hint: dir / jump / hold)
	var hint := {}
	for ob in level.world.get_node("Objects").get_children():
		if ob.has_method("bot_hint"):
			hint = ob.bot_hint(p)
			if not hint.is_empty():
				break
	if hint.get("duck", false):
		Input.action_press("down")
	else:
		Input.action_release("down")
	if p.ride != null and hint.get("jump", false):
		if frames % 4 == 0:
			Input.action_press("jump")         # tap jump while riding (mine cart)
		else:
			Input.action_release("jump")
	if hint.get("up", false) and frames % 2 == 0:
		Input.action_press("up")
	if hint.get("dash", false) and p.is_on_floor() and not p.sliding:
		if frames % 2 == 0:
			Input.action_press("action")
		else:
			Input.action_release("action")
	if hint.get("mash", false):
		if frames % 2 == 0:
			Input.action_press("throw")
		else:
			Input.action_release("throw")
	if hint.has("lane"):
		Input.action_press("up" if hint.lane == 0 else "down")
	if hint.get("cast", false):
		if frames % 20 == 0:
			Input.action_press("throw")
		elif frames % 20 == 2:
			Input.action_release("throw")
	if hint.has("reel"):
		if hint.reel:
			Input.action_press("throw")
		else:
			Input.action_release("throw")
	if hint.get("throw", false) and p.rocks > 0:
		if frames % 30 == 0:
			Input.action_press("throw")
		elif frames % 30 == 2:
			Input.action_release("throw")
	if hint.has("dir"):
		dir = hint.dir
	if hint.get("jump", false):
		want_jump = true
	if hint.get("hold", false) or (hint.has("dir") and hint.dir == 0.0):
		hold_still = true

	var space := p.get_world_2d().direct_space_state
	var gap := false
	if dir > 0.0:
		gap = level.gap_ahead(p.global_position.x).x < 20.0
	else:
		var ahead := p.global_position + Vector2(-26, -2)
		gap = space.intersect_ray(PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 40), 1)).is_empty()
	var wall := not space.intersect_ray(PhysicsRayQueryParameters2D.create(
		p.global_position + Vector2(0, -10), p.global_position + Vector2(30 * dir, -10), 1)).is_empty()
	var gap_near := false
	for k in range(2, 10):
		var at := p.global_position + Vector2(16 * k * dir, -2)
		if space.intersect_ray(PhysicsRayQueryParameters2D.create(at, at + Vector2(0, 12), 3)).is_empty():
			gap_near = true
	if hint.has("dir"):
		gap = false                            # the set piece knows best (e.g. riding a train over a ravine)
		wall = false
	var sheet := not space.intersect_ray(PhysicsRayQueryParameters2D.create(
		p.global_position + Vector2(0, -40), p.global_position + Vector2(44 * dir, -40), 64)).is_empty()
	if sheet and p.is_on_floor() and not p.sliding:
		if frames % 2 == 0:
			Input.action_press("action")       # tap, so a press during the dash cooldown isn't lost
		else:
			Input.action_release("action")
	elif dash_t == 0:
		Input.action_release("action")
	var hen_ahead := false
	for ob in level.world.get_node("Objects").get_children():
		if ob.get("barrels") != null:
			for b in ob.barrels:
				var bx: float = ob.global_position.x + b.x - p.global_position.x
				if not b.dead and bx > 10.0 and bx < 60.0:
					hen_ahead = true
	for h in level.actors.get_children():
		if h is Hen and not h.tumbling and h.kind != Hen.Kind.FLAP and h.kind != Hen.Kind.HERD:
			var dx: float = (h.global_position.x - p.global_position.x) * dir
			if dx > 10.0 and dx < 48.0 and not gap_near:
				hen_ahead = true

	# water: wait at the edge for a log, ride it, hop off at the far side
	if level.data.get("water", false) and level.data.get("flags", {}).get("logs", true) and p.is_on_floor():
		var g := level.gap_ahead(p.global_position.x)
		var riding := _log_under(p) != null
		if riding:
			var g2 := level.gap_ahead(p.global_position.x)
			hold_still = true
			gap = false
			if g2.x > 0.0 and g2.x < 400.0:
				pass
			var shore := _next_shore(p.global_position.x)
			if shore - p.global_position.x < 70.0:
				want_jump = true
				hold_still = false
		elif g.x < 30.0 and g.y > 120.0:
			gap = false
			hold_still = true
			var lg := _log_near(g.x + p.global_position.x)
			if lg != null:
				want_jump = true
				hold_still = false

	# corks: hop over them
	for c in level.world.get_children():
		if c is Projectile and c.kind == Projectile.Kind.CORK:
			var dx: float = p.global_position.x - c.global_position.x
			if dx > 0.0 and dx < 70.0 and c.velocity.x > 0.0:
				want_jump = true

	Input.action_release("left")
	Input.action_release("right")
	if not hold_still:
		Input.action_press("right" if dir >= 0.0 else "left")

	if p.is_on_floor() and (want_jump or wall or gap or (hen_ahead and level.phase != Level.Phase.SHOWDOWN)):
		if holding_jump > 0 and holding_jump < 20:
			Input.action_release("jump")
			holding_jump = 0
		elif holding_jump == 0:
			Input.action_press("jump")
			holding_jump = 26
	if holding_jump > 0:
		holding_jump -= 1
		if holding_jump == 0:
			Input.action_release("jump")

	# rocks at Earl
	throw_cd = maxi(throw_cd - 1, 0)
	if p.can_throw and level.earl and throw_cd == 0 and p.rocks > 0:
		var ed := level.earl.global_position.x - p.global_position.x
		if ed > 80.0 and ed < 260.0 and level.phase == Level.Phase.CHASE:
			Input.action_press("throw")
			throw_cd = 90
	elif throw_cd == 88:
		Input.action_release("throw")

	# slippery showdown: rope him with the lasso before tackling
	var slippery: bool = level.earl != null and level.earl.ai.get("slippery", false)
	if slippery and level.phase == Level.Phase.SHOWDOWN and level.earl.roped_t == 0 and level.earl.can_be_tackled():
		var ex := level.earl.global_position.x - p.global_position.x
		if absf(ex) < 150.0 and absf(ex) > 30.0 and p.is_on_floor() and signf(ex) == float(p.facing) and frames % 20 == 0:
			Input.action_press("lasso")
	# showdown: dash into Earl when he's close and not mid-dodge
	if level.phase == Level.Phase.SHOWDOWN and level.earl.can_be_tackled() and dash_t == 0 and (not slippery or level.earl.roped_t > 0):
		if absf(level.earl.global_position.x - p.global_position.x) < 80.0 and p.is_on_floor():
			Input.action_press("action")
			dash_t = 30
	if dash_t > 0:
		dash_t -= 1
		if dash_t == 28:
			Input.action_release("action")

	var tag := "L%d %s" % [target + 1, Game.level_id()]
	if level.phase == Level.Phase.WON and (OS.get_environment("HOLD") == "" or level.end_t > 40):
		print("%s WON in %.1fs: pies %d/%d, golden=%s, score=%d, hearts=%d, hurts=%d, falls=%d%s" % [
			tag, level.time, level.pies_got, level.pies_total, level.golden_got, level.score,
			p.hearts, hurts, falls, " (god mode)" if god else ""])
		get_tree().quit(0)
	elif level.phase == Level.Phase.LOST or frames > 60 * 180:
		print("%s FAILED (%s) at x=%d of %d, hurts=%d falls=%d" % [tag, Level.Phase.keys()[level.phase],
			p.global_position.x, level.corner_x(), hurts, falls])
		get_tree().quit(1)


# --- car chase: gas, ease off for curves, floor it at the ramp, dodge, bump ----
func _drive(c: Node2D) -> void:
	for a in ["up", "down", "action", "jump", "left", "right"]:
		Input.action_release(a)
	var gas := true
	for cv in c.course.curves:
		if c.x > cv[0] - 140.0 and c.x < cv[1] and c.speed > cv[3] - 10.0:
			gas = false
			if c.speed > cv[3] + 10.0:
				Input.action_press("left")
	Input.action_press("right" if gas else "action")
	if not gas:
		Input.action_release("action")
	if frames % 3 != 0:
		return
	var want: int = c.lane
	if _blocked(c, c.lane):
		for l in [c.lane - 1, c.lane + 1, c.lane - 2, c.lane + 2]:
			if l >= 0 and l < 3 and not _blocked(c, l):
				want = l
				break
		if want == c.lane and frames % 30 == 0:
			Input.action_press("action")          # siren: make them pull over
	elif c.truck.lane != c.lane and not _blocked(c, c.truck.lane) and c.truck.x - c.x < 300.0:
		want = c.lane + signi(c.truck.lane - c.lane)
	if want < c.lane:
		Input.action_press("up")
	elif want > c.lane:
		Input.action_press("down")


func _blocked(c: Node2D, l: int) -> bool:
	for v in c.traffic:
		if not v.gone and v.lane == l and v.x - c.x > -40.0 and v.x - c.x < 230.0:
			return true
	for cr in c.crates:
		if not cr.hit and cr.lane == l and cr.x - c.x > 0.0 and cr.x - c.x < 160.0:
			return true
	return false


# --- lasso across a wide gap with hooks over it ---------------------------------------
func _lasso_gap(p: Player) -> bool:
	if level.hooks.is_empty() or level.phase != Level.Phase.CHASE:
		return false
	var g := level.gap_ahead(p.global_position.x)
	if p.is_on_floor() and g.x < 40.0 and g.x > -4.0 and g.y > 140.0:
		Input.action_release("right")
		if p.lasso.state == Lasso.State.IDLE and frames % 10 == 0:
			Input.action_press("lasso")
		return true
	if not p.is_on_floor() and p.lasso.state == Lasso.State.IDLE and p.velocity.y > -100.0:
		for hk in level.hooks:
			var d: Vector2 = hk - (p.global_position + Vector2(0, -30))
			if d.x > 0.0 and d.length() < Lasso.RANGE - 10.0:
				Input.action_press("lasso")
				return true
	return false


func _swing(p: Player) -> void:
	Input.action_release("jump")
	Input.action_press("right")
	var L: Lasso = p.lasso
	if L.theta > 0.55 and L.omega > 0.0:
		Input.action_press("jump")


func _ring_bell(p: Player) -> void:
	if holding_jump > 0:
		holding_jump -= 1
		if holding_jump == 10:
			Input.action_release("jump")
	for n in level.lasso_targets:
		var dx: float = n.lasso_point().x - p.global_position.x
		Input.action_release("left")
		Input.action_release("right")
		if absf(dx) > 20.0:
			Input.action_press("right" if dx > 0.0 else "left")
		elif p.is_on_floor() and holding_jump == 0:
			Input.action_press("jump")
			holding_jump = 30


func _log_under(p: Player) -> Node2D:
	for n in level.world.get_children():
		if n is AnimatableBody2D:
			var x: float = n.position.x
			if p.global_position.x > x and p.global_position.x < x + 96.0 and absf(p.global_position.y - n.position.y) < 6.0:
				return n
	return null


func _log_near(edge_x: float) -> Node2D:
	for n in level.world.get_children():
		if n is AnimatableBody2D:
			var x: float = n.position.x
			if x > edge_x - 4.0 and x < edge_x + 26.0:
				return n
	return null


func _next_shore(x: float) -> float:
	for seg in level.data.ground:
		if seg[0] * Level.TILE > x:
			return seg[0] * Level.TILE
	return INF
