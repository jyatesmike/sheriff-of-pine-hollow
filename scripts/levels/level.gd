# Level: loads data/levels/<id>.json (geometry) and GameText.LEVELS[id]
# (words), builds the world and runs the rules.
#  Sheriff levels: chase Earl, win the showdown, cuff him.
#  Earl level:     reach the county line before the deputy catches you.
# Extra mechanics switch on from the level data: rocks + boulders, logs on
# water, Earl's AI flags. Units in the JSON are 16 px tiles; heights are
# "tiles above the ground line".
class_name Level
extends Node2D

enum Phase { CHASE, SHOWDOWN, WON, LOST }

const TILE := 16
const GROUND_Y := 208.0          # world y of the ground surface
const GROUND_DEPTH := 200.0
const CRATE := 32.0              # crates are 2x2 tiles
const FENCE_H := 160.0
const LAYER_SOLID := 1
const LAYER_ONEWAY := 2
const PIES_PER_HEART := 10
const START_ROCKS := 3
const MAX_ROCKS := 5
const AWNING_BOUNCE := -700.0
const AWNING_BOUNCE_HELD := -820.0

const EarlScene := preload("res://scenes/actors/earl.tscn")
const HenScene := preload("res://scenes/actors/hen.tscn")
const DeweyScene := preload("res://scenes/actors/dewey.tscn")
const DeputyScene := preload("res://scenes/actors/deputy.tscn")
const PopupScript := preload("res://scripts/ui/popup_text.gd")
const LogScript := preload("res://scripts/actors/log_platform.gd")
const ChaseScript := preload("res://scripts/levels/chase/chase.gd")
const ChaseView := preload("res://scripts/levels/chase/chase_view.gd")

var data: Dictionary
var text: Dictionary             # this level's lines from GameText.LEVELS
var role := "sheriff"
var hero := "sheriff"          # who's playing: sheriff / dewey / jim (earl on the jail level)
var width_px := 0.0
var time := 0.0
var phase := Phase.CHASE
var finished := false            # true once won or lost
var score := 0
var pies_got := 0
var pies_total := 0
var golden_got := false
var pie_streak := 0              # pies toward the next bonus heart
var end_t := 0                   # frames since win/lose (to delay "press jump")
var earl: Earl
var deputy: Deputy
var boulders: Array = []         # [StaticBody2D, Rect2]
var stones: Array = []           # Vector2 positions of rocks lying around
var lamp_xs: Array = []
var hooks: Array = []            # lasso hook points (world positions)
var lasso: Lasso
var lasso_targets: Array = []    # objects the lasso can catch (fire bell...)
var rock_targets: Array = []     # objects a thrown rock can hit (rock_hit(rect) -> bool)
var tower: Node2D                # water tower (Main Street's finale), if any
var chase: Node2D                # the car chase while it's running
var chase_data: Dictionary
var truck_x := -1.0              # where Earl hops into the milk truck (if any)
var collected: Array = []        # positions of pies picked up (so a checkpoint keeps them)
var checkpoint_x := -1.0         # x of the last checkpoint touched
var stars_got := 0
var stars_total := 0
var favor_done := false
var favor_obj: Node2D             # this level's favor (favor.gd), if any
var mud_zones: Array = []        # [x0, x1, kind]: "deep" (slow) or "slick" (slippery)
var crate_bodies: Array = []     # StaticBody2D per data.crates entry, so a powered-up mower can plow one
var crates_destroyed: Dictionary = {}    # data.crates index -> true; shared with Terrain for drawing

@onready var world: Node2D = $World
@onready var actors: Node2D = $World/Actors
@onready var pies: Node2D = $World/Pies
@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	add_to_group("level")
	Engine.time_scale = 1.0
	var id: String = Game.level_id()
	data = _load_json("res://data/levels/%s.json" % id)
	text = GameText.LEVELS.get(id, {})
	role = data.get("role", "sheriff")
	hero = Game.character() if role == "sheriff" else "earl"
	Names.hero = hero if role == "sheriff" else "sheriff"
	width_px = data.width_tiles * TILE
	_build_solids()
	_build_platforms()
	$Background.setup(data, width_px, GROUND_Y)
	$World/Terrain.setup(data, GROUND_Y, text)
	$World/Terrain.crates_destroyed = crates_destroyed
	lamp_xs = $World/Terrain.lamp_xs()
	_build_tiles()

	player.global_position = Vector2(data.player_start * TILE, GROUND_Y)
	player.kill_y = GROUND_Y + (40.0 if data.get("water", false) else 140.0)
	player.last_safe = player.global_position
	player.fell_out.connect(_on_fell_out)
	player.landed.connect(_on_landed)
	player.hurt_taken.connect(_on_player_hurt)
	player.died.connect(_on_player_died)
	player.combo_ended.connect(_on_combo_ended)
	player.throw_pressed.connect(_on_throw_pressed)
	player.jumped.connect(func(): Audio.sfx("jump", randf_range(0.95, 1.05)))
	if role == "earl":
		player.set_character("earl")
	elif hero != "sheriff":
		player.set_character(hero)
	pass  # (4.3 physics interpolation not in 4.1)
	if role == "earl":
		_spawn_deputy()
	else:
		_spawn_earl()
	_spawn_hens()
	_spawn_pies()
	_spawn_deweys()
	if data.get("flags", {}).get("rocks", false):
		_setup_rocks()
	if data.get("water", false) and data.get("flags", {}).get("logs", true):
		_spawn_logs()
	for hk in data.get("hooks", []):
		hooks.append(Vector2(hk[0] * TILE + 8, GROUND_Y - hk[1] * TILE))
	if role == "sheriff":
		lasso = Lasso.new()
		world.add_child(lasso)
		lasso.setup(player, self)
		lasso.style = {"dewey": "cables", "jim": "hose"}.get(hero, "rope")
		player.lasso = lasso
	_spawn_objects()
	_spawn_powerups()
	camera.setup(player, width_px, GROUND_Y)
	hud.setup(self)
	Audio.music(data.get("music", ""))
	if Lighting.enabled() and not data.get("train", false):
		var grass := GrassFringe.new()
		grass.name = "Grass"
		world.add_child(grass)
		grass.setup(self)
	var lighting := Lighting.new()
	world.add_child(lighting)
	lighting.setup(self)
	if Game.checkpoint.get("level", -1) == Game.level_index:
		_resume_checkpoint(Game.checkpoint)
	elif earl and earl.global_position.x - player.global_position.x > 140.0 and not data.get("train", false):
		# open on Earl (he's just said his piece), then glide back to the Sheriff
		camera.intro(earl.global_position + Vector2(0, -52), 0.9, 1.1)
		_intro_freeze(true)


