# Props: crates, awning pieces, the end gate, signboards, sidewalk furniture,
# pies, hearts and HUD portraits. Each returns an Image; the generator packs
# them into art/sprites/props.png and records regions in data/props.json.
extends RefCounted

const P := preload("res://tools/gen/pix.gd")
const Rig := preload("res://tools/gen/rig.gd")
const WOOD := ["4a2c18", "7a5230", "a87a46", "c89a66"]


static func all(cast: Dictionary) -> Dictionary:
	var out := {
		"crate": crate(),
		"awning_l": awning(0), "awning_m": awning(1), "awning_r": awning(2), "awning_post": post(),
		"gate": gate(), "signboard": signboard(),
		"lamp": lamp(), "bench": bench(), "planter": planter(), "hydrant": hydrant(),
		"mailbox": mailbox(), "barrel": barrel(),
		"pie": pie(false), "pie_gold": pie(true),
		"heart": heart(Color("d8342a")), "heart_empty": heart(Color("6a5a58")),
		"rock": rock(),
		"boulder": boulder(), "log": log_prop(), "cork": cork(),
		"hook_ring": hook_ring(), "patrol_car": patrol_car(), "car_wheel": car_wheel(),
		"parade_float": parade_float(), "cone": cone(), "barricade": barricade(),
		"milk_truck": milk_truck(), "tractor": tractor(), "hay_bale": hay_bale(), "milk_crate": milk_crate(),
		"sedan_blue": sedan(P.ramp("1a2e5a,2a4a8a,3a6ab8,6a9ad8")),
		"sedan_green": sedan(P.ramp("1a3a22,2a5a32,3a7a44,5a9a5a")),
		"sedan_yellow": sedan(P.ramp("8a6a10,c09a20,e8c040,f8e080")),
	}
	for n in cast:
		out["portrait_" + n] = portrait(cast[n])
	return out


static func _c(h: String) -> Color:
	return Color(h)


static func crate() -> Image:
	var im := P.img(32, 32)
	var w := P.ramp(",".join(WOOD))
	for y in 32:
		for x in 32:
			var plank := (y / 8) % 2
			var v := 0.2 - (x + y) / 64.0 * 0.6 + (0.25 if plank else 0.0)
			P.put(im, x, y, P.shade(w, v))
	for y in [7, 15, 23]:
		for x in 32:
			P.put(im, x, y, w[0])
	# frame + diagonal brace
	for i in 32:
		for t in 3:
			P.put(im, i, t, w[2] if t == 0 else w[1]); P.put(im, i, 31 - t, w[0] if t == 0 else w[1])
			P.put(im, t, i, w[2] if t == 0 else w[1]); P.put(im, 31 - t, i, w[0] if t == 0 else w[1])
	for i in range(3, 29):
		P.put(im, i, i, w[3]); P.put(im, i + 1, i, w[1]); P.put(im, i - 1, i, w[2])
	for p in [Vector2i(4, 4), Vector2i(27, 4), Vector2i(4, 27), Vector2i(27, 27)]:
		P.put(im, p.x, p.y, Color("2a2a30"))
	P.outline(im)
	return _trim_outline(im, 32, 32)


## crops nothing; outline pass grew past edges only where possible (kept for symmetry)
static func _trim_outline(im: Image, _w: int, _h: int) -> Image:
	return im


static func awning(part: int) -> Image:
	# 16x14: striped canvas with scalloped hem; part 0 = left end, 2 = right end
	var im := P.img(16, 14)
	var red := P.ramp("8a1a14,b82a22,d8342a,f06a50")
	var cream := P.ramp("b8b0a0,d8d0c0,f4f0e6,ffffff")
	for y in 10:
		for x in 16:
			var r: Array = red if (x / 4) % 2 == 0 else cream
			var v := 0.5 - y / 10.0 * 1.1
			P.put(im, x, y, P.shade(r, v))
	for x in 16:
		var r: Array = red if (x / 4) % 2 == 0 else cream
		if x % 4 != 3:
			P.put(im, x, 10, r[1]); P.put(im, x, 11, r[0])
		if x % 4 == 1 or x % 4 == 2:
			P.put(im, x, 12, r[0])
	for x in 16:
		P.put(im, x, 0, Color("4a2c18"))
	if part == 0:
		for y in 13:
			P.put(im, 0, y, Color("24140e"))
	if part == 2:
		for y in 13:
			P.put(im, 15, y, Color("24140e"))
	return im


