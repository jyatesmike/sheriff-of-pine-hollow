# Game: global state, settings and save/load (user://save.json).
# Also guards against "stuck" keys: every action is released when the
# window loses focus, and handles the global pause / restart actions.
extends Node

signal paused_changed(is_paused: bool)

const SAVE_PATH := "user://save.json"
const LEVEL_SCENE := "res://scenes/levels/level.tscn"
const TITLE_SCENE := "res://scenes/ui/title.tscn"
# Level order. Each id matches data/levels/<id>.json and GameText.LEVELS.
const LEVELS := ["main_street", "chicken_run", "rock_creek", "gone_fishin", "earls_big_break", "county_fair", "last_train"]

var level_index := 0
var checkpoint := {}          # last checkpoint reached in this level (see level.gd)

var settings := {
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"voice_volume": 0.8,
	"voices_on": true,
	"scanlines": true,
	"screen_shake": true,
	"fullscreen": false,
	"unlock_all": false,
	"fancy_effects": true,    # lighting, particles (turn off on slow computers)
	"character": "sheriff",   # who you play as (picked on the title screen)
	"zoom": 0.0,              # game zoom: 0 = automatic (bigger on small handheld screens), else 1.0 / 1.25 / 1.5 / 1.75 / 2.0
	"pixel_perfect": true,    # handheld screens: draw at the screen's own size, crisp (see _setup_display)
	"controls": {},           # action -> {"key": physical keycode, "joy": button}: your own keys
}

# Who you can play as (except in the jail-escape episode, where you're Earl).
const CHARACTERS := ["sheriff", "dewey", "jim"]


const ZOOMS := [1.0, 1.25, 1.5, 1.75, 2.0]


## How far the in-game camera is zoomed in. Handheld display: the whole number
## picked in _setup_display() (2x on the RG35XX), so every art pixel is an exact
## square of screen pixels. Otherwise automatic: 1.5x on small screens, 1x on a computer.
func zoom() -> float:
	if handheld:
		return float(world_scale)
	var z: float = settings.get("zoom", 0.0)
	if z > 0.0:
		return z
	return 1.5 if _small_screen() else 1.0


# ---------------- handheld display ----------------
# The game is designed at 480x270. On a computer that picture is scaled up to the
# window. On a small handheld screen (the RG35XX's 640x480) that scaling is uneven
# (1.33x: blurry, jagged pixels and black bars), so instead the game draws at the
# screen's own size: the world zoomed by a whole number (crisp), the HUD and menus
# laid out on the full screen at a whole-number scale.
const DESIGN := Vector2i(480, 270)
var handheld := false     # true once the handheld display is on
var world_scale := 1      # camera zoom in the handheld display
var ui_scale := 1         # HUD / menu scale in the handheld display


func _setup_display() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	if not settings.get("pixel_perfect", true):
		return
	var s := DisplayServer.screen_get_size()
	# Handheld-sized screens only (a laptop keeps the normal, scaled picture).
	if s.x <= 0 or s.y <= 0 or s.x > 1024 or s.y > 768:
		return
	var k := mini(s.x / 320, s.y / 180)    # show at least 320 x 180 of the world
	if k < 2:
		return
	handheld = true
	world_scale = k
	ui_scale = maxi(1, mini(s.x / DESIGN.x, s.y / DESIGN.y))
	var root := get_tree().root
	root.content_scale_size = s
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


## The size the HUD and menus lay themselves out in: 480x270 normally, the
## screen's own size (divided by the UI scale) in the handheld display.
func ui_size() -> Vector2:
	if handheld:
		return Vector2(get_tree().root.content_scale_size) / ui_scale
	return Vector2(DESIGN)


func _small_screen() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var sz := DisplayServer.screen_get_size()
	return sz.y > 0 and sz.y <= 800 and sz.x <= 1280


func character() -> String:
	var c: String = settings.get("character", "sheriff")
	return c if CHARACTERS.has(c) else "sheriff"


# Actions you can remap in Settings > CONTROLS (the first key / button of each).
const REMAPPABLE := ["left", "right", "up", "down", "jump", "action", "lasso", "throw", "pause", "restart"]
const PAD_NAMES := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "BACK", 6: "START", 7: "L-STICK", 8: "R-STICK",
	9: "LB", 10: "RB", 11: "UP", 12: "DOWN", 13: "LEFT", 14: "RIGHT"}
