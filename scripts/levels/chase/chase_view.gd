# Draws the car chase: scenery layers (town fading to farmland and back),
# the road over the hills, the bridge ramp and creek, warning signs, hay
# bales on the curves, skid marks, traffic, crates, pies, the milk truck
# and the patrol car. Reads all state from its parent (chase.gd).
extends Node2D

const OUTLINE := Color("24140e")
const LAYERS := [["far", 0.15], ["mid", 0.3], ["main", 0.55], ["near", 0.8]]

const COW_WALK_FRAMES: Array[Texture2D] = [
	preload("res://art/sprites/props/cow_walk/frame_0.png"),
	preload("res://art/sprites/props/cow_walk/frame_1.png"),
	preload("res://art/sprites/props/cow_walk/frame_2.png"),
	preload("res://art/sprites/props/cow_walk/frame_3.png"),
	preload("res://art/sprites/props/cow_walk/frame_4.png"),
	preload("res://art/sprites/props/cow_walk/frame_5.png"),
	preload("res://art/sprites/props/cow_walk/frame_6.png"),
]
const BOTTLE_SPIN_FRAMES: Array[Texture2D] = [
	preload("res://art/sprites/props/bottle_spin/frame_0.png"),
	preload("res://art/sprites/props/bottle_spin/frame_1.png"),
	preload("res://art/sprites/props/bottle_spin/frame_2.png"),
	preload("res://art/sprites/props/bottle_spin/frame_3.png"),
	preload("res://art/sprites/props/bottle_spin/frame_4.png"),
]
const MILK_SPLAT_FRAMES: Array[Texture2D] = [
	preload("res://art/sprites/props/milk_splat/frame_0.png"),
	preload("res://art/sprites/props/milk_splat/frame_1.png"),
	preload("res://art/sprites/props/milk_splat/frame_2.png"),
	preload("res://art/sprites/props/milk_splat/frame_3.png"),
	preload("res://art/sprites/props/milk_splat/frame_4.png"),
]
const CROSSING_TEX := preload("res://art/sprites/props/railroad_crossing.png")
const CROSSING_LOWER_FRAMES: Array[Texture2D] = [
	preload("res://art/sprites/props/crossing_lower/frame_0.png"),
	preload("res://art/sprites/props/crossing_lower/frame_1.png"),
	preload("res://art/sprites/props/crossing_lower/frame_2.png"),
	preload("res://art/sprites/props/crossing_lower/frame_3.png"),
	preload("res://art/sprites/props/crossing_lower/frame_4.png"),
	preload("res://art/sprites/props/crossing_lower/frame_5.png"),
	preload("res://art/sprites/props/crossing_lower/frame_6.png"),
]

var c: Node2D                      # the chase
var town_layers: Array = []
var farm_layers: Array = []
var bubble := ""
var bubble_t := 0
var wheel := 0.0


func _ready() -> void:
	c = get_parent()
	z_index = 1


## Called by the chase once it's in the tree: build the parallax scenery.
func build_backdrop(holder: Node2D) -> void:
	for area in ["town", "farm"]:
		for l in LAYERS:
			var tex: Texture2D = load("res://art/backgrounds/%s/%s.png" % [area, l[0]])
			var px := Parallax2D.new()
			px.scroll_scale = Vector2(l[1], 0.9)
			px.repeat_size = Vector2(tex.get_width(), 0)
			px.repeat_times = 3
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.centered = false
			spr.position = Vector2(0, -4 - tex.get_height())
			px.add_child(spr)
			holder.add_child(px)
			(town_layers if area == "town" else farm_layers).append(px)


func say(t: String) -> void:
	bubble = t.to_upper()
	bubble_t = 120


func _process(delta: float) -> void:
	wheel += c.speed * delta / 7.0
	bubble_t = maxi(bubble_t - 1, 0)
	var k: float = c.countryside(c.x)
	for p in town_layers:
		p.modulate = Color(0.85, 0.87, 0.95, 1.0 - k)
	for p in farm_layers:
		p.modulate = Color(0.85, 0.87, 0.95, k)
	queue_redraw()


