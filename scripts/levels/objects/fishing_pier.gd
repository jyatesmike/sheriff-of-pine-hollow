# The finale of Gone Fishin': Earl jumps in a rowboat at the end of the
# pier and rows for it. Stand at the end of the pier and press F (the
# throw button) to cast your line at his boat, then HOLD F to reel him in.
# When he yanks back ("!"), let go or the line snaps! Reel him all the way
# to the pier and he's caught.
#   {"type": "fishing_pier", "x": 280, "w": 20}
extends LevelObject

const OUT := 300.0           # how far out Earl rows
const REEL := 62.0           # px/s while reeling
const TUG := 32.0            # px/s Earl pulls away while tugging
const WARN := 40             # frames of warning ("!") before each yank

var w := 0.0
var state := 0               # 0 waiting, 1 Earl rowing out / out, 2 line flying, 3 hooked, 4 landed
var bx := 0.0                # boat distance out from the pier end
var tension := 0.0
var tug_t := 0               # frames left in Earl's current yank
var warn_t := 0              # frames left in the warning before a yank
var tug_cd := 150
var cast_t := 0.0
var snap_t := 0
var _t := 0.0


func _setup() -> void:
	w = o.get("w", 20) * TILE


func _end_x() -> float:
	return global_position.x + w


func _boat_pos() -> Vector2:
	return Vector2(w + 20.0 + bx, 12.0 + roundf(sin(_t * 2.2)))


func at_end(p: Player) -> bool:
	return p.is_on_floor() and p.global_position.x > _end_x() - 56.0


func step(delta: float) -> void:
	_t += delta
	var p := player()
	var e: Node2D = level.earl
	snap_t = maxi(snap_t - 1, 0)
	match state:
		0:
			if level.truck_x < 0.0:
				level.truck_x = _end_x() - 30.0      # (once the canoe's done) Earl jumps in the rowboat here
			elif e and e.state == Earl.State.WAIT and absf(level.truck_x - (_end_x() - 30.0)) < 1.0:
				state = 1
				bx = 0.0
		1:
			bx = move_toward(bx, OUT, 70.0 * delta)
			if at_end(p) and Input.is_action_just_pressed("throw") and p.facing > 0 and bx > 200.0:
				state = 2
				cast_t = 0.0
				Audio.sfx("throw", 1.2)
		2:
			cast_t += delta / 0.45
			if cast_t >= 1.0:
				state = 3
				tension = 0.0
				tug_cd = 45 + randi() % 40
				level.popup(global_position + _boat_pos() + Vector2(0, -50), GameText.GF_HOOKED, Color("ffd23f"))
				Audio.sfx("pickup", 0.6)
		3:
			var reeling := Input.is_action_pressed("throw")
			tug_cd -= 1
			if tug_cd <= 0 and tug_t == 0 and warn_t == 0:
				warn_t = WARN                       # Earl winds up first, so you can let go in time
				tug_cd = 130 + randi() % 90
				if e:
					var k := randi() % GameText.GF_EARL_TUG.size()
					e.say(GameText.GF_EARL_TUG[k], 60, "gf_tug_%d" % (k + 1))
			if warn_t > 0:
				warn_t -= 1
				if warn_t == 0:
					tug_t = 45 + randi() % 25
			if tug_t > 0:
				tug_t -= 1
				bx += TUG * delta
				tension += (1.6 if reeling else -0.6) * delta
			elif reeling:
				bx -= REEL * delta
				tension -= 0.3 * delta              # steady reeling lets the line ease off
			else:
				tension -= 0.8 * delta
				bx += 12.0 * delta                  # he keeps rowing while you rest
			tension = clampf(tension, 0.0, 1.0)
			bx = minf(bx, OUT + 40.0)
			if reeling and Engine.get_physics_frames() % 10 == 0:
				Audio.sfx("dash", 1.8)
			if tension >= 1.0 or not at_end(p):
				_snap()
			elif bx <= 24.0:
				_land()
	p.throw_t = maxi(p.throw_t, 2) if state == 3 and Input.is_action_pressed("throw") else p.throw_t
	queue_redraw()


func _snap() -> void:
	state = 1
	snap_t = 60
	tension = 0.0
	tug_t = 0
	Audio.sfx("break", 1.4)
	level.popup(player().global_position + Vector2(0, -64), GameText.GF_SNAP, Color("ff6a4a"))
	if level.earl:
		level.earl.say(GameText.GF_EARL_SNAP, 80, "gf_snap")


func _land() -> void:
	state = 4
	var e: Earl = level.earl
	if e == null:
		return
	e.global_position = Vector2(_end_x() - 20.0, global_position.y)
	e.visible = true
	pass  # (4.3 physics interpolation not in 4.1)
	e.tackles = Earl.TACKLES_NEEDED - 1
	e.state = Earl.State.IDLE
	e.on_contact()                      # caught: straight into the cuffs
	Audio.sfx("splash", 0.9)


