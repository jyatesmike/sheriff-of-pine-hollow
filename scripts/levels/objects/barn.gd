# The big red barn. Three ways through:
#  - the ground floor: watch for bales tumbling off the loft edges, and duck
#    (slide) under the hay wall below the far loft;
#  - or climb the ladder (hold up) to the hayloft, rope the beam hook with
#    the lasso (E/Z) and swing across to the far loft, grabbing pies.
#   {"type": "barn", "x": 124, "w": 48}
extends LevelObject

const H := 10.5              # tiles: inside height (ceiling)
const LOFT := 6.0            # tiles: hayloft height
const CLIMB_SPEED := 95.0
const WALL_GAP := 26.0       # px: crawl space under the hay wall

var w := 0.0
var top := 0.0
var loft := 0.0
var ladder_x := 0.0
var wall := Vector2.ZERO     # local x range of the hay wall
var bales: Array = []        # falling bales: {x, y, vy, state}


func _setup() -> void:
	w = o.get("w", 48) * TILE
	top = tiles_up(H)
	loft = tiles_up(LOFT)
	ladder_x = 3.0 * TILE
	wall = Vector2(36.0 * TILE, 39.0 * TILE)
	add_box(Rect2(2 * TILE, loft, 18 * TILE, 6), 2, true)                 # near loft
	add_box(Rect2(31 * TILE, loft, w - 33 * TILE, 6), 2, true)            # far loft
	add_box(Rect2(-8, top - 8, w + 16, 8), 1)                             # roof (ceiling)
	# the hay wall: solid for the Sheriff only, with a crawl space underneath
	add_box(Rect2(wall.x, loft, wall.y - wall.x, -loft - WALL_GAP), 64)
	level.hooks.append(global_position + Vector2(25.5 * TILE, tiles_up(9.4)))
	if Lighting.enabled():
		add_child(Lighting.radial(Vector2(12 * TILE, top + 30), Color(1, 0.78, 0.45), 1.4, 0.9))
		add_child(Lighting.radial(Vector2(38 * TILE, top + 30), Color(1, 0.78, 0.45), 1.4, 0.9))
	for bx in [19.0 * TILE, 32.0 * TILE]:
		bales.append({"x": bx, "y": loft - 16.0, "vy": 0.0, "state": 0})


func step(delta: float) -> void:
	var p := player()
	# ladder up to the near loft
	if p.ride == null and not (p.lasso and p.lasso.swinging()):
		var lx := p.global_position.x - (global_position.x + ladder_x)
		var feet := p.global_position.y - global_position.y
		if absf(lx) < 10.0 and feet > loft + 2.0 and feet <= 1.0 and Input.is_action_pressed("up"):
			p.start_ride(self)
	# bales tumble off the loft edges when the Sheriff walks underneath
	for b in bales:
		match b.state:
			0:
				var dx: float = global_position.x + b.x + 8.0 - p.global_position.x
				var below: bool = p.global_position.y > global_position.y - 4.0
				if below and dx < 64.0 and dx > -8.0:
					b.state = 1
					b.vy = -60.0
					Audio.sfx("dash", 0.5)
			1:
				b.vy += 900.0 * delta
				b.y += b.vy * delta
				var r := Rect2(global_position + Vector2(b.x, b.y), Vector2(16, 16))
				if r.intersects(p.body_rect()):
					p.hurt(r.get_center().x)
					b.state = 2
					level.dust(r.get_center(), 10, Color("e8c860"))
				elif b.y >= -16.0:
					b.y = -16.0
					b.state = 2
					level.dust(global_position + Vector2(b.x + 8, -2), 8, Color("e8c860"))
					Audio.sfx("land", 0.7)
	queue_redraw()


## Player.ride callback: climb the loft ladder.
func ride_step(p: Player, delta: float) -> bool:
	var dir := Input.get_axis("up", "down")
	p.global_position.x = move_toward(p.global_position.x, global_position.x + ladder_x, 120.0 * delta)
	p.global_position.y += dir * CLIMB_SPEED * delta
	p.velocity = Vector2.ZERO
	p.anim = "climb" if dir != 0.0 else "climb_idle"
	var feet := p.global_position.y - global_position.y
	if feet <= loft:
		p.global_position.y = global_position.y + loft - 1.0
		return false
	if feet >= 0.0 and dir > 0.0:
		p.global_position.y = global_position.y
		return false
	if Input.is_action_just_pressed("jump"):
		p.velocity = Vector2(p.facing * 130.0, -320.0)
		return false
	return true