func _draw() -> void:
	var cx: float = c.cam.position.x
	var x0 := cx - 340.0
	var x1 := cx + 340.0
	_road(x0, x1)
	_signs(x0, x1)
	_skids()
	# everything on the road, back lane first
	var items: Array = []
	for v in c.traffic:
		items.append(["v", v.ly, v])
	for cr in c.crates:
		items.append(["crate", c.LANES[cr.lane], cr])
	for p in c.pies:
		if not p.got:
			items.append(["pie", c.LANES[p.lane], p])
	for cw in c.cows:
		items.append(["cow", cw.ly, cw])
	for b in c.bottles:
		items.append(["bottle", c.LANES[b.lane], b])
	items.append(["truck", c.truck.ly, c.truck])
	items.append(["car", c.lane_y, null])
	items.sort_custom(func(a, b): return a[1] < b[1])
	for it in items:
		match it[0]:
			"v": _vehicle(it[2])
			"crate": _crate(it[2])
			"pie": draw_texture(SpriteLib.prop("pie"), c.screen_point(it[2].x, c.LANES[it[2].lane]) + Vector2(-8, -14))
			"cow": _cow(it[2])
			"bottle": _bottle(it[2])
			"truck": _truck()
			"car": _car()
	_crossing()
	_hay_bales(x0, x1, true)
	_warnings()
	if bubble_t > 0:
		_speech(c.screen_point(c.truck.x, c.truck.ly) + Vector2(10, -56), bubble)


# --- road -----------------------------------------------------------------------
func _road(x0: float, x1: float) -> void:
	var k: float = c.countryside(c.x)
	var shoulder := Color("d8d0bc").lerp(Color("5a9a3a"), k)
	var shoulder_dk := Color("8a8478").lerp(Color("3a6a2a"), k)
	var asphalt := Color("3c3c44").lerp(Color("4a4440"), k)
	var ground := Color("2e2e34").lerp(Color("7a4a24"), k)
	var x := floorf(x0 / 4.0) * 4.0
	while x < x1:
		if c.in_gap(x):
			var wy := 46.0
			draw_rect(Rect2(x, wy, 4, 200), Color("1e4a78"))
			draw_rect(Rect2(x, wy, 4, 2), Color("6aa8e0") if int(x / 8 + c._t * 6) % 3 else Color("4a88c0"))
		else:
			var top: float = -c.elevation(x)
			draw_rect(Rect2(x, top - 8, 4, 6), shoulder)
			draw_rect(Rect2(x, top - 2, 4, 2), shoulder_dk)
			draw_rect(Rect2(x, top, 4, 50), asphalt)
			if int(x) % 32 < 16:
				draw_rect(Rect2(x, top + 18, 4, 1), Color("e8d890"))
				draw_rect(Rect2(x, top + 32, 4, 1), Color("e8d890"))
			draw_rect(Rect2(x, top + 50, 4, 3), shoulder_dk)
			draw_rect(Rect2(x, top + 53, 4, 200), ground)
		x += 4.0
	# the ramp up to the broken bridge, and the bridge stubs
	var r: Array = c.course.ramp
	if r[0] < x1 and r[1] + r[2] > x0:
		var base: float = -c.elevation(r[0])
		var poly := PackedVector2Array([Vector2(r[0], base + 50), Vector2(r[0], base), Vector2(r[1], base - 22), Vector2(r[1], base + 50)])
		draw_colored_polygon(poly, Color("7a5230"))
		for i in 6:
			var px: float = lerpf(r[0], r[1], i / 6.0)
			draw_line(Vector2(px, base - 22.0 * i / 6.0), Vector2(px, base + 50), Color("4a2c18"), 1.0)
		draw_line(Vector2(r[0], base), Vector2(r[1], base - 22), Color("f0c848"), 2.0)
		for side in [r[1], r[1] + r[2]]:
			draw_rect(Rect2(side - 3, base, 6, 60), Color("5a3a22"))


