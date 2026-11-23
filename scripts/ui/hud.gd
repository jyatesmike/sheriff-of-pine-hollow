# HUD: portrait + hearts + pies (top left), closing-in meter / tackle count
# (top centre), score + time (top right), intro blurb, pause overlay,
# results and lose panels, and an F3 debug readout.
extends CanvasLayer

const TEXT := Color("fff2c0")
const ACCENT := Color("ffd23f")
const PANEL := Color("5a2e1a")
const PANEL_EDGE := Color("c8901c")

var level: Level
var canvas: Node2D
var debug := false
var intro_t := 4.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = Node2D.new()
	add_child(canvas)
	canvas.draw.connect(_on_draw)


func setup(l: Level) -> void:
	level = l


var pause_sel := 0


func _pause_items() -> Array:
	var m: Dictionary = GameText.MENU
	var items := [m.pause_resume]
	if not Game.checkpoint.is_empty():
		items.append(m.pause_checkpoint)
	items.append(m.pause_restart)
	items.append(m.pause_menu)
	return items


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		debug = not debug
	if not get_tree().paused:
		pause_sel = 0
		return
	var items := _pause_items()
	if event.is_action_pressed("up"):
		pause_sel = posmod(pause_sel - 1, items.size())
	elif event.is_action_pressed("down"):
		pause_sel = posmod(pause_sel + 1, items.size())
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		var m: Dictionary = GameText.MENU
		match items[pause_sel]:
			m.pause_resume: Game.set_paused(false)
			m.pause_checkpoint: Game.restart_level(true)
			m.pause_restart: Game.restart_level()
			m.pause_menu: Game.go_to_title()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := int((event.position.y - 117.0) / 12.0)
		if i >= 0 and i < items.size() and absf(event.position.x - 240.0) < 90.0:
			pause_sel = i
			var ev := InputEventAction.new()
			ev.action = "jump"
			ev.pressed = true
			_unhandled_input(ev)
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	intro_t = maxf(intro_t - delta, 0.0)
	canvas.queue_redraw()