func _physics_process(delta: float) -> void:
	if finished:
		end_t += 1
		return
	if camera.in_intro():
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
			camera.skip_intro()
		return
	if intro_frozen:
		_intro_freeze(false)
	time += delta
	if in_chase():
		return                 # the chase handles its own collisions
	_apply_mud()
	_check_hens()
	_check_crates()
	_check_platforms()
	_check_pies()
	_mow()
	_check_stones()
	_check_boulders()
	if earl and earl.body_rect().intersects(player.body_rect()) and player.hurt_t == 0:
		# a power-up is for bowling birds, not a shortcut: you can't nab Earl
		# early while it's running (showdown tackles still count)
		if player.power_t <= 0.0 or phase == Phase.SHOWDOWN:
			earl.on_contact()
	if deputy and deputy.active:
		_check_deputy()
	if role == "earl" and player.global_position.x >= corner_x():
		_win()


var intro_frozen := false


func _intro_freeze(on: bool) -> void:
	intro_frozen = on
	player.input_enabled = not on
	for a in [earl, deputy]:
		if a:
			a.set_physics_process(not on)


func _exit_tree() -> void:
	Names.hero = "sheriff"
	Audio.stop_loops()          # siren, engine, screech, mower: never carry over to the next scene


## A line for whoever you're playing (GameText.HEROES), or `fallback` if
## their list is empty there.
func hero_line(kind: String, i := -1, fallback := "") -> String:
	var v = GameText.HEROES.get(hero, {}).get(kind, "")
	if v is Array:
		if v.is_empty():
			return fallback
		var pick: String = v[i % v.size()] if i >= 0 else v[randi() % v.size()]
		return pick if pick != "" else fallback
	return v if v != "" else fallback


func _unhandled_input(event: InputEvent) -> void:
	if finished and end_t > 45 and event.is_action_pressed("jump"):
		if phase == Phase.WON:
			Game.next_level()
		else:
			Game.restart_level(true)        # back to the last checkpoint, if any


# --- queries used by actors and the HUD --------------------------------------------
func fence_px() -> float:
	return data.fence_x * TILE


func corner_x() -> float:
	return fence_px() - 6 * TILE


## The stretch of solid ground at (or nearest to) x, as [left, right].
func ground_segment_at(x: float) -> Array:
	var best: Array = data.ground[0]
	var best_d := INF
	for seg in data.ground:
		var a: float = seg[0] * TILE
		var b: float = seg[1] * TILE
		var d := 0.0 if x >= a and x <= b else minf(absf(x - a), absf(x - b))
		if d < best_d:
			best_d = d
			best = seg
	return [best[0] * TILE, best[1] * TILE]


func next_ground_x(x: float) -> float:
	for seg in data.ground:
		if seg[0] * TILE > x:
			return seg[0] * TILE + 24.0
	return x


## Distance from x to the next gap in the ground, and that gap's width.
## Returns (INF, 0) when there is no gap ahead.
func gap_ahead(x: float) -> Vector2:
	for i in data.ground.size() - 1:
		var edge: float = data.ground[i][1] * TILE
		var next: float = data.ground[i + 1][0] * TILE
		if edge >= x - 4.0:
			return Vector2(edge - x, next - edge)
	return Vector2(INF, 0.0)


func platform_starting_near(x: float, tol: float) -> bool:
	for p in data.platforms:
		if absf(p.x * TILE - x) < tol:
			return true
	return false


func crate_near(x: float, tol: float) -> bool:
	for c in data.crates:
		if absf(c.x * TILE + 16.0 - x) < tol:
			return true
	return false


func in_chase() -> bool:
	return chase != null


func is_lit(x: float) -> bool:
	for lx in lamp_xs:
		if absf(x - lx) < 40.0:
			return true
	return false


## 0 = far apart, 1 = right on top of each other (Earl for the Sheriff,
## the deputy for Earl).
var chaser: Node2D               # the hound etc.: whoever the HUD meter should track right now


func closing_in() -> float:
	var other: Node2D = deputy if deputy else earl
	if deputy and not deputy.active:
		if chaser == null:
			return 0.0
		other = chaser
	var d := absf(other.global_position.x - player.global_position.x)
	return clampf(1.0 - (d - 24.0) / 560.0, 0.0, 1.0)


# --- spawning ------------------------------------------------------------------------
func _spawn_earl() -> void:
	earl = EarlScene.instantiate()
	actors.add_child(earl)
	earl.global_position = Vector2(data.earl_start * TILE, GROUND_Y)
	earl.setup(player, self)
	pass  # (4.3 physics interpolation not in 4.1)
	earl.cornered.connect(_on_earl_cornered)
	earl.tackled.connect(_on_earl_tackled)
	earl.cuffed.connect(_on_earl_cuffed)
	earl.threw.connect(func(at, vel): _throw(Projectile.Kind.EARL_ROCK, at, vel))
	if Game.checkpoint.get("level", -1) != Game.level_index:
		earl.say(text.get("start", ""), 120, data.id + "_start")