var _default_events := {}
var progress := {}   # level_id -> {best_time, pies, stars, medals}  (milestone 6)
var names_data := {} # filled by Names


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in REMAPPABLE:
		_default_events[a] = []
		for e in InputMap.action_get_events(a):
			_default_events[a].append(e.duplicate())
	load_game()
	apply_controls()
	_setup_display()
	apply_display.call_deferred()
	_add_scanlines()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all_actions()
		if is_inside_tree() and not get_tree().paused and _in_level():
			set_paused(true)


func release_all_actions() -> void:
	for a in InputMap.get_actions():
		Input.action_release(a)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _in_level():
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and _in_level():
		restart_level()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and _in_level():
		# Number keys 1-7 jump straight to a level
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < LEVELS.size():
			go_to_level(n)
			get_viewport().set_input_as_handled()


func _in_level() -> bool:
	var s := get_tree().current_scene
	return s != null and s.is_in_group("level")


func set_paused(p: bool) -> void:
	get_tree().paused = p
	paused_changed.emit(p)


## Reload the level. keep_checkpoint = true goes back to the last checkpoint
## (after losing); otherwise (R, or a new level) it starts from the beginning.
func restart_level(keep_checkpoint := false) -> void:
	if _changing:
		return
	_changing = true
	if not keep_checkpoint:
		checkpoint = {}
	await iris_close()
	Audio.stop_loops()
	Engine.time_scale = 1.0
	set_paused(false)
	release_all_actions()
	if _in_level():
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(LEVEL_SCENE)
	_changing = false
	iris_open()


func go_to_title() -> void:
	if _changing:
		return
	_changing = true
	checkpoint = {}
	await iris_close()
	Audio.stop_loops()
	Engine.time_scale = 1.0
	set_paused(false)
	release_all_actions()
	get_tree().change_scene_to_file(TITLE_SCENE)
	_changing = false
	iris_open()


# ---------------- iris wipe between scenes ----------------
var _iris: ColorRect
var _iris_busy := false
var _changing := false


func _iris_rect() -> ColorRect:
	if _iris == null:
		var layer := CanvasLayer.new()
		layer.layer = 120
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(layer)
		_iris = ColorRect.new()
		_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/iris.gdshader")
		_iris.material = m
		_iris.visible = false
		layer.add_child(_iris)
	return _iris


func _iris_tween(from: float, to: float, secs: float) -> void:
	var r := _iris_rect()
	var size := get_viewport().get_visible_rect().size
	var m := r.material as ShaderMaterial
	m.set_shader_parameter("screen", size)
	var c := size * 0.5
	var lv := get_tree().current_scene
	if lv and lv.get("player") is Node2D and lv.player.is_inside_tree():
		c = lv.player.get_global_transform_with_canvas().origin + Vector2(0, -24)
	m.set_shader_parameter("center", c)
	r.visible = true
	# stepped by the wall clock so pause and slow-motion don't affect it
	var start := Time.get_ticks_msec()
	while true:
		var u := clampf((Time.get_ticks_msec() - start) / (secs * 1000.0), 0.0, 1.0)
		m.set_shader_parameter("radius", lerpf(from, to, 0.5 - 0.5 * cos(u * PI)))
		if u >= 1.0:
			break
		await get_tree().process_frame


func iris_close() -> void:
	if DisplayServer.get_name() == "headless" or _iris_busy:
		return
	_iris_busy = true
	await _iris_tween(560.0, 0.0, 0.45)
	_iris_busy = false


func iris_open() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await _iris_tween(0.0, 560.0, 0.5)
	_iris.visible = false


# ---------------- progress ----------------
## A level is open once the one before it has been won (or "all unlocked" is on).
func is_unlocked(i: int) -> bool:
	return i == 0 or settings.unlock_all or progress.get(LEVELS[i - 1], {}).get("done", false)


## The first level not yet won (where PLAY / CONTINUE starts).
func next_unplayed() -> int:
	for i in LEVELS.size():
		if not progress.get(LEVELS[i], {}).get("done", false):
			return i
	return 0


