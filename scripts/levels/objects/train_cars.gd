# The Last Train: the whole level is the top of a moving freight train.
# Each ground segment is one car; this draws the cars (wheels turning, rails
# rushing by underneath) and adds the solid parts you climb over: boxcar
# and passenger-car roofs, tank cars, the coal in the tender, the engine cab.
#   {"type": "train_cars", "x": 0, "styles": ["caboose", "flat", "box", ...]}
extends LevelObject

const SOLID := {             # style: [inset tiles each end, height tiles] of the solid part
	"box": [2.5, 3.0], "tank": [2.5, 2.5], "pass": [2.5, 3.2], "tender": [3.0, 1.4], "caboose": [3.0, 2.2],
}
var cars: Array = []         # {a, b (px), style}
var speed := 260.0
var _t := 0.0


func _setup() -> void:
	speed = level.data.get("train_speed", 260.0)
	var styles: Array = o.get("styles", [])
	for i in level.data.ground.size():
		var seg: Array = level.data.ground[i]
		var st: String = styles[i] if i < styles.size() else "flat"
		var a: float = seg[0] * TILE
		var b: float = seg[1] * TILE
		cars.append({"a": a, "b": b, "style": st})
		if SOLID.has(st):
			var ins: float = SOLID[st][0] * TILE
			var h: float = SOLID[st][1] * TILE
			add_box(Rect2(a + ins, -h, b - a - ins * 2.0, h), 1)
		elif st == "engine":
			add_box(Rect2(b - 5 * TILE, -4 * TILE, 4 * TILE, 4 * TILE), 1)        # the cab
			if Lighting.enabled():
				var hl := Lighting.cone(Vector2(b + 4, -2.4 * TILE), Color(1, 0.95, 0.7), 2.6, 1.2)
				add_child(hl)
				add_child(Lighting.radial(Vector2(b - 3 * TILE, -2 * TILE), Color(1, 0.6, 0.3), 1.0, 0.8))   # firebox glow


## The flat deck spots at each end of the car under x (for the bot): [left, right], or [] if none.
func deck_spots(x: float) -> Array:
	for c in cars:
		if x >= c.a - 8.0 and x <= c.b + 8.0:
			var ins: float = SOLID[c.style][0] * TILE if SOLID.has(c.style) else 0.0
			if ins == 0.0:
				return []
			return [c.a + ins * 0.5, c.b - ins * 0.5]
	return []


## Test bot: jump at the end of a roof (so you clear the gap to the next car).
func bot_hint(p: Player) -> Dictionary:
	if not p.is_on_floor() or p.global_position.y > level.GROUND_Y - 10.0:
		return {}
	var x := p.global_position.x
	for c in cars:
		if SOLID.has(c.style):
			var ins: float = SOLID[c.style][0] * TILE
			var end: float = c.b - ins
			if x > c.a and x < end + 4.0 and end - x < 18.0:
				return {"dir": 1.0, "jump": true}
	return {}


