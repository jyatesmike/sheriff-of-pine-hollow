# The car chase: Earl is getting away in a stolen milk truck and the Sheriff
# follows in the patrol car. Runs inside the level (the level hides its own
# world while this plays). Course data: data/chases/<level id>.json.
#
# Controls: right = gas, left = brake, up/down = change lane,
#           Shift / C (action) = siren blast: traffic pulls over.
# Curves: the screen leans; take them too fast and you skid toward the hay.
# Hills: crest them fast to catch air. Bridge out: hit the ramp at full speed.
# Bump the milk truck 3 times to spin Earl out.
extends Node2D

signal finished(bumps: int)

const LANES := [12.0, 26.0, 40.0]   # lane offsets below the road surface
const MIN_SPEED := 0.0
const CRUISE := 170.0
const MAX_SPEED := 300.0
const ACCEL := 240.0
const BRAKE := 420.0
const GRAVITY := 900.0
const CAR_HALF := 36.0
const TRUCK_HALF := 44.0
const MPH := 0.25                    # px/s -> "miles per hour" shown on the HUD
const ONCOMING_SCALE := 0.75         # oncoming cars drive at this share of the speed in the course file
const WARN_DIST := 950.0             # oncoming car in your lane: "!" warning and a horn this far ahead
const DODGE_DIST := 300.0            # oncoming drivers try to swerve out of your lane this close

var level: Node
var course: Dictionary
var x := 0.0                         # car position along the road
var speed := 0.0
var lane := 1
var lane_y := LANES[1]
var height := 0.0                    # car height above the road surface
var vy := 0.0                        # vertical velocity (up = positive)
var airborne := false
var drift := 0.0
var skids: Array = []                # skid marks [x, lane_y]
var lean := 0.0
var invuln := 0
var siren_cd := 0
var shake := 0.0
var traffic: Array = []
var crates: Array = []
var pies: Array = []
var truck := {"x": 300.0, "lane": 1, "ly": 26.0, "v": 200.0, "lane_t": 120, "drop_t": 200, "spin": 0.0}
var bumps := 0
var outro := -1                      # frames left in the ending, -1 = still chasing
var splash_t := 0
var msg := ""
var msg_t := 0
var _t := 0.0

@onready var cam: Camera2D = $Camera


func setup(l: Node, data: Dictionary) -> void:
	level = l
	course = data
	for v in course.traffic:
		var vel := float(v[3]) * (ONCOMING_SCALE if float(v[3]) < 0.0 else 1.0)
		traffic.append({"kind": v[0], "x": float(v[1]), "lane": int(v[2]), "ly": LANES[v[2]], "v": vel,
				"gone": false, "vy": 0.0, "h": 0.0, "warned": false, "dodged": false})
	for pz in course.pies:
		pies.append({"x": float(pz[0]), "lane": int(pz[1]), "got": false})
		level.pies_total += 1
	var backdrop := Node2D.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	move_child(backdrop, 0)
	$View.build_backdrop(backdrop)
	cam.make_current()
	cam.position = Vector2(x + 120, -60)
	pass  # (4.3 physics interpolation not in 4.1)
	say(GameText.CHASE_START, "chase_start")


# --- the road ------------------------------------------------------------------
## Height of the road surface above the baseline at x (hills).
func elevation(px: float) -> float:
	for h in course.hills:
		if px >= h[0] and px <= h[1]:
			return h[2] * sin(PI * (px - h[0]) / (h[1] - h[0]))
	return 0.0


## Extra height of the bridge ramp at x (0 when not on the ramp).
func ramp_height(px: float) -> float:
	var r: Array = course.ramp
	if px >= r[0] and px <= r[1]:
		return 22.0 * (px - r[0]) / (r[1] - r[0])
	return 0.0


func in_gap(px: float) -> bool:
	var r: Array = course.ramp
	return px > r[1] and px < r[1] + r[2]


## Road surface height at x, or -INF over the washed-out bridge.
func surface(px: float) -> float:
	if in_gap(px):
		return -INF
	return elevation(px) + ramp_height(px)


func curve_at(px: float) -> Array:
	for c in course.curves:
		if px >= c[0] and px <= c[1]:
			return c
	return []


