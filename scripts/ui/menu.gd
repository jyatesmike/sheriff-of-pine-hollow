# The title screen and its menus: PLAY / CHOOSE EPISODE / SETTINGS /
# EDIT NAMES / QUIT. Everything is drawn with the pixel font, and works
# with keyboard, gamepad, mouse and touch. All the words are in
# scripts/config/game_text.gd (MENU).
extends Node2D

enum Screen { TITLE, EPISODES, SETTINGS, NAMES, CREDITS, CONTROLS }

const W := 480.0
const H := 270.0
const ROW := 14.0
const OUTLINE := Color("24140e")
const GOLD := Color("ffd23f")
const CREAM := Color("fff6dc")
const DIM := Color("8a8070")
const NAME_KEYS := ["town", "sheriff", "earl", "dewey", "jim", "deputy"]
const MAX_NAME := 16

var screen := Screen.TITLE
var sel := 0
var scroll := 0
var editing := -1              # index of the name being typed, or -1
var edit_text := ""
var fresh := false             # first key typed replaces the old name
var waiting := ""              # CONTROLS: the action waiting for a new key / button
var confirm_erase := false
var rows: Array = []           # [text, value_text, enabled] for the current screen
var row_rects: Array = []      # clickable areas
var layers: Array = []         # [texture, speed]
var _t := 0.0
var held := 0                  # frames a left/right key has been held (for sliders)


func _ready() -> void:
	for l in [["sky", 0.0], ["far", 6.0], ["mid", 14.0], ["main", 26.0], ["near", 40.0]]:
		var path = "res://art/backgrounds/town/%s.png" % l[0]
		if ResourceLoader.exists(path):
			layers.append([load(path), l[1]])
	Audio.music("title")
	Game.release_all_actions()
	_build_rows()


# --- rows for each screen ---------------------------------------------------------------
func _build_rows() -> void:
	rows.clear()
	var m: Dictionary = GameText.MENU
	match screen:
		Screen.TITLE:
			var nxt := Game.next_unplayed()
			rows.append([m.play if nxt == 0 else m["continue"] % (nxt + 1), "", true])
			rows.append([_who_label(), "", true])
			rows.append([m.episodes, "", true])
			rows.append([m.settings, "", true])
			rows.append([m.names, "", true])
			rows.append([m.credits, "", true])
			if not OS.has_feature("web"):
				rows.append([m.quit, "", true])
		Screen.EPISODES:
			for i in Game.LEVELS.size():
				var info: Dictionary = GameText.LEVELS.get(Game.LEVELS[i], {})
				rows.append(["%d  %s" % [i + 1, Names.fmt(info.get("name", Game.LEVELS[i]))], "", Game.is_unlocked(i)])
			rows.append([m.back, "", true])
		Screen.SETTINGS:
			var s: Dictionary = Game.settings
			rows.append([m.music_volume, _bar(s.music_volume), true])
			rows.append([m.sfx_volume, _bar(s.sfx_volume), true])
			rows.append([m.voice_volume, _bar(s.voice_volume), true])
			rows.append([m.voices_on, m.on if s.voices_on else m.off, true])
			rows.append([m.zoom, _zoom_label(), true])
			rows.append([m.screen_shake, m.on if s.screen_shake else m.off, true])
			rows.append([m.scanlines, m.on if s.scanlines else m.off, true])
			rows.append([m.fancy_effects, m.on if s.fancy_effects else m.off, true])
			if not OS.has_feature("web"):
				rows.append([m.fullscreen, m.on if s.fullscreen else m.off, true])
			rows.append([m.unlock_all, m.on if s.unlock_all else m.off, true])
			rows.append([m.controls_menu, "", true])
			rows.append([m.reset_confirm if confirm_erase else m.reset_progress, "", true])
			rows.append([m.back, "", true])
		Screen.CONTROLS:
			for a in Game.REMAPPABLE:
				rows.append([m["ctl_" + a], Game.control_label(a), true])
			rows.append([m.reset_controls, "", true])
			rows.append([m.back, "", true])
		Screen.NAMES:
			for k in NAME_KEYS:
				rows.append([m["name_" + k], Names.values[k], true])
			for i in Names.signs.size():
				rows.append([m.shop % (i + 1), Names.signs[i], true])
			rows.append([m.reset_names, "", true])
			rows.append([m.back, "", true])
	sel = clampi(sel, 0, rows.size() - 1)


func _zoom_label() -> String:
	var z: float = Game.settings.get("zoom", 0.0)
	if z <= 0.0:
		return "%s (%sX)" % [GameText.MENU.zoom_auto, String.num(Game.zoom(), 2)]
	return "%sX" % String.num(z, 2)


func _who_label() -> String:
	var who: Dictionary = GameText.HEROES.get(Game.character(), {})
	return "%s:  %s" % [GameText.MENU.playing_as, Names.fmt(who.get("label", "{sheriff}")).to_upper()]


func _bar(v: float) -> String:
	return "%%%f" % v              # drawn as a slider by _list()