func _spawn_deputy() -> void:
	deputy = DeputyScene.instantiate()
	actors.add_child(deputy)
	deputy.global_position = Vector2(data.get("deputy_start", 4) * TILE, GROUND_Y)
	deputy.setup(player, self)
	pass  # (4.3 physics interpolation not in 4.1)
	deputy.active = not data.get("deputy_waits", false)
	deputy.fired.connect(func(at, dir): _throw(Projectile.Kind.CORK, at, Vector2(dir * 300.0, 0)); Audio.sfx("cork_pop"))
	if Game.checkpoint.get("level", -1) != Game.level_index and deputy.active:
		deputy.say(GameText.DEPUTY_START, 150, "start")
		player.get_node("Bubble").show_text(Names.fmt(text.get("start", "")), 120, data.id + "_start")


func _spawn_hens() -> void:
	for r in data.get("hens", []):
		_add_hen(Hen.Kind.HEN, Vector2(r[0] * TILE, r[1] * TILE), GROUND_Y)
	for r in data.get("geese", []):
		_add_hen(Hen.Kind.GOOSE, Vector2(r[0] * TILE, r[1] * TILE), GROUND_Y)
	if GameText.POWERUPS.has(hero) and role == "sheriff":
		# extra hens near the power-ups, for Dewey and Jim to bowl over
		for r in data.get("powerup_hens", []):
			_add_hen(Hen.Kind.HEN, Vector2(r[0] * TILE, r[1] * TILE), GROUND_Y)
	for r in data.get("ducks", []):
		_add_hen(Hen.Kind.DUCK, Vector2(r[0] * TILE, r[1] * TILE), GROUND_Y)
	var i := 0
	for x in data.get("flap_hens", []):
		var cx: float = x * TILE
		_add_hen(Hen.Kind.FLAP, Vector2(cx - 34.0, cx + 34.0), GROUND_Y - 75.0, i * 1.7)
		i += 1


func _add_hen(kind: int, xr: Vector2, y: float, ph := 0.0) -> void:
	var h: Hen = HenScene.instantiate()
	actors.add_child(h)
	h.setup(kind, xr, y, ph)
	pass  # (4.3 physics interpolation not in 4.1)
func _spawn_pies() -> void:
	for x in data.get("pies", []):
		_add_pie(Vector2(x * TILE + 8, GROUND_Y - 45.0))
	for p in data.platforms:
		var cx: float = p.x * TILE + p.w * TILE / 2.0
		var top: float = GROUND_Y - p.h * TILE
		for k in 3:
			_add_pie(Vector2(cx - 28.0 + k * 28.0, top - 22.0))
	for a in data.get("pie_arcs", []):
		for k in 5:
			var x: float = lerpf(a[0] * TILE, a[1] * TILE, k / 4.0)
			_add_pie(Vector2(x, GROUND_Y - 45.0 - sin(PI * k / 4.0) * 70.0))
	for x in data.get("flap_hens", []):
		_add_pie(Vector2(x * TILE, GROUND_Y - 176.0))
	if data.get("flags", {}).get("gapPies", false):
		# pies over the water, to grab while riding the logs
		for i in data.ground.size() - 1:
			var a: float = data.ground[i][1] * TILE
			var b: float = data.ground[i + 1][0] * TILE
			for j in 3:
				_add_pie(Vector2(lerpf(a, b, (j + 1) / 4.0), GROUND_Y - 62.0))
	for sp in data.get("sky_pies", []):          # pies placed by height, e.g. above a springy line
		_add_pie(Vector2(sp[0] * TILE + 8, GROUND_Y - sp[1] * TILE))
	for g in data.get("golden_pie", []):
		_add_pie(Vector2(g.x * TILE + 8, GROUND_Y - g.h * TILE), true)


func _add_pie(at: Vector2, golden := false, count := true) -> void:
	var p := Pie.new()
	p.golden = golden
	p.position = at
	pies.add_child(p)
	if count:
		pies_total += 1


func _spawn_deweys() -> void:
	var lines: Array = text.get("dewey", [])
	for i in data.get("dewey", []).size():
		var dw = DeweyScene.instantiate()
		actors.add_child(dw)
		dw.global_position = Vector2(data.dewey[i] * TILE, GROUND_Y)
		dw.setup(player, lines[i] if i < lines.size() else "", "%s_%d" % [data.id, i + 1])
		if hero == "dewey":
			# you're playing Dewey, so the Sheriff gives the tips instead
			dw.get_node("Sprite").set_sheet("sheriff")
			dw.get_node("Bubble").voice = "sheriff"


## Set-piece objects from the level's "objects" list (scripts/levels/objects/).
func _spawn_objects() -> void:
	var holder := Node2D.new()
	holder.name = "Objects"
	world.add_child(holder)
	world.move_child(holder, 3)
	for o in data.get("objects", []):
		var path = "res://scripts/levels/objects/%s.gd" % o.type
		if not ResourceLoader.exists(path):
			push_warning("Unknown object type: " + str(o.type))
			continue
		var n := Node2D.new()
		n.set_script(load(path))
		holder.add_child(n)
		n.setup(self, o)
		if o.type == "patrol_car":
			truck_x = (o.x + 6) * TILE