func _signs(x0: float, x1: float) -> void:
	for cv in c.course.curves:
		var sx: float = cv[0] - 260.0
		if sx > x0 and sx < x1:
			var top: float = -c.elevation(sx) - 8.0
			draw_rect(Rect2(sx - 1, top - 30, 3, 30), Color("4a4a56"))
			var d := PackedVector2Array([Vector2(sx, top - 46), Vector2(sx + 12, top - 34), Vector2(sx, top - 22), Vector2(sx - 12, top - 34)])
			draw_colored_polygon(d, OUTLINE)
			var d2 := PackedVector2Array([Vector2(sx, top - 44), Vector2(sx + 10, top - 34), Vector2(sx, top - 24), Vector2(sx - 10, top - 34)])
			draw_colored_polygon(d2, Color("f0c848"))
			var dir: float = cv[2]
			draw_line(Vector2(sx - 5 * dir, top - 30), Vector2(sx - 5 * dir, top - 37), OUTLINE, 2.0)
			draw_line(Vector2(sx - 5 * dir, top - 37), Vector2(sx + 4 * dir, top - 37), OUTLINE, 2.0)
			PixelFont.draw_centered(self, GameText.CHASE_SIGN_CURVE, sx, top - 56, Color("f0c848"))
	var rx: float = c.course.ramp[0] - 420.0
	if rx > x0 and rx < x1:
		var top: float = -c.elevation(rx) - 8.0
		draw_rect(Rect2(rx - 1, top - 28, 3, 28), Color("4a4a56"))
		var t := GameText.CHASE_SIGN_RAMP
		var w := PixelFont.width(t) + 8
		draw_rect(Rect2(rx - w / 2.0 - 1, top - 44, w + 2, 14), OUTLINE)
		draw_rect(Rect2(rx - w / 2.0, top - 43, w, 12), Color("f08a1a"))
		PixelFont.draw_centered(self, t, rx, top - 40, OUTLINE)
	if not c.crossing.is_empty():
		var rxc: float = c.crossing.x - 460.0
		if rxc > x0 and rxc < x1:
			var top: float = -c.elevation(rxc) - 8.0
			draw_rect(Rect2(rxc - 1, top - 28, 3, 28), Color("4a4a56"))
			var t := GameText.CHASE_SIGN_CROSSING
			var w := PixelFont.width(t) + 8
			draw_rect(Rect2(rxc - w / 2.0 - 1, top - 44, w + 2, 14), OUTLINE)
			draw_rect(Rect2(rxc - w / 2.0, top - 43, w, 12), Color("f4ecd4"))
			PixelFont.draw_centered(self, t, rxc, top - 40, OUTLINE)
	var fx: float = c.course.farm_stand
	if fx > x0 - 60 and fx < x1:
		var top: float = -c.elevation(fx) - 8.0
		draw_rect(Rect2(fx - 31, top - 33, 62, 33), OUTLINE)
		draw_rect(Rect2(fx - 30, top - 32, 60, 32), Color("a87a46"))
		for k in 6:
			draw_rect(Rect2(fx - 30 + k * 10, top - 40, 10, 8), Color("d8342a") if k % 2 == 0 else Color("f4f0e6"))
		PixelFont.draw_centered(self, GameText.CHASE_FARM_STAND, fx, top - 24, Color("f4f0e6"))
	_hay_bales(x0, x1, false)


## Hay bales line the outside of every curve (far side drawn first).
func _hay_bales(x0: float, x1: float, near: bool) -> void:
	var tex := SpriteLib.prop("hay_bale")
	for cv in c.course.curves:
		var outer_near: bool = cv[2] > 0
		if outer_near != near:
			continue
		var bx: float = cv[0]
		while bx < cv[1]:
			if bx > x0 - 30 and bx < x1:
				var top: float = -c.elevation(bx)
				var y := top + 54.0 if near else top - 22.0
				draw_texture(tex, Vector2(bx - 15, y - (16 if near else 0)))
			bx += 34.0


