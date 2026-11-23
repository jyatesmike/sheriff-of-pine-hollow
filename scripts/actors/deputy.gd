# Deputy Purvis Plum chases Earl (the player) on the night level.
#  RUN    - runs after you, hopping gaps and crates; faster in lamplight
#  AIM    - stops and aims his one-cork popgun (a clear wind-up: jump!)
#  FUMBLE - after the shot he pats his pockets looking for the cork
#  BONKED - you jumped on his cap: he's dazed for a moment
# Touching him costs a heart. Lamplight makes him spot you faster.
class_name Deputy
extends CharacterBody2D

signal fired(at: Vector2, dir: float)

enum State { RUN, AIM, FUMBLE, BONKED }

const GRAVITY := 1600.0
const JUMP_V := -560.0
const AIR_MIN := 190.0
const AIM_FRAMES := 42
const FUMBLE_FRAMES := 80

var player: Player
var level: Node
var state := State.RUN
var facing := 1
var timer := 0
var cooldown := 150
var lit := false
var spotted_said := false
var stuck_t := 0
var active := true           # false = not on the scene yet (released by the level's finale)

@onready var visual := $Visual
@onready var bubble := $Bubble


func setup(p: Player, l: Node) -> void:
	player = p
	level = l


func say(text: String, frames := 100, line_id := "") -> void:
	bubble.show_text(Names.fmt(text), frames, line_id)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	visible = active
	if not active:
		return
	timer = maxi(timer - 1, 0)
	cooldown = maxi(cooldown - 1, 0)
	lit = level.is_lit(player.global_position.x)
	if lit and not spotted_said and state == State.RUN:
		spotted_said = true
		say(GameText.DEPUTY_SPOTTED, 80, "spotted")
	var d := player.global_position.x - global_position.x
	match state:
		State.RUN:
			facing = 1 if d >= 0.0 else -1
			var sp := 150.0
			if absf(d) > 240.0:
				sp = 205.0        # never fall too far behind
			elif lit:
				sp = 172.0
			if is_on_floor():
				velocity.x = facing * sp
				var g: Vector2 = level.gap_ahead(global_position.x) if facing > 0 else Vector2(INF, 0)
				if g.y > 150.0 and g.x < 30.0:
					velocity.x = 0.0                 # too wide to jump (the ravine): stop at the edge
					if not spotted_said or timer == 0:
						timer = 200
						say(GameText.NB_DEPUTY_RAVINE, 120, "nb_ravine")
				elif _gap_ahead() or _wall_ahead():
					velocity.y = JUMP_V
				stuck_t = stuck_t + 1 if absf(get_real_velocity().x) < 20.0 else 0
				if stuck_t > 50:
					velocity.y = JUMP_V
					stuck_t = 0
				var aim_range := absf(d) > 70.0 and absf(d) < 300.0
				if aim_range and cooldown == 0 and not level.finished:
					state = State.AIM
					timer = AIM_FRAMES
					velocity.x = 0.0
					var k := randi() % GameText.DEPUTY_AIM.size()
					say(GameText.DEPUTY_AIM[k], 60, "aim_%d" % (k + 1))
			else:
				velocity.x = facing * maxf(sp, AIR_MIN)
		State.AIM:
			velocity.x = 0.0
			facing = 1 if d >= 0.0 else -1
			if timer == 0:
				fired.emit(global_position + Vector2(facing * 16, -30), facing)
				state = State.FUMBLE
				timer = FUMBLE_FRAMES
				cooldown = 110 if lit else 190
		State.FUMBLE:
			velocity.x = 0.0
			if timer == FUMBLE_FRAMES - 30:
				say(GameText.DEPUTY_FUMBLE, 70, "fumble")
			if timer == 0:
				state = State.RUN
		State.BONKED:
			velocity.x = move_toward(velocity.x, 0.0, 10.0)
			if timer == 0:
				state = State.RUN
	velocity.y = minf(velocity.y + GRAVITY * delta, 560.0)
	move_and_slide()
	if global_position.y > player.kill_y:
		# fell in: climb out ahead, unless it was the ravine (then he's stuck on the near side)
		var back := -1.0
		for i in level.data.ground.size() - 1:
			var a: float = level.data.ground[i][1] * level.TILE
			var b: float = level.data.ground[i + 1][0] * level.TILE
			if global_position.x > a - 20.0 and global_position.x < b and b - a > 150.0:
				back = a - 24.0
		var to: float = back if back > 0.0 else level.next_ground_x(global_position.x)
		global_position = Vector2(to, level.GROUND_Y)
		velocity = Vector2.ZERO
		pass  # (4.3 physics interpolation not in 4.1)
	visual.facing = facing
	visual.play_anim(_anim())


func bonk() -> void:
	state = State.BONKED
	timer = 50
	cooldown = maxi(cooldown, 60)
	say(GameText.DEPUTY_BONKED, 60, "bonked")


func _anim() -> String:
	match state:
		State.AIM:
			return "aim"
		State.FUMBLE:
			return "fumble"
		State.BONKED:
			return "stunned"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	return "run" if absf(velocity.x) > 10.0 else "idle"


func _gap_ahead() -> bool:
	var from := global_position + Vector2(22.0 * facing, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 14), 3)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_ahead() -> bool:
	var from := global_position + Vector2(0, -12)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(26.0 * facing, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func body_rect() -> Rect2:
	return Rect2(global_position.x - 8.0, global_position.y - 50.0, 16.0, 50.0)