# --- the car chase -------------------------------------------------------------------
func start_chase(_o: Dictionary) -> void:
	chase_data = _load_json("res://data/chases/%s.json" % data.id)
	chase = Node2D.new()
	chase.set_script(ChaseScript)
	var cam := Camera2D.new()
	cam.name = "Camera"
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam.ignore_rotation = false
	chase.add_child(cam)
	var view := Node2D.new()
	view.name = "View"
	view.set_script(ChaseView)
	chase.add_child(view)
	add_child(chase)
	_show_world(false)
	chase.setup(self, chase_data)
	chase.finished.connect(_on_chase_finished)
	Audio.music("chase", true)
	save_checkpoint("chase", player.global_position.x)


func _on_chase_finished(bumps: int) -> void:
	chase.queue_free()
	chase = null
	_show_world(true)
	camera.make_current()
	player.global_position = Vector2(chase_data.resume_x * TILE, GROUND_Y)
	player.velocity = Vector2.ZERO
	player.last_safe = player.global_position
	pass  # (4.3 physics interpolation not in 4.1)
	camera.snap_to_target()
	if earl:
		earl.after_chase(Vector2(chase_data.earl_resume_x * TILE, GROUND_Y))
	if bumps >= 3:
		popup(player.global_position + Vector2(0, -70), "SPUN HIM OUT! +1000", Color("ff9a3a"))
	Audio.music(data.get("music", ""))
	save_checkpoint("after_chase", player.global_position.x)


## Mud (Chicken Run): "deep" slows you down, "slick" makes you slide about.
func mud_at(x: float) -> String:
	for z in mud_zones:
		if x >= z[0] and x <= z[1]:
			return z[2]
	return ""


func _apply_mud() -> void:
	var m := mud_at(player.global_position.x) if player.global_position.y > GROUND_Y - 3.0 else ""
	player.speed_scale = 0.42 if m == "deep" else (0.62 if m == "creek" else 1.0)
	player.jump_scale = 0.75 if m == "deep" else (0.85 if m == "creek" else 1.0)
	player.traction = 0.2 if m == "slick" else 1.0


# --- checkpoints ---------------------------------------------------------------------
## Remember where to come back to if you lose. kind: "post" (a checkpoint post at x),
## "chase" (start of the car chase) or "after_chase" (back on foot after it).
func save_checkpoint(kind: String, at_x: float) -> void:
	checkpoint_x = at_x
	Game.checkpoint = {
		"level": Game.level_index, "kind": kind, "x": at_x,
		"score": score, "pies_got": pies_got, "golden": golden_got, "streak": pie_streak,
		"collected": collected.duplicate(), "time": time,
		"stars": _taken_stars(), "favor": favor_obj.state if favor_obj else 0,
	}
	if kind != "chase":
		popup(Vector2(at_x, GROUND_Y - 80), GameText.UI.checkpoint, Color("8ae08a"))
		Audio.sfx("heart", 1.2)


func _resume_checkpoint(cp: Dictionary) -> void:
	score = cp.score
	pies_got = cp.pies_got
	golden_got = cp.golden
	pie_streak = cp.streak
	time = cp.time
	collected = cp.collected.duplicate()
	checkpoint_x = cp.x
	for st in get_tree().get_nodes_in_group("stars"):
		if st.global_position.x in cp.get("stars", []):
			st.take(false)
	if favor_obj:
		favor_obj.restore(cp.get("favor", 0))
	for p in pies.get_children():
		if p is Pie and p.position in collected:
			p.queue_free()
	var x: float = cp.x
	match cp.kind:
		"post":
			player.global_position = Vector2(x, GROUND_Y)
			if earl:
				earl.global_position = Vector2(x + (data.earl_start - data.player_start) * TILE, GROUND_Y)
			if deputy:
				deputy.global_position = Vector2(x - (data.player_start - data.get("deputy_start", 4)) * TILE, GROUND_Y)
		"chase":
			# drop the Sheriff by the patrol car: the chase starts straight away
			var cars := get_tree().get_nodes_in_group("patrol_car")
			player.global_position = Vector2(cars[0].global_position.x if cars else x, GROUND_Y)
			if earl:
				earl.global_position = Vector2(truck_x, GROUND_Y)
				earl.state = Earl.State.WAIT
				earl.visible = false
		"after_chase":
			player.global_position = Vector2(chase_data_resume_x(), GROUND_Y)
			if earl:
				earl.after_chase(Vector2(_load_json("res://data/chases/%s.json" % data.id).earl_resume_x * TILE, GROUND_Y))
			for obj in get_tree().get_nodes_in_group("patrol_car"):
				obj.used = true
	player.last_safe = player.global_position
	player.invuln = Player.INVULN_FRAMES
	pass  # (4.3 physics interpolation not in 4.1)
	if earl:
		pass  # (4.3 physics interpolation not in 4.1)
	if deputy:
		pass  # (4.3 physics interpolation not in 4.1)
	camera.snap_to_target()
	for obj in get_tree().get_nodes_in_group("checkpoint"):
		if obj.global_position.x <= x + 1.0:
			obj.reached = true


func _taken_stars() -> Array:
	var out := []
	for st in get_tree().get_nodes_in_group("stars"):
		if st.taken:
			out.append(st.global_position.x)
	return out


## Medals for this run: {"time": 0-3, "pies": 0-3, "stars": 0-3} (3 = gold).
func medals() -> Dictionary:
	var t: Array = data.get("medals", {}).get("time", [60, 90, 150])
	var tm := 3 if time <= t[0] else (2 if time <= t[1] else (1 if time <= t[2] else 0))
	var share := float(pies_got) / maxf(pies_total, 1.0)
	var pm := 3 if pies_got >= pies_total else (2 if share >= 0.75 else (1 if share >= 0.5 else 0))
	var sm := mini(stars_got, 3) if stars_total >= 3 else (3 if stars_got >= stars_total and stars_total > 0 else 0)
	return {"time": tm, "pies": pm, "stars": sm}


func chase_data_resume_x() -> float:
	return _load_json("res://data/chases/%s.json" % data.id).resume_x * TILE