static func post() -> Image:
	var im := P.img(4, 8)
	var w := P.ramp(",".join(WOOD))
	for y in 8:
		P.put(im, 0, y, Color("24140e")); P.put(im, 1, y, w[2]); P.put(im, 2, y, w[1]); P.put(im, 3, y, Color("24140e"))
	return im


static func gate() -> Image:
	# tall plank fence that marks the end of the level (24x160)
	var im := P.img(24, 160)
	var w := P.ramp(",".join(WOOD))
	for x in 24:
		for y in range(4, 160):
			var plank := x / 6
			var v := 0.3 - (x % 6) / 6.0 * 0.9 + (0.15 if plank % 2 else 0.0)
			P.put(im, x, y, P.shade(w, v))
		if x % 6 == 0:
			for y in range(4, 160):
				P.put(im, x, y, w[0])
	for x in 24:  # pointed tops
		var top := 4 - absi((x % 6) - 3)
		for y in range(top, 4):
			P.put(im, x, y, w[2])
	for y in [30, 120]:
		for x in 24:
			P.put(im, x, y, w[0]); P.put(im, x, y + 1, w[3]); P.put(im, x, y + 2, w[1]); P.put(im, x, y + 3, w[0])
	P.outline(im)
	return im


static func signboard() -> Image:
	# blank green road sign; text is drawn at runtime with the player's names
	var im := P.img(72, 22)
	var g := P.ramp("1a4a2a,2e6a3e,3e8a50,5aa868")
	for y in 22:
		for x in 72:
			P.put(im, x, y, P.shade(g, 0.4 - y / 22.0))
	for x in 72:
		P.put(im, x, 1, Color("f4f0e6")); P.put(im, x, 20, Color("f4f0e6"))
	for y in 22:
		P.put(im, 1, y, Color("f4f0e6")); P.put(im, 70, y, Color("f4f0e6"))
	return im


static func lamp() -> Image:
	var im := P.img(16, 80)
	var iron := P.ramp("101014,24242c,3a3a46,5a5a6a")
	P.capsule(im, Vector2(8, 14), Vector2(8, 76), 1.6, iron)
	P.capsule(im, Vector2(5, 76), Vector2(11, 76), 2.5, iron)
	P.capsule(im, Vector2(8, 30), Vector2(8, 31), 2.5, iron)
	P.capsule(im, Vector2(4, 12), Vector2(12, 12), 1.8, iron)
	P.disc(im, Vector2(8, 7), 4.5, P.ramp("d8b060,f0d890,fff2c0,ffffff"))
	P.capsule(im, Vector2(5, 2), Vector2(11, 2), 1.2, iron)
	P.outline(im)
	return im


static func bench() -> Image:
	var im := P.img(36, 18)
	var w := P.ramp(",".join(WOOD))
	var iron := P.ramp("101014,24242c,3a3a46,5a5a6a")
	for y in [2, 5]:
		P.capsule(im, Vector2(2, y), Vector2(33, y), 1.3, w)
	P.capsule(im, Vector2(1, 10), Vector2(34, 10), 1.6, w)
	for x in [5, 30]:
		P.capsule(im, Vector2(x, 2), Vector2(x, 16), 1.1, iron)
	P.outline(im)
	return im


static func planter() -> Image:
	var im := P.img(18, 20)
	var w := P.ramp(",".join(WOOD))
	for y in range(8, 20):
		for x in range(1, 17):
			P.put(im, x, y, P.shade(w, 0.5 - x / 16.0 - (0.3 if y in [10, 16] else 0.0)))
	var leaf := P.ramp("1e4a2e,2e6a3e,4a8a4c,6aa860")
	for c in [Vector2(5, 7), Vector2(9, 5), Vector2(13, 7), Vector2(7, 4), Vector2(11, 3)]:
		P.disc(im, c, 2.6, leaf)
	for c in [Vector2(5, 5), Vector2(9, 3), Vector2(13, 5), Vector2(11, 7), Vector2(7, 7)]:
		P.disc(im, c, 1.3, P.ramp("b03a6a,e0609a,f490c0,ffd0e8"))
	P.outline(im)
	return im


