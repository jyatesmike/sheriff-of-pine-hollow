# The Sheriff. Tight platformer movement:
#  - reaches top speed in 6 frames, snappy turn-around
#  - coyote time (6 frames) and jump buffer (8 frames)
#  - variable jump height (release to cut the jump short)
#  - lower gravity near the top of the arc while jump is held
#  - dash/slide on "action": low hitbox slips under laundry lines and fences,
#    and never leaves you stuck: it keeps sliding until there's headroom.
# All numbers are in pixels and seconds (physics runs at 60 Hz).
class_name Player
extends CharacterBody2D

signal jumped
signal landed(impact_speed: float)
signal fell_out
signal hurt_taken
signal died
signal combo_ended(count: int)
signal throw_pressed

# --- tuning -----------------------------------------------------------------
const MAX_SPEED := 180.0
const ACCEL := MAX_SPEED / (6.0 / 60.0)    # 0 -> top speed in 6 frames
const TURN_ACCEL := ACCEL * 2.0            # quick turn-around
const GROUND_FRICTION := 2000.0
const AIR_ACCEL := ACCEL * 0.75
const AIR_DRAG := 450.0

const JUMP_VELOCITY := -560.0              # ~106 px (6.5 tiles) at full height
const GRAVITY_UP := 1500.0
const GRAVITY_APEX := 800.0                # softer "hang" at the top of the arc
const APEX_RANGE := 70.0                   # |vy| below this counts as the apex
const GRAVITY_FALL := 1900.0
const MAX_FALL := 560.0
const JUMP_CUT := 0.45                     # vy multiplier when jump is released early

const COYOTE_FRAMES := 6
const BUFFER_FRAMES := 8

const DASH_SPEED := 330.0
const DASH_FRAMES := 16
const DASH_COOLDOWN := 18
const SLIDE_MIN_SPEED := 110.0             # crawl speed while stuck under something

const MAX_HEARTS := 5
const INVULN_FRAMES := 90
const HURT_FRAMES := 18                    # no control while knocked back
const BOUNCE_LOW := -400.0                 # stomp bounce; hold jump for full JUMP_VELOCITY

const LAYER_SOLID := 1                     # physics layer 1: solid ground/crates
const LAYER_SHEETS := 64                   # hanging laundry: slide under it
# layer 2 = one-way platforms (awnings); the player collides with both.

# --- state --------------------------------------------------------------------
var facing := 1
var input_enabled := true
var coyote := 0
var jump_buffer := 0
var jumping := false        # rising from a jump we started (for variable height)
var sliding := false
var dash_t := 0
var dash_cd := 0
var was_on_floor := true
var air_frames := 0
var last_safe := Vector2.ZERO
var kill_y := 1000.0
var anim := "idle"          # idle, run, skid, jump, fall, land, slide (read by Visual)
var land_t := 0
var hearts := 3
var invuln := 0
var hurt_t := 0
var combo := 0              # stomps chained without touching the ground
var won := false
var idle_t := 0             # frames standing still (for the tip-hat taunt)
var throw_t := 0            # frames left in the throw animation
var rocks := 0              # rocks carried (Rock Creek)
var can_throw := false
var stand_h := 50.0         # standing hitbox height (Earl is shorter)
var lasso: Lasso = null     # set by the level on Sheriff levels
var ride: Object = null     # ladder / zip line currently in control (has ride_step)
var power := ""             # "soda" (Dewey's Lightning Soda) / "mower" (Jim's zero-turn), while it lasts
var power_t := 0.0          # seconds left
const POWER_SECS := 8.0
var _mower_front: Mower
var _mower_back: Mower
var speed_scale := 1.0      # set by the level each frame: mud slows you (Chicken Run)
var jump_scale := 1.0
var traction := 1.0         # below 1 = slippery

@onready var stand_shape: CollisionShape2D = $StandShape
@onready var slide_shape: CollisionShape2D = $SlideShape
@onready var visual: Node2D = $Visual


func _ready() -> void:
	last_safe = global_position