func _on_draw() -> void:
	if level == null:
		return
	var p := level.player
	_hud_portrait(level.hero)
	for i in Player.MAX_HEARTS:
		if i < p.hearts:
			canvas.draw_texture(SpriteLib.prop("heart"), Vector2(35 + i * 10, 5))
		elif i < 3:
			canvas.draw_texture(SpriteLib.prop("heart_empty"), Vector2(35 + i * 10, 5))
	canvas.draw_texture(SpriteLib.prop("pie"), Vector2(34, 16))
	PixelFont.draw(canvas, "X%d" % level.pies_got, Vector2(52, 20), TEXT)
	if level.golden_got:
		canvas.draw_texture(SpriteLib.prop("pie_gold"), Vector2(72, 16))
	if p.can_throw:
		canvas.draw_texture(SpriteLib.prop("rock"), Vector2(88, 18))
		PixelFont.draw(canvas, "X%d" % p.rocks, Vector2(100, 20), TEXT)
	if level.stars_total > 0:
		for i in level.stars_total:
			_star(Vector2(38 + i * 9, 33), i < level.stars_got)
	if p.power_t > 0.0:
		# power-up timer under the portrait
		var name: String = GameText.POWERUPS.get(level.hero, "")
		var k := clampf(p.power_t / Player.POWER_SECS, 0.0, 1.0)
		var br := Rect2(6, 46, 70, 4)
		PixelFont.draw(canvas, name, Vector2(6, 39), Color("ffe060") if p.power == "soda" else Color("8ad06a"))
		canvas.draw_rect(br.grow(1), PixelFont.OUTLINE)
		canvas.draw_rect(br, Color("3a2a2a"))
		var col := Color.from_hsv(fmod(level.time * 2.0, 1.0), 0.6, 1.0) if p.power == "soda" else Color("6ab04a")
		canvas.draw_rect(Rect2(br.position, Vector2(br.size.x * k, br.size.y)), col)

	if level.in_chase():
		var c: Node2D = level.chase
		_meter(c.closeness(), GameText.UI.milk_truck)
		PixelFont.draw_centered(canvas, "BUMPS %d/3" % c.bumps, 240, 24, TEXT)
		var mph = "%d MPH" % c.mph()
		PixelFont.draw(canvas, mph, Vector2(476 - PixelFont.width(mph, 2), 252), ACCENT, 2)
		if c._t < 5.0:
			_label_box_at(GameText.CHASE_CONTROLS, 236)
		if c.msg_t > 0:
			_label_box_at(c.msg, 60)
	elif level.phase == Level.Phase.CHASE:
		_meter(level.closing_in(), GameText.UI.deputy_near if level.role == "earl" else GameText.UI.closing_in)
	elif level.phase == Level.Phase.SHOWDOWN:
		_label_box("SHOWDOWN!  TACKLES %d/3" % level.earl.tackles)

	var sc := "%06d" % level.score
	PixelFont.draw(canvas, "SCORE", Vector2(476 - PixelFont.width(sc, 2), 4), ACCENT)
	PixelFont.draw(canvas, sc, Vector2(476 - PixelFont.width(sc, 2), 11), TEXT, 2)
	var tm := _fmt_time(level.time)
	PixelFont.draw(canvas, tm, Vector2(476 - PixelFont.width(tm), 24), TEXT)

	var t: Dictionary = level.text
	if intro_t > 0.0 and not level.finished:
		if Lighting.enabled():
			_comic_intro(t)
		else:
			_panel([Names.fmt(t.get("episode", ""))] + _fmt_lines(t.get("blurb", [])), 40)

	if level.phase == Level.Phase.WON and level.end_t > 60:
		_results()
	elif level.phase == Level.Phase.LOST and level.end_t > 50:
		_panel([Names.fmt(GameText.UI["lose_title_" + level.role]), "",
			GameText.UI.try_checkpoint if not Game.checkpoint.is_empty() else GameText.UI.try_again, GameText.MENU.end_menu], 90)

	if get_tree().paused:
		canvas.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.45))
		var items := _pause_items()
		var rect := Rect2(150, 95, 180, 30 + items.size() * 12)
		canvas.draw_rect(rect.grow(1), PixelFont.OUTLINE)
		canvas.draw_rect(rect, PANEL)
		canvas.draw_rect(rect.grow(-2), PANEL_EDGE, false, 1.0)
		PixelFont.draw_centered(canvas, GameText.UI.paused, 240, 101, ACCENT, 2)
		for i in items.size():
			var y := 117.0 + i * 12.0
			if i == pause_sel:
				canvas.draw_rect(Rect2(160, y - 3, 160, 11), Color(0, 0, 0, 0.4))
			PixelFont.draw_centered(canvas, items[i], 240, y, ACCENT if i == pause_sel else TEXT)

	if debug:
		var lines := [
			"VEL %d, %d" % [p.velocity.x, p.velocity.y],
			"ANIM " + p.anim + ("  FLOOR" if p.is_on_floor() else ""),
			"COYOTE %d  BUFFER %d  COMBO %d" % [p.coyote, p.jump_buffer, p.combo],
			("EARL " + Earl.State.keys()[level.earl.state] if level.earl else "DEPUTY " + Deputy.State.keys()[level.deputy.state]) + "  FPS %d" % Engine.get_frames_per_second(),
		]
		for i in lines.size():
			PixelFont.draw(canvas, lines[i], Vector2(6, 238 + i * 8), TEXT)


# --- pieces --------------------------------------------------------------------------
func _meter(v: float, label: String) -> void:
	var w := 120.0
	var x := 240.0 - w / 2.0
	PixelFont.draw_centered(canvas, label, 240, 4, ACCENT)
	var r := Rect2(x, 11, w, 8)
	canvas.draw_rect(r.grow(1), PixelFont.OUTLINE)
	canvas.draw_rect(r, Color("3a2414"))
	var segs := 10
	for i in segs:
		if float(i + 1) / segs <= v + 0.05:
			var c := Color("ffd23f").lerp(Color("ff6a3a"), float(i) / segs)
			canvas.draw_rect(Rect2(x + 1 + i * (w / segs), 12, w / segs - 2, 6), c)


func _label_box(t: String) -> void:
	var w := PixelFont.width(t) + 10
	var r := Rect2(240 - w / 2.0, 6, w, 11)
	canvas.draw_rect(r.grow(1), PixelFont.OUTLINE)
	canvas.draw_rect(r, PANEL)
	PixelFont.draw_centered(canvas, t, 240, 9, ACCENT)


func _label_box_at(t: String, y: float) -> void:
	var w := PixelFont.width(t) + 10
	var r := Rect2(240 - w / 2.0, y, w, 11)
	canvas.draw_rect(r.grow(1), PixelFont.OUTLINE)
	canvas.draw_rect(r, PANEL)
	PixelFont.draw_centered(canvas, t, 240, y + 3, ACCENT)