# --- input ---------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if waiting != "":
		_capture(event)
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	if editing >= 0:
		_edit_input(event)
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var i := _row_at(event.position)
		if i >= 0 and rows[i][2]:
			sel = i
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _row_at(event.position)
		if i >= 0:
			sel = i
			_activate(0)
		elif screen == Screen.TITLE:
			pass
		return
	if screen == Screen.CREDITS and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
		_back()
		return
	var on_map := screen == Screen.EPISODES
	if event.is_action_pressed("up"):
		_move(-1)
	elif event.is_action_pressed("down"):
		_move(1)
	elif event.is_action_pressed("left"):
		if on_map:
			_move(-1)
		else:
			_activate(-1)
	elif event.is_action_pressed("right"):
		if on_map:
			_move(1)
		else:
			_activate(1)
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		_activate(0)
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_back()
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _row_at(pos: Vector2) -> int:
	# the viewport is 480x270; mouse events arrive in viewport coordinates
	for i in row_rects.size():
		if row_rects[i] is Rect2 and row_rects[i].has_point(pos):
			return i
	return -1


func _move(d: int) -> void:
	confirm_erase = false
	for k in rows.size():
		sel = posmod(sel + d, rows.size())
		if rows[sel][2]:
			break
	Audio.sfx("pickup", 1.5)
	_build_rows()


func _go(to: int) -> void:
	screen = to
	sel = 0
	scroll = 0
	confirm_erase = false
	Audio.sfx("dash", 1.2)
	_build_rows()


func _back() -> void:
	if screen == Screen.TITLE:
		return
	if screen == Screen.CONTROLS:
		_go(Screen.SETTINGS)
		return
	_go(Screen.TITLE)


## CONTROLS: the next key or pad button pressed becomes the new control.
func _capture(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			waiting = ""
			Audio.sfx("dash", 0.8)
		else:
			Game.set_control(waiting, event)
			waiting = ""
			Audio.sfx("heart")
		_build_rows()
	elif event is InputEventJoypadButton and event.pressed:
		Game.set_control(waiting, event)
		waiting = ""
		Audio.sfx("heart")
		_build_rows()


## dir: 0 = OK pressed, -1/+1 = left/right (sliders and switches).
func _activate(dir: int) -> void:
	var m: Dictionary = GameText.MENU
	var label: String = rows[sel][0]
	match screen:
		Screen.TITLE:
			if label == _who_label():
				var cs: Array = Game.CHARACTERS
				var i := (cs.find(Game.character()) + (dir if dir != 0 else 1) + cs.size()) % cs.size()
				Game.settings.character = cs[i]
				Game.save_game()
				Audio.sfx("pickup")
				_build_rows()
				return
			if dir != 0:
				return
			match label:
				m.episodes: _go(Screen.EPISODES)
				m.settings: _go(Screen.SETTINGS)
				m.names: _go(Screen.NAMES)
				m.credits: _go(Screen.CREDITS)
				m.quit: get_tree().quit()
				_: _start(Game.next_unplayed())
		Screen.EPISODES:
			if dir != 0:
				return
			if sel == rows.size() - 1:
				_back()
			elif rows[sel][2]:
				_start(sel)
		Screen.SETTINGS:
			var s: Dictionary = Game.settings
			if label == m.back:
				if dir == 0:
					_back()
				return
			if label == m.controls_menu:
				if dir == 0:
					_go(Screen.CONTROLS)
				return
			if label == m.reset_progress or label == m.reset_confirm:
				if dir != 0:
					return
				if confirm_erase:
					Game.erase_progress()
					confirm_erase = false
					Audio.sfx("break")
				else:
					confirm_erase = true
				_build_rows()
				return
			if label == m.zoom:
				# AUTO, 100%, 125% ... 200%
				var opts: Array = [0.0] + Game.ZOOMS
				var i: int = opts.find(float(s.get("zoom", 0.0)))
				i = (maxi(i, 0) + (dir if dir != 0 else 1) + opts.size()) % opts.size()
				s.zoom = opts[i]
				Audio.sfx("pickup")
				Game.save_game()
				_build_rows()
				return
			var key := ""
			for k in ["music_volume", "sfx_volume", "voice_volume", "voices_on", "screen_shake", "scanlines", "fancy_effects", "fullscreen", "unlock_all"]:
				if label == m[k]:
					key = k
			if key == "":
				return
			if key.ends_with("volume"):
				var step := 0.1 if dir >= 0 else -0.1
				if dir == 0:
					s[key] = 0.0 if s[key] >= 0.95 else s[key] + 0.1
				else:
					s[key] = clampf(snappedf(s[key] + step, 0.1), 0.0, 1.0)
				Audio.apply_volumes()
				Audio.sfx("pie")
			else:
				s[key] = not s[key]
				if key == "fullscreen":
					Game.apply_display()
				if key == "scanlines":
					Game.apply_scanlines()
				Audio.sfx("pickup")
			Game.save_game()
			_build_rows()
		Screen.CONTROLS:
			if dir != 0:
				return
			if label == m.back:
				_back()
			elif label == m.reset_controls:
				Game.reset_controls()
				Audio.sfx("break", 1.4)
				_build_rows()
			else:
				waiting = Game.REMAPPABLE[sel]
				Audio.sfx("dash", 1.4)
		Screen.NAMES:
			if dir != 0:
				return
			if label == m.back:
				_back()
			elif label == m.reset_names:
				Names.reset_to_original()
				Audio.sfx("break", 1.4)
				_build_rows()
			else:
				editing = sel
				edit_text = rows[sel][1]
				fresh = true
				if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) and DisplayServer.is_touchscreen_available():
					DisplayServer.virtual_keyboard_show(edit_text)
				Audio.sfx("dash", 1.4)