func step(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var x0 := -40.0
	var x1: float = level.width_px + 40.0
	# the ground rushing by + rails and ties
	draw_rect(Rect2(x0, 24, x1 - x0, 300), Color("4a3428"))
	var off := fmod(_t * speed, 20.0)
	for x in range(int(x0), int(x1), 20):
		draw_rect(Rect2(x - off, 22, 12, 4), Color("2a1a12"))
	draw_rect(Rect2(x0, 20, x1 - x0, 2), Color("9a9aa6"))
	var stones := fmod(_t * speed, 37.0)
	for x in range(int(x0), int(x1), 37):
		draw_rect(Rect2(x - stones, 30 + (x / 37 % 3) * 9, 3, 2), Color("6a5446"))
	for i in cars.size():
		var c: Dictionary = cars[i]
		_car(c)
		if i < cars.size() - 1:
			var nx: float = cars[i + 1].a
			draw_rect(Rect2(c.b, 6, nx - c.b, 3), Color("2a2a30"))           # coupler
			draw_rect(Rect2(c.b + (nx - c.b) * 0.5 - 3, 4, 6, 7), Color("3a3a42"))


func _car(c: Dictionary) -> void:
	var a: float = c.a
	var b: float = c.b
	var w := b - a
	var cols := {"caboose": Color("b0442e"), "flat": Color("6a4a2a"), "box": Color("8a3a2a"), "tank": Color("2a2a32"),
		"pass": Color("2a5a3a"), "tender": Color("1e1e24"), "engine": Color("1e1e24")}
	var col: Color = cols.get(c.style, Color("6a4a2a"))
	# deck / chassis
	draw_rect(Rect2(a - 1, -1, w + 2, 14), OUTLINE)
	draw_rect(Rect2(a, 0, w, 6), Color("7a5a36") if c.style == "flat" else col.lightened(0.1))
	draw_rect(Rect2(a, 6, w, 6), Color("2a2a30"))
	for k in range(int(a) + 6, int(b), 10):
		draw_rect(Rect2(k, 1, 1, 4), Color(0, 0, 0, 0.25))
	# wheels (two trucks of two)
	for tx in [a + 18.0, b - 34.0]:
		for dx in [0.0, 16.0]:
			var wc := Vector2(tx + dx, 14)
			draw_circle(wc, 7.0, OUTLINE)
			draw_circle(wc, 5.5, Color("3a3a42"))
			var ang := -_t * speed / 7.0
			draw_line(wc, wc + Vector2(cos(ang), sin(ang)) * 5.0, Color("8a8a96"), 1.0)
	# the body above the deck
	if SOLID.has(c.style):
		var ins: float = SOLID[c.style][0] * TILE
		var h: float = SOLID[c.style][1] * TILE
		var r := Rect2(a + ins, -h, w - ins * 2.0, h)
		match c.style:
			"tank":
				draw_rect(r.grow(1), OUTLINE)
				draw_rect(r, col)
				draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(r.size.x, 3)), col.lightened(0.25))
				outlined_rect(Rect2(r.get_center().x - 5, r.position.y - 4, 10, 4), col.lightened(0.2))
				PixelFont.draw_centered(self, "OIL", r.get_center().x, r.position.y + 16, Color("e8e0d0"))
			"tender":
				outlined_rect(Rect2(a + 4, -8, w - 8, 8), col)
				for k in 6:
					draw_circle(Vector2(r.position.x + 8 + k * (r.size.x - 16) / 5.0, r.position.y + 10 - (k % 2) * 4), 8.0, Color("14141a"))
			_:
				draw_rect(r.grow(1), OUTLINE)
				draw_rect(r, col)
				draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), col.lightened(0.25))
				if c.style == "pass":
					for k in range(int(r.position.x) + 8, int(r.end.x) - 12, 18):
						draw_rect(Rect2(k, r.position.y + 12, 10, 12), Color("e8c060"))
				elif c.style == "caboose":
					outlined_rect(Rect2(r.get_center().x - 10, r.position.y - 12, 20, 12), col)   # cupola
					draw_rect(Rect2(r.get_center().x - 6, r.position.y - 9, 5, 6), Color("e8c060"))
				else:
					for k in range(int(r.position.x) + 6, int(r.end.x), 10):
						draw_rect(Rect2(k, r.position.y + 4, 1, r.size.y - 6), col.darkened(0.25))
					outlined_rect(Rect2(r.get_center().x - 10, r.position.y + 10, 20, r.size.y - 12), col.darkened(0.15))
	elif c.style == "engine":
		var cab := Rect2(b - 5 * TILE, -4 * TILE, 4 * TILE, 4 * TILE)
		outlined_rect(Rect2(a + 6, -3 * TILE, cab.position.x - a - 6, 3 * TILE), col)          # boiler
		draw_rect(Rect2(a + 6, -3 * TILE + 4, cab.position.x - a - 6, 2), Color("4a4a56"))
		outlined_rect(Rect2(a + 14, -3 * TILE - 18, 10, 18), col)                                # smokestack
		for k in 4:
			var sx: float = a + 19 - k * 14.0 - fmod(_t * 60.0, 14.0)
			draw_circle(Vector2(sx, -3 * TILE - 26 - k * 8), 5.0 + k * 2.0, Color(0.6, 0.6, 0.62, 0.55 - k * 0.12))
		outlined_rect(cab, Color("2a2a32"))
		draw_rect(Rect2(cab.position + Vector2(8, 10), Vector2(18, 14)), Color("e8c060"))
		draw_rect(Rect2(cab.position.x - 4, cab.position.y - 4, cab.size.x + 8, 5), Color("14141a"))
		draw_colored_polygon(PackedVector2Array([Vector2(b - 2, 12), Vector2(b + 12, 12), Vector2(b - 2, -6)]), Color("c83a3a"))  # cowcatcher
