# The pie-eating contest (a bonus). Stand at the table and press F to
# start; then mash F as fast as you can for 6 seconds. Out-eat the farmer
# and win a full set of hearts and 1000 points. One go per visit.
#   {"type": "pie_contest", "x": 108}
extends LevelObject

const LENGTH := 6.0
const PRESSES_PER_PIE := 4.0

var state := 0               # 0 ready, 1 countdown, 2 eating, 3 done
var t := 0.0
var presses := 0
var rival := 0.0
var won := false
var _t := 0.0


func _setup() -> void:
	if Lighting.enabled():
		add_child(Lighting.radial(Vector2(0, -60), Color(1, 0.85, 0.55), 1.2, 0.8))


func _near() -> bool:
	var p := player()
	return absf(p.global_position.x - global_position.x) < 26.0 and p.is_on_floor()


func step(delta: float) -> void:
	_t += delta
	var p := player()
	match state:
		0:
			if _near() and Input.is_action_just_pressed("throw"):
				state = 1
				t = 2.4
				p.input_enabled = false
				p.velocity = Vector2.ZERO
				Audio.say("barker", Names.fmt(GameText.CF_CONTEST_START), "cf_contest")
		1:
			t -= delta
			p.velocity.x = 0.0
			if t <= 0.0:
				state = 2
				t = LENGTH
				Audio.sfx("bell", 1.2)
		2:
			t -= delta
			p.velocity.x = 0.0
			if Input.is_action_just_pressed("throw"):
				presses += 1
				if presses % int(PRESSES_PER_PIE) == 0:
					Audio.sfx("pie", 1.0 + randf() * 0.3)
			rival += delta * (1.05 + 0.25 * sin(_t * 3.0))
			if t <= 0.0:
				state = 3
				p.input_enabled = true
				won = mine() > int(rival)
				if won:
					level.score += 1000
					while p.hearts < Player.MAX_HEARTS:
						p.heal()
					level.popup(global_position + Vector2(0, -80), GameText.CF_CONTEST_WIN, Color("ffd23f"))
					Audio.sfx("win", 1.2)
				else:
					level.score += 200
					level.popup(global_position + Vector2(0, -80), GameText.CF_CONTEST_LOSE, Color("e8dcc0"))
	queue_redraw()


func mine() -> int:
	return int(presses / PRESSES_PER_PIE)


## Test bot: stop at the table, start, and mash.
func bot_hint(p: Player) -> Dictionary:
	if state == 3:
		return {}
	var dx := global_position.x - p.global_position.x
	if state == 0:
		if absf(dx) > 12.0 and dx > -30.0 and dx < 120.0:
			return {"dir": signf(dx)}
		if absf(dx) <= 12.0:
			return {"dir": 0.0, "mash": true}
		return {}
	return {"dir": 0.0, "mash": true}


func _draw() -> void:
	# striped tent
	for k in 8:
		var col := Color("e84a4a") if k % 2 == 0 else Color("f4ece0")
		draw_rect(Rect2(-64 + k * 16, -90, 16, 20), col)
	draw_colored_polygon(PackedVector2Array([Vector2(-70, -90), Vector2(70, -90), Vector2(0, -116)]), Color("e84a4a"))
	draw_rect(Rect2(-66, -70, 4, 70), Color("8a6a42"))
	draw_rect(Rect2(62, -70, 4, 70), Color("8a6a42"))
	PixelFont.draw_centered(self, GameText.CF_CONTEST_SIGN, 0, -84, Color("3a2414"))
	# table with pies
	outlined_rect(Rect2(-40, -22, 80, 6), Color("a87a46"))
	draw_rect(Rect2(-36, -16, 3, 16), Color("6a4a2a"))
	draw_rect(Rect2(33, -16, 3, 16), Color("6a4a2a"))
	var tex := SpriteLib.prop("pie")
	var left := maxi(0, 4 - mine())
	for k in left:
		draw_texture(tex, Vector2(-30 + k * 10, -34))
	# the rival (a farmer) at the other end
	var bob := roundf(sin(_t * (14.0 if state == 2 else 2.0)))
	draw_rect(Rect2(28, -46 + bob, 14, 24), Color("4a6aa0"))
	draw_rect(Rect2(29, -58 + bob, 12, 12), Color("eab48a"))
	draw_rect(Rect2(26, -60 + bob, 18, 3), Color("c8a060"))
	draw_rect(Rect2(30, -66 + bob, 10, 6), Color("c8a060"))
	if state == 2:
		draw_circle(Vector2(36, -50 + bob), 2.0, Color("f0c060"))
	# scoreboard
	if state >= 1:
		var r := Rect2(-46, -140, 92, 30)
		draw_rect(r.grow(1), OUTLINE)
		draw_rect(r, Color("2a1a14"))
		var head: String = GameText.CF_COUNTDOWN[clampi(int(ceil(t)) - 1, 0, 2)] if state == 1 else ("%.1f" % maxf(t, 0.0) if state == 2 else (GameText.CF_CONTEST_WIN if won else GameText.CF_CONTEST_LOSE))
		PixelFont.draw_centered(self, head, 0, -136, Color("ffd23f"))
		PixelFont.draw(self, "YOU %d" % mine(), Vector2(-40, -124), Color("fff6dc"))
		PixelFont.draw(self, "FARMER %d" % int(rival), Vector2(4, -124), Color("fff6dc"))
	elif _near() and int(_t * 3.0) % 2 == 0:
		PixelFont.draw_centered(self, GameText.CF_CONTEST_HINT, 0, -134, Color("ffd23f"))
	if state == 2:
		PixelFont.draw_centered(self, GameText.CF_MASH, 0, -150, Color("ff9a3a") if int(_t * 8.0) % 2 == 0 else Color("ffd23f"))