func _start(i: int) -> void:
	Audio.sfx("win", 1.2)
	Game.go_to_level(i)


# --- typing a new name ------------------------------------------------------------------
func _edit_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_finish_edit(true)
		KEY_ESCAPE:
			_finish_edit(false)
		KEY_BACKSPACE:
			edit_text = edit_text.substr(0, maxi(edit_text.length() - 1, 0))
			fresh = false
		_:
			var c := char(event.unicode).to_upper() if event.unicode > 0 else ""
			if c != "" and PixelFont.GLYPHS.has(c):
				if fresh:
					edit_text = ""
					fresh = false
				if edit_text.length() < MAX_NAME:
					edit_text += c
				Audio.sfx("pickup", 1.8)


func _finish_edit(keep: bool) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	var t := edit_text.strip_edges()
	if keep and t != "":
		if editing < NAME_KEYS.size():
			Names.values[NAME_KEYS[editing]] = _title_case(t)
		else:
			Names.signs[editing - NAME_KEYS.size()] = t.to_upper()
		Names.store()
		Audio.sfx("heart")
	editing = -1
	_build_rows()


## Names show in speech as typed ("Pine Hollow"); the font draws capitals anyway.
func _title_case(t: String) -> String:
	var out := ""
	var up := true
	for ch in t.to_lower():
		out += ch.to_upper() if up else ch
		up = ch == " " or ch == "-"
	return out


# --- drawing ----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if screen == Screen.TITLE and Lighting.enabled():
		_title_scene()
	else:
		_backdrop()
	match screen:
		Screen.TITLE:
			_title()
			var panel := Rect2(W / 2.0 - 84, 138, 168, rows.size() * ROW + 10)
			draw_rect(panel.grow(2), OUTLINE)
			draw_rect(panel.grow(1), Color("8a6a42"))
			draw_rect(panel, Color(0.12, 0.07, 0.05, 0.88))
			for k in 4:
				draw_rect(Rect2(panel.position + Vector2(-1, -1) + Vector2(k % 2, k / 2) * (panel.size + Vector2(-1, -1)), Vector2(3, 3)), GOLD)
			_list(145.0, 140.0, false)
			# little arrows either side of PLAYING AS: left/right changes who you play
			var wi := rows.find(rows.filter(func(r): return r[0] == _who_label()).front())
			if wi >= 0 and row_rects.size() > wi and row_rects[wi] != null:
				var rr: Rect2 = row_rects[wi]
				var hw := PixelFont.width(_who_label()) / 2.0 + 6.0
				var cy := rr.position.y + 5.0
				var c := GOLD if sel == wi else DIM
				var nudge := 1.0 if sel == wi and int(_t * 3.0) % 2 == 0 else 0.0
				draw_colored_polygon(PackedVector2Array([Vector2(W / 2.0 - hw - nudge, cy), Vector2(W / 2.0 - hw + 4 - nudge, cy - 3), Vector2(W / 2.0 - hw + 4 - nudge, cy + 3)]), c)
				draw_colored_polygon(PackedVector2Array([Vector2(W / 2.0 + hw + nudge, cy), Vector2(W / 2.0 + hw - 4 + nudge, cy - 3), Vector2(W / 2.0 + hw - 4 + nudge, cy + 3)]), c)
		Screen.EPISODES:
			_map()
		Screen.CONTROLS:
			_heading(GameText.MENU.controls_menu)
			draw_rect(Rect2(W / 2.0 - 177, 44, 354, rows.size() * ROW + 12), Color(0.05, 0.03, 0.08, 0.5))
			_list(50.0, 330.0, true)
			var help: String = GameText.MENU.controls_wait if waiting != "" else GameText.MENU.controls_help
			PixelFont.draw_centered(self, help, W / 2.0, 36, GOLD if waiting != "" else DIM)
		Screen.CREDITS:
			var lines: Array = GameText.CREDITS
			for i in lines.size():
				PixelFont.draw_centered(self, Names.fmt(lines[i]), W / 2.0, 40.0 + i * 13.0, GOLD if i == 0 else CREAM, 2 if i == 0 else 1)
		Screen.SETTINGS:
			_heading(GameText.MENU.settings)
			draw_rect(Rect2(W / 2.0 - 162, 50, 324, rows.size() * ROW + 10), Color(0.05, 0.03, 0.08, 0.5))
			_list(56.0, 300.0, true)
		Screen.NAMES:
			_heading(GameText.MENU.names)
			draw_rect(Rect2(W / 2.0 - 177, 44, 354, H - 66), Color(0.05, 0.03, 0.08, 0.5))
			_list(50.0, 330.0, true)
			var help: String = GameText.MENU.editing_help if editing >= 0 else GameText.MENU.names_help
			PixelFont.draw_centered(self, help, W / 2.0, 36, DIM)
	PixelFont.draw_centered(self, GameText.MENU.map_help if screen == Screen.EPISODES else GameText.MENU.controls, W / 2.0, H - 10, DIM)