## Test bot: take the ground floor and slide under the hay wall.
func bot_hint(p: Player) -> Dictionary:
	var lx := p.global_position.x - global_position.x
	if lx < 0.0 or lx > w:
		return {}
	for b in bales:
		var dx: float = b.x - lx
		if b.state == 1 and dx > -10.0 and dx < 40.0:
			return {"dir": -1.0}           # back off from a falling bale
	return {}


func _draw() -> void:
	var red := Color("8a2e22")
	var plank := red.darkened(0.25)
	# back wall
	draw_rect(Rect2(0, top, w, -top), red.darkened(0.35))
	for x in range(0, int(w), 12):
		draw_rect(Rect2(x, top, 1, -top), plank.darkened(0.3))
	# roof outside
	draw_colored_polygon(PackedVector2Array([Vector2(-14, top), Vector2(w + 14, top), Vector2(w * 0.5 + 40, top - 46), Vector2(w * 0.5 - 40, top - 46)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(-11, top - 1), Vector2(w + 11, top - 1), Vector2(w * 0.5 + 38, top - 44), Vector2(w * 0.5 - 38, top - 44)]), Color("5a3a2e"))
	outlined_rect(Rect2(w * 0.5 - 14, top - 40, 28, 22), Color("e8e0cc"))       # loft door up top
	draw_line(Vector2(w * 0.5 - 14, top - 40), Vector2(w * 0.5 + 14, top - 18), red, 2.0)
	draw_line(Vector2(w * 0.5 + 14, top - 40), Vector2(w * 0.5 - 14, top - 18), red, 2.0)
	PixelFont.draw_centered(self, GameText.CR_BARN_SIGN, w * 0.5, top - 56, Color("fff6dc"))
	# beams and posts
	draw_rect(Rect2(0, top, w, 4), Color("4a2a1a"))
	draw_rect(Rect2(20 * TILE, top + 2, 12 * TILE, 3), Color("4a2a1a"))
	for px in [0.0, w - 8.0]:
		outlined_rect(Rect2(px, top, 8, -top), Color("6a2a1e"))
	# lofts
	for r in [Rect2(2 * TILE, loft, 18 * TILE, 6), Rect2(31 * TILE, loft, w - 33 * TILE, 6)]:
		outlined_rect(r, Color("8a6a42"))
		for k in range(int(r.position.x) + 6, int(r.end.x), 22):
			draw_rect(Rect2(k, loft + 6, 3, -loft - 6), Color("5a3a22"))
	var hay := SpriteLib.prop("hay_bale")
	for hx in [3.0, 6.0, 33.0, 43.0]:
		draw_texture_rect(hay, Rect2(hx * TILE, loft - 16, 32, 16), false)
	# hay wall with the crawl space
	var wh := -loft - WALL_GAP
	var y := loft
	while y < loft + wh - 1:
		for x in range(int(wall.x), int(wall.y), 16):
			draw_texture_rect(hay, Rect2(x, y, 16, minf(12.0, loft + wh - y)), false)
		y += 12.0
	draw_rect(Rect2(wall.x, -WALL_GAP, wall.y - wall.x, WALL_GAP), Color(0, 0, 0, 0.35))
	# ladder
	for side in [-6.0, 6.0]:
		draw_rect(Rect2(ladder_x + side - 1, loft - 2, 3, -loft + 2), Color("4a2a16"))
	var ly := loft + 2.0
	while ly < -2.0:
		draw_rect(Rect2(ladder_x - 6, ly, 13, 2), Color("7a5a36"))
		ly += 8.0
	# hook on the beam
	var hk := Vector2(25.5 * TILE, tiles_up(9.4))
	draw_line(Vector2(hk.x, top + 4), hk + Vector2(0, -3), Color("3a3a3a"), 1.0)
	draw_arc(hk, 3.0, 0, TAU, 10, OUTLINE, 2.0)
	draw_arc(hk, 3.0, 0, TAU, 10, Color("b0b0b8"), 1.0)
	# falling bales
	for b in bales:
		draw_texture_rect(hay, Rect2(b.x, b.y, 16, 16), false)
