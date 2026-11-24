# Earl, the escaped jailbird. Two phases:
#  CHASE    - runs ahead, rubber-banding to the Sheriff's distance, hopping
#             gaps and crates. What else he does comes from the level's
#             "earl_ai" flags (data/levels/<id>.json):
#               taunts    - doubles back now and then to jeer
#               shortcuts - hops up onto awnings / lofts
#               hides     - ducks behind crates and pops out
#               throws    - chucks rocks back at you
#               leaps     - takes huge leaps over wide water
#  SHOWDOWN - once cornered (or caught), he dodges around a small arena.
#             Tackle him 3 times (dash works best) and he's cuffed.
# Earl passes through the Sheriff; the level checks for contact.
class_name Earl
extends CharacterBody2D

signal cornered
signal tackled(count: int)
signal cuffed
signal threw(at: Vector2, vel: Vector2)

enum State { CHASE, TAUNT, HIDE, WAIT, CLIMB, TOWER, FALL, IDLE, WINDUP, DODGE, STUNNED, CUFFED }

const GRAVITY := 1600.0
const MAX_FALL := 560.0
const JUMP_V := -560.0
const AIR_MIN := 190.0        # always fast enough in the air to clear a gap
const AIR_TIME := 0.7         # seconds a full jump stays in the air
const TACKLES_NEEDED := 3

var player: Player
var level: Node
var ai := {}
var state := State.CHASE
var facing := 1
var timer := 0
var taunt_cd := 240
var hide_cd := 300
var throw_cd := 150
var throw_t := 0
var stuck_t := 0
var leap_vx := 0.0
var tackles := 0
var arena := Vector2.ZERO        # x range of the showdown arena
var dodge_cd := 0
var roped_t := 0                 # slippery showdown: frames he can be tackled after the lasso
var slip_say_cd := 0

@onready var visual := $Visual
var _was_floor := true
@onready var bubble := $Bubble


func setup(p: Player, l: Node) -> void:
	player = p
	level = l
	ai = l.data.get("earl_ai", {})