static func hydrant() -> Image:
	var im := P.img(12, 18)
	var r := P.ramp("8a1a14,b82a22,d8342a,f06a50")
	P.capsule(im, Vector2(6, 6), Vector2(6, 16), 3.2, r)
	P.disc(im, Vector2(6, 4), 3.0, r)
	P.capsule(im, Vector2(1, 9), Vector2(11, 9), 1.5, r)
	P.capsule(im, Vector2(2, 17), Vector2(10, 17), 1.0, r)
	P.outline(im)
	return im


static func mailbox() -> Image:
	var im := P.img(16, 26)
	var b := P.ramp("142a5a,1e3e7a,2e5aa0,4a7ac0")
	for y in range(2, 14):
		for x in range(1, 15):
			P.put(im, x, y, P.shade(b, 0.6 - x / 14.0))
	P.disc(im, Vector2(8, 3), 6.5, b)
	P.capsule(im, Vector2(4, 14), Vector2(4, 25), 1.0, b)
	P.capsule(im, Vector2(12, 14), Vector2(12, 25), 1.0, b)
	for x in range(4, 12):
		P.put(im, x, 8, Color("10203f"))
	P.outline(im)
	return im


static func barrel() -> Image:
	var im := P.img(16, 20)
	var w := P.ramp(",".join(WOOD))
	for y in 20:
		for x in 16:
			var bulge := 1 if y > 3 and y < 16 else 2
			if x >= bulge and x < 16 - bulge:
				P.put(im, x, y, P.shade(w, 0.5 - x / 16.0 * 1.2))
	for y in [3, 16]:
		for x in range(1, 15):
			P.put(im, x, y, Color("3a3a40"))
	P.outline(im)
	return im


static func pie(golden: bool) -> Image:
	var im := P.img(16, 12)
	var crust := P.ramp("8a5a20,c08a40,eab866,f8dca0") if not golden else P.ramp("a87010,d8a020,ffd23f,fff6c0")
	var fill := P.ramp("6a1018,a01c2a,c8283a,e85060") if not golden else P.ramp("c89020,e8c040,fff0a0,ffffff")
	var tin := P.ramp("5a6068,7a8088,a8b0b8,d0d8e0")
	P.capsule(im, Vector2(2, 9), Vector2(13, 9), 1.6, tin)
	for y in range(3, 9):
		var half := 6.0 - absf(y - 6.0) * 0.4
		for x in range(int(8 - half), int(8 + half)):
			P.put(im, x, y, P.shade(crust, 0.6 - (x - 2) / 12.0 - (y - 3) / 8.0))
	for x in [4, 7, 10]:
		P.put(im, x, 5, fill[1]); P.put(im, x + 1, 5, fill[2]); P.put(im, x, 6, fill[0])
	P.outline(im)
	return im


static func heart(c: Color) -> Image:
	var im := P.img(9, 8)
	var rows := ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
	for y in rows.size():
		for x in 7:
			if rows[y][x] == "1":
				P.put(im, x + 1, y + 1, c if y > 0 or x % 3 != 1 else c.lightened(0.4))
	P.put(im, 2, 2, c.lightened(0.5))
	P.outline(im)
	return im


static func rock() -> Image:
	var im := P.img(10, 9)
	P.disc(im, Vector2(5, 5), 3.6, P.ramp("5e5850,8a8478,b0aa9c,d4cec0"))
	P.outline(im)
	return im


static func boulder() -> Image:
	var im := P.img(34, 30)
	var r := P.ramp("5e5048,857468,a89884,c8baa4")
	P.disc(im, Vector2(17, 18), 12.0, r)
	P.disc(im, Vector2(10, 21), 8.0, r)
	P.disc(im, Vector2(24, 21), 8.5, r)
	for c in [Vector2(12, 14), Vector2(21, 20), Vector2(15, 24)]:
		P.put(im, int(c.x), int(c.y), r[0]); P.put(im, int(c.x) + 1, int(c.y) + 1, r[0]); P.put(im, int(c.x) + 2, int(c.y) + 1, r[0])
	P.outline(im)
	return im


