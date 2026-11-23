# A place to hide from the flashlights: stand in front and press UP to
# duck in, press UP (or LEFT/RIGHT/JUMP) again to slip out. Beams pass
# right over you. (The bloodhound can still smell you!)
#   {"type": "hiding_spot", "x": 26, "kind": "hedge"}   kinds: hedge, barrel, doorway, basket
extends LevelObject

var tucked := false
var near := false
var _t := 0.0


func step(delta: float) -> void:
	_t += delta
	var p := player()
	near = absf(p.global_position.x - global_position.x) < 16.0 and p.is_on_floor()
	if tucked:
		p.velocity = Vector2.ZERO
		p.global_position.x = global_position.x
		if Input.is_action_just_pressed("up") or Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right") or Input.is_action_just_pressed("jump") or p.hearts <= 0:
			_set_hidden(false)
	elif near and Input.is_action_just_pressed("up") and p.ride == null:
		_set_hidden(true)
	queue_redraw()


func _set_hidden(on: bool) -> void:
	tucked = on
	var p := player()
	p.set_meta("hidden", on)
	p.visible = not on
	p.input_enabled = not on
	Audio.sfx("dash", 0.6 if on else 0.9)


## Test bot: hide here while a walking watchman comes this way; slip out once he's gone past.
func bot_hint(p: Player) -> Dictionary:
	var threat := false
	for w in get_tree().get_nodes_in_group("watchers"):
		if not w.walker:
			continue
		var gx: float = w.global_position.x + w.wx
		var dx: float = global_position.x - gx
		if absf(dx) < w.length + 50.0 and signf(dx) == w.wdir:
			threat = true
	if tucked:
		return {"dir": 0.0, "up": not threat}
	if threat and absf(p.global_position.x - global_position.x) < 70.0:
		if near:
			return {"dir": 0.0, "up": true}
		return {"dir": signf(global_position.x - p.global_position.x)}
	return {}


func _draw() -> void:
	var kind: String = o.get("kind", "hedge")
	match kind:
		"hedge":
			for k in 5:
				draw_circle(Vector2(-14 + k * 7, -12 - (k % 2) * 6), 9.0, OUTLINE)
			for k in 5:
				draw_circle(Vector2(-14 + k * 7, -12 - (k % 2) * 6), 8.0, Color("2a5a2a"))
			draw_rect(Rect2(-20, -12, 40, 12), Color("2a5a2a"))
		"barrel":
			outlined_rect(Rect2(-12, -30, 24, 30), Color("7a5232"))
			draw_rect(Rect2(-12, -24, 24, 2), Color("4a4a50"))
			draw_rect(Rect2(-12, -8, 24, 2), Color("4a4a50"))
		"doorway":
			outlined_rect(Rect2(-14, -56, 28, 56), Color("3a2a1a"))
			draw_rect(Rect2(-11, -53, 22, 53), Color("120c08"))
			draw_rect(Rect2(-18, -60, 36, 4), Color("5a4a3a"))
		"basket":
			outlined_rect(Rect2(-16, -26, 32, 26), Color("b8945a"))
			for y in range(-22, 0, 5):
				draw_rect(Rect2(-16, y, 32, 1), Color("8a6a3a"))
			for k in 4:
				draw_rect(Rect2(-14 + k * 8, -30, 7, 5), Color("e8e0d0"))     # laundry poking out
	if tucked:
		var blink := int(_t * 1.5) % 4 != 0
		var ey := -40.0 if kind == "doorway" else -20.0
		if blink:
			draw_rect(Rect2(-4, ey, 2, 2), Color("fff6dc"))
			draw_rect(Rect2(2, ey, 2, 2), Color("fff6dc"))
	elif near and int(_t * 3.0) % 2 == 0:
		PixelFont.draw_centered(self, GameText.NB_HIDE_HINT, 0, -70, Color("ffd23f"))