func say(text: String, frames := 120, line_id := "") -> void:
	bubble.show_text(Names.fmt(text), frames, line_id)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	timer = maxi(timer - 1, 0)
	dodge_cd = maxi(dodge_cd - 1, 0)
	roped_t = maxi(roped_t - 1, 0)
	slip_say_cd = maxi(slip_say_cd - 1, 0)
	throw_t = maxi(throw_t - 1, 0)
	if state in [State.WAIT, State.CLIMB, State.TOWER]:
		_scripted(delta)
		visual.facing = facing
		visual.play_anim(_anim())
		return
	match state:
		State.CHASE: _chase()
		State.TAUNT: _taunt()
		State.HIDE: _hide()
		State.IDLE: _idle()
		State.WINDUP: _windup()
		State.DODGE: _dodge()
		State.STUNNED: _stunned()
		State.CUFFED: velocity.x = move_toward(velocity.x, 0.0, 20.0)
		State.FALL: velocity.x = move_toward(velocity.x, 0.0, 2.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var fall_v := velocity.y
	move_and_slide()
	if is_on_floor() and not _was_floor and fall_v > 200.0:
		var k := clampf(fall_v / 900.0, 0.3, 1.0)
		visual.squash(Vector2(1.0 + 0.3 * k, 1.0 - 0.3 * k))
	if not is_on_floor() and _was_floor and velocity.y < -200.0:
		visual.squash(Vector2(0.8, 1.22))
	_was_floor = is_on_floor()
	if is_on_floor() and velocity.y >= 0.0:
		leap_vx = 0.0
		if state == State.DODGE:
			state = State.IDLE
			dodge_cd = 24
		elif state == State.FALL:
			_start_showdown(true)
			state = State.STUNNED
			timer = 70
	if global_position.y > player.kill_y:
		_recover_from_fall()
	visual.modulate.a = 0.55 if state == State.HIDE else 1.0
	visual.facing = facing
	visual.play_anim(_anim())


# --- chase ----------------------------------------------------------------------
func _chase() -> void:
	var d := global_position.x - player.global_position.x
	var sp := 60.0
	if d < 0.0:
		sp = 225.0            # Sheriff got past somehow: sprint to get ahead again
	elif d < 120.0:
		sp = 205.0
	elif d < 300.0:
		sp = 175.0
	elif d < 520.0:
		sp = 130.0
	facing = 1
	if player.power_t > 0.0 and d < 300.0:
		sp *= 1.45                               # a glowing Dewey / a mower bearing down: Earl runs scared
	if level.mud_at(global_position.x) == "deep" and global_position.y > level.GROUND_Y - 3.0:
		sp *= 0.5                                # slogging through the mud
	if level.truck_x > 0.0 and global_position.x >= level.truck_x:
		state = State.WAIT                       # hops in the milk truck (or mine cart)
		visible = false
		if level.text.has("vehicle"):
			say(level.text.vehicle, 100, level.data.id + "_vehicle")
		else:
			say(GameText.EARL_TRUCK, 100, "truck")
		return
	if level.tower:
		if global_position.x >= level.tower.ladder_x() - 4.0 and is_on_floor():
			state = State.CLIMB
			return
	elif global_position.x >= level.corner_x():
		_start_showdown(true)
		return
	if not is_on_floor():
		velocity.x = maxf(maxf(sp, AIR_MIN), leap_vx)
		return
	if throw_t > 0:
		velocity.x = 0.0          # planting his feet to throw
		facing = -1
		return
	velocity.x = sp
	var gap: Vector2 = level.gap_ahead(global_position.x)   # (distance to edge, width)
	if gap.x < 22.0:
		velocity.y = JUMP_V
		if ai.get("leaps", false):
			leap_vx = (gap.x + gap.y + 50.0) / AIR_TIME
	elif _wall_ahead() or (ai.get("shortcuts", false) and _awning_ahead()):
		velocity.y = JUMP_V
	# safety: if something blocks us for a second, hop
	stuck_t = stuck_t + 1 if absf(get_real_velocity().x) < 20.0 else 0
	if stuck_t > 60:
		velocity.y = JUMP_V
		stuck_t = 0
	taunt_cd = maxi(taunt_cd - 1, 0)
	hide_cd = maxi(hide_cd - 1, 0)
	throw_cd = maxi(throw_cd - 1, 0)
	if ai.get("throws", false) and throw_cd == 0 and d > 150.0 and d < 460.0:
		_throw(d)
	elif ai.get("hides", false) and hide_cd == 0 and d > 260.0 and level.crate_near(global_position.x, 20.0):
		state = State.HIDE
		timer = 360
		say(GameText.EARL_HIDES, 90, "hides")
	elif ai.get("taunts", false) and d > 420.0 and taunt_cd == 0:
		_begin_taunt()


func _throw(d: float) -> void:
	throw_t = 16
	throw_cd = 110 + randi() % 70
	# aim so the rock lands about where the Sheriff is now
	var t := 0.8
	var vx := -clampf(d / t, 120.0, 380.0)
	threw.emit(global_position + Vector2(-10, -38), Vector2(vx, -300.0))
	if randf() < 0.35:
		if level.data.get("eggs", false):
			var e := randi() % GameText.CR_EARL_EGGS.size()
			say(GameText.CR_EARL_EGGS[e], 70, "cr_egg_%d" % (e + 1))
		else:
			var k := randi() % GameText.EARL_THROWS.size()
			say(GameText.EARL_THROWS[k], 70, "throw_%d" % (k + 1))


func _begin_taunt() -> void:
	state = State.TAUNT
	timer = 80
	taunt_cd = 420 + randi() % 240
	# The general taunts, plus the episode's own (GameText.LEVELS.<id>.taunts).
	var lid := Game.level_id()
	var own: Array = GameText.LEVELS.get(lid, {}).get("taunts", [])
	var k := randi() % (GameText.EARL_TAUNTS.size() + own.size())
	if k < GameText.EARL_TAUNTS.size():
		say(GameText.EARL_TAUNTS[k], 90, "taunt_%d" % (k + 1))
	else:
		var j := k - GameText.EARL_TAUNTS.size()
		say(own[j], 90, "%s_taunt_%d" % [lid, j + 1])


func _taunt() -> void:
	# double back a few steps (if there's ground behind), then turn and jeer
	facing = -1
	velocity.x = -70.0 if timer > 55 and not _gap_at(-20.0) else move_toward(velocity.x, 0.0, 30.0)
	var d := global_position.x - player.global_position.x
	if timer == 0 or d < 150.0:
		state = State.CHASE


func _hide() -> void:
	velocity.x = 0.0
	facing = -1
	var d := global_position.x - player.global_position.x
	if d < 130.0 or timer == 0:
		say(GameText.EARL_PEEKABOO, 70, "peekaboo")
		state = State.CHASE
		hide_cd = 600


# --- milk truck and water tower (Main Street) --------------------------------------------
func _scripted(delta: float) -> void:
	match state:
		State.WAIT:
			velocity = Vector2.ZERO
		State.CLIMB:
			global_position.x = level.tower.ladder_x()
			global_position.y -= 75.0 * delta
			facing = 1
			if global_position.y <= level.tower.deck_y():
				global_position = Vector2(level.tower.global_position.x - 8.0, level.tower.deck_y())
				state = State.TOWER
				timer = 90
				if level.text.has("tower"):
					say(level.text.tower, 120, level.data.id + "_tower")
				else:
					say(GameText.EARL_TOWER, 120, "tower")
				level.on_earl_tower()
		State.TOWER:
			var dx := player.global_position.x - global_position.x
			facing = 1 if dx > 0.0 else -1
			if timer == 0:
				timer = 100 + randi() % 40
				throw_t = 16
				# lob a bucket so it lands about where the Sheriff stands
				var t := 1.0
				var from := global_position + Vector2(facing * 8, -30)
				var to := player.global_position + Vector2(0, -20)
				var vel := Vector2((to.x - from.x) / t, (to.y - from.y - 0.5 * 900.0 * t * t) / t)
				threw.emit(from, vel)


## Back on foot after the car chase.
func after_chase(at: Vector2) -> void:
	level.truck_x = -1.0
	global_position = at
	velocity = Vector2.ZERO
	visible = true
	state = State.CHASE
	pass  # (4.3 physics interpolation not in 4.1)
## Rock Creek: hit by the Sheriff's rocks while up on the rock pillar.
## Three hits and he tumbles off, dazed: one tackle then cuffs him.
var pillar_hits := 0


func pillar_hit() -> bool:
	if state != State.TOWER:
		return false
	pillar_hits += 1
	if pillar_hits >= 3:
		state = State.FALL
		velocity = Vector2(-110.0, -220.0)
		tackles = TACKLES_NEEDED - 1
		say(GameText.RC_EARL_KNOCKED, 100, "rc_knocked")
	else:
		var k := mini(pillar_hits - 1, GameText.RC_EARL_HIT.size() - 1)
		say(GameText.RC_EARL_HIT[k], 60, "rc_hit_%d" % (k + 1))
		timer = maxi(timer, 40)
	return true


## The fire hose knocks him off the water tower.
func hosed() -> void:
	if state != State.TOWER:
		return
	state = State.FALL
	velocity = Vector2(95.0, -200.0)
	say(GameText.EARL_HOSED, 100, "hosed")


# --- showdown -----------------------------------------------------------------------
func _start_showdown(at_fence: bool) -> void:
	var seg: Array = level.ground_segment_at(global_position.x)
	var left: float = maxf(seg[0] + 24.0, global_position.x - 240.0)
	var right: float = minf(minf(seg[1], level.fence_px()) - 24.0, global_position.x + 240.0)
	arena = Vector2(left, maxf(right, left + 64.0))
	global_position.x = clampf(global_position.x, arena.x, arena.y)
	state = State.IDLE
	dodge_cd = 40
	velocity.x = 0.0
	if at_fence:
		say(GameText.EARL_CORNERED, 120, "cornered")
	else:
		say(GameText.EARL_CAUGHT_EARLY, 120, "caught_early")
	cornered.emit()


## Called by the level when the Sheriff touches Earl.
func on_contact() -> void:
	match state:
		State.CHASE, State.TAUNT, State.HIDE:
			if is_on_floor():
				_start_showdown(false)
		State.STUNNED:
			if pillar_hits >= 3 and tackles < TACKLES_NEEDED:
				_take_tackle()              # knocked off the rock pillar: nab him
		State.IDLE, State.WINDUP:
			if ai.get("slippery", false) and roped_t == 0:
				_slip_away()
			else:
				_take_tackle()


## Caught by the Sheriff's lasso. Returns true if it had an effect.
func lassoed() -> bool:
	match state:
		State.CHASE, State.TAUNT, State.HIDE:
			if not is_on_floor():
				return false
			state = State.STUNNED
			timer = 75
			velocity.x = 0.0
			say(GameText.EARL_LASSOED, 70, "lassoed")
			return true
		State.IDLE, State.WINDUP:
			# roped in a showdown: he can't dodge for a moment
			state = State.IDLE
			dodge_cd = 150
			roped_t = 150
			velocity.x = 0.0
			say(GameText.EARL_LASSOED, 70, "lassoed")
			return true
	return false


## Hit by one of the Sheriff's rocks.
func bonk() -> bool:
	if state in [State.CHASE, State.TAUNT, State.HIDE]:
		state = State.STUNNED
		timer = 100
		velocity.x = 0.0
		say(GameText.EARL_BONKED, 80, "bonked")
		return true
	return false


## Slippery showdown (pig pen): a tackle without roping him first just squirts him away.
func _slip_away() -> void:
	if slip_say_cd == 0:
		slip_say_cd = 150
		say(GameText.CR_EARL_SLIPPERY, 80, "slippery")
		level.popup(global_position + Vector2(0, -64), GameText.CR_ROPE_FIRST, Color("ffd23f"))
	_do_dodge()
	velocity.x *= 1.3


func _take_tackle() -> void:
	roped_t = 0
	tackles += 1
	visual.squash(Vector2(1.45, 0.62))
	tackled.emit(tackles)
	if tackles >= TACKLES_NEEDED:
		state = State.CUFFED
		velocity = Vector2(0, -150)
		say(GameText.EARL_CUFFED, 200, "cuffed")
		cuffed.emit()
		return
	state = State.STUNNED
	timer = 45
	var away := signf(global_position.x - player.global_position.x)
	if away == 0.0:
		away = 1.0
	velocity = Vector2(away * 160.0, -220.0)
	var t := mini(tackles - 1, GameText.EARL_TACKLED.size() - 1)
	say(GameText.EARL_TACKLED[t], 60, "tackled_%d" % (t + 1))


func _idle() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 25.0)
	var dx := player.global_position.x - global_position.x
	facing = 1 if dx > 0.0 else -1
	if absf(dx) < 72.0 and dodge_cd == 0 and is_on_floor():
		state = State.WINDUP
		timer = [16, 12, 10][mini(tackles, 2)]   # quicker after each tackle