static func log_prop() -> Image:
	var im := P.img(96, 14)
	var bark := P.ramp("3a2414,5a3a22,7a5230,9a6a40")
	P.capsule(im, Vector2(6, 7), Vector2(89, 7), 5.5, bark)
	for x in range(10, 86, 9):
		P.put(im, x, 5, bark[0]); P.put(im, x + 1, 6, bark[0]); P.put(im, x + 4, 9, bark[0])
	P.disc(im, Vector2(90, 7), 5.0, P.ramp("a87a46,c89a66,e0b884,f0d4a4"))
	P.put(im, 90, 7, Color("7a5230")); P.put(im, 89, 6, Color("7a5230"))
	P.outline(im)
	return im


static func cork() -> Image:
	var im := P.img(8, 6)
	P.capsule(im, Vector2(2, 3), Vector2(5, 3), 2.0, P.ramp("8a5a30,c08a50,e0b070,f0d090"))
	P.outline(im)
	return im


static func hook_ring() -> Image:
	var im := P.img(12, 12)
	var iron := P.ramp("1a1a20,3a3a46,5a5a6a,8a8a9a")
	for a in 24:
		var t := a / 24.0 * TAU
		P.disc(im, Vector2(6 + cos(t) * 3.6, 6 + sin(t) * 3.6), 1.1, iron)
	P.outline(im)
	return im


## 1960s patrol car, side view facing right, 76x30 (wheels drawn separately).
static func patrol_car() -> Image:
	var im := P.img(76, 30)
	var black := P.ramp("0e0e14,1e1e28,30303e,4a4a5c")
	var white := P.ramp("b8b8b0,d8d8d0,f0f0e8,ffffff")
	var glass := P.ramp("3a5a7a,5a8ab0,8ab8d8,c8e4f4")
	# lower body: black hood and trunk, white doors
	for y in range(12, 25):
		for x in range(2, 74):
			var nose := x > 66 and y < 15
			var tail := x < 6 and y < 14
			if nose or tail:
				continue
			var r: Array = white if x > 20 and x < 56 else black
			P.put(im, x, y, P.shade(r, 0.6 - (y - 12) / 13.0 * 1.4))
	# cabin
	for y in range(3, 13):
		var inset := 12 - y
		for x in range(20 + inset, 58 - inset / 2):
			P.put(im, x, y, P.shade(white, 0.7 - (y - 3) / 10.0))
	for y in range(5, 11):
		for x in range(25 + (11 - y), 37):
			P.put(im, x, y, P.shade(glass, 0.8 - (x - 25) / 12.0))
		for x in range(40, 53 - (11 - y) / 2):
			P.put(im, x, y, P.shade(glass, 0.8 - (x - 40) / 13.0))
	# chrome bumpers, headlight, tail light
	for y in range(19, 23):
		P.put(im, 73, y, Color("d8d8e0")); P.put(im, 74, y, Color("a8a8b0"))
		P.put(im, 1, y, Color("d8d8e0"))
	P.disc(im, Vector2(72, 16), 1.6, P.ramp("c8a040,f0d070,fff0b0,ffffff"))
	P.put(im, 3, 15, Color("d8342a")); P.put(im, 3, 16, Color("d8342a"))
	# gold star on the door, red roof light
	var c := Vector2(38, 17)
	for o in [Vector2(0, -2), Vector2(-2, -1), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(2, -1),
			Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]:
		P.put(im, int(c.x + o.x), int(c.y + o.y), Color("ffd23f"))
	P.disc(im, Vector2(40, 2), 1.8, P.ramp("8a1a14,d8342a,ff6a50,ffc0b0"))
	# wheel arches
	for wx in [16, 60]:
		for y in range(19, 25):
			for x in range(wx - 7, wx + 8):
				if Vector2(x - wx, y - 25).length() < 7.5:
					P.put(im, x, y, Color(0, 0, 0, 0))
	P.outline(im)
	return im


static func car_wheel() -> Image:
	var im := P.img(14, 14)
	P.disc(im, Vector2(7, 7), 6.0, P.ramp("0a0a0e,16161c,24242c,34343e"))
	P.disc(im, Vector2(7, 7), 3.0, P.ramp("8a8a96,b0b0bc,d8d8e0,ffffff"))
	P.put(im, 7, 4, Color("3a3a46")); P.put(im, 7, 5, Color("3a3a46"))
	P.outline(im)
	return im


