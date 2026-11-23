# The midnight freight: Earl's ride out of town. When Earl reaches the
# station it pulls out and the deputy comes running. Jump up onto the car
# roofs, hop from car to car, and slide (dash) under the signal arms. The
# train crosses the ravine the deputy can't; ride it to the county line.
#   {"type": "freight_train", "x": 236, "cars": 4, "trigger": 232, "arms": [256, 300]}
extends LevelObject

const ROOF := -56.0
const CAR := 72.0
const GAP := 14.0
const TOP_SPEED := 115.0

var cars: Array = []         # AnimatableBody2D, rear first
var tx := 0.0                # rear car's local x
var speed := 0.0
var state := 0               # 0 at the station, 1 rolling
var arms: Array = []         # world x of signal arms
var headlamp: PointLight2D
var _t := 0.0


func _setup() -> void:
	var n: int = int(o.get("cars", 4))
	for i in n + 1:                                   # + the engine at the front
		var b := AnimatableBody2D.new()
		b.sync_to_physics = true
		b.collision_layer = 2
		b.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		var w := CAR if i < n else CAR + 10.0
		sh.size = Vector2(w, 6)
		cs.shape = sh
		cs.position = Vector2(w / 2.0, ROOF + 3.0)
		cs.one_way_collision = true
		b.add_child(cs)
		add_child(b)
		cars.append(b)
	for a in o.get("arms", []):
		arms.append(a * TILE)
	_place()
	player().fell_out.connect(_on_fell)
	if Lighting.enabled():
		headlamp = Lighting.cone(Vector2.ZERO, Color(1, 0.95, 0.7), 2.4, 1.4)
		cars[cars.size() - 1].add_child(headlamp)
		headlamp.position = Vector2(CAR + 12, ROOF + 22)


func _place() -> void:
	for i in cars.size():
		cars[i].position = Vector2(roundf(tx + i * (CAR + GAP)), 0)


func step(delta: float) -> void:
	_t += delta
	var p := player()
	if state == 0 and p.global_position.x > o.trigger * TILE:
		state = 1
		Audio.sfx("honk", 0.4)
		var d: Deputy = level.deputy
		if d and not d.active:
			d.active = true
			d.global_position = Vector2(p.global_position.x - 230.0, level.GROUND_Y)
			pass  # (4.3 physics interpolation not in 4.1)
			d.cooldown = 120
			d.say(GameText.NB_DEPUTY_TRAIN, 120, "nb_train")
	if state == 1:
		speed = move_toward(speed, TOP_SPEED, 40.0 * delta)
		tx += speed * delta
		_place()
	# signal arms: slide (dash) under them on the roofs
	var feet := p.global_position.y - global_position.y
	if feet < ROOF + 4.0 and feet > ROOF - 30.0 and not p.sliding:
		for ax in arms:
			if absf(p.global_position.x - ax) < 10.0 and p.invuln == 0:
				p.hurt(ax - 10.0)
				level.popup(Vector2(ax, global_position.y - 120), GameText.NB_DUCK, Color("ff9a3a"))
	queue_redraw()


## Fell into the ravine with the train already gone ahead: bring it back to the station.
func _on_fell() -> void:
	call_deferred("_maybe_reset")


func _maybe_reset() -> void:
	var p := player()
	if state == 1 and p.global_position.x < global_position.x + tx - 40.0:
		state = 0
		tx = 0.0
		speed = 0.0
		_place()


## Test bot: catch the train, jump up, hop the gaps, slide under the arms.
func bot_hint(p: Player) -> Dictionary:
	if state == 0:
		return {}
	var lx := p.global_position.x - global_position.x
	var front: float = tx + cars.size() * (CAR + GAP)
	if lx > front + 40.0:
		return {}
	var on_roof := p.is_on_floor() and p.global_position.y < global_position.y + ROOF + 4.0
	if on_roof:
		var engine_x: float = cars[cars.size() - 1].position.x
		if lx > engine_x + 20.0:
			return {"dir": 0.0}                              # on the engine: just ride
		for ax in arms:
			var d: float = ax - p.global_position.x
			if d > 0.0 and d < 46.0:
				return {"dir": 1.0, "dash": true}
		var space := p.get_world_2d().direct_space_state
		var ahead := p.global_position + Vector2(12, -2)
		var floor_ahead := not space.intersect_ray(PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 8), 2)).is_empty()
		return {"dir": 1.0, "jump": not floor_ahead}
	if p.is_on_floor() and lx > tx - 30.0 and lx < front:
		return {"dir": 1.0, "jump": true}                    # climb aboard
	return {"dir": 1.0}