## The results screen: time / pies / stars with their medals, the favor and the score.
func _results() -> void:
	var last := Game.level_index == Game.LEVELS.size() - 1
	var md: Dictionary = level.medals()
	var names: Array = GameText.UI.medal_names
	var rect := Rect2(130, 52, 220, 150)
	canvas.draw_rect(rect.grow(1), PixelFont.OUTLINE)
	canvas.draw_rect(rect, PANEL)
	canvas.draw_rect(rect.grow(-2), PANEL_EDGE, false, 1.0)
	PixelFont.draw_centered(canvas, Names.fmt(GameText.UI["win_title_" + level.role]), 240, 60, ACCENT, 2)
	var rows := [
		["TIME", _fmt_time(level.time), md.time],
		["PIES", "%d / %d" % [level.pies_got, level.pies_total], md.pies],
		["STARS", "%d / %d" % [level.stars_got, level.stars_total], md.stars],
	]
	for i in rows.size():
		var y := 80.0 + i * 14.0
		PixelFont.draw(canvas, rows[i][0], Vector2(146, y), TEXT)
		PixelFont.draw(canvas, rows[i][1], Vector2(196, y), TEXT)
		_medal(Vector2(268, y + 2), rows[i][2])
		PixelFont.draw(canvas, names[rows[i][2]], Vector2(276, y), _medal_color(rows[i][2]) if rows[i][2] > 0 else TEXT)
	var y2 := 124.0
	PixelFont.draw(canvas, "GOLDEN PIE", Vector2(146, y2), TEXT)
	PixelFont.draw(canvas, "YES" if level.golden_got else "NO", Vector2(276, y2), ACCENT if level.golden_got else TEXT)
	if level.favor_obj:
		PixelFont.draw(canvas, GameText.UI.favor, Vector2(146, y2 + 12), TEXT)
		PixelFont.draw(canvas, GameText.UI.favor_yes if level.favor_done else GameText.UI.favor_no, Vector2(276, y2 + 12), ACCENT if level.favor_done else TEXT)
	PixelFont.draw(canvas, "SCORE", Vector2(146, y2 + 24), TEXT)
	PixelFont.draw(canvas, "%d" % level.score, Vector2(276, y2 + 24), ACCENT)
	PixelFont.draw_centered(canvas, GameText.UI.last_level if last else GameText.UI.next_level, 240, 178, TEXT)
	PixelFont.draw_centered(canvas, GameText.MENU.end_menu, 240, 189, TEXT)


static func _medal_color(m: int) -> Color:
	return [Color("6a5a4a"), Color("c8844a"), Color("d0d4dc"), Color("ffd23f")][clampi(m, 0, 3)]


func _medal(at: Vector2, m: int) -> void:
	canvas.draw_circle(at, 4.5, PixelFont.OUTLINE)
	canvas.draw_circle(at, 3.5, _medal_color(m))
	if m > 0:
		canvas.draw_rect(Rect2(at + Vector2(-1, -2), Vector2(1, 2)), Color(1, 1, 1, 0.7))