## Parade float: a decorated hay wagon with bunting (text added at runtime).
static func parade_float() -> Image:
	var im := P.img(100, 50)
	var wood := P.ramp(",".join(WOOD))
	for y in range(24, 40):
		for x in range(4, 96):
			P.put(im, x, y, P.shade(wood, 0.5 - (y - 24) / 16.0))
	var hay := P.ramp("a8782a,c8a040,e8c860,f8e090")
	for k in 9:
		P.disc(im, Vector2(10 + k * 10, 22), 6.5, hay)
	for x in range(4, 96):   # red/white/blue bunting
		var col: Color = [Color("d8342a"), Color("f4f0e6"), Color("2e5aa0")][(x / 8) % 3]
		var dip := int(sin(fmod(x, 16.0) / 16.0 * PI) * 4)
		for y in range(26, 29 + dip):
			P.put(im, x, y, col)
	for x in range(10, 90):   # banner board
		for y in range(5, 14):
			P.put(im, x, y, Color("f4ecd4"))
	for wx in [18, 82]:
		P.disc(im, Vector2(wx, 42), 6.0, P.ramp("2a1a10,4a2c18,7a5230,a87a46"))
		P.disc(im, Vector2(wx, 42), 2.0, P.ramp("8a8a96,b0b0bc,d8d8e0,ffffff"))
	P.outline(im)
	return im


static func cone() -> Image:
	var im := P.img(12, 16)
	var o := P.ramp("a83a10,e05a1a,f88a3a,ffc080")
	for y in range(2, 14):
		var half := 1 + (y - 2) * 4 / 12
		for x in range(6 - half, 6 + half + 1):
			var c := P.shade(o, 0.6 - (x - 6 + half) / float(half * 2 + 1))
			P.put(im, x, y, Color("f4f0e6") if y in [7, 8] else c)
	for x in range(0, 12):
		P.put(im, x, 14, o[0]); P.put(im, x, 15, o[0])
	P.outline(im)
	return im


static func barricade() -> Image:
	var im := P.img(56, 30)
	for x in range(2, 54):
		for y in range(4, 13):
			var stripe := ((x + y) / 5) % 2 == 0
			P.put(im, x, y, Color("f08a1a") if stripe else Color("f4f0e6"))
	var w := P.ramp(",".join(WOOD))
	for lx in [8, 46]:
		P.capsule(im, Vector2(lx, 12), Vector2(lx - 5, 29), 1.5, w)
		P.capsule(im, Vector2(lx, 12), Vector2(lx + 5, 29), 1.5, w)
	P.outline(im)
	return im


## Earl's stolen milk truck, facing right, 92x40 (wheels separate).
static func milk_truck() -> Image:
	var im := P.img(92, 40)
	var white := P.ramp("a8b0b8,c8d0d8,e8ecf0,ffffff")
	var blue := P.ramp("1a3a6a,2a5a9a,3a7ac8,6aa0e0")
	for y in range(2, 32):        # box body
		for x in range(2, 62):
			P.put(im, x, y, P.shade(white, 0.7 - (y - 2) / 30.0 * 1.3))
	for x in range(2, 62):        # blue stripe
		for y in range(24, 28):
			P.put(im, x, y, blue[2])
	for y in range(10, 32):       # cab
		for x in range(62, 88):
			if x > 80 and y < 16:
				continue
			P.put(im, x, y, P.shade(blue, 0.7 - (y - 10) / 22.0 * 1.3))
	for y in range(12, 20):       # windshield
		for x in range(68, 80 - (19 - y) / 3):
			P.put(im, x, y, Color("8ab8d8") if x > 72 else Color("c8e4f4"))
	for y in range(26, 30):
		P.put(im, 89, y, Color("d8d8e0")); P.put(im, 88, y, Color("a8a8b0"))
	P.disc(im, Vector2(86, 22), 1.6, P.ramp("c8a040,f0d070,fff0b0,ffffff"))
	for wx in [18, 74]:
		for y in range(27, 33):
			for x in range(wx - 8, wx + 9):
				if Vector2(x - wx, y - 33).length() < 8.5:
					P.put(im, x, y, Color(0, 0, 0, 0))
	P.outline(im)
	return im


