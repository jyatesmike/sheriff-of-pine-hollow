# Side-scroller camera:
#  - horizontal look-ahead in the direction you face (grows with speed)
#  - exponential smoothing, separate rates for x and y
#  - "platform snap" vertically: only re-centres on the ground you land on,
#    so small hops don't bob the screen; follows when you fall or climb high
#  - screen shake (respects the Screen Shake setting)
#  - punch(): a short zoom-in on a point (showdowns, the final tackle)
#  - intro(): opens on Earl, then glides back to the Sheriff
extends Camera2D

const LOOK_AHEAD := 64.0
const LOOK_RATE := 2.5
const X_RATE := 9.0
const Y_RATE := 5.0
const FOCUS_ABOVE_FEET := 52.0
const FALL_MARGIN := 24.0
const RISE_MARGIN := 80.0

var target: Player
var world_width := 4000.0
var _look := 0.0
var _focus_y := 0.0
var _shake := 0.0
var _zoom := 1.0
var _punch_zoom := 1.0
var _punch_t := 0.0
var _punch_len := 1.0
var _punch_at := Vector2.ZERO
var _punch_pair: Array = []      # [Node2D, Node2D]: keep both in frame
var _intro_t := 0.0
var _intro_len := 0.0
var _intro_hold := 0.0
var _intro_from := Vector2.ZERO


func setup(p: Player, width_px: float, ground_y: float) -> void:
	target = p
	world_width = width_px
	limit_left = 0
	limit_right = int(width_px)
	# How much of the road below the ground line may show. The handheld's taller
	# view would otherwise spend a quarter of the screen on it.
	limit_bottom = int(ground_y + (40.0 if Game.handheld else 62.0))
	limit_top = -2000
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	snap_to_target()
	make_current()


func snap_to_target() -> void:
	_focus_y = target.global_position.y - FOCUS_ABOVE_FEET
	_look = target.facing * LOOK_AHEAD * 0.35
	global_position = _desired()
	pass  # (4.3 physics interpolation not in 4.1)
func shake(amount: float) -> void:
	if Game.settings.screen_shake:
		_shake = maxf(_shake, amount)


## Zoom in on `at` for `secs` seconds (real time), then ease back out.
func punch(amount: float, at: Vector2, secs: float) -> void:
	_punch_zoom = amount
	_punch_at = at
	_punch_t = secs
	_punch_len = secs
	_punch_pair = []


## Zoom in on two characters, following them, and only as far as keeps
## both on screen (no zoom at all if they're too far apart).
func punch_pair(a: Node2D, b: Node2D, amount: float, secs: float) -> void:
	punch(amount, (a.global_position + b.global_position) * 0.5, secs)
	_punch_pair = [a, b]


func _pair_fit() -> float:
	if _punch_pair.size() < 2 or not is_instance_valid(_punch_pair[0]) or not is_instance_valid(_punch_pair[1]):
		return _punch_zoom
	var a: Vector2 = _punch_pair[0].global_position
	var b: Vector2 = _punch_pair[1].global_position
	_punch_at = (a + b) * 0.5 + Vector2(0, -40)
	var vp := get_viewport_rect().size
	var need_w := absf(a.x - b.x) + 90.0          # both bodies plus a margin
	var need_h := absf(a.y - b.y) + 110.0
	return clampf(minf(vp.x / need_w, vp.y / need_h) / Game.zoom(), 1.0, _punch_zoom)


## Start looking at `from`, hold, then glide to the player.
func intro(from: Vector2, hold: float, glide: float) -> void:
	_intro_from = from
	_intro_hold = hold
	_intro_len = hold + glide
	_intro_t = _intro_len
	global_position = _clamped(from)
	pass  # (4.3 physics interpolation not in 4.1)
func in_intro() -> bool:
	return _intro_t > 0.0


func skip_intro() -> void:
	_intro_t = minf(_intro_t, 0.25)


func _process(delta: float) -> void:
	# zoom runs in real time so slow-motion doesn't drag it out
	var real := delta / maxf(Engine.time_scale, 0.05)
	var want_zoom := 1.0
	if _punch_t > 0.0:
		_punch_t -= real
		var u := 1.0 - _punch_t / _punch_len
		want_zoom = lerpf(1.0, _pair_fit(), minf(u * 5.0, 1.0) * minf((1.0 - u) * 3.0, 1.0))
	_zoom = want_zoom * Game.zoom()
	zoom = Vector2(_zoom, _zoom)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	if _intro_t > 0.0:
		_intro_t -= delta
		var k := clampf((_intro_len - _intro_t - _intro_hold) / maxf(_intro_len - _intro_hold, 0.01), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		_focus_y = target.global_position.y - FOCUS_ABOVE_FEET
		_look = target.facing * LOOK_AHEAD * 0.35
		global_position = _clamped(_intro_from).lerp(_desired(), k)
		return
	var speed_k := clampf(absf(target.velocity.x) / Player.MAX_SPEED, 0.0, 1.0)
	var want_look := target.facing * LOOK_AHEAD * lerpf(0.35, 1.0, speed_k)
	_look = lerpf(_look, want_look, 1.0 - exp(-LOOK_RATE * delta))

	var feet_focus := target.global_position.y - FOCUS_ABOVE_FEET
	if target.is_on_floor():
		_focus_y = feet_focus
	elif feet_focus > _focus_y + FALL_MARGIN:
		_focus_y = feet_focus - FALL_MARGIN
	elif feet_focus < _focus_y - RISE_MARGIN:
		_focus_y = feet_focus + RISE_MARGIN

	var want := _desired()
	global_position.x = lerpf(global_position.x, want.x, 1.0 - exp(-X_RATE * delta))
	global_position.y = lerpf(global_position.y, want.y, 1.0 - exp(-Y_RATE * delta))

	if _shake > 0.1:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, 30.0 * delta)
	else:
		offset = Vector2.ZERO


func _desired() -> Vector2:
	var want := Vector2(target.global_position.x + _look, _focus_y)
	if _punch_t > 0.0:
		var w := clampf(minf(u_of_punch() * 5.0, (1.0 - u_of_punch()) * 3.0), 0.0, 1.0)
		if _punch_pair.size() == 2 and absf(_punch_pair[0].global_position.x - _punch_pair[1].global_position.x) > get_viewport_rect().size.x / Game.zoom() - 60.0:
			w = 0.0          # too far apart to frame both: stay on the Sheriff
		want = want.lerp(_punch_at, w)
	return _clamped(want)


func u_of_punch() -> float:
	return 1.0 - _punch_t / maxf(_punch_len, 0.01)


func _clamped(p: Vector2) -> Vector2:
	var half_w := get_viewport_rect().size.x * 0.5 / _zoom
	var half_h := get_viewport_rect().size.y * 0.5 / _zoom
	var x := clampf(p.x, half_w, world_width - half_w)
	var y := minf(p.y, limit_bottom - half_h)
	return Vector2(x, y)