func _star(at: Vector2, got: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var r := 4.0 if k % 2 == 0 else 1.8
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	var out := PackedVector2Array()
	for q in pts:
		out.append(at + (q - at) * 1.35)
	canvas.draw_colored_polygon(out, PixelFont.OUTLINE)
	canvas.draw_colored_polygon(pts, Color("ffd23f") if got else Color("4a4038"))


func _panel(lines: Array, y: float) -> void:
	var w := 0
	for l in lines:
		w = maxi(w, PixelFont.width(str(l), 1))
	var h := lines.size() * 10 + 8
	var rect := Rect2(240 - w / 2.0 - 10, y, w + 20, h)
	canvas.draw_rect(rect.grow(1), PixelFont.OUTLINE)
	canvas.draw_rect(rect, PANEL)
	canvas.draw_rect(rect.grow(-2), PANEL_EDGE, false, 1.0)
	for i in lines.size():
		PixelFont.draw_centered(canvas, str(lines[i]), 240, y + 6 + i * 10, ACCENT if i == 0 else TEXT)


## Episode intro as two comic panels that slam in: the villain's mug shot
## and a caption box with the episode title and blurb.
func _comic_intro(t: Dictionary) -> void:
	var ep: String = Names.fmt(t.get("episode", ""))
	var parts := ep.split(" - ", true, 1)
	var head_line: String = parts[0]
	var title: String = parts[1].replace("\"", "") if parts.size() > 1 else ""
	var blurb := _fmt_lines(t.get("blurb", []))
	var age := 4.0 - intro_t
	var ease := func(u: float) -> float:
		u = clampf(u, 0.0, 1.0)
		return 1.0 + 2.2 * pow(u - 1.0, 3.0) + 1.2 * pow(u - 1.0, 2.0)     # overshoot
	var ka: float = ease.call(age / 0.35)
	var kb: float = ease.call((age - 0.12) / 0.35)
	var lift := 0.0 if intro_t > 0.45 else (1.0 - intro_t / 0.45) * 160.0
	# panel A: mug shot
	var who := "earl" if level.role == "sheriff" else "deputy"
	var a := Rect2(lerpf(-130.0, 12.0, ka), 46.0 - lift, 108.0, 86.0)
	canvas.draw_set_transform(a.get_center(), -0.03, Vector2.ONE)
	var la := Rect2(-a.size / 2.0, a.size)
	canvas.draw_rect(la.grow(3), Color("fff6dc"))
	canvas.draw_rect(la.grow(1), PixelFont.OUTLINE)
	canvas.draw_rect(la, Color("e8802e"))
	for yy in range(int(la.position.y) + 3, int(la.end.y), 5):
		for xx in range(int(la.position.x) + 2 + (yy / 5 % 2) * 2, int(la.end.x), 5):
			canvas.draw_rect(Rect2(xx, yy, 1, 1), Color("c85a1e"))
	var burst := PackedVector2Array()
	for k in 16:
		var r := 40.0 if k % 2 == 0 else 26.0
		var ang := k * TAU / 16.0 + age * 0.4
		burst.append(Vector2(cos(ang), sin(ang)) * r + Vector2(0, 4))
	canvas.draw_colored_polygon(burst, Color("ffd23f"))
	var face := SpriteLib.head(who)
	if face.size() > 0:
		var fr := Rect2(-33, -30, 66, 66)
		canvas.draw_texture_rect_region(face[0], fr, face[1])
	canvas.draw_rect(Rect2(la.position.x, la.end.y - 12, la.size.x, 12), PixelFont.OUTLINE)
	PixelFont.draw_centered(canvas, Names.fmt("{%s}" % who), 0, la.end.y - 9, Color("ffd23f"))
	# panel B: caption + blurb
	var b := Rect2(lerpf(500.0, 128.0, kb), 46.0 - lift, 340.0, 86.0)
	canvas.draw_set_transform(b.get_center(), 0.015, Vector2.ONE)
	var lb := Rect2(-b.size / 2.0, b.size)
	canvas.draw_rect(lb.grow(3), Color("fff6dc"))
	canvas.draw_rect(lb.grow(1), PixelFont.OUTLINE)
	canvas.draw_rect(lb, Color("fbf3e0"))
	canvas.draw_rect(Rect2(lb.position + Vector2(0, lb.size.y - 4), Vector2(lb.size.x, 4)), Color("e8dcc0"))
	var cap := Rect2(lb.position + Vector2(-6, -8), Vector2(PixelFont.width(head_line.to_upper()) + 14.0, 13.0))
	canvas.draw_rect(cap.grow(1), PixelFont.OUTLINE)
	canvas.draw_rect(cap, Color("ffd23f"))
	PixelFont.draw(canvas, head_line, cap.position + Vector2(7, 3), PixelFont.OUTLINE)
	var tsc := 2 if PixelFont.width(title.to_upper(), 2) < lb.size.x - 20 else 1
	PixelFont.draw_centered(canvas, title, 1, lb.position.y + 13, Color("e8a830"), tsc)
	PixelFont.draw_centered(canvas, title, 0, lb.position.y + 12, Color("a8321e"), tsc)
	for i in blurb.size():
		PixelFont.draw_centered(canvas, str(blurb[i]), 0, lb.position.y + 38 + i * 11, Color("3a2414"))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Top-left mug shot, cut from the character's own sprite sheet so new art
## (e.g. from PixelLab) shows up here too.
func _hud_portrait(role: String) -> void:
	var face := SpriteLib.head(role)
	var r := Rect2(Vector2(4, 4), Vector2(28, 28))
	if face.is_empty():
		canvas.draw_texture(SpriteLib.prop("portrait_" + role), r.position)
		return
	canvas.draw_rect(r, PixelFont.OUTLINE)
	canvas.draw_rect(r.grow(-1), Color("8a6a42"))
	canvas.draw_rect(r.grow(-2), Color("e8c890"))
	canvas.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 8)), Color("f4dcaa"))
	canvas.draw_texture_rect_region(face[0], r.grow(-2), face[1])


func _fmt_lines(a: Array) -> Array:
	var out := []
	for l in a:
		out.append(Names.fmt(str(l)))
	return out


static func _fmt_time(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