static func tractor() -> Image:
	var im := P.img(60, 40)
	var red := P.ramp("6a1a14,8a2a1e,b03a28,d8604a")
	for y in range(14, 30):
		for x in range(20, 54):
			P.put(im, x, y, P.shade(red, 0.6 - (y - 14) / 16.0))
	for y in range(4, 16):        # cab frame
		P.put(im, 22, y, red[0]); P.put(im, 23, y, red[1]); P.put(im, 36, y, red[0])
	for x in range(20, 40):
		P.put(im, x, 3, red[1]); P.put(im, x, 4, red[0])
	P.capsule(im, Vector2(48, 6), Vector2(48, 14), 1.4, P.ramp("1a1a20,2a2a30,3a3a46,5a5a6a"))   # exhaust
	P.disc(im, Vector2(14, 28), 11.0, P.ramp("0e0e12,1e1e24,2e2e38,40404c"))
	P.disc(im, Vector2(14, 28), 5.0, P.ramp("a86a10,d89a20,f0c040,f8e080"))
	P.disc(im, Vector2(50, 33), 6.0, P.ramp("0e0e12,1e1e24,2e2e38,40404c"))
	P.disc(im, Vector2(50, 33), 2.5, P.ramp("a86a10,d89a20,f0c040,f8e080"))
	P.outline(im)
	return im


## A plain sedan facing LEFT (oncoming traffic), 68x26, wheels drawn in.
static func sedan(body: Array) -> Image:
	var im := P.img(68, 28)
	var glass := P.ramp("3a5a7a,5a8ab0,8ab8d8,c8e4f4")
	for y in range(11, 22):
		for x in range(2, 66):
			if (x < 6 and y < 14) or (x > 62 and y < 13):
				continue
			P.put(im, x, y, P.shade(body, 0.6 - (y - 11) / 11.0 * 1.3))
	for y in range(3, 12):
		var inset := 11 - y
		for x in range(16 + inset / 2, 50 - inset):
			P.put(im, x, y, P.shade(body, 0.8 - (y - 3) / 9.0))
	for y in range(5, 10):
		for x in range(20 + (9 - y) / 2, 31):
			P.put(im, x, y, glass[2])
		for x in range(34, 46 - (9 - y)):
			P.put(im, x, y, glass[1])
	P.disc(im, Vector2(4, 15), 1.5, P.ramp("c8a040,f0d070,fff0b0,ffffff"))
	for wx in [14, 54]:
		P.disc(im, Vector2(wx, 22), 5.0, P.ramp("0a0a0e,16161c,24242c,34343e"))
		P.disc(im, Vector2(wx, 22), 2.0, P.ramp("8a8a96,b0b0bc,d8d8e0,ffffff"))
	P.outline(im)
	return im


static func hay_bale() -> Image:
	var im := P.img(30, 20)
	var hay := P.ramp("a8782a,c8a040,e8c860,f8e090")
	for y in range(1, 19):
		for x in range(1, 29):
			var v := 0.6 - y / 19.0 + (0.3 if (x + y * 3) % 7 == 0 else 0.0)
			P.put(im, x, y, P.shade(hay, v))
	for x in range(1, 29):
		P.put(im, x, 6, Color("7a5a20")); P.put(im, x, 13, Color("7a5a20"))
	P.outline(im)
	return im


static func milk_crate() -> Image:
	var im := P.img(18, 16)
	for y in range(1, 15):
		for x in range(1, 17):
			var edge := x < 3 or x > 14 or y < 3 or y > 12
			P.put(im, x, y, Color("d8342a") if edge else Color("b02a22"))
	for bx in [5, 9, 13]:
		P.disc(im, Vector2(bx, 4), 2.0, P.ramp("c8c8c0,e8e8e0,f8f8f0,ffffff"))
	P.outline(im)
	return im


static func portrait(ch: Dictionary) -> Image:
	# head grid framed in a 28x28 HUD portrait
	var im := P.img(28, 28)
	P.dither_gradient(im, Rect2i(2, 2, 24, 24), [Color("6aa8e0"), Color("c8e0f0")])
	var head := P.img(28, 28)
	var hd: Dictionary = ch.head
	var rows: Array = hd.rows
	var at := Vector2i(14 - hd.anchor.x, 27 - rows.size() + 1)
	P.grid(head, rows, hd.pal, at)
	P.outline(head)
	P.blit(im, head)
	for i in 28:
		for t in 2:
			var c := Color("c8901c") if t == 1 else Color("24140e")
			P.put(im, i, t, c); P.put(im, i, 27 - t, c); P.put(im, t, i, c); P.put(im, 27 - t, i, c)
	return im