func _show_world(on: bool) -> void:
	world.visible = on
	player.visible = on
	player.set_physics_process(on)
	for n in $Background.get_children():
		if n is Parallax2D:
			n.visible = on
	if earl:
		earl.visible = on
		earl.set_physics_process(on)


# --- water tower finale -------------------------------------------------------------
func on_earl_tower() -> void:
	if text.has("tower_hint"):
		player.get_node("Bubble").show_text(Names.fmt(text.tower_hint), 150, data.id + "_tower_hint")
	else:
		player.get_node("Bubble").show_text(Names.fmt(GameText.SHERIFF_BELL_HINT), 150, "bell_hint")


func on_bell() -> void:
	if earl and tower and earl.state == Earl.State.TOWER:
		tower.spray(player.global_position.x)
		get_tree().create_timer(0.6).timeout.connect(func(): earl.hosed())
		score += 200
		popup(tower.global_position + Vector2(0, -60), "+200", Color("6ab8ff"))


func _spawn_logs() -> void:
	for i in data.ground.size() - 1:
		var a: float = data.ground[i][1] * TILE
		var b: float = data.ground[i + 1][0] * TILE
		var lg := AnimatableBody2D.new()
		lg.set_script(LogScript)
		world.add_child(lg)
		lg.setup(a + 2.0, b - 98.0, GROUND_Y + 4.0, 1.0 if i % 2 == 0 else -1.0)


# --- rocks and boulders (Rock Creek) ---------------------------------------------------
func _setup_rocks() -> void:
	player.can_throw = true
	player.rocks = START_ROCKS
	for x in data.get("stones", []):
		_add_stone(Vector2(x * TILE + 8, GROUND_Y))
	for bx in data.get("boulders", []):
		var body := StaticBody2D.new()
		body.collision_layer = LAYER_SOLID
		body.collision_mask = 0
		var r := Rect2(bx * TILE, GROUND_Y - 28.0, 32.0, 28.0)
		_rect_shape(body, r)
		var spr := Sprite2D.new()
		spr.texture = SpriteLib.prop("boulder")
		spr.centered = false
		spr.position = Vector2(bx * TILE - 1, GROUND_Y - 30.0)
		body.add_child(spr)
		world.add_child(body)
		boulders.append([body, r])
		pies_total += 3       # each boulder hides three pies


func _add_stone(at: Vector2) -> void:
	stones.append(at)
	var spr := Sprite2D.new()
	spr.texture = SpriteLib.prop("rock")
	spr.position = at + Vector2(0, -4)
	spr.name = "Stone%d" % stones.size()
	spr.set_meta("stone", at)
	pies.add_child(spr)


func _check_stones() -> void:
	if not player.can_throw:
		return
	var r := player.body_rect().grow(4)
	for spr in pies.get_children():
		if spr.has_meta("stone") and not spr.is_queued_for_deletion() and r.has_point(spr.get_meta("stone") + Vector2(0, -2)):
			if player.rocks < MAX_ROCKS:
				player.rocks += 1
				popup(spr.position + Vector2(0, -16), "+1 ROCK", Color("e8dcc0"))
				Audio.sfx("pickup")
				spr.queue_free()


func _on_throw_pressed() -> void:
	if player.rocks <= 0:
		popup(player.global_position + Vector2(0, -60), "NO ROCKS!", Color("e8dcc0"))
		return
	player.rocks -= 1
	player.throw_t = 14
	var from := player.global_position + Vector2(player.facing * 12, -40)
	var vel := Vector2(player.facing * 320.0 + player.velocity.x * 0.4, -230.0)
	if earl and earl.state == Earl.State.TOWER:
		# Earl's up on the rock pillar: lob it up at him
		var to := earl.global_position + Vector2(0, -24)
		var dx := to.x - from.x
		if signf(dx) == float(player.facing) and absf(dx) < 360.0:
			var t := clampf(absf(dx) / 300.0, 0.55, 1.0)
			vel = Vector2(dx / t, (to.y - from.y - 0.5 * 900.0 * t * t) / t)
	_throw(Projectile.Kind.PLAYER_ROCK, from, vel)


func _throw(kind: int, at: Vector2, vel: Vector2) -> void:
	var p := Projectile.new()
	p.setup(kind, at, vel, self)
	p.egg = kind == Projectile.Kind.EARL_ROCK and data.get("eggs", false)
	p.z_index = 5
	world.add_child(p)
	if kind != Projectile.Kind.CORK:
		Audio.sfx("throw")


## Called every frame by each projectile. Return true to remove it.
func projectile_step(p: Projectile) -> bool:
	var r := p.hit_rect()
	match p.kind:
		Projectile.Kind.PLAYER_ROCK:
			if earl and earl.state == Earl.State.TOWER and r.intersects(earl.body_rect()) and earl.pillar_hit():
				score += 300
				popup(earl.global_position + Vector2(0, -56), "BONK! %d/3" % earl.pillar_hits, Color("ff9a3a"))
				Audio.sfx("bonk")
				Game.hit_stop(3)
				return true
			for obj in rock_targets:
				if obj.rock_hit(r):
					return true
			if earl and r.intersects(earl.body_rect()) and earl.bonk():
				score += 200
				popup(earl.global_position + Vector2(0, -56), "BONK! +200")
				Audio.sfx("bonk")
				Game.hit_stop(3)
				return true
			for h in actors.get_children():
				if h is Hen and not h.tumbling and h.kind != Hen.Kind.FLAP and r.intersects(h.body_rect()):
					h.knock(signi(int(p.velocity.x)))
					score += 50
					popup(h.global_position + Vector2(0, -20), "+50")
					Audio.sfx("cluck")
					return true
			for b in boulders:
				if r.intersects(b[1]):
					_break_boulder(b)
					return true
		Projectile.Kind.EARL_ROCK, Projectile.Kind.CORK:
			if r.intersects(player.body_rect()):
				if player.hurt(p.global_position.x) and p.kind == Projectile.Kind.CORK:
					popup(player.global_position + Vector2(0, -60), "POP!", Color("ff6a4a"))
				return true
	return false