func _backdrop() -> void:
	for l in layers:
		var tex: Texture2D = l[0]
		var off: float = fmod(_t * l[1], tex.get_width())
		var y := H - tex.get_height() if l[1] > 0.0 else 0.0
		var x := -off
		while x < W:
			draw_texture(tex, Vector2(x, y))
			x += tex.get_width()
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.03, 0.08, 0.35 if screen == Screen.TITLE else 0.6))
	# the Sheriff chasing Earl along the bottom of the title screen
	if screen == Screen.TITLE:
		var loop := fmod(_t * 70.0, W + 200.0) - 100.0
		var earl := SpriteLib.frames("earl").get_frame_texture("run", int(_t * 10.0) % 6)
		var sheriff := SpriteLib.frames("sheriff").get_frame_texture("run", int(_t * 10.0 + 2) % 6)
		if earl:
			draw_texture(earl, Vector2(loop + 60, H - 22 - earl.get_height()))
		if sheriff:
			draw_texture(sheriff, Vector2(loop - 10, H - 22 - sheriff.get_height()))


## The painted title screen: sunset over the county, the town on the hill,
## the Sheriff in the foreground and Earl peeking out from behind a pine.
func _title_scene() -> void:
	# sky: banded sunset
	var bands := [Color("2a1e4a"), Color("3a2458"), Color("562a62"), Color("7a3266"), Color("a43e5e"),
		Color("c8564e"), Color("e07446"), Color("f09a4a"), Color("f8c060")]
	var bh := 150.0 / bands.size()
	for i in bands.size():
		draw_rect(Rect2(0, i * bh, W, bh + 1), bands[i])
		if i > 0:
			for x in range(int(fmod(i * 7.0, 4.0)), int(W), 4):         # dithered seam
				draw_rect(Rect2(x, i * bh, 2, 1), bands[i - 1])
	# stars in the top band
	for k in 26:
		var sx := fmod(k * 97.3, W)
		var sy := fmod(k * 41.7, 34.0)
		if int(_t * 3.0 + k) % 7 != 0:
			draw_rect(Rect2(sx, sy, 1, 1), Color(1, 0.95, 0.8, 0.8))
	# sun with slowly turning rays
	var sun := Vector2(W / 2.0, 150)
	for k in 14:
		var a := _t * 0.08 + k * TAU / 14.0
		var tri := PackedVector2Array([sun, sun + Vector2.from_angle(a - 0.07) * 330.0, sun + Vector2.from_angle(a + 0.07) * 330.0])
		draw_colored_polygon(tri, Color(1.0, 0.85, 0.5, 0.07))
	draw_circle(sun, 46.0, Color(1.0, 0.8, 0.45, 0.35))
	draw_circle(sun, 36.0, Color("ffd47a"))
	draw_circle(sun, 30.0, Color("ffe6a0"))
	for k in 4:
		draw_rect(Rect2(sun.x - 40, sun.y - 20 + k * 9, 80, 2 + k), Color("f09a4a"))
	# birds
	for k in 4:
		var bx := fmod(_t * (14.0 + k * 3.0) + k * 130.0, W + 40.0) - 20.0
		var by := 40.0 + k * 13.0 + sin(_t * 1.3 + k) * 4.0
		var fl := 2.0 if int(_t * 6.0 + k) % 2 == 0 else -1.0
		draw_line(Vector2(bx - 4, by - fl), Vector2(bx, by), OUTLINE, 1.0)
		draw_line(Vector2(bx, by), Vector2(bx + 4, by - fl), OUTLINE, 1.0)
	# far hills
	_hill(150.0, 14.0, 0.013, 1.0, Color("6a3a5e"))
	_hill(166.0, 10.0, 0.021, 2.4, Color("4e2e52"))
	# Pine Hollow on the ridge: houses, church steeple, water tower, lit windows
	var town := Color("2e1e36")
	var lit := Color("ffd27a")
	var bx2 := 300.0
	for i in 9:
		var hw := 10.0 + float((i * 7) % 9)
		var hh := 10.0 + float((i * 5) % 11)
		var base := 168.0 - sin((bx2) * 0.021 + 2.4) * 10.0
		draw_rect(Rect2(bx2, base - hh, hw, hh + 4), town)
		draw_colored_polygon(PackedVector2Array([Vector2(bx2 - 1, base - hh), Vector2(bx2 + hw + 1, base - hh), Vector2(bx2 + hw / 2.0, base - hh - 6)]), town)
		if int(_t * 0.5 + i) % 5 != 0:
			draw_rect(Rect2(bx2 + 3, base - hh + 4, 2, 2), lit)
		bx2 += hw + 3.0
	var ch := Vector2(286, 156)                       # church
	draw_rect(Rect2(ch.x, ch.y - 16, 12, 20), town)
	draw_colored_polygon(PackedVector2Array([Vector2(ch.x - 1, ch.y - 16), Vector2(ch.x + 13, ch.y - 16), Vector2(ch.x + 6, ch.y - 34)]), town)
	draw_line(Vector2(ch.x + 6, ch.y - 34), Vector2(ch.x + 6, ch.y - 40), town, 1.0)
	draw_line(Vector2(ch.x + 4, ch.y - 38), Vector2(ch.x + 8, ch.y - 38), town, 1.0)
	draw_rect(Rect2(ch.x + 5, ch.y - 10, 2, 3), lit)
	var wt := Vector2(432, 150)                       # water tower
	for dx in [-6.0, 6.0]:
		draw_line(Vector2(wt.x + dx, wt.y), Vector2(wt.x + dx * 1.4, wt.y + 22), town, 1.0)
	draw_line(Vector2(wt.x - 7, wt.y + 10), Vector2(wt.x + 7, wt.y + 10), town, 1.0)
	draw_colored_polygon(ellipse_pts(Vector2(wt.x, wt.y - 6), Vector2(11, 9)), town)
	draw_rect(Rect2(wt.x - 11, wt.y - 6, 22, 7), town)
	draw_colored_polygon(PackedVector2Array([Vector2(wt.x - 12, wt.y - 13), Vector2(wt.x + 12, wt.y - 13), Vector2(wt.x, wt.y - 22)]), town)
	# near hill with grass
	_hill(206.0, 8.0, 0.017, 0.6, Color("2a3a22"))
	_hill(218.0, 6.0, 0.03, 4.0, Color("223018"))
	for x in range(0, int(W), 3):
		var gy := 218.0 - sin(x * 0.03 + 4.0) * 6.0
		var lean := sin(_t * 1.6 + x * 0.05) * 1.2
		draw_line(Vector2(x, gy + 1), Vector2(x + lean, gy - 2 - (x * 7 % 4)), Color("3a5a2a"), 1.0)
	# pines, left and right
	_pine(Vector2(18, 232), 1.25)
	_pine(Vector2(452, 236), 1.5)
	_pine(Vector2(400, 240), 1.0)
	# Earl peeking out from behind the big pine, the Sheriff in front on the left
	var peek := 0.5 + 0.5 * sin(_t * 0.9)
	var et := SpriteLib.frames("earl").get_frame_texture("taunt", int(_t * 6.0) % 4)
	if et:
		draw_set_transform(Vector2(440 - peek * 18.0, 258), 0.0, Vector2(-2, 2))
		draw_texture(et, Vector2(-et.get_width() / 2.0, -et.get_height()))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_pine(Vector2(452, 262), 1.9, true)
	var anim := "tiphat" if fmod(_t, 7.0) < 0.7 else "idle"
	var stx := SpriteLib.frames(Game.character()).get_frame_texture(anim, int(_t * 7.0) % 4)
	if stx:
		draw_colored_polygon(ellipse_pts(Vector2(66, 260), Vector2(26, 4)), Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2(66, 262), 0.0, Vector2(2, 2))
		draw_texture(stx, Vector2(-stx.get_width() / 2.0, -stx.get_height()))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# fireflies rising out of the grass
	for k in 10:
		var fx := fmod(k * 53.0 + sin(_t * 0.7 + k) * 20.0, W)
		var fy := 250.0 - fmod(_t * (6.0 + k % 4) + k * 19.0, 90.0)
		var a := 0.5 + 0.5 * sin(_t * 4.0 + k * 1.7)
		draw_rect(Rect2(fx, fy, 1, 1), Color(1.0, 0.95, 0.5, a))