func _physics_process(delta: float) -> void:
	var dir := _input_dir()
	var on_floor := is_on_floor()
	invuln = maxi(invuln - 1, 0)
	_power_step(delta)
	if hurt_t > 0:
		hurt_t -= 1
		dir = 0.0

	# --- timers ---
	if on_floor:
		coyote = COYOTE_FRAMES
		if velocity.y >= 0.0:
			jumping = false
	else:
		coyote = maxi(coyote - 1, 0)
	if input_enabled and Input.is_action_just_pressed("jump"):
		jump_buffer = BUFFER_FRAMES
	else:
		jump_buffer = maxi(jump_buffer - 1, 0)
	dash_cd = maxi(dash_cd - 1, 0)

	# --- ladders and zip lines take over movement while you're on them ---
	if ride != null:
		if not ride.ride_step(self, delta):
			ride = null
			was_on_floor = false
			coyote = 0
		visual.facing = facing
		visual.play_anim(anim)
		visual.visible = invuln % 8 < 5
		return

	# --- lasso: swinging replaces normal movement ---
	if lasso and lasso.swinging():
		if Input.is_action_just_pressed("jump") and input_enabled:
			lasso.release(true)
			jump_buffer = 0
			jumping = false
		elif Input.is_action_just_pressed("lasso"):
			lasso.drop()
		else:
			lasso.swing_step(delta, dir)
			anim = "jump" if velocity.y < 0.0 else "fall"
			visual.facing = facing
			visual.play_anim(anim)
			visual.visible = invuln % 8 < 5
			was_on_floor = false
			air_frames += 1
			if global_position.y > kill_y:
				lasso.drop()
				fell_out.emit()
			return
	if lasso and input_enabled and hurt_t == 0 and not sliding and Input.is_action_just_pressed("lasso"):
		lasso.fire()

	throw_t = maxi(throw_t - 1, 0)
	if can_throw and input_enabled and hurt_t == 0 and not sliding and Input.is_action_just_pressed("throw"):
		throw_pressed.emit()

	# --- horizontal ---
	if hurt_t == 0 and input_enabled and Input.is_action_just_pressed("action") and on_floor and not sliding and dash_cd == 0:
		_start_slide()
	if sliding:
		_update_slide(on_floor)
	else:
		_run(dir, on_floor, delta)

	# --- jump ---
	if jump_buffer > 0 and coyote > 0 and hurt_t == 0 and (not sliding or _can_stand()):
		if sliding:
			_end_slide()
		velocity.y = JUMP_VELOCITY * jump_scale
		jumping = true
		jump_buffer = 0
		coyote = 0
		visual.squash(Vector2(0.8, 1.2))
		jumped.emit()
	if jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= JUMP_CUT
		jumping = false

	# --- gravity ---
	velocity.y = minf(velocity.y + _gravity() * delta, MAX_FALL)

	var impact := velocity.y
	move_and_slide()

	# --- after moving ---
	on_floor = is_on_floor()
	if on_floor and not was_on_floor and air_frames > 4:
		land_t = 6
		var k := clampf(impact / MAX_FALL, 0.3, 1.0)
		visual.squash(Vector2(1.0 + 0.3 * k, 1.0 - 0.3 * k))
		landed.emit(impact)
	if on_floor and combo > 0 and velocity.y >= 0.0:
		if combo > 1:
			combo_ended.emit(combo)
		combo = 0
	air_frames = 0 if on_floor else air_frames + 1
	was_on_floor = on_floor
	land_t = maxi(land_t - 1, 0)
	if on_floor and not sliding:
		_record_safe_spot()
	if global_position.y > kill_y:
		fell_out.emit()
	_pick_anim(dir, on_floor)
	visual.facing = facing
	if power == "mower" and anim in ["run", "skid", "land", "slide"]:
		anim = "idle"                     # sitting on the mower
	visual.play_anim(anim)
	visual.visible = invuln % 8 < 5      # flicker while invulnerable


func _input_dir() -> float:
	if not input_enabled or won:
		return 0.0
	var d := Input.get_axis("left", "right")
	return 0.0 if absf(d) < 0.3 else signf(d)   # digital feel, even on a stick