func projectile_landed(p: Projectile) -> void:
	dust(p.global_position, 4, Color("a8a094"))
	# about half of Earl's rocks stay where they land, so you never run out
	if p.egg:
		dust(p.global_position, 8, Color("fff0a0"))
		Audio.sfx("stomp", 1.6)
		return
	if p.kind == Projectile.Kind.EARL_ROCK and randf() < 0.6 and _on_ground(p.global_position.x):
		_add_stone(Vector2(p.global_position.x, GROUND_Y))
	if p.kind == Projectile.Kind.CORK and deputy and not finished:
		deputy.say(GameText.DEPUTY_MISSED, 80, "missed")


func _on_ground(x: float) -> bool:
	for seg in data.ground:
		if x > seg[0] * TILE + 4 and x < seg[1] * TILE - 4:
			return true
	return false


func _check_boulders() -> void:
	# a dash/slide smashes boulders too, so they never block you for good
	if not player.sliding:
		return
	for b in boulders:
		if player.body_rect().grow(3).intersects(b[1]):
			_break_boulder(b)
			return


func _break_boulder(b: Array) -> void:
	boulders.erase(b)
	var r: Rect2 = b[1]
	b[0].queue_free()
	dust(r.get_center(), 14, Color("a89884"))
	camera.shake(2.0)
	Audio.sfx("break")
	score += 100
	for k in 3:
		_add_pie(Vector2(r.position.x + 4 + k * 12, GROUND_Y - 34 - (k % 2) * 10), false, false)


# --- rules -----------------------------------------------------------------------------
func _check_hens() -> void:
	for h in actors.get_children():
		if not h is Hen:
			continue
		match h.check_player(player):
			"bowl":
				if h.bowl(player.facing):
					_on_bowled(h)
			"stomp", "bounce":
				player.bounce()
				var mult := mini(1 << (player.combo - 1), 16)
				var pts := 50 * mult
				score += pts
				popup(h.global_position + Vector2(0, -20), "+%d" % pts + ("  X%d" % mult if mult > 1 else ""))
				Audio.sfx("stomp", 1.0 + 0.1 * player.combo)
				Audio.sfx(_bird_sound(h))
				dust(h.global_position, 10, Color.WHITE)
				Game.hit_stop(3)
			"knock":
				score += 25
				popup(h.global_position + Vector2(0, -20), "+25")
				Audio.sfx("honk" if h.kind == Hen.Kind.GOOSE else "cluck")
			"hurt":
				player.hurt(h.global_position.x)


func _check_deputy() -> void:
	if not deputy.body_rect().intersects(player.body_rect()):
		return
	var feet := player.global_position.y
	if player.velocity.y > 0.0 and feet - deputy.body_rect().position.y < 16.0:
		player.bounce()
		deputy.bonk()
		score += 100
		popup(deputy.global_position + Vector2(0, -60), "+100")
		Audio.sfx("bonk")
	elif deputy.state != Deputy.State.BONKED:
		player.hurt(deputy.global_position.x)


func _check_pies() -> void:
	var r := player.body_rect()
	for p in pies.get_children():
		if not p is Pie or p.is_queued_for_deletion() or not p.touches(r):
			continue
		if p.bonus:
			score += 100
			Audio.sfx("pie")
			dust(p.global_position, 5, Color("8ad06a"))
		else:
			collect_pie(p.global_position, p.golden)
			collected.append(p.position)
		p.queue_free()


## Score a pie (also used by the patrol car). Every 10 pies = +1 heart.
func collect_pie(at: Vector2, golden := false) -> void:
	pies_got += 1
	if golden:
		golden_got = true
		score += 1000
		popup(at + Vector2(0, -12), "GOLDEN PIE! +1000")
		Audio.sfx("golden_pie")
		dust(at, 16, Color("ffd23f"))
	else:
		score += 100
		Audio.sfx("pie")
		dust(at, 5, Color("f0c060"))
	pie_streak += 1
	if pie_streak >= PIES_PER_HEART:
		pie_streak = 0
		if player.hearts < Player.MAX_HEARTS:
			player.heal()
			Audio.sfx("heart")
			popup(player.global_position + Vector2(0, -60), "+1 HEART!", Color("ff7a6a"))


func _bird_sound(h: Hen) -> String:
	return "honk" if h.kind in [Hen.Kind.GOOSE, Hen.Kind.DUCK] else "cluck"


# --- power-ups (Dewey's Lightning Soda, Jim's mower) -------------------------------
var _shazam_t := 0
var mowed_px := 0.0
var _mow_next := 140.0
var _mow_pies := 0
const MOW_PIES_MAX := 6


func on_powerup(kind: String, at: Vector2) -> void:
	score += 500
	popup(at + Vector2(0, -20), "%s! +500" % GameText.POWERUPS.get(hero, kind.to_upper()), Color("ffe060"))
	Audio.sfx("golden_pie")
	dust(at, 20, Color("ffe060") if kind == "soda" else Color("8ad06a"))
	camera.shake(2.0)
	var l := hero_line("powerup")
	if l != "":
		player.get_node("Bubble").show_text(Names.fmt(l), 90, "powerup")


