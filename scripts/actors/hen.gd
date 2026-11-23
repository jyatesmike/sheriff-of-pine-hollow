# Hens, geese, ducks and flapping hens.
#  - bowled over by a powered-up Dewey or Jim: they tumble, land dazed for a
#    moment and get back up (herd hens flutter straight home to the coop)
#  - walkers patrol between two x positions, stop to peck, turn at ledges
#  - flappers hover in place over gaps: harmless bounce pads that never
#    leave, so the high pie above them can always be reached again
#  - herd hens (Chicken Run) run away from the Sheriff; push them into the coop.
#    They never hurt and can't be stomped. Cornered, they flutter over you.
#  - stomp from above = bounce (hold jump to go higher) and a combo
#  - touching one from the side hurts; a dash/slide knocks it aside
class_name Hen
extends CharacterBody2D

enum Kind { HEN, GOOSE, FLAP, HERD, DUCK }

const GRAVITY := 1400.0
const STOMP_WINDOW := 14.0     # px: how far the Sheriff's feet may be below our top

var kind := Kind.HEN
var patrol := Vector2.ZERO     # x range
var base_y := 0.0
var phase := 0.0
var dir := -1
var peck_t := 0
var tumbling := false
var squish_t := 0
var spin := 0.0
var _t := 0.0
var home := false            # herd hen safely in the coop
var coop_x := 0.0            # herd hens: reaching this x = home
var flutter := false
var herder: Player           # herd hens: who they run from
var bowled := false          # knocked flying by a power-up
var fly_home := false
var dazed := 0
var _layer := 0
var _mask := 0


func setup(k: int, x_range: Vector2, y: float, ph := 0.0) -> void:
	kind = k
	patrol = x_range
	base_y = y
	phase = ph
	$Sprite.set_sheet("goose" if kind == Kind.GOOSE else ("duck" if kind == Kind.DUCK else "hen"))
	global_position = Vector2((x_range.x + x_range.y) * 0.5, y)


func _physics_process(delta: float) -> void:
	_t += delta
	if bowled:
		_bowled_step(delta)
		return
	if dazed > 0:
		dazed -= 1
		velocity.x = 0.0
		velocity.y = minf(velocity.y + GRAVITY * delta, 500.0)
		move_and_slide()
		return
	if tumbling:
		velocity.y += GRAVITY * delta
		spin += 0.3
		global_position += velocity * delta
		if global_position.y > base_y + 400.0:
			queue_free()
		return
	if kind == Kind.FLAP:
		squish_t = maxi(squish_t - 1, 0)
		global_position = Vector2(
			lerpf(patrol.x, patrol.y, 0.5 + 0.5 * sin(_t * 0.9 + phase)),
			base_y + sin(_t * 3.0 + phase) * 12.0)
		dir = 1 if cos(_t * 0.9 + phase) > 0.0 else -1
		return
	if kind == Kind.HERD:
		_herd(delta)
		return
	if peck_t > 0:
		peck_t -= 1
		velocity.x = 0.0
	else:
		velocity.x = dir * (40.0 if kind == Kind.GOOSE else (34.0 if kind == Kind.DUCK else 30.0))
		if randf() < 0.004:
			peck_t = 40
	velocity.y = minf(velocity.y + GRAVITY * delta, 500.0)
	move_and_slide()
	var x := global_position.x
	if (x < patrol.x and dir < 0) or (x > patrol.y and dir > 0) or is_on_wall() or _ledge_ahead():
		dir = -dir