static func ellipse_pts(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _hill(y: float, amp: float, freq: float, phase: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, H)])
	for x in range(0, int(W) + 9, 8):
		pts.append(Vector2(x, y - sin(x * freq + phase) * amp))
	pts.append(Vector2(W, H))
	draw_colored_polygon(pts, col)


func _pine(base: Vector2, sc: float, front := false) -> void:
	var dark := Color("14200f") if front else Color("1a2a14")
	var mid := Color("22361a") if front else Color("26381c")
	draw_rect(Rect2(base.x - 2 * sc, base.y - 10 * sc, 4 * sc, 12 * sc), Color("2a1a10"))
	for k in 4:
		var w := (22.0 - k * 4.5) * sc
		var y := base.y - (8.0 + k * 13.0) * sc
		draw_colored_polygon(PackedVector2Array([Vector2(base.x - w - 1, y + 1), Vector2(base.x + w + 1, y + 1), Vector2(base.x, y - 20 * sc - 1)]), OUTLINE)
		draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, y), Vector2(base.x + w, y), Vector2(base.x, y - 20 * sc)]), dark)
		draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, y), Vector2(base.x - w * 0.2, y), Vector2(base.x, y - 20 * sc)]), mid)


func _title() -> void:
	if Lighting.enabled():
		_title_sign()
		return
	var top := Names.fmt(GameText.MENU.title_top)
	var main := Names.fmt(GameText.MENU.title_main)
	var bob := roundf(sin(_t * 2.0) * 2.0)
	# badge star
	var c := Vector2(W / 2.0, 30 + bob)
	var pts := PackedVector2Array()
	for k in 10:
		var r := 13.0 if k % 2 == 0 else 6.0
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var outer := PackedVector2Array()
	for q in pts:
		outer.append(c + (q - c) * 1.18)
	draw_colored_polygon(outer, OUTLINE)
	draw_colored_polygon(pts, GOLD)
	PixelFont.draw_centered(self, top, W / 2.0, 52 + bob, CREAM, 2)
	var sc := 5 if PixelFont.width(main, 5) < W - 20 else (4 if PixelFont.width(main, 4) < W - 20 else 3)
	var x := W / 2.0 - PixelFont.width(main, sc) / 2.0
	for dx in [-2, 2]:
		PixelFont.draw(self, main, Vector2(x + dx, 70 + bob), OUTLINE, sc, false)
	PixelFont.draw(self, main, Vector2(x, 72 + bob), OUTLINE, sc, false)
	PixelFont.draw(self, main, Vector2(x, 68 + bob), GOLD, sc, false)
	PixelFont.draw_centered(self, Names.fmt(GameText.MENU.tagline), W / 2.0, 104 + bob, CREAM)