func _on_bowled(h: Hen) -> void:
	score += 100
	popup(h.global_position + Vector2(0, -26), "+100")
	Audio.sfx(_bird_sound(h), randf_range(0.9, 1.2))
	Audio.sfx("stomp", 1.2)
	dust(h.global_position + Vector2(0, -8), 12, Color.WHITE)       # feathers
	camera.shake(1.5)
	var t := Time.get_ticks_msec()
	if t > _shazam_t:
		_shazam_t = t + 900
		var l := hero_line("bird")
		if l != "":
			player.get_node("Bubble").show_text(Names.fmt(l), 50, "shazam" if hero == "dewey" else "bird")


## Jim's mower cuts the grass it drives over and now and then turns up a pie.
func _mow() -> void:
	if player.power != "mower" or not player.is_on_floor():
		return
	var g := world.get_node_or_null("Grass") as GrassFringe
	if g and g.mow(player.global_position.x - 14.0, player.global_position.x + 14.0):
		mowed_px += absf(player.velocity.x) / 60.0
		if mowed_px > _mow_next and _mow_pies < MOW_PIES_MAX:
			_mow_next = mowed_px + randf_range(120.0, 220.0)
			_mow_pies += 1
			var p := Pie.new()
			p.bonus = true
			p.position = player.global_position + Vector2(player.facing * 40.0, -14.0)
			pies.add_child(p)
			popup(p.position + Vector2(0, -16), "FOUND ONE!", Color("8ad06a"))


## A platform with "bounce": true (e.g. a shop awning) launches you up instead
## of just holding you: {"type": platforms entry, "x", "w", "h", "bounce": true}.
## Hold jump for a higher bounce, same as the clothesline spring.
func _check_platforms() -> void:
	if not player.is_on_floor():
		return
	for pf in data.platforms:
		if not pf.get("bounce", false):
			continue
		var top: float = GROUND_Y - pf.h * TILE
		var x: float = player.global_position.x
		if absf(player.global_position.y - top) < 3.0 and x > pf.x * TILE and x < (pf.x + pf.w) * TILE:
			var held := Input.is_action_pressed("jump")
			player.velocity.y = AWNING_BOUNCE_HELD if held else AWNING_BOUNCE
			player.jumping = false
			player.visual.squash(Vector2(0.8, 1.25))
			Audio.sfx("jump", 0.7)


## A powered-up mower plows straight through crates instead of stopping at them.
func _check_crates() -> void:
	if player.power != "mower":
		return
	var pr: Rect2 = player.body_rect()
	for i in data.crates.size():
		if crates_destroyed.has(i):
			continue
		var c = data.crates[i]
		var r := Rect2(c.x * TILE, GROUND_Y - CRATE * (c.stack + 1), CRATE, CRATE)
		if r.grow(2).intersects(pr):
			_smash_crate(i)


func _smash_crate(i: int) -> void:
	crates_destroyed[i] = true
	crate_bodies[i].queue_free()
	var c = data.crates[i]
	dust(Vector2(c.x * TILE + 16.0, GROUND_Y - CRATE * c.stack - 16.0), 12, Color("c89a5c"))
	Audio.sfx("break", 1.1)
	camera.shake(1.5)
	$World/Terrain.queue_redraw()


func _spawn_powerups() -> void:
	if role != "sheriff" or hero == "sheriff":
		return
	for o in data.get("objects", []):
		if o.type == "powerup":
			return          # the level places its own
	# otherwise two, about a third and two thirds of the way along, on solid ground
	var holder := world.get_node("Objects")
	for f in [0.3, 0.66]:
		var x := _ground_tile_near(f * data.width_tiles)
		if x < 0.0:
			continue
		var n := Node2D.new()
		n.set_script(load("res://scripts/levels/objects/powerup.gd"))
		holder.add_child(n)
		n.setup(self, {"type": "powerup", "x": x, "h": 1.2})


## The middle of the nearest stretch of ground to tile x (or -1).
func _ground_tile_near(x: float) -> float:
	var best := -1.0
	for seg in data.ground:
		if seg[1] - seg[0] < 4:
			continue
		var c: float = clampf(x, seg[0] + 2.0, seg[1] - 2.0)
		if best < 0.0 or absf(c - x) < absf(best - x):
			best = c
	return best


func on_lasso_earl(e: Earl) -> bool:
	if e.lassoed():
		score += 150
		var msg: String = GameText.UI.roped_tackle if e.roped_t > 0 else GameText.UI.roped
		popup(e.global_position + Vector2(0, -56), msg, Color("ff9a3a"))
		Audio.sfx("bonk", 0.8)
		Game.hit_stop(3)
		return true
	popup(e.global_position + Vector2(0, -56), GameText.UI.lasso_missed, Color("c8c0b0"))
	return false


func on_lasso_hen(h: Hen) -> void:
	score += 75
	popup(h.global_position + Vector2(0, -24), "ROPED! +75")
	Audio.sfx(_bird_sound(h))


func _on_combo_ended(count: int) -> void:
	popup(player.global_position + Vector2(0, -60), "COMBO X%d!" % count, Color("ff9a3a"))


func _on_earl_cornered() -> void:
	phase = Phase.SHOWDOWN
	camera.punch_pair(player, earl, 1.3, 1.3)
	popup(earl.global_position + Vector2(0, -64), GameText.UI.showdown, Color("ff9a3a"))
	Audio.music("showdown", true)


func _on_earl_tackled(n: int) -> void:
	score += 300
	popup(earl.global_position + Vector2(0, -56), "TACKLE %d/3!" % n, Color("ff9a3a"))
	camera.shake(3.0)
	Audio.sfx("tackle")
	dust(earl.global_position, 10, Color("d8c8a8"))
	Game.hit_stop(5)


func _on_earl_cuffed() -> void:
	score += 2000
	camera.punch_pair(player, earl, 1.6, 1.8)
	Game.slow_mo(0.3, 0.8)
	_win()