func _run(dir: float, on_floor: bool, delta: float) -> void:
	var accel: float
	if dir != 0.0:
		facing = int(dir)
		var turning := velocity.x != 0.0 and signf(velocity.x) != dir
		if on_floor:
			accel = TURN_ACCEL if turning else ACCEL
		else:
			accel = AIR_ACCEL * (1.5 if turning else 1.0)
	else:
		accel = GROUND_FRICTION if on_floor else AIR_DRAG
	var boost := 1.3 if power == "soda" else (1.4 if power == "mower" else 1.0)
	if power == "mower" and dir != 0.0 and on_floor:
		velocity.x = dir * MAX_SPEED * speed_scale * boost     # a zero-turn: no wind-up, no skid
		return
	velocity.x = move_toward(velocity.x, dir * MAX_SPEED * speed_scale * boost, accel * traction * delta)


func _gravity() -> float:
	var held := Input.is_action_pressed("jump")
	if absf(velocity.y) < APEX_RANGE and held and (jumping or velocity.y >= 0.0) and not is_on_floor():
		return GRAVITY_APEX
	return GRAVITY_UP if velocity.y < 0.0 else GRAVITY_FALL


# --- dash / slide ---------------------------------------------------------------
func _start_slide() -> void:
	sliding = true
	dash_t = DASH_FRAMES
	velocity.x = facing * DASH_SPEED
	stand_shape.disabled = true
	slide_shape.disabled = false
	visual.squash(Vector2(1.2, 0.85))
	Audio.sfx("dash")


func _update_slide(on_floor: bool) -> void:
	dash_t -= 1
	if dash_t > 0:
		# ease from full dash speed down to ~60%
		var t := 1.0 - float(dash_t) / DASH_FRAMES
		velocity.x = facing * DASH_SPEED * lerpf(1.0, 0.6, t)
	elif _can_stand():
		_end_slide()
	else:
		# Something low overhead: keep scooting so we can never get stuck.
		if is_on_wall():
			facing = -facing
		velocity.x = facing * maxf(SLIDE_MIN_SPEED, absf(velocity.x))
	if not on_floor and dash_t <= 0 and _can_stand():
		_end_slide()


func _end_slide() -> void:
	sliding = false
	dash_cd = DASH_COOLDOWN
	stand_shape.disabled = false
	slide_shape.disabled = true


## True if the standing hitbox would fit here (ignores one-way platforms).
func _can_stand() -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = stand_shape.shape
	q.transform = Transform2D(0.0, global_position + stand_shape.position + Vector2(0, -1))
	q.collision_mask = LAYER_SOLID | LAYER_SHEETS
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


# --- combat ---------------------------------------------------------------------
## Called when we land on a hen/goose. Hold jump for a higher bounce.
func bounce() -> void:
	var held := Input.is_action_pressed("jump") and input_enabled
	velocity.y = JUMP_VELOCITY if held else BOUNCE_LOW
	jumping = held
	coyote = 0
	combo += 1
	visual.squash(Vector2(0.85, 1.15))


## Lose a heart. Returns false if we're still flashing from the last hit.
func hurt(from_x: float) -> bool:
	if invuln > 0 or won or hearts <= 0 or power_t > 0.0:
		return false
	hearts -= 1
	if ride == null or not ride.get("keep_rider"):
		ride = null                 # a hit knocks you off ladders and zip lines, not out of the mine cart
	if lasso:
		lasso.drop()
	invuln = INVULN_FRAMES
	hurt_t = HURT_FRAMES
	combo = 0
	if sliding:
		_end_slide()
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 190.0, -300.0)
	visual.squash(Vector2(1.3, 0.75))
	jumping = false
	hurt_taken.emit()
	if hearts <= 0:
		input_enabled = false
		died.emit()
	return true


## A ladder or zip line takes control (it must have ride_step(player, delta) -> bool).
func start_ride(obj: Object) -> void:
	if sliding:
		_end_slide()
	if lasso:
		lasso.drop()
	ride = obj
	velocity = Vector2.ZERO
	jumping = false