## The title on a wooden sign hanging from two ropes, with a star badge.
func _title_sign() -> void:
	var top := Names.fmt(GameText.MENU.title_top)
	var main := Names.fmt(GameText.MENU.title_main)
	var swing := sin(_t * 1.1) * 0.012
	var piv := Vector2(W / 2.0, -6)
	draw_set_transform(piv, swing, Vector2.ONE)
	var sc := 4 if PixelFont.width(main, 4) < 300 else 3
	var tw := maxf(PixelFont.width(main, sc), PixelFont.width(top, 2)) + 40.0
	var r := Rect2(-tw / 2.0, 30, tw, 72)
	# ropes
	for dx in [-tw / 2.0 + 18.0, tw / 2.0 - 18.0]:
		draw_line(Vector2(dx, 0), Vector2(dx, r.position.y + 4), OUTLINE, 3.0)
		draw_line(Vector2(dx, 0), Vector2(dx, r.position.y + 4), Color("c8a060"), 1.0)
	# planks
	draw_rect(r.grow(2), OUTLINE)
	var woods := [Color("8a5a32"), Color("7a4e2a"), Color("94643a")]
	for k in 3:
		var pr := Rect2(r.position.x, r.position.y + k * 24.0, r.size.x, 24.0)
		draw_rect(pr, woods[k])
		draw_rect(Rect2(pr.position, Vector2(pr.size.x, 1)), woods[k].lightened(0.2))
		draw_rect(Rect2(pr.position + Vector2(0, 23), Vector2(pr.size.x, 1)), OUTLINE)
		for g in 5:
			var gx := pr.position.x + fmod(g * 71.0 + k * 33.0, pr.size.x - 30.0) + 10.0
			draw_line(Vector2(gx, pr.position.y + 8 + g % 3 * 4), Vector2(gx + 22, pr.position.y + 8 + g % 3 * 4), woods[k].darkened(0.2), 1.0)
		for nx in [r.position.x + 5, r.end.x - 7]:
			draw_rect(Rect2(nx, pr.position.y + 10, 2, 2), Color("c8c8d0"))
	# star badge on top
	var c := Vector2(0, r.position.y - 2)
	var pts := PackedVector2Array()
	for k in 10:
		var rr := 14.0 if k % 2 == 0 else 6.5
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	var outer := PackedVector2Array()
	for q in pts:
		outer.append(c + (q - c) * 1.2)
	draw_colored_polygon(outer, OUTLINE)
	draw_colored_polygon(pts, GOLD)
	draw_circle(c, 3.0, Color("c8901c"))
	var shine := fmod(_t * 0.6, 2.0)
	if shine < 1.0:
		var sx := lerpf(-12.0, 12.0, shine)
		draw_line(c + Vector2(sx - 3, 8), c + Vector2(sx + 3, -8), Color(1, 1, 0.9, 0.8), 2.0)
	# lettering
	PixelFont.draw_centered(self, top, 0, r.position.y + 10, CREAM, 2)
	var x := -PixelFont.width(main, sc) / 2.0
	var y := r.position.y + 30
	for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, 2), Vector2(0, -2), Vector2(2, 2)]:
		PixelFont.draw(self, main, Vector2(x, y) + d, OUTLINE, sc, false)
	PixelFont.draw(self, main, Vector2(x, y), Color("f0a830"), sc, false)
	PixelFont.draw(self, main, Vector2(x, y - 1), GOLD, sc, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	PixelFont.draw_centered(self, Names.fmt(GameText.MENU.tagline), W / 2.0, 116, CREAM)


func _heading(t: String) -> void:
	PixelFont.draw_centered(self, t, W / 2.0, 14, GOLD, 2)


## A plain menu list. With values: label on the left, value on the right.
func _list(y0: float, width: float, values: bool) -> void:
	row_rects.clear()
	var shown := int((H - 30.0 - y0) / ROW)
	if sel < scroll:
		scroll = sel
	elif sel >= scroll + shown:
		scroll = sel - shown + 1
	var x0 := W / 2.0 - width / 2.0
	for i in rows.size():
		row_rects.append(null)
		if i < scroll or i >= scroll + shown:
			continue
		var y := y0 + (i - scroll) * ROW
		var r := Rect2(x0 - 6, y - 3, width + 12, ROW - 2)
		row_rects[i] = r
		var chosen := i == sel
		if chosen:
			draw_rect(r, Color(0, 0, 0, 0.55))
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), GOLD)
		var col := (GOLD if chosen else CREAM) if rows[i][2] else DIM
		if values:
			PixelFont.draw(self, rows[i][0], Vector2(x0, y), col)
			var v: String = rows[i][1]
			if v.begins_with("%"):
				var k := float(v.substr(1))
				var br := Rect2(x0 + width - 82, y - 1, 80, 7)
				draw_rect(br.grow(1), OUTLINE)
				draw_rect(br, Color("3a2a2a"))
				draw_rect(Rect2(br.position, Vector2(br.size.x * k, br.size.y)), col)
				PixelFont.draw(self, "%d" % int(roundf(k * 10.0)), Vector2(br.position.x - 14, y), col)
				continue
			if i == editing:
				v = edit_text
				col = Color("8ae08a")
				if int(_t * 3.0) % 2 == 0:
					draw_rect(Rect2(x0 + width + 2, y, 3, 5), col)        # blinking cursor
			PixelFont.draw(self, v, Vector2(x0 + width - PixelFont.width(v), y), col)
		else:
			PixelFont.draw_centered(self, rows[i][0], W / 2.0, y, col)
	if scroll > 0:
		PixelFont.draw_centered(self, "-", W / 2.0, y0 - 9, DIM)
	if scroll + shown < rows.size():
		PixelFont.draw_centered(self, "...", W / 2.0, y0 + shown * ROW - 2, DIM)