## 0 = town, 1 = farm country (used to fade the scenery).
func countryside(px: float) -> float:
	var a := clampf((px - course.town_until) / 300.0, 0.0, 1.0)
	var b := clampf((course.town_from - px) / 300.0, 0.0, 1.0)
	return minf(a, b)


# --- per frame --------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_t += delta
	invuln = maxi(invuln - 1, 0)
	siren_cd = maxi(siren_cd - 1, 0)
	msg_t = maxi(msg_t - 1, 0)
	shake = move_toward(shake, 0.0, 20.0 * delta)
	level.player.invuln = invuln
	if outro >= 0:
		_outro(delta)
	elif splash_t > 0:
		_splashed()
	else:
		_drive(delta)
		_truck_ai(delta)
		_traffic(delta)
		_collide()
	_camera(delta)
	Audio.loop("engine", true, 0.6 + speed / MAX_SPEED * 1.2, 0.5)
	Audio.loop("siren", outro < 0 and splash_t == 0, 1.0, 0.35)


func _drive(delta: float) -> void:
	var gas := Input.is_action_pressed("right")
	var brake := Input.is_action_pressed("left")
	if level.finished:
		gas = false
	var goal := MAX_SPEED if gas else (MIN_SPEED if brake else CRUISE)
	speed = move_toward(speed, goal, (BRAKE if brake else ACCEL) * delta)
	if not airborne:
		if Input.is_action_just_pressed("up"):
			lane = maxi(lane - 1, 0)
		if Input.is_action_just_pressed("down"):
			lane = mini(lane + 1, LANES.size() - 1)
	if Input.is_action_just_pressed("action") and siren_cd == 0:
		_siren_blast()
	lane_y = move_toward(lane_y, LANES[lane], 110.0 * delta)
	var before := surface(x)
	x += speed * delta
	_vertical(before, delta)
	_curves(delta)


## Follow the road, or fly: crest a hill fast or hit the ramp and you get air.
func _vertical(before: float, delta: float) -> void:
	var now := surface(x)
	if airborne:
		vy -= GRAVITY * delta
		height += vy * delta
		if now != -INF and height <= now:
			height = now
			airborne = false
			vy = 0.0
			shake = 2.0
			Audio.sfx("land", 0.6)
		elif now == -INF and height < -30.0:
			_splash()
		return
	if now == -INF:
		airborne = true                           # drove off the broken bridge
		vy = speed * 0.85 if ramp_height(x - speed * delta) > 15.0 else 0.0
		if vy > 0.0:
			Audio.sfx("jump", 0.6)
		return
	var climb := (now - before) / delta           # how fast the road rises
	var predicted := height + vy * delta - GRAVITY * delta * delta
	if now < predicted - 0.5 and vy > 60.0:
		airborne = true                           # the road drops away faster than gravity
		height += vy * delta
	else:
		height = now
		vy = climb


func _curves(delta: float) -> void:
	var c := curve_at(x)
	var target := 0.0
	if not c.is_empty():
		target = float(c[2]) * 0.06
		var safe: float = c[3]
		if speed > safe and not airborne:
			drift += delta * (speed - safe) / 35.0
			Audio.loop("screech", true, 1.0, 0.4)
			if int(_t * 30.0) % 2 == 0:
				skids.append([x - 20.0, lane_y])
			if drift >= 1.0:
				drift = 0.0
				var next: int = lane + int(c[2])
				if next < 0 or next > 2:
					_hit_hay(speed > safe + 50.0)
				else:
					lane = next
		else:
			drift = maxf(drift - delta, 0.0)
			Audio.loop("screech", false)
	else:
		Audio.loop("screech", false)
		drift = 0.0
	lean = move_toward(lean, target, 0.12 * delta)
	if skids.size() > 400:
		skids = skids.slice(skids.size() - 400)


func _hit_hay(hard: bool) -> void:
	speed = 70.0
	shake = 5.0
	Audio.sfx("crash", 0.9)
	flash(GameText.CHASE_SKID)
	if hard:
		invuln = maxi(invuln, 30)          # the hay is soft: costs you speed, not hearts


