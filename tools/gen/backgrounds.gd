# Parallax background layers per area: sky (screen-sized), far, mid, main,
# near. Every scrolling layer tiles seamlessly across its width and its
# bottom edge sits on the ground line. Storefront signboards are left blank
# and their rectangles are returned, so shop names stay editable at runtime.
extends RefCounted

const P := preload("res://tools/gen/pix.gd")

const LAYER_SIZES := {"far": Vector2i(1024, 120), "mid": Vector2i(1024, 140), "main": Vector2i(1536, 160), "near": Vector2i(1024, 200)}


## Returns {"sky": Image, "far": Image, "mid": Image, "main": Image, "near": Image, "signs": Array}
static func theme(name: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var out := {"signs": []}
	for k in LAYER_SIZES:
		out[k] = P.img(LAYER_SIZES[k].x, LAYER_SIZES[k].y)
	out["sky"] = P.img(480, 270)
	match name:
		"town", "night":
			var night := name == "night"
			if night:
				_sky(out.sky, ["0a0c1e", "141a3a", "232a52", "3a3a64"], rng, false)
				_stars(out.sky, rng)
				P.disc(out.sky, Vector2(380, 50), 12, P.ramp("c8c0a0,e8e0c0,f8f2dc,ffffff"))
			else:
				_sky(out.sky, ["3a78c0", "5a98d4", "8ab8e0", "bcd8ec", "f0e4c4"], rng, true)
			_hills(out.far, [["2a3448" if night else "5a8a9a", 70, 0.3], ["1e2638" if night else "4a7a6a", 46, 0.5]], rng)
			_treeline(out.mid, night, rng)
			_water_tower(out.mid, 300, night)
			_steeple(out.mid, 760, night)
			out.signs = _storefronts(out.main, night, rng)
			_poles(out.near, night)
		"farm":
			_sky(out.sky, ["4a3a7a", "a85a7a", "f08a5a", "f8c878", "fce8b0"], rng, true)
			P.disc(out.sky, Vector2(330, 205), 26, P.ramp("f8b048,fcd070,fff0a8,ffffff"))
			_hills(out.far, [["6a4a7a", 64, 0.3], ["8a5a6a", 40, 0.6]], rng)
			_fields(out.mid, rng)
			_farm_buildings(out.main, rng)
			_rail_fence(out.near)
		"quarry":
			_sky(out.sky, ["4a80c0", "78a8d8", "b8d0e0", "f0dcb0"], rng, true)
			_mesas(out.far, rng)
			_cliffs(out.mid, P.ramp("8a5a3a,a8744a,c08c5a,d8a874"), 120, rng)
			_cliffs(out.main, P.ramp("6a4228,8a5a38,a8744a,c48e60"), 150, rng)
			_pines(out.main, 6, P.ramp("1e3a28,2e5236,3e6a42,5a8a50"), rng)
			_spires(out.near, rng)
		"lake":
			_sky(out.sky, ["3a80d0", "6aa8e0", "a8d0ec", "e0f0f4"], rng, true)
			_hills(out.far, [["5a7aa8", 90, 0.25], ["4a6a90", 60, 0.5]], rng)
			_pines(out.mid, 40, P.ramp("142a20,1e3e2a,2e5236,3e6a42"), rng)
			_water(out.main, rng)
			_reeds(out.near, rng)
	return out


# --- sky ---------------------------------------------------------------------------
static func _sky(im: Image, hexes: Array, rng: RandomNumberGenerator, clouds: bool) -> void:
	var cols := []
	for h in hexes:
		cols.append(Color(h))
	P.dither_gradient(im, Rect2i(0, 0, 480, 270), cols)
	if clouds:
		var cr := P.ramp("b8c4d4,dce4ee,f4f6fa,ffffff")
		for i in 5:
			var cx := rng.randf_range(20, 460)
			var cy := rng.randf_range(20, 120)
			var s := rng.randf_range(0.7, 1.3)
			for k in 7:
				var o := Vector2(rng.randf_range(-22, 22) * s, rng.randf_range(-6, 4) * s)
				P.disc(im, Vector2(cx, cy) + o, rng.randf_range(7, 12) * s, cr)
			for x in range(int(cx - 30 * s), int(cx + 30 * s)):
				P.put(im, x, int(cy + 8 * s), cr[0])


static func _stars(im: Image, rng: RandomNumberGenerator) -> void:
	for i in 120:
		var c := Color("fff6dc") if i % 5 else Color("a8c0ff")
		P.put(im, rng.randi_range(0, 479), rng.randi_range(0, 180), c)


# --- terrain silhouettes ---------------------------------------------------------------
## bands: [[hex, height, roughness], ...] far to near
static func _hills(im: Image, bands: Array, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for b in bands:
		var col := Color(b[0])
		var ramp := [col.darkened(0.25), col, col.lightened(0.12), col.lightened(0.22)]
		var k1 := rng.randi_range(2, 3)
		var k2 := rng.randi_range(5, 8)
		var ph := rng.randf() * TAU
		for x in w:
			var t := float(x) / w * TAU
			var top: float = h - b[1] - sin(t * k1 + ph) * 14.0 - sin(t * k2) * 6.0 * b[2] - sin(t * 13.0 + ph) * 2.0
			for y in range(int(top), h):
				var slope := cos(t * k1 + ph) * k1
				var v := 0.4 - (y - top) / 60.0 + slope * 0.08
				var c: Color = ramp[3] if v > 0.35 and P.bayer(x, y) > 0.5 else P.shade(ramp, v)
				P.put(im, x, y, c)


static func _treeline(im: Image, night: bool, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var ramp := P.ramp("0e1a18,14261e,1c3226,24402e") if night else P.ramp("2a4a2a,3a6a3a,4e8446,6aa058")
	for x in range(0, w + 24, 14):
		var cx := float(x % w)
		var r := rng.randf_range(9, 15)
		var cy := h - 22 - rng.randf_range(0, 18)
		for dx in [0.0, -float(w), float(w)]:
			P.disc(im, Vector2(cx + dx, cy), r, ramp)
			P.disc(im, Vector2(cx + dx + 6, cy + 8), r * 0.8, ramp)
	for x in w:
		for y in range(h - 14, h):
			P.put(im, x, y, ramp[0])


static func _water_tower(im: Image, x: int, night: bool) -> void:
	var h := im.get_height()
	var metal := P.ramp("1a1e2a,262c3a,323a4a,404a5c") if night else P.ramp("7a8a9a,9aaab8,bccad4,dce6ee")
	for lx in [x - 14, x - 5, x + 5, x + 14]:
		P.capsule(im, Vector2(lx, h - 60), Vector2(lx + signf(lx - x) * 3, h - 10), 1.3, metal)
	for y in range(h - 95, h - 62):
		for dx in range(-20, 21):
			P.put(im, x + dx, y, P.shade(metal, 0.5 - (dx + 20) / 40.0 * 1.2))
	for dx in range(-22, 23):
		var top := h - 95 - int((22 - absi(dx)) * 0.5)
		for y in range(top, h - 95):
			P.put(im, x + dx, y, metal[2] if dx < 0 else metal[1])
	for dx in range(-20, 21):
		P.put(im, x + dx, h - 80, metal[0])


static func _steeple(im: Image, x: int, night: bool) -> void:
	var h := im.get_height()
	var wall := P.ramp("1a1c28,24283a,2e3448,3a4258") if night else P.ramp("b8b0a0,d8d0c0,f0eadc,ffffff")
	for y in range(h - 70, h - 10):
		for dx in range(-9, 10):
			P.put(im, x + dx, y, P.shade(wall, 0.5 - (dx + 9) / 18.0 * 1.2))
	for y in range(h - 110, h - 70):
		var half := (y - (h - 110)) * 9 / 40
		for dx in range(-half, half + 1):
			P.put(im, x + dx, y, wall[1] if dx > 0 else wall[2])
	for y in range(h - 62, h - 50):
		P.put(im, x, y, Color("3a2a20"))
		P.put(im, x + 1, y, Color("3a2a20"))


# --- Main Street storefronts --------------------------------------------------------------
static func _storefronts(im: Image, night: bool, rng: RandomNumberGenerator) -> Array:
	var w := im.get_width()
	var h := im.get_height()
	var signs := []
	var x := 0
	var i := 0
	var styles := ["brick", "clapboard", "stucco", "clapboard", "brick", "stucco"]
	var facades := {
		"brick": ["6a2a1e,8a3a28,a84a32,c06040"],
		"clapboard": ["5a7a9a,7a9ab8,9abcd4,b8d4e8", "6a8a5a,8aaa76,a8c494,c4dcae", "a8946a,c8b488,e0d0a8,f0e4c4", "9a6a7a,ba8a9a,d4a8b4,e8c4cc"],
		"stucco": ["a88a5a,c8a878,e0c494,f0dab0", "a8a090,c8c0ae,e0dacb,f2ecde"],
	}
	var awnings := ["d8342a", "2e6a3e", "3a5a9a", "c8901c", "8a3a6a"]
	while x < w - 40:
		var bw := rng.randi_range(110, 170)
		if x + bw > w:
			bw = w - x
		var bh := rng.randi_range(110, 150)
		var style: String = styles[i % styles.size()]
		var opts: Array = facades[style]
		var ramp := P.ramp(opts[rng.randi_range(0, opts.size() - 1)])
		if night:
			ramp = [ramp[0].darkened(0.7), ramp[1].darkened(0.65), ramp[2].darkened(0.6), ramp[3].darkened(0.55)]
		_facade(im, Rect2i(x, h - bh, bw, bh), style, ramp)
		_cornice(im, Rect2i(x, h - bh, bw, bh), ramp)
		# upper storey windows
		var n := 2 if bw < 140 else 3
		for k in n:
			var wx := x + 14 + k * ((bw - 28) / n) + ((bw - 28) / n - 14) / 2
			_window(im, Rect2i(wx, h - bh + 12, 14, 22), night, rng)
		# signboard (blank; text drawn at runtime)
		var sw := mini(bw - 24, 100)
		var sr := Rect2i(x + (bw - sw) / 2, h - 82, sw, 16)
		_signboard(im, sr, night)
		signs.append({"x": sr.position.x, "y": sr.position.y - h, "w": sr.size.x, "h": sr.size.y, "i": i % 12})
		# awning + display windows + door
		var aw_col := Color(awnings[(i * 3) % awnings.size()])
		_awning(im, Rect2i(x + 6, h - 62, bw - 12, 12), aw_col, night)
		var door_x := x + bw - 30 if i % 2 == 0 else x + 10
		_door(im, Rect2i(door_x, h - 46, 18, 46), night)
		var dx0 := x + 34 if i % 2 == 1 else x + 8
		_display(im, Rect2i(dx0, h - 46, bw - 48, 34), night, rng)
		if i % 6 == 4:
			_barber_pole(im, x + bw - 8, h - 50)
		# alley shadow between buildings
		for y in range(h - bh, h):
			P.put(im, x + bw - 1, y, Color("24140e"))
			P.put(im, x + bw, y, Color("24140e"))
		x += bw + rng.randi_range(2, 10)
		i += 1
	return signs


static func _facade(im: Image, r: Rect2i, style: String, ramp: Array) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var lx := x - r.position.x
			var ly := y - r.position.y
			var c: Color = ramp[2]
			match style:
				"brick":
					var row := ly / 4
					var off := 4 if row % 2 else 0
					if ly % 4 == 3 or (lx + off) % 8 == 7:
						c = ramp[0].lerp(Color("c8b8a0"), 0.35)
					else:
						c = ramp[2] if P.bayer(x, y) > 0.3 else ramp[1]
				"clapboard":
					c = ramp[0] if ly % 5 == 4 else (ramp[3] if ly % 5 == 0 else ramp[2])
				"stucco":
					c = ramp[1] if P.bayer(x, y) > 0.8 else ramp[2]
			if lx < 2:
				c = c.lightened(0.12)
			elif lx > r.size.x - 4:
				c = c.darkened(0.2)
			P.put(im, x, y, c)


static func _cornice(im: Image, r: Rect2i, ramp: Array) -> void:
	for x in range(r.position.x - 2, r.end.x + 2):
		for t in 5:
			P.put(im, x, r.position.y + t, [ramp[3], ramp[1], ramp[1], ramp[0], ramp[0]][t])
		if (x - r.position.x) % 4 == 0:
			P.put(im, x, r.position.y + 5, ramp[0])
	for x in range(r.position.x - 2, r.end.x + 2):
		P.put(im, x, r.position.y - 1, Color("24140e"))


static func _window(im: Image, r: Rect2i, night: bool, rng: RandomNumberGenerator) -> void:
	var frame := Color("e8e0cc") if not night else Color("6a6458")
	var lit := night and rng.randf() < 0.5
	for y in range(r.position.y - 2, r.end.y + 2):
		for x in range(r.position.x - 2, r.end.x + 2):
			P.put(im, x, y, frame)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Color("2a3a5a")
			if lit:
				c = Color("f8d070") if P.bayer(x, y) > 0.2 else Color("e0a040")
			elif (x - r.position.x) - (y - r.position.y) / 2 in [3, 4, 9]:
				c = Color("8ab0d0")
			elif night:
				c = Color("141c30")
			P.put(im, x, y, c)
	for x in range(r.position.x, r.end.x):
		P.put(im, x, r.position.y + r.size.y / 2, frame)
	for x in range(r.position.x - 3, r.end.x + 3):
		P.put(im, x, r.position.y - 3, Color("24140e"))
		P.put(im, x, r.end.y + 2, Color("24140e"))


static func _signboard(im: Image, r: Rect2i, night: bool) -> void:
	var board := Color("f4ecd4") if not night else Color("8a8270")
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			var edge := x < r.position.x or y < r.position.y or x >= r.end.x or y >= r.end.y
			P.put(im, x, y, Color("24140e") if edge else board)
	for x in range(r.position.x + 1, r.end.x - 1):
		P.put(im, x, r.position.y + 1, board.darkened(0.15))
		P.put(im, x, r.end.y - 2, board.darkened(0.15))


static func _awning(im: Image, r: Rect2i, col: Color, night: bool) -> void:
	var a := col.darkened(0.5) if night else col
	var b := Color("f4f0e6").darkened(0.55) if night else Color("f4f0e6")
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := a if ((x - r.position.x) / 6) % 2 == 0 else b
			var t := float(y - r.position.y) / r.size.y
			P.put(im, x, y, c.lightened(0.15) if t < 0.2 else (c.darkened(0.15) if t > 0.7 else c))
	for x in range(r.position.x, r.end.x):
		if (x - r.position.x) % 6 in [1, 2, 3, 4]:
			var c := a if ((x - r.position.x) / 6) % 2 == 0 else b
			P.put(im, x, r.end.y, c.darkened(0.25))
		P.put(im, x, r.position.y - 1, Color("24140e"))
	# shadow under the awning
	for y in range(r.end.y + 1, r.end.y + 4):
		for x in range(r.position.x, r.end.x):
			P.put(im, x, y, im.get_pixel(x, y).darkened(0.3))


static func _display(im: Image, r: Rect2i, night: bool, rng: RandomNumberGenerator) -> void:
	for y in range(r.position.y - 2, r.end.y + 4):
		for x in range(r.position.x - 2, r.end.x + 2):
			P.put(im, x, y, Color("5a3a22") if not night else Color("2a1c14"))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var lx := x - r.position.x
			var ly := y - r.position.y
			var c := Color("2e4060") if not night else Color("f0c060")
			if not night and ((lx + ly) % 23 in [0, 1, 2] or (lx + ly) % 23 == 6):
				c = Color("9ac0dc")
			if lx % (r.size.x / 3) == 0:
				c = Color("5a3a22") if not night else Color("2a1c14")
			P.put(im, x, y, c)
	# goods in the window: a few shapes on the sill
	for k in rng.randi_range(2, 4):
		var gx := r.position.x + 4 + k * (r.size.x / 4)
		var col := Color.from_hsv(rng.randf(), 0.5, 0.8 if not night else 0.4)
		for y in range(r.end.y - 8, r.end.y):
			for x in range(gx, gx + 6):
				P.put(im, x, y, col if P.bayer(x, y) > 0.2 else col.darkened(0.3))


static func _door(im: Image, r: Rect2i, night: bool) -> void:
	var wood := P.ramp("3a2414,5a3a22,7a5230,a87a46")
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			P.put(im, x, y, P.shade(wood, 0.5 - (x - r.position.x) / float(r.size.x)))
	for y in range(r.position.y + 4, r.position.y + 20):
		for x in range(r.position.x + 3, r.end.x - 3):
			P.put(im, x, y, Color("2e4060") if not night else Color("f0c060"))
	P.put(im, r.end.x - 4, r.position.y + 26, Color("f0c848"))
	for y in range(r.position.y - 1, r.end.y):
		P.put(im, r.position.x - 1, y, Color("24140e"))
		P.put(im, r.end.x, y, Color("24140e"))


static func _barber_pole(im: Image, x: int, y: int) -> void:
	for dy in 22:
		for dx in 5:
			var stripe := ((dy + dx) / 3) % 3
			var c: Color = [Color("d8342a"), Color("f4f0e6"), Color("3a5a9a")][stripe]
			P.put(im, x + dx, y + dy, c if dx > 0 else c.darkened(0.25))
	for dx in range(-1, 6):
		P.put(im, x + dx, y - 1, Color("f0c848"))
		P.put(im, x + dx, y + 22, Color("f0c848"))


static func _poles(im: Image, night: bool) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var wood := P.ramp("1a120c,2a1c12,3a2818,4a3420") if night else P.ramp("3a2414,5a3a22,7a5230,8a6440")
	var xs := [128, 640]
	for px in xs:
		P.capsule(im, Vector2(px, 12), Vector2(px, h), 2.6, wood)
		P.capsule(im, Vector2(px - 18, 22), Vector2(px + 18, 22), 1.6, wood)
		for ix in [px - 15, px - 6, px + 6, px + 15]:
			P.disc(im, Vector2(ix, 19), 1.4, P.ramp("6a8a7a,8ab09a,b0d0c0,e0f0e8"))
	# two sagging wires per span; the last span wraps around the layer width
	var wire := Color("1a1410")
	for x in w:
		var a: int = xs[0] if x >= xs[0] and x < xs[1] else xs[1]
		var span := float(xs[1] - xs[0]) if a == xs[0] else float(w - xs[1] + xs[0])
		var t := fposmod(x - a, w) / span
		var sag := sin(t * PI) * 16.0
		P.put(im, x, int(19 + sag), wire)
		P.put(im, x, int(23 + sag * 0.9), wire)
	P.outline(im)


# --- farm -------------------------------------------------------------------------------
static func _fields(im: Image, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for y in range(h - 50, h):
		for x in w:
			var row := (y - (h - 50)) / 4
			var c := Color("c8a050") if row % 2 == 0 else Color("a8843a")
			if (x / 256) % 2 == 1:
				c = Color("7a9a3a") if row % 2 == 0 else Color("5a7a2a")
			P.put(im, x, y, c.darkened(0.1) if P.bayer(x, y) > 0.8 else c)
	for i in 10:
		var cx := rng.randf_range(0, w)
		P.disc(im, Vector2(cx, h - 54), rng.randf_range(6, 11), P.ramp("3a3a2a,4a5a2e,5a6a36,7a7a44"))


static func _farm_buildings(im: Image, rng: RandomNumberGenerator) -> void:
	var h := im.get_height()
	var red := P.ramp("6a1a14,8a2a1e,b03a28,c8503a")
	for bx in [180, 900]:
		for y in range(h - 90, h):
			for x in range(bx, bx + 120):
				var c := P.shade(red, 0.5 - (x - bx) / 120.0)
				P.put(im, x, y, c.darkened(0.25) if (x - bx) % 6 == 0 else c)
		for y in range(h - 125, h - 90):
			var half := (y - (h - 125)) * 70 / 35
			for x in range(bx + 60 - half, bx + 60 + half):
				P.put(im, x, y, Color("4a3a3a") if y < h - 120 else red[1])
		for t in 4:   # white X doors
			for k in 40:
				P.put(im, bx + 40 + k, h - 40 + k * 40 / 40 - t, Color("f4f0e6"))
				P.put(im, bx + 80 - k, h - 40 + k - t, Color("f4f0e6"))
		var silo := P.ramp("5a6a7a,7a8a9a,9aaaba,b8c8d4")
		for y in range(h - 130, h):
			for x in range(bx + 130, bx + 160):
				P.put(im, x, y, P.shade(silo, 0.6 - (x - bx - 130) / 30.0 * 1.4))
		P.disc(im, Vector2(bx + 145, h - 130), 15, silo)
	for i in 6:
		var hx := rng.randf_range(400, 860) if i < 3 else rng.randf_range(1100, 1500)
		P.disc(im, Vector2(hx, h - 10), 12, P.ramp("a8782a,c8a040,e8c860,f8e090"))
	P.outline(im)


static func _rail_fence(im: Image) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var wood := P.ramp("3a2414,5a3a22,7a5230,a87a46")
	for x in range(0, w, 64):
		P.capsule(im, Vector2(x + 8, h - 44), Vector2(x + 8, h), 2.4, wood)
	for y in [h - 38, h - 22]:
		for x in w:
			P.put(im, x, y, wood[2]); P.put(im, x, y + 1, wood[1]); P.put(im, x, y + 2, wood[0])
	P.outline(im)


# --- quarry -------------------------------------------------------------------------------
static func _mesas(im: Image, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var ramp := P.ramp("8a5a6a,a8707a,c08a8a,d8a8a0")
	for m in 4:
		var cx := m * w / 4 + rng.randi_range(40, 180)
		var top := h - rng.randi_range(60, 100)
		var half := rng.randi_range(60, 110)
		for y in range(top, h):
			var extra := int((y - top) * 0.6)
			for x in range(cx - half - extra, cx + half + extra):
				P.put(im, posmod(x, w), y, P.shade(ramp, 0.5 - (x - cx + half) / float(half * 2) - (0.4 if (y - top) % 9 == 0 else 0.0)))


static func _cliffs(im: Image, ramp: Array, height: int, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var ph := rng.randf() * TAU
	for x in w:
		var t := float(x) / w * TAU
		var top := h - height + int(20 + sin(t * 3 + ph) * 14 + sin(t * 11) * 5)
		for y in range(top, h):
			var band := ((y - top) / 7) % 3
			var v := 0.6 - (y - top) / float(height) - band * 0.2 + (0.3 if (x * 7 + y) % 37 == 0 else 0.0)
			P.put(im, x, y, P.shade(ramp, v))
		P.put(im, x, top, Color("24140e"))


static func _pines(im: Image, count: int, ramp: Array, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for i in count:
		var x := rng.randf_range(0, w)
		var base := h - rng.randf_range(4, 30)
		var ht := rng.randf_range(30, 60)
		for k in 6:
			var y := base - k * ht / 6.0
			var half := (6 - k) * ht / 14.0
			for yy in range(int(y - ht / 6.0), int(y)):
				for xx in range(int(x - half), int(x + half)):
					P.put(im, posmod(xx, w), yy, P.shade(ramp, 0.5 - (xx - x + half) / (half * 2.0) * 1.2))
		P.capsule(im, Vector2(x, base), Vector2(x, base + 6), 1.5, P.ramp("2a1a10,3a2414,5a3a22,7a5230"))


static func _spires(im: Image, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var ramp := P.ramp("4a2e1c,6a4228,8a5a38,a8744a")
	for i in 3:
		var cx := i * w / 3 + rng.randi_range(60, 260)
		var top := h - rng.randi_range(55, 95)
		for y in range(top, h):
			var half := 6 + (y - top) / 6
			for x in range(cx - half, cx + half):
				P.put(im, posmod(x, w), y, P.shade(ramp, 0.5 - (x - cx + half) / float(half * 2) * 1.4))
	P.outline(im)


# --- lake ---------------------------------------------------------------------------------
static func _water(im: Image, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for y in range(h - 70, h):
		for x in w:
			var t := float(y - (h - 70)) / 70.0
			var c := Color("4a88c0").lerp(Color("2a5a8a"), t)
			if (x * 3 + y * 17) % 41 == 0 or (x + y * 5) % 67 == 0:
				c = Color("b8dcf0")
			P.put(im, x, y, c)
	# boathouse on the far shore
	var bx := 600
	for y in range(h - 100, h - 70):
		for x in range(bx, bx + 70):
			P.put(im, x, y, Color("8a5a3a") if (y / 4) % 2 else Color("a8744a"))
	for y in range(h - 118, h - 100):
		var half := (y - (h - 118)) * 40 / 18
		for x in range(bx + 35 - half, bx + 35 + half):
			P.put(im, x, y, Color("4a3a3a"))
	for y in range(h - 70, h - 50):
		for x in range(bx, bx + 70):
			if (y + x) % 3 == 0:
				P.put(im, x, y, Color("8a5a3a").darkened(0.3))


static func _reeds(im: Image, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var g := P.ramp("1e3a1e,2e5a2a,4a7a3a,6a9a4a")
	for i in 40:
		var x := rng.randf_range(0, w)
		var ht := rng.randf_range(20, 50)
		P.capsule(im, Vector2(x, h), Vector2(x + rng.randf_range(-4, 4), h - ht), 0.8, g)
		if i % 3 == 0:
			P.capsule(im, Vector2(x, h - ht + 2), Vector2(x, h - ht + 9), 1.6, P.ramp("3a2414,5a3a22,7a5230,8a6440"))
	P.outline(im)