func _episodes() -> void:
	row_rects.clear()
	var m: Dictionary = GameText.MENU
	var y := 40.0
	for i in rows.size():
		var last := i == rows.size() - 1
		var hgt := 14.0 if last else 36.0
		var r := Rect2(70, y - 4, W - 140, hgt - 2)
		row_rects.append(r)
		var chosen := i == sel
		draw_rect(r, Color(0, 0, 0, 0.65 if chosen else 0.4))
		if chosen:
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), GOLD)
		var col := (GOLD if chosen else CREAM) if rows[i][2] else DIM
		PixelFont.draw(self, rows[i][0], Vector2(r.position.x + 10, y), col, 1)
		if not last:
			var id: String = Game.LEVELS[i]
			var info: Dictionary = GameText.LEVELS.get(id, {})
			PixelFont.draw(self, Names.fmt(info.get("episode", "")), Vector2(r.position.x + 22, y + 10), DIM if not rows[i][2] else CREAM)
			var p: Dictionary = Game.progress.get(id, {})
			var line: String = m.locked
			if rows[i][2]:
				line = m.not_played
				if p.get("done", false):
					line = m.best % [_fmt_time(p.get("best_time", 0.0)), p.get("best_pies", 0), p.get("pies_total", 0)]
					if p.get("golden", false):
						line += "   " + m.golden
			PixelFont.draw(self, line, Vector2(r.position.x + 22, y + 20), GOLD if p.get("golden", false) else DIM)
			if p.get("done", false):
				# medals: time, pies, stars (+ a tick for the favor)
				var md: Dictionary = p.get("medals", {})
				var mx := r.end.x - 70.0
				for k in ["time", "pies", "stars"]:
					var mv: int = md.get(k, 0)
					var c: Color = [Color("6a5a4a"), Color("c8844a"), Color("d0d4dc"), Color("ffd23f")][mv]
					draw_circle(Vector2(mx, y + 4), 5.0, OUTLINE)
					draw_circle(Vector2(mx, y + 4), 4.0, c)
					PixelFont.draw_centered(self, k.substr(0, 1), mx, y + 12, DIM)
					mx += 14.0
				if p.get("favor", false):
					PixelFont.draw_centered(self, "+", mx + 2, y + 2, Color("8ae08a"), 2)
		y += hgt


func _fmt_time(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]



# --- the county map (choose an episode) ---------------------------------------------------
const MAP_POS := [Vector2(62, 206), Vector2(122, 150), Vector2(190, 200), Vector2(246, 128),
		Vector2(312, 184), Vector2(372, 118), Vector2(430, 186)]