func _draw() -> void:
	# track (rails + ties) along the whole line
	var x0 := -40.0
	var x1: float = level.width_px - global_position.x + 40.0
	for x in range(int(x0), int(x1), 10):
		draw_rect(Rect2(x, -3, 7, 3), Color("3a2a1a"))
	draw_rect(Rect2(x0, -5, x1 - x0, 2), Color("8a8a96"))
	# trestle legs over the ravine
	var seg: Array = level.ground_segment_at(global_position.x + 10.0)
	var gap_a: float = seg[1] - global_position.x
	var gap_b: float = level.next_ground_x(seg[1] + 2.0) - 24.0 - global_position.x
	if gap_b > gap_a:
		for x in range(int(gap_a), int(gap_b), 20):
			draw_line(Vector2(x, 0), Vector2(x + 10, 140), Color("4a3422"), 3.0)
			draw_line(Vector2(x + 20, 0), Vector2(x + 10, 140), Color("4a3422"), 3.0)
		draw_rect(Rect2(gap_a, -2, gap_b - gap_a, 4), Color("4a3422"))
	# signal gantries
	for ax in arms:
		var lx: float = ax - global_position.x
		draw_rect(Rect2(lx + 18, -130, 4, 130), Color("5a5a66"))
		outlined_rect(Rect2(lx - 26, ROOF - 44, 48, 10), Color("8a8a96"))
		draw_circle(Vector2(lx - 18, ROOF - 39), 3.0, Color("ff4a3a") if int(_t * 2.0) % 2 == 0 else Color("6a2a2a"))
	# cars
	for i in cars.size():
		var cx: float = cars[i].position.x
		if i < cars.size() - 1:
			var col: Color = [Color("7a3a2a"), Color("4a5a3a"), Color("6a4a2a"), Color("3a4a5a")][i % 4]
			outlined_rect(Rect2(cx, ROOF, CAR, -ROOF - 10), col)
			for k in range(int(cx) + 8, int(cx + CAR), 12):
				draw_rect(Rect2(k, ROOF + 4, 1, -ROOF - 18), col.darkened(0.3))
			outlined_rect(Rect2(cx + CAR * 0.5 - 10, ROOF + 10, 20, 30), col.darkened(0.2))   # sliding door
			draw_rect(Rect2(cx, ROOF - 2, CAR, 3), col.lightened(0.25))
			draw_line(Vector2(cx + CAR, -14), Vector2(cx + CAR + GAP, -14), Color("2a2a30"), 2.0)  # coupler
		else:
			# the engine
			var e := Color("2a2a30")
			outlined_rect(Rect2(cx, ROOF, 30, -ROOF - 10), e)                                 # cab
			draw_rect(Rect2(cx + 6, ROOF + 8, 14, 12), Color("e8c060"))
			outlined_rect(Rect2(cx + 30, ROOF + 16, CAR - 22, -ROOF - 26), e)                 # boiler
			outlined_rect(Rect2(cx + CAR - 4, ROOF + 2, 8, 16), e)                            # stack
			if state == 1:
				for k in 3:
					draw_circle(Vector2(cx + CAR - 4 - k * 10 - fmod(_t * 30.0, 10.0), ROOF - 8 - k * 7), 4.0 + k, Color(0.7, 0.7, 0.7, 0.5 - k * 0.12))
		for wx in [10.0, CAR - 10.0]:
			draw_circle(Vector2(cx + wx, -7), 6.0, OUTLINE)
			draw_circle(Vector2(cx + wx, -7), 4.5, Color("3a3a42"))