## The lasso caught a hook: stop sliding, keep any combo going.
func on_swing_start() -> void:
	if sliding:
		_end_slide()
	jumping = false
	coyote = 0


## Play as someone else (Earl on the night level): new sprites, shorter hitbox.
func set_character(sheet: String) -> void:
	visual.set_sheet(sheet)
	$Bubble.voice = sheet
	if sheet == "earl":
		stand_h = 44.0
		stand_shape.shape = stand_shape.shape.duplicate()     # don't change the shared resource
		(stand_shape.shape as RectangleShape2D).size = Vector2(16, 44)
		stand_shape.position = Vector2(0, -22)


## Dewey's Lightning Soda / Jim's mower: 8 seconds of can't-be-hurt.
func start_power(kind: String) -> void:
	power = kind
	power_t = POWER_SECS
	invuln = 0
	if kind == "mower":
		if _mower_front == null:
			_mower_back = Mower.new()
			_mower_back.front = false
			_mower_back.z_index = -1
			add_child(_mower_back)
			_mower_front = Mower.new()
			_mower_front.z_index = 1
			add_child(_mower_front)
		_mower_front.visible = true
		_mower_back.visible = true


func _power_step(delta: float) -> void:
	if power == "":
		return
	power_t -= delta
	var ending := power_t < 1.5 and int(power_t * 10.0) % 2 == 0      # blink: about to run out
	if power == "soda":
		# rainbow fizz
		var c := Color.from_hsv(fmod(power_t * 2.5, 1.0), 0.55, 1.0)
		visual.modulate = Color.WHITE if ending else c.lightened(0.25)
	elif power == "mower":
		_mower_front.facing = facing
		_mower_back.facing = facing
		_mower_front.modulate.a = 0.4 if ending else 1.0
		Audio.loop("engine", power_t > 0.0, 1.4 + absf(velocity.x) / 600.0, 0.5)
	if power_t <= 0.0:
		if power == "mower":
			_mower_front.visible = false
			_mower_back.visible = false
			Audio.loop("engine", false)
		power = ""
		power_t = 0.0
		visual.modulate = Color.WHITE
		invuln = 40           # a moment's grace as it wears off


func heal() -> void:
	hearts = mini(hearts + 1, MAX_HEARTS)


## Body rectangle in world space (feet at global_position).
func body_rect() -> Rect2:
	var h := 22.0 if sliding else stand_h
	return Rect2(global_position.x - 8.0, global_position.y - h, 16.0, h)


# --- respawn helpers ------------------------------------------------------------
func _record_safe_spot() -> void:
	# Only remember spots with solid ground under both feet.
	# Only solid ground counts (not awnings or drifting logs).
	var space := get_world_2d().direct_space_state
	for dx in [-10.0, 10.0]:
		var from := global_position + Vector2(dx, -2)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), LAYER_SOLID)
		q.exclude = [get_rid()]
		if space.intersect_ray(q).is_empty():
			return
	last_safe = global_position


func respawn() -> void:
	if sliding:
		_end_slide()
	global_position = last_safe + Vector2(0, -2)
	velocity = Vector2.ZERO
	jumping = false
	pass  # (4.3 physics interpolation not in 4.1)
func _pick_anim(dir: float, on_floor: bool) -> void:
	if won:
		anim = "victory"
	elif hurt_t > 0:
		anim = "hurt"
	elif throw_t > 0:
		anim = "throw"
	elif sliding:
		anim = "slide"
	elif not on_floor:
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif land_t > 0:
		anim = "land"
	elif dir != 0.0 and velocity.x != 0.0 and signf(velocity.x) != dir and absf(velocity.x) > 60.0:
		anim = "skid"
	elif absf(velocity.x) > 10.0:
		anim = "run"
	else:
		anim = "idle"
	# stand still for 3 seconds and the Sheriff tips his hat
	idle_t = idle_t + 1 if anim == "idle" else 0
	if idle_t > 180 and idle_t < 250:
		anim = "tiphat"
	elif idle_t >= 600:
		idle_t = 0