func _skids() -> void:
	for s in c.skids:
		var p: Vector2 = c.screen_point(s[0], s[1])
		draw_rect(Rect2(p.x - 2, p.y - 2, 5, 1), Color(0, 0, 0, 0.45))


# --- vehicles -------------------------------------------------------------------------
func _car() -> void:
	var tex := SpriteLib.prop("patrol_car")
	var at := Vector2(c.x - 38, -c.height + c.lane_y - 30)
	draw_texture(tex, at)
	draw_rect(Rect2(at.x + 42, at.y + 3, 9, 2), Color("7a5230"))     # Sheriff's hat
	draw_rect(Rect2(at.x + 44, at.y + 1, 5, 2), Color("7a5230"))
	if int(c._t * 8.0) % 2 == 0:
		draw_rect(Rect2(at.x + 38, at.y - 1, 5, 3), Color("ff3a2a"))
		draw_circle(at + Vector2(40, 1), 7.0, Color(1, 0.2, 0.1, 0.25))
	else:
		draw_rect(Rect2(at.x + 38, at.y - 1, 5, 3), Color("3a6aff"))
		draw_circle(at + Vector2(40, 1), 7.0, Color(0.2, 0.4, 1, 0.25))
	_wheels(at, [16.0, 60.0], 24.0)
	if c.splash_t > 0:
		for k in 5:
			draw_circle(at + Vector2(20 + k * 10, 26 - (c.splash_t % 20)), 4.0, Color(0.6, 0.85, 1, 0.8))