func _windup() -> void:
	velocity.x = 0.0
	if timer == 0:
		_do_dodge()


func _do_dodge() -> void:
	var dx := player.global_position.x - global_position.x
	var away := -1.0 if dx > 0.0 else 1.0
	var room_away := (global_position.x - arena.x) if away < 0.0 else (arena.y - global_position.x)
	state = State.DODGE
	if room_away > 90.0:
		velocity = Vector2(away * 210.0, -380.0)          # hop away
	else:
		velocity = Vector2(-away * 230.0, JUMP_V)          # leap over the Sheriff


func _dodge() -> void:
	# never leave the arena
	if (global_position.x < arena.x and velocity.x < 0.0) or (global_position.x > arena.y and velocity.x > 0.0):
		velocity.x = 0.0


func _stunned() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 8.0)
	if timer == 0 and is_on_floor():
		if tackles > 0 or level.phase == level.Phase.SHOWDOWN:
			state = State.IDLE
			dodge_cd = 20
		else:
			state = State.CHASE


func in_showdown() -> bool:
	return state >= State.IDLE


func can_be_tackled() -> bool:
	return state == State.IDLE or state == State.WINDUP


# --- sensing ------------------------------------------------------------------------
func _gap_at(dx: float) -> bool:
	var from := global_position + Vector2(dx, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 14), 3)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_ahead() -> bool:
	var from := global_position + Vector2(0, -12)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(26.0 * facing, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _awning_ahead() -> bool:
	return level.platform_starting_near(global_position.x + 48.0, 16.0)


func _recover_from_fall() -> void:
	var x: float = level.next_ground_x(global_position.x)
	global_position = Vector2(x, level.GROUND_Y)
	velocity = Vector2.ZERO
	leap_vx = 0.0
	pass  # (4.3 physics interpolation not in 4.1)
func body_rect() -> Rect2:
	return Rect2(global_position.x - 8.0, global_position.y - 44.0, 16.0, 44.0)


func _anim() -> String:
	if throw_t > 0:
		return "throw"
	if roped_t > 0 and state == State.IDLE:
		return "stunned"                 # tied up in the lasso
	match state:
		State.WAIT:
			return "taunt"
		State.CLIMB:
			return "climb"
		State.TOWER:
			return "taunt"
		State.FALL:
			return "hurt"
		State.TAUNT:
			return "run" if absf(velocity.x) > 10.0 else "taunt"
		State.HIDE, State.WINDUP:
			return "land"
		State.IDLE:
			return "idle"
		State.STUNNED:
			return "stunned"
		State.CUFFED:
			return "cuffed"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	return "run" if absf(velocity.x) > 10.0 else "idle"