func _win() -> void:
	if finished:
		return
	Game.checkpoint = {}
	Game.record_win(data.id, time, pies_got, pies_total, golden_got, score, medals(), stars_got, favor_done)
	Lighting.confetti(world, player.global_position + Vector2(0, -40))
	phase = Phase.WON
	finished = true
	player.won = true
	player.input_enabled = false
	player.velocity.x = 0.0
	player.get_node("Bubble").show_text(Names.fmt(hero_line("win", Game.level_index, text.get("win", ""))), 400, data.id + "_win")
	Audio.sfx("win")


func _on_fell_out() -> void:
	camera.shake(3.0)
	if data.get("water", false):
		Audio.sfx("splash")
		dust(Vector2(player.global_position.x, GROUND_Y + 12), 16, Color("9ad0f0"))
	# a pit costs a heart, unless you're still flashing from the hit that sent you in
	if player.invuln == 0:
		player.hurt(player.global_position.x)
	if player.hearts > 0:
		player.respawn()
		player.invuln = Player.INVULN_FRAMES
		camera.snap_to_target()


var _hurt_line_t := 0


func _on_player_hurt() -> void:
	camera.shake(4.0)
	Audio.sfx("hurt")
	var t := Time.get_ticks_msec()
	if t > _hurt_line_t:
		var l := hero_line("hurt")
		if l != "":
			_hurt_line_t = t + 6000
			player.get_node("Bubble").show_text(Names.fmt(l), 90, "hurt")


func _on_player_died() -> void:
	phase = Phase.LOST
	finished = true
	var speaker: Node = deputy if deputy else earl
	speaker.say(text.get("lose", ""), 400, data.id + "_lose")
	Audio.sfx("lose")


func _on_landed(impact: float) -> void:
	if impact > 420.0:
		camera.shake(2.0)
	if impact > 200.0:
		dust(player.global_position, 6, Color("d8c8a8"))
		Audio.sfx("land", randf_range(0.9, 1.1))


# --- effects ---------------------------------------------------------------------------
func popup(at: Vector2, msg: String, color := Color("ffd23f")) -> void:
	var p := PopupScript.new()
	p.text = msg
	p.color = color
	p.position = at
	p.z_index = 20
	world.add_child(p)


func dust(at: Vector2, n: int, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = n
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.35
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = color
	p.emitting = true
	world.add_child(p)
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


# --- building --------------------------------------------------------------------------
func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "Missing level file " + path)
	var d = JSON.parse_string(f.get_as_text())
	assert(typeof(d) == TYPE_DICTIONARY, "Bad JSON in " + path)
	return d


func _rect_shape(parent: Node, rect: Rect2, one_way := false) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.get_center()
	cs.one_way_collision = one_way
	parent.add_child(cs)


func _build_solids() -> void:
	var body := StaticBody2D.new()
	body.name = "Solids"
	body.collision_layer = LAYER_SOLID
	body.collision_mask = 0
	world.add_child(body)
	for seg in data.ground:
		var x0: float = seg[0] * TILE
		var x1: float = seg[1] * TILE
		_rect_shape(body, Rect2(x0, GROUND_Y, x1 - x0, GROUND_DEPTH))
	for c in data.crates:
		var cbody := StaticBody2D.new()
		cbody.collision_layer = LAYER_SOLID
		cbody.collision_mask = 0
		world.add_child(cbody)
		_rect_shape(cbody, Rect2(c.x * TILE, GROUND_Y - CRATE * (c.stack + 1), CRATE, CRATE))
		crate_bodies.append(cbody)
	# invisible walls at both edges, and the end-of-level fence
	_rect_shape(body, Rect2(-TILE, -400, TILE, 1000))
	_rect_shape(body, Rect2(fence_px(), GROUND_Y - FENCE_H, TILE * 1.5, FENCE_H))
	_rect_shape(body, Rect2(width_px, -400, TILE, 1000))


## Ground tiles via Godot terrain autotiling, plus the pits/water behind them.
func _build_tiles() -> void:
	if data.get("train", false):
		return                 # The Last Train: the train_cars object draws the "ground"
	var terrain: Node2D = $World/Terrain
	var pits := Node2D.new()
	pits.name = "Pits"
	pits.draw.connect(func(): terrain.draw_pits(pits))
	world.add_child(pits)
	world.move_child(pits, 0)
	if data.get("water", false):
		# reflective lake surface in every gap between ground segments
		var x := -TILE * 2.0
		var segs: Array = data.ground.duplicate()
		segs.append([data.width_tiles + 2, data.width_tiles + 3])
		for seg in segs:
			var a: float = seg[0] * TILE
			if a > x + 1.0:
				Water.make(world, Rect2(x, GROUND_Y + 10.0, a - x, 110.0))
			x = seg[1] * TILE
	var tiles := TileMap.new()             # Godot 4.1: TileMap (TileMapLayer is 4.3+)
	tiles.name = "Ground"
	tiles.tile_set = SpriteLib.terrain_tileset(data.get("theme", "town"))
	tiles.collision_animatable = false     # collision comes from _build_solids()
	world.add_child(tiles)
	world.move_child(tiles, 1)
	var cells: Array[Vector2i] = []
	var top := int(GROUND_Y / TILE)
	for seg in data.ground:
		for x in range(int(seg[0]), int(seg[1])):
			for y in range(top, top + 6):
				cells.append(Vector2i(x, y))
	tiles.set_cells_terrain_connect(0, cells, 0, 0, false)


func _build_platforms() -> void:
	var body := StaticBody2D.new()
	body.name = "OneWay"
	body.collision_layer = LAYER_ONEWAY
	body.collision_mask = 0
	world.add_child(body)
	for p in data.platforms:
		_rect_shape(body, Rect2(p.x * TILE, GROUND_Y - p.h * TILE, p.w * TILE, 6), true)