func _siren_blast() -> void:
	siren_cd = 70
	Audio.sfx("honk", 0.7)
	var moved := false
	for v in traffic:
		if v.gone:
			continue
		var dx: float = v.x - x
		if dx > 0.0 and dx < 520.0 and v.lane == lane:
			for l in [lane - 1, lane + 1]:
				if l >= 0 and l <= 2 and _lane_clear(l, v.x, v):
					v.lane = l
					moved = true
					break
	if moved:
		flash(GameText.CHASE_PULL_OVER)


func _lane_clear(l: int, at_x: float, except: Dictionary) -> bool:
	for v in traffic:
		if v != except and not v.gone and v.lane == l and absf(v.x - at_x) < 120.0:
			return false
	return true


func _truck_ai(delta: float) -> void:
	var dist: float = truck.x - x
	# keep just out of reach, but never run off for good
	var target := clampf(205.0 + (dist - 240.0) * -0.5, 150.0, 330.0)
	if dist > 700.0:
		target = 140.0
	truck.v = move_toward(truck.v, target, 200.0 * delta)
	truck.x += truck.v * delta
	truck.spin = move_toward(truck.spin, 0.0, 2.0 * delta)
	truck.lane_t -= 1
	if truck.lane_t <= 0:
		truck.lane_t = 90 + randi() % 120
		var options := []
		for l in 3:
			if l != truck.lane and _lane_clear(l, truck.x + 150.0, {}):
				options.append(l)
		if not options.is_empty():
			truck.lane = options[randi() % options.size()]
	truck.ly = move_toward(truck.ly, LANES[truck.lane], 70.0 * delta)
	truck.drop_t -= 1
	if truck.drop_t <= 0 and dist > 120.0 and truck.x < course.end - 400:
		truck.drop_t = 150 + randi() % 90
		crates.append({"x": truck.x - TRUCK_HALF - 10.0, "lane": truck.lane, "hit": false, "vy": 0.0, "y": 0.0})
		if randf() < 0.5:
			say(GameText.CHASE_EARL_CRATE, "chase_crate")
	if truck.x >= course.end:
		_begin_outro()


func _traffic(delta: float) -> void:
	for v in traffic:
		if v.gone:
			v.vy -= GRAVITY * delta
			v.h += v.vy * delta
			continue
		v.x += v.v * delta
		v.ly = move_toward(v.ly, LANES[v.lane], 60.0 * delta)
		if v.v < 0.0:
			var dx: float = v.x - x
			if not v.warned and v.lane == lane and dx > 0.0 and dx < WARN_DIST:
				v.warned = true
				Audio.sfx("honk", 1.25)
			# the other driver sees you coming and pulls aside, if there's room
			if not v.dodged and v.lane == lane and dx > 0.0 and dx < DODGE_DIST:
				v.dodged = true
				for l in ([lane - 1, lane + 1] if randf() < 0.5 else [lane + 1, lane - 1]):
					if l >= 0 and l <= 2 and _lane_clear(l, v.x, v) and randf() < 0.6:
						v.lane = l
						break


## Oncoming cars in your lane that are still off the right edge of the screen (for the "!" warning).
func incoming() -> Array:
	var out := []
	var right := cam.position.x + 240.0
	for v in traffic:
		if not v.gone and v.v < 0.0 and v.x > right - 20.0 and v.x - x < WARN_DIST:
			out.append(v)
	return out