## Called by the level when it's won: keep the best time / pies / score.
func record_win(id: String, time: float, pies: int, pies_total: int, golden: bool, score: int,
		medals := {}, stars := 0, favor := false) -> void:
	var p: Dictionary = progress.get(id, {})
	var best: Dictionary = p.get("medals", {})
	for k in medals:
		best[k] = maxi(best.get(k, 0), medals[k])
	p["medals"] = best
	p["best_stars"] = maxi(p.get("best_stars", 0), stars)
	p["favor"] = p.get("favor", false) or favor
	p["done"] = true
	p["best_time"] = minf(p.get("best_time", INF), time) if p.has("best_time") else time
	p["best_pies"] = maxi(p.get("best_pies", 0), pies)
	p["pies_total"] = pies_total
	p["golden"] = p.get("golden", false) or golden
	p["best_score"] = maxi(p.get("best_score", 0), score)
	progress[id] = p
	save_game()


func erase_progress() -> void:
	progress = {}
	save_game()


var _scan: CanvasLayer


## A light CRT scanline overlay over everything (Settings > SCANLINES).
func _add_scanlines() -> void:
	_scan = CanvasLayer.new()
	_scan.layer = 120
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/scanlines.gdshader")
	rect.material = mat
	_scan.add_child(rect)
	add_child(_scan)
	apply_scanlines()


func apply_scanlines() -> void:
	if _scan:
		_scan.visible = settings.scanlines


# ---------------- remapping ----------------
## Rebuild the input map: the defaults, with your chosen key / button in first place.
func apply_controls() -> void:
	var custom: Dictionary = settings.get("controls", {})
	for a in REMAPPABLE:
		var events: Array = []
		for e in _default_events.get(a, []):
			events.append(e.duplicate())
		var c: Dictionary = custom.get(a, {})
		if c.has("key"):
			var k := InputEventKey.new()
			k.physical_keycode = int(c.key)
			_replace_first(events, k)
		if c.has("joy"):
			var j := InputEventJoypadButton.new()
			j.button_index = int(c.joy)
			_replace_first(events, j)
		InputMap.action_erase_events(a)
		for e in events:
			InputMap.action_add_event(a, e)


func _replace_first(events: Array, with: InputEvent) -> void:
	for i in events.size():
		if events[i].get_class() == with.get_class():
			# drop the same key/button from the other slots so it isn't listed twice
			events[i] = with
			for j in range(events.size() - 1, i, -1):
				if events[j].get_class() == with.get_class() and _same(events[j], with):
					events.remove_at(j)
			return
	events.push_front(with)


func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	return a.button_index == b.button_index


func set_control(action: String, ev: InputEvent) -> void:
	var c: Dictionary = settings.controls.get(action, {})
	if ev is InputEventKey:
		c["key"] = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	elif ev is InputEventJoypadButton:
		c["joy"] = ev.button_index
	settings.controls[action] = c
	apply_controls()
	save_game()


func reset_controls() -> void:
	settings.controls = {}
	apply_controls()
	save_game()


## "SPACE / A" style label: the first key and first pad button of an action.
func control_label(action: String) -> String:
	var key := "-"
	var pad := "-"
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and key == "-":
			key = OS.get_keycode_string(e.physical_keycode if e.physical_keycode != 0 else e.keycode).to_upper()
		elif e is InputEventJoypadButton and pad == "-":
			pad = PAD_NAMES.get(e.button_index, "BTN %d" % e.button_index)
	return "%s  /  PAD %s" % [key, pad]


func apply_display() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


## Freeze the action for a few frames to sell an impact (stomps, tackles).
func hit_stop(frames := 3) -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(frames / 60.0, true, false, true).timeout
	if Engine.time_scale == 0.0:
		Engine.time_scale = 1.0


## Slow motion for `secs` real seconds (the final tackle).
func slow_mo(scale := 0.3, secs := 0.9) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(secs, true, false, true).timeout
	if Engine.time_scale == scale:
		Engine.time_scale = 1.0


func level_id() -> String:
	return LEVELS[level_index]


func go_to_level(i: int) -> void:
	level_index = posmod(i, LEVELS.size())
	restart_level()


func next_level() -> void:
	if level_index + 1 >= LEVELS.size():
		go_to_title()
	else:
		go_to_level(level_index + 1)


# ---------------- save / load ----------------
func save_game() -> void:
	var data := {"version": 1, "settings": settings, "progress": progress, "names": names_data}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	if typeof(data) != TYPE_DICTIONARY:
		return
	for k in data.get("settings", {}):
		if settings.has(k):
			settings[k] = data.settings[k]
	if typeof(settings.controls) != TYPE_DICTIONARY:
		settings.controls = {}
	progress = data.get("progress", {})
	names_data = data.get("names", {})