## Herd hen: scurry away from the Sheriff; trapped against the fence, flap over his head.
func _herd(delta: float) -> void:
	var p: Player = herder
	var dx := global_position.x - p.global_position.x
	var near := absf(dx) < 70.0 and absf(p.global_position.y - global_position.y) < 60.0
	if is_on_floor():
		flutter = false
	if flutter:
		pass
	elif near:
		dir = 1 if dx >= 0.0 else -1
		velocity.x = dir * 135.0
		peck_t = 0
		if is_on_floor() and dir < 0 and global_position.x < patrol.x + 14.0 and absf(dx) < 34.0:
			# backed into the fence: flutter over the Sheriff
			flutter = true
			velocity = Vector2(170.0, -430.0)
			dir = 1
	elif peck_t > 0:
		peck_t -= 1
		velocity.x = 0.0
	else:
		velocity.x = dir * 25.0
		if randf() < 0.01:
			peck_t = 50
		if randf() < 0.008:
			dir = -dir
	velocity.y = minf(velocity.y + GRAVITY * (0.45 if flutter and velocity.y > 0.0 else 1.0) * delta, 500.0)
	move_and_slide()
	var x := global_position.x
	if x < patrol.x:
		global_position.x = patrol.x
		dir = 1
	if x > coop_x:
		home = true
		visible = false
		collision_layer = 0
		set_physics_process(false)


func _ledge_ahead() -> bool:
	if not is_on_floor():
		return false
	var from := global_position + Vector2(10.0 * dir, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 10), 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Returns "stomp", "knock", "hurt" or "" for this frame's contact with the Sheriff.
func check_player(p: Player) -> String:
	if tumbling or bowled or not body_rect().intersects(p.body_rect()):
		return ""
	if p.power_t > 0.0 and kind != Kind.FLAP:
		return "bowl"
	if dazed > 0:
		return ""
	var from_above := p.velocity.y > 0.0 and p.global_position.y - body_rect().position.y < STOMP_WINDOW
	if kind == Kind.HERD:
		return ""
	if kind == Kind.FLAP:
		if from_above:
			squish_t = 10
			return "bounce"
		return ""
	if p.sliding:
		knock(p.facing)
		return "knock"
	if from_above:
		knock(p.facing)
		return "stomp"
	return "hurt"


## Bowled over by a powered-up player. Returns false if it can't be (flappers,
## already flying).
func bowl(toward: int) -> bool:
	if kind == Kind.FLAP or bowled or tumbling or home:
		return false
	bowled = true
	_layer = collision_layer
	_mask = collision_mask
	collision_layer = 0
	if kind == Kind.HERD and coop_x > 0.0:
		fly_home = true
		velocity = Vector2(signf(coop_x - global_position.x) * 230.0, -260.0)
	else:
		velocity = Vector2(toward * 170.0, -380.0)
	return true


func _bowled_step(delta: float) -> void:
	spin += 0.35
	if fly_home:
		# flap off over everything, straight back to the coop
		velocity.y = move_toward(velocity.y, sin(_t * 9.0) * 40.0, 600.0 * delta)
		global_position += velocity * delta
		global_position.y = minf(global_position.y, base_y - 30.0)
		if global_position.x >= coop_x:
			home = true
			visible = false
			bowled = false
			set_physics_process(false)
		return
	velocity.y += GRAVITY * 0.7 * delta
	global_position += velocity * delta
	if velocity.y > 0.0 and global_position.y >= base_y:
		global_position.y = base_y
		bowled = false
		spin = 0.0
		dazed = 70
		collision_layer = _layer
		collision_mask = _mask
		velocity = Vector2.ZERO


func knock(toward: int) -> void:
	tumbling = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2(toward * 140.0, -360.0)


func body_rect() -> Rect2:
	return Rect2(global_position.x - 9.0, global_position.y - 16.0, 18.0, 16.0)


func _process(_delta: float) -> void:
	var spr := $Sprite
	spr.facing = dir
	if tumbling or bowled:
		spr.play_anim("tumble" if not fly_home else "flap")
	elif dazed > 0:
		spr.play_anim("peck")
	elif kind == Kind.FLAP or flutter:
		spr.play_anim("flap")
	elif peck_t > 0:
		spr.play_anim("peck")
	else:
		spr.play_anim("walk")
	spr.rotation = spin if (tumbling or (bowled and not fly_home)) else 0.0
	queue_redraw()
	if squish_t > 0:
		spr.squash(Vector2(1.3, 0.7))


func _draw() -> void:
	if dazed > 0:
		# little stars circling a dazed bird
		for k in 3:
			var a := _t * 6.0 + k * TAU / 3.0
			draw_rect(Rect2(Vector2(cos(a) * 7.0 - 1, -24 + sin(a) * 2.0), Vector2(2, 2)), Color("ffd23f"))