func _collide() -> void:
	if airborne and height > 10.0:
		return
	# traffic
	for v in traffic:
		if v.gone or absf(v.ly - lane_y) > 8.0:
			continue
		var half := 30.0 if v.kind != "car" else 34.0
		if absf(v.x - x) > CAR_HALF + half:
			continue
		if v.v < 0.0:
			# head-on with an oncoming car
			v.gone = true
			v.vy = 220.0
			speed = 0.0
			shake = 6.0
			Audio.sfx("crash")
			flash(GameText.CHASE_CRASH)
			if invuln == 0 and level.player.hearts > 1:
				level.player.hurt(x)
				invuln = 150
		else:
			var rel: float = speed - v.v
			x = v.x - CAR_HALF - half - 2.0
			speed = maxf(v.v - 20.0, 0.0)
			shake = 3.0
			Audio.sfx("crash", 1.3)
			if rel > 60.0:
				flash(GameText.CHASE_HONK_TIP)    # rear-ending slow traffic just slows you down
	# milk crates
	for c in crates:
		if not c.hit and absf(LANES[c.lane] - lane_y) < 8.0 and absf(c.x - x) < CAR_HALF + 8.0:
			c.hit = true
			c.vy = 200.0
			speed *= 0.7
			shake = 2.0
			Audio.sfx("break", 1.2)
	# pies
	for p in pies:
		if not p.got and absf(LANES[p.lane] - lane_y) < 8.0 and absf(p.x - x) < CAR_HALF:
			p.got = true
			level.collect_pie(screen_point(p.x, LANES[p.lane]) + Vector2(0, -24))
	# the milk truck
	if absf(truck.ly - lane_y) < 8.0 and x + CAR_HALF >= truck.x - TRUCK_HALF and x < truck.x and speed > truck.v:
		bumps += 1
		truck.x += 70.0
		truck.spin = 1.0
		truck.lane = (truck.lane + (1 if truck.lane < 2 else -1)) % 3
		speed = truck.v - 30.0
		shake = 4.0
		level.score += 300
		Audio.sfx("tackle")
		flash(GameText.CHASE_BUMP % [bumps])
		var k := mini(bumps - 1, GameText.CHASE_EARL_BUMPED.size() - 1)
		say(GameText.CHASE_EARL_BUMPED[k], "chase_bumped_%d" % (k + 1))
		if bumps >= 3:
			level.score += 1000
			_begin_outro()


func _splash() -> void:
	splash_t = 80
	speed = 0.0
	Audio.sfx("splash")
	flash(GameText.CHASE_SPLASH)


func _splashed() -> void:
	splash_t -= 1
	if splash_t == 0:
		# fished out and put back before the ramp for another go
		x = course.ramp[0] - 500.0
		height = surface(x)
		vy = 0.0
		airborne = false
		speed = 120.0
		lane = 1
		lane_y = LANES[1]
		if truck.x < course.ramp[1] + course.ramp[2] + 300.0:
			truck.x = course.ramp[1] + course.ramp[2] + 300.0


func _begin_outro() -> void:
	if outro >= 0:
		return
	outro = 150
	truck.spin = 6.0
	say(GameText.CHASE_EARL_SPINOUT, "chase_spinout")
	Audio.sfx("screech")
	Audio.loop("screech", false)


func _outro(delta: float) -> void:
	outro -= 1
	speed = move_toward(speed, 0.0, 250.0 * delta)
	x += speed * delta
	truck.v = move_toward(truck.v, 0.0, 300.0 * delta)
	truck.x += truck.v * delta
	truck.spin = move_toward(truck.spin, 0.0, 3.0 * delta)
	height = maxf(surface(x), 0.0) if surface(x) != -INF else height
	if outro == 0:
		Audio.loop("engine", false)
		Audio.loop("siren", false)
		finished.emit(bumps)


func _camera(delta: float) -> void:
	var ahead := 90.0 + speed * 0.35
	var target := Vector2(x + ahead, -height - 70.0)
	cam.position = cam.position.lerp(target, 1.0 - exp(-6.0 * delta))
	cam.rotation = lean
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake


# --- helpers for the HUD and drawing -----------------------------------------------
func screen_point(px: float, lane_off: float) -> Vector2:
	return Vector2(px, -surface(px) + lane_off) if not in_gap(px) else Vector2(px, lane_off)


func closeness() -> float:
	return clampf(1.0 - (truck.x - x - 80.0) / 600.0, 0.0, 1.0)


func mph() -> int:
	return int(speed * MPH)


## Earl yells from the truck (speech bubble + voice / voice file).
func say(t: String, line_id := "") -> void:
	$View.say(Names.fmt(t))
	Audio.say("earl", Names.fmt(t), line_id)


func flash(t: String) -> void:
	msg = Names.fmt(t).to_upper()
	msg_t = 90