## Test bot: walk to the end of the pier, cast, reel, let go when he tugs.
func bot_hint(p: Player) -> Dictionary:
	if state == 0 or state == 4:
		return {}
	if not at_end(p):
		return {"dir": 1.0}
	if p.facing < 0:
		return {"dir": 1.0}
	match state:
		1:
			return {"dir": 0.0, "cast": snap_t == 0 and bx > 210.0}
		3:
			return {"dir": 0.0, "reel": tug_t == 0 and tension < 0.85}   # (lets go late, like a person would)
	return {"dir": 0.0}


func _draw() -> void:
	var wood := Color("9a7a52")
	# pier planks + posts
	outlined_rect(Rect2(0, -5, w + 8, 6), wood)
	for k in range(4, int(w) + 8, 9):
		draw_rect(Rect2(k, -4, 1, 4), wood.darkened(0.3))
	for px in range(8, int(w) + 8, 40):
		draw_rect(Rect2(px, 1, 4, 30), wood.darkened(0.35))
	draw_rect(Rect2(w + 2, -14, 5, 44), wood.darkened(0.2))
	# the rowboat
	if state >= 1 and state <= 3:
		var bp := _boat_pos()
		var tex := SpriteLib.frames("earl").get_frame_texture("taunt" if tug_t == 0 else "throw", 0)
		if tex:
			draw_texture(tex, bp + Vector2(-tex.get_width() / 2.0, -tex.get_height() - 4))
		var hull := Color("6a8a5a")
		draw_colored_polygon(PackedVector2Array([bp + Vector2(-30, -14), bp + Vector2(30, -14), bp + Vector2(22, -2), bp + Vector2(-22, -2)]), OUTLINE)
		draw_colored_polygon(PackedVector2Array([bp + Vector2(-28, -13), bp + Vector2(28, -13), bp + Vector2(21, -3), bp + Vector2(-21, -3)]), hull)
		draw_rect(Rect2(bp + Vector2(-27, -13), Vector2(54, 2)), hull.lightened(0.3))
		var oar := sin(_t * (9.0 if tug_t > 0 or state == 1 else 2.0)) * 0.6
		draw_line(bp + Vector2(-4, -22), bp + Vector2(-4 - 22 * cos(oar), 6), Color("7a5230"), 2.0)
	# the fishing line
	var p := player()
	var hand := p.global_position + Vector2(10, -36) - global_position
	if state == 2 or state == 3:
		var bp2 := _boat_pos() + Vector2(-20, -16)
		var tip := hand.lerp(bp2, minf(cast_t, 1.0)) + Vector2(0, -sin(minf(cast_t, 1.0) * PI) * 40.0)
		if state == 3:
			tip = bp2
		var sag := 18.0 * (1.0 - tension)
		var mid := (hand + tip) * 0.5 + Vector2(0, sag)
		var col := Color(0.95, 0.95, 0.95) if tension < 0.7 else Color(1.0, 0.45, 0.35)
		draw_line(hand, mid, col, 1.0)
		draw_line(mid, tip, col, 1.0)
		draw_line(hand, hand + Vector2(-8, 10), Color("5a3a22"), 2.0)       # the rod
	# prompts + tension meter
	if state == 1 and bx > 200.0 and int(_t * 2.0) % 2 == 0:
		PixelFont.draw_centered(self, GameText.GF_CAST if at_end(p) else GameText.GF_GO_END, hand.x - 10, hand.y - 40, Color("ffd23f"))
	if state == 3:
		var r := Rect2(hand.x - 30, hand.y - 34, 60, 6)
		draw_rect(r.grow(1), OUTLINE)
		draw_rect(r, Color("3a2a2a"))
		draw_rect(Rect2(r.position, Vector2(r.size.x * tension, r.size.y)), Color("8ae08a").lerp(Color("ff4a3a"), tension))
		var msg: String = GameText.GF_REEL
		var mc := Color("ffd23f")
		if tug_t > 0:
			msg = GameText.GF_LET_GO
			mc = Color("ff6a4a")
		elif warn_t > 0:
			msg = GameText.GF_GET_READY
			mc = Color("ffa040")
		PixelFont.draw_centered(self, msg, r.get_center().x, r.position.y - 10, mc)
		# progress: how far Earl still is from the pier
		var k := clampf(1.0 - (bx - 24.0) / (OUT - 24.0), 0.0, 1.0)
		var pr := Rect2(hand.x - 30, hand.y - 26, 60, 3)
		draw_rect(pr.grow(1), OUTLINE)
		draw_rect(Rect2(pr.position, Vector2(pr.size.x * k, pr.size.y)), Color("6ab8ff"))
	# "!" over Earl while he winds up for a yank
	if state == 3 and (warn_t > 0 or tug_t > 0) and int(_t * 8.0) % 2 == 0:
		var bp3 := _boat_pos()
		PixelFont.draw_centered(self, "!", bp3.x, bp3.y - 70, Color("ff4a3a"), 2)