func _map() -> void:
	row_rects.clear()
	var m: Dictionary = GameText.MENU
	# land, river, hills
	draw_rect(Rect2(20, 64, W - 40, H - 84), OUTLINE)
	draw_rect(Rect2(22, 66, W - 44, H - 88), Color("5a8a3a"))
	for k in 18:
		var p := Vector2(40 + (k * 97) % 400, 80 + (k * 53) % 150)
		draw_circle(p, 9.0 + k % 3 * 3.0, Color("4e7a32"))
	var river := PackedVector2Array()
	for k in 30:
		var x := 22.0 + k * (W - 44.0) / 29.0
		river.append(Vector2(x, 100 + sin(k * 0.6) * 18.0 + k * 1.5))
	draw_polyline(river, Color("3a6a9a"), 6.0)
	draw_polyline(river, Color("6aa0d0"), 2.0)
	# the road between the places
	var road := PackedVector2Array(MAP_POS)
	draw_polyline(road, OUTLINE, 6.0)
	draw_polyline(road, Color("d8c090"), 4.0)
	for i in MAP_POS.size() - 1:
		var a: Vector2 = MAP_POS[i]
		var b: Vector2 = MAP_POS[i + 1]
		for k in 4:
			draw_rect(Rect2(a.lerp(b, (k + 0.5) / 4.0) - Vector2(1, 0), Vector2(2, 1)), Color("f4ecd0"))
	# places
	for i in Game.LEVELS.size():
		var p: Vector2 = MAP_POS[i] if i < MAP_POS.size() else Vector2(40 + i * 60, 200)
		var open := Game.is_unlocked(i)
		row_rects.append(Rect2(p - Vector2(16, 16), Vector2(32, 30)))
		_place_icon(i, p, open)
		var prog: Dictionary = Game.progress.get(Game.LEVELS[i], {})
		if prog.get("done", false):
			draw_circle(p + Vector2(12, -12), 4.0, OUTLINE)
			draw_circle(p + Vector2(12, -12), 3.0, Color("8ae08a"))
		PixelFont.draw_centered(self, str(i + 1), p.x, p.y + 10, CREAM if open else DIM)
	row_rects.append(null)
	# the Sheriff standing at the chosen place
	if sel < Game.LEVELS.size():
		var sp: Vector2 = MAP_POS[sel]
		var bob := roundf(absf(sin(_t * 5.0)) * -3.0)
		var tex := SpriteLib.prop("portrait_sheriff")
		if tex:
			draw_texture(tex, sp + Vector2(-tex.get_width() / 2.0, -46 + bob))
	# info about the chosen place
	var panel := Rect2(40, 8, W - 80, 52)
	draw_rect(panel.grow(1), OUTLINE)
	draw_rect(panel, Color(0.12, 0.08, 0.06, 0.92))
	if sel >= Game.LEVELS.size():
		PixelFont.draw_centered(self, Names.fmt(m.map_title), W / 2.0, 26, GOLD, 2)
		return
	var id: String = Game.LEVELS[sel]
	var info: Dictionary = GameText.LEVELS.get(id, {})
	PixelFont.draw_centered(self, "%d  %s" % [sel + 1, Names.fmt(info.get("name", id))], W / 2.0, 14, GOLD, 2)
	PixelFont.draw_centered(self, Names.fmt(info.get("episode", "")), W / 2.0, 30, CREAM)
	var prog: Dictionary = Game.progress.get(id, {})
	if not Game.is_unlocked(sel):
		PixelFont.draw_centered(self, m.locked, W / 2.0, 44, DIM)
	elif not prog.get("done", false):
		PixelFont.draw_centered(self, m.not_played, W / 2.0, 44, DIM)
	else:
		var line: String = m.best % [_fmt_time(prog.get("best_time", 0.0)), prog.get("best_pies", 0), prog.get("pies_total", 0)]
		PixelFont.draw(self, line, Vector2(60, 44), CREAM)
		var md: Dictionary = prog.get("medals", {})
		var mx := W - 150.0
		for k in ["time", "pies", "stars"]:
			var mv: int = md.get(k, 0)
			draw_circle(Vector2(mx, 46), 5.0, OUTLINE)
			draw_circle(Vector2(mx, 46), 4.0, [Color("6a5a4a"), Color("c8844a"), Color("d0d4dc"), Color("ffd23f")][mv])
			PixelFont.draw(self, k.substr(0, 1), Vector2(mx + 7, 44), DIM)
			mx += 24.0
		if prog.get("favor", false):
			PixelFont.draw(self, GameText.UI.favor, Vector2(mx + 4, 44), Color("8ae08a"))


func _place_icon(i: int, p: Vector2, open: bool) -> void:
	var tint := Color.WHITE if open else Color(0.45, 0.45, 0.45)
	match i:
		0:      # Main Street: a row of shops
			for k in 3:
				draw_rect(Rect2(p + Vector2(-13 + k * 9, -14 + (k % 2) * 3), Vector2(8, 14 - (k % 2) * 3)), Color("b0644a") * tint)
		1:      # barn
			draw_rect(Rect2(p + Vector2(-10, -10), Vector2(20, 10)), Color("a83a2a") * tint)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-12, -10), p + Vector2(12, -10), p + Vector2(0, -18)]), Color("6a2a1e") * tint)
		2:      # canyon rocks
			draw_colored_polygon(PackedVector2Array([p + Vector2(-13, 0), p + Vector2(-6, -16), p + Vector2(2, -6), p + Vector2(8, -14), p + Vector2(14, 0)]), Color("b0744a") * tint)
		3:      # lake
			draw_circle(p + Vector2(0, -6), 11.0, Color("3a6a9a") * tint)
			draw_rect(Rect2(p + Vector2(4, -10), Vector2(10, 2)), Color("8a6a42") * tint)
		4:      # night town: jail and a moon
			draw_rect(Rect2(p + Vector2(-10, -12), Vector2(20, 12)), Color("5a5a6a") * tint)
			for k in 3:
				draw_rect(Rect2(p + Vector2(-6 + k * 5, -10), Vector2(1, 8)), Color("2a2a32"))
			draw_circle(p + Vector2(10, -18), 4.0, Color("f0e8b0") * tint)
		5:      # Ferris wheel
			draw_arc(p + Vector2(0, -10), 9.0, 0, TAU, 16, Color("e8e0d0") * tint, 2.0)
			draw_line(p + Vector2(0, -10), p + Vector2(-6, 0), Color("8a8070") * tint, 2.0)
			draw_line(p + Vector2(0, -10), p + Vector2(6, 0), Color("8a8070") * tint, 2.0)
		6:      # the train
			draw_rect(Rect2(p + Vector2(-14, -8), Vector2(10, 7)), Color("8a3a2a") * tint)
			draw_rect(Rect2(p + Vector2(-2, -10), Vector2(14, 9)), Color("2a2a32") * tint)
			draw_rect(Rect2(p + Vector2(6, -15), Vector2(3, 5)), Color("2a2a32") * tint)
	if not open:
		draw_rect(Rect2(p + Vector2(-3, -8), Vector2(6, 5)), Color("c8a040"))
		draw_arc(p + Vector2(0, -8), 2.5, PI, TAU, 6, Color("c8a040"), 1.0)