func _truck() -> void:
	var t: Dictionary = c.truck
	var tex := SpriteLib.prop("milk_truck")
	var y: float
	if c.in_gap(t.x):
		var r: Array = c.course.ramp
		var s: float = (t.x - r[1]) / r[2]
		y = -c.elevation(r[1]) - 22.0 - sin(s * PI) * 30.0 + s * 22.0
	else:
		y = -c.surface(t.x)
	var center := Vector2(t.x, y + t.ly - 20)
	draw_set_transform(center, sin(t.spin * 8.0) * 0.15 * t.spin, Vector2.ONE)
	draw_texture(tex, Vector2(-46, -20))
	var label := Names.fmt(GameText.CHASE_TRUCK).to_upper()
	PixelFont.draw_centered(self, label, -14, -12, Color("2a5a9a"))
	# Earl at the wheel: striped cap in the cab window
	for k in 3:
		draw_rect(Rect2(25, -8 + k * 2, 7, 1), Color("f0f0e8") if k % 2 == 0 else Color("22222c"))
	draw_rect(Rect2(26, -2, 5, 3), Color("eab48a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_wheels(center + Vector2(-46, -20), [18.0, 74.0], 34.0)


func _vehicle(v: Dictionary) -> void:
	var base: Vector2 = c.screen_point(v.x, v.ly) + Vector2(0, -v.h)
	match v.kind:
		"tractor":
			var tex := SpriteLib.prop("tractor")
			draw_texture(tex, base + Vector2(-30, -40))
		"hay_wagon":
			var hay := SpriteLib.prop("hay_bale")
			draw_rect(Rect2(base.x - 34, base.y - 20, 68, 12), OUTLINE)
			draw_rect(Rect2(base.x - 33, base.y - 19, 66, 10), Color("a87a46"))
			draw_texture(hay, base + Vector2(-32, -40))
			draw_texture(hay, base + Vector2(2, -40))
			draw_texture(hay, base + Vector2(-15, -56))
			for wx in [-22.0, 22.0]:
				draw_circle(base + Vector2(wx, -6), 6.0, OUTLINE)
				draw_circle(base + Vector2(wx, -6), 4.5, Color("5a3a22"))
		"car":
			var names := ["sedan_blue", "sedan_green", "sedan_yellow"]
			var tex := SpriteLib.prop(names[int(v.x / 97.0) % 3])
			draw_texture(tex, base + Vector2(-34, -28))


func _crate(cr: Dictionary) -> void:
	var p: Vector2 = c.screen_point(cr.x, c.LANES[cr.lane])
	if cr.hit:
		cr.y += cr.vy * get_process_delta_time()
		cr.vy -= 900.0 * get_process_delta_time()
		draw_texture(SpriteLib.prop("milk_crate"), p + Vector2(-9, -16 - cr.y))
	else:
		draw_texture(SpriteLib.prop("milk_crate"), p + Vector2(-9, -16))


func _cow(cw: Dictionary) -> void:
	var frame: int = int(cw.t * 6.0) % COW_WALK_FRAMES.size()
	var p: Vector2 = c.screen_point(cw.x, cw.ly)
	draw_texture(COW_WALK_FRAMES[frame], p + Vector2(-24, -36))


func _bottle(b: Dictionary) -> void:
	var p: Vector2 = c.screen_point(b.x, c.LANES[b.lane])
	if b.landed:
		var frame: int = clampi(int(b.t * 12.0), 0, MILK_SPLAT_FRAMES.size() - 1)
		draw_texture(MILK_SPLAT_FRAMES[frame], p + Vector2(-16, -20))
	else:
		var s: float = b.t / c.BOTTLE_FALL_TIME
		var arc := sin(s * PI) * 26.0
		var frame: int = int(s * (BOTTLE_SPIN_FRAMES.size() - 1))
		draw_texture(BOTTLE_SPIN_FRAMES[frame], p + Vector2(-16, -32 - arc))


## The railroad crossing: a static gate that lowers (crossing_lower frames) as
## you approach, then blinks warning lights once it's part-way down. Only
## spans the middle lane, so there's always a way around.
func _crossing() -> void:
	if c.crossing.is_empty():
		return
	var cx: float = c.crossing.x
	var top: float = -c.elevation(cx) - 8.0
	var lower: float = c.crossing.lower
	var tex: Texture2D = CROSSING_TEX
	if lower > 0.0:
		tex = CROSSING_LOWER_FRAMES[clampi(int(lower * 6.0), 0, CROSSING_LOWER_FRAMES.size() - 1)]
	draw_texture(tex, Vector2(cx - 32, top - 128))
	if lower > 0.05 and int(c._t * 6.0) % 2 == 0:
		draw_circle(Vector2(cx - 20, top - 94), 3.0, Color("ff3a2a"))
		draw_circle(Vector2(cx + 20, top - 94), 3.0, Color("ff3a2a"))


func _wheels(at: Vector2, xs: Array, y: float) -> void:
	var tex := SpriteLib.prop("car_wheel")
	for wx in xs:
		draw_set_transform(at + Vector2(wx, y), wheel, Vector2.ONE)
		draw_texture(tex, -tex.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _speech(at: Vector2, t: String) -> void:
	var w := PixelFont.width(t) + 8
	var r := Rect2(at.x - w / 2.0, at.y - 12, w, 11)
	draw_rect(r.grow(1), OUTLINE)
	draw_rect(r, Color("fff6dc"))
	PixelFont.draw_centered(self, t, at.x, at.y - 9, Color("3a2414"))


## Flashing "!" at the right edge for an oncoming car that's not on screen yet.
func _warnings() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var bob := 2.0 * sin(t * 14.0)
	for v in c.incoming():
		var ex: float = c.cam.position.x + c.half_width() - 16.0
		var p: Vector2 = c.screen_point(ex, v.ly) + Vector2(bob, -16)
		var mine: bool = v.lane == c.lane
		var col := Color("ff4a3a") if mine else Color("ffd23f")
		var tri := PackedVector2Array([p + Vector2(0, -10), p + Vector2(9, 7), p + Vector2(-9, 7)])
		draw_colored_polygon(tri, OUTLINE)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(6.5, 5.5), p + Vector2(-6.5, 5.5)]), col)
		PixelFont.draw_centered(self, "!", p.x, p.y - 3, OUTLINE)
