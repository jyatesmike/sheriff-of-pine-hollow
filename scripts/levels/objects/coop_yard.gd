# The hen yard at the start of the Chicken Run. Earl has let the hens out,
# and the farm gate won't open until every hen is back in the coop.
# Hens run away from the Sheriff, so get behind them (hop over) and walk
# them home. Earl waits on the far side of the gate, jeering.
#   {"type": "coop_yard", "x": 12, "coop": 50, "gate": 60, "hens": [18, 26, 33, 40]}
extends LevelObject

const HenScene := preload("res://scenes/actors/hen.tscn")
const GATE_H := 128.0

var hens: Array = []
var coop := 0.0          # local x of the coop door
var gate := 0.0          # local x of the gate
var opened := false
var swing := 0.0         # 0 shut .. 1 wide open
var gate_body: StaticBody2D
var started := false
var _t := 0.0


func _setup() -> void:
	coop = (o.coop - o.x) * TILE
	gate = (o.gate - o.x) * TILE
	gate_body = add_box(Rect2(gate - 4, -GATE_H, 10, GATE_H), 1)
	for hx in o.get("hens", []):
		var h = HenScene.instantiate()
		level.actors.add_child(h)
		h.setup(Hen.Kind.HERD, Vector2(global_position.x + 10.0, global_position.x + coop), level.GROUND_Y)
		h.global_position = Vector2(hx * TILE, level.GROUND_Y)
		h.coop_x = global_position.x + coop
		h.herder = level.player
		h.dir = -1 if hens.size() % 2 == 0 else 1
		pass  # (4.3 physics interpolation not in 4.1)
		hens.append(h)


func home_count() -> int:
	var n := 0
	for h in hens:
		if h.home:
			n += 1
	return n


func step(delta: float) -> void:
	_t += delta
	var p := player()
	if not started:
		started = true
		if p.global_position.x > global_position.x + gate:
			_open(true)                     # resumed from a checkpoint past the gate
		elif level.earl:
			level.earl.state = Earl.State.WAIT
			level.earl.global_position = Vector2(global_position.x + gate + 70.0, level.GROUND_Y)
			pass  # (4.3 physics interpolation not in 4.1)
			level.earl.say(GameText.CR_EARL_GATE, 150, "cr_gate")
	for h in hens:
		if h.home and not h.get_meta("counted", false):
			h.set_meta("counted", true)
			level.popup(Vector2(global_position.x + coop, level.GROUND_Y - 50), GameText.CR_HEN_HOME, Color("8ae08a"))
			level.score += 100
			Audio.sfx("cluck", 1.2)
			if home_count() == hens.size():
				level.score += 1000
				level.popup(Vector2(global_position.x + gate, level.GROUND_Y - 90), GameText.CR_ALL_HOME, Color("ffd23f"))
				Audio.sfx("heart")
				_open(false)
	if opened:
		swing = move_toward(swing, 1.0, delta * 1.5)
	queue_redraw()


func _open(silent: bool) -> void:
	if opened:
		return
	opened = true
	gate_body.queue_free()
	for h in hens:
		if not h.home:
			h.home = true
			h.set_meta("counted", true)
			h.visible = false
			h.set_physics_process(false)
	if level.earl and level.earl.state == Earl.State.WAIT:
		level.earl.state = Earl.State.CHASE
		if not silent:
			level.earl.say(GameText.CR_EARL_FREE, 110, "cr_free")
	if silent:
		swing = 1.0


## Used by the test bot: walk around behind the leftmost loose hen and push it home.
func bot_hint(p: Player) -> Dictionary:
	if opened or p.global_position.x > global_position.x + gate + 20.0:
		return {}
	var target: Node2D = null
	for h in hens:
		if not h.home and (target == null or h.global_position.x < target.global_position.x):
			target = h
	if target == null:
		return {}
	var dx: float = target.global_position.x - p.global_position.x
	if dx < 26.0:
		# get to its left: run back and hop over it
		return {"dir": -1.0, "jump": dx > -60.0 and dx < 26.0 and target.is_on_floor()}
	return {"dir": 1.0}


func _draw() -> void:
	var wood := Color("a87a46")
	var dark := Color("6a4a2a")
	# yard fence (left)
	for k in 3:
		outlined_rect(Rect2(-4 + k * 3, -40, 3, 40), wood)
	outlined_rect(Rect2(-6, -34, 12, 3), dark)
	outlined_rect(Rect2(-6, -18, 12, 3), dark)
	# the coop: little red henhouse with a ramp up to the door
	var cx := coop
	var red := Color("b0442e")
	draw_rect(Rect2(cx - 1, -63, 70, 64), OUTLINE)
	draw_rect(Rect2(cx, -62, 68, 62), red)
	for y in range(-58, 0, 6):
		draw_rect(Rect2(cx, y, 68, 1), red.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 8, -60), Vector2(cx + 76, -60), Vector2(cx + 34, -86)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, -61), Vector2(cx + 73, -61), Vector2(cx + 34, -83)]), Color("6a3a2a"))
	outlined_rect(Rect2(cx + 2, -26, 18, 26), Color("2a1a10"))            # door
	outlined_rect(Rect2(cx + 40, -48, 16, 12), Color("e8d8a0"))            # window
	draw_rect(Rect2(cx + 47, -48, 1, 12), dark)
	var n := home_count()
	PixelFont.draw_centered(self, "%d/%d" % [n, hens.size()], cx + 34, -74, Color("fff6dc"))
	# straw by the door
	for k in 6:
		draw_rect(Rect2(cx - 10 + k * 3, -2 - (k % 2), 4, 2), Color("e8c860"))
	# the big farm gate
	var gx := gate
	outlined_rect(Rect2(gx - 6, -GATE_H - 6, 6, GATE_H + 6), dark)        # hinge post
	outlined_rect(Rect2(gx + 46, -GATE_H - 6, 6, GATE_H + 6), dark)       # far post
	var w := 46.0 * (1.0 - swing * 0.85)
	for k in 6:
		var y := -GATE_H + 8 + k * 22.0
		outlined_rect(Rect2(gx, y, w, 6), wood)
	outlined_rect(Rect2(gx, -GATE_H + 2, 4, GATE_H - 2), wood)
	outlined_rect(Rect2(gx + w - 4, -GATE_H + 2, 4, GATE_H - 2), wood)
	if not opened:
		# sign on the gate
		var lines: Array = GameText.CR_GATE_SIGN
		var sw := 0
		for l in lines:
			sw = maxi(sw, PixelFont.width(l))
		var r := Rect2(gx - sw - 18, -72, sw + 8, lines.size() * 9 + 4)
		draw_rect(r.grow(1), OUTLINE)
		draw_rect(r, Color("f0e4c4"))
		for i in lines.size():
			PixelFont.draw_centered(self, lines[i], r.get_center().x, r.position.y + 3 + i * 9, Color("3a2414"))
		PixelFont.draw_centered(self, GameText.CR_HENS % [n, hens.size()], r.get_center().x, r.end.y + 4, Color("ffd23f"))
