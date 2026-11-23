# Pixel helpers for the placeholder generator: shaded capsules (limbs),
# shaded polygons (torsos), text pixel grids, outlines and compositing.
# Light always comes from the top-left.
extends RefCounted

const OUTLINE := Color("24140e")
const LIGHT := Vector2(-0.6, -0.8)


static func img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func put(im: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		im.set_pixel(x, y, c)


## ramp = [shadow, mid, light, highlight]; v is roughly -1..1
static func shade(ramp: Array, v: float) -> Color:
	if v > 0.6:
		return ramp[3]
	if v > 0.1:
		return ramp[2]
	if v > -0.45:
		return ramp[1]
	return ramp[0]


## A limb segment from a to b with radius r, shaded like a cylinder.
static func capsule(im: Image, a: Vector2, b: Vector2, r: float, ramp: Array, stripe := []) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r + 1, r + 1)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r + 1, r + 1)
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	var light := LIGHT.normalized()
	for y in range(int(lo.y), int(hi.y) + 1):
		for x in range(int(lo.x), int(hi.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var d := p - (a + ab * t)
			var dist := d.length()
			if dist <= r:
				var v := (d / r).dot(light) + 0.15
				var rp: Array = ramp
				if not stripe.is_empty() and (y / 2) % 2 == 1:
					rp = stripe
				put(im, x, y, shade(rp, v))


static func disc(im: Image, c: Vector2, r: float, ramp: Array) -> void:
	capsule(im, c, c + Vector2(0.01, 0), r, ramp)


## Filled polygon shaded across `axis` (unit vector pointing to the right side).
static func poly(im: Image, pts: PackedVector2Array, ramp: Array, center: Vector2, axis: Vector2, half_w: float, stripe := []) -> void:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	for y in range(int(r.position.y) - 1, int(r.end.y) + 2):
		for x in range(int(r.position.x) - 1, int(r.end.x) + 2):
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, pts):
				var u := (p - center).dot(axis) / maxf(half_w, 1.0)
				var v := -u * 0.9 + 0.2
				var rp: Array = ramp
				if not stripe.is_empty() and (y / 2) % 2 == 1:
					rp = stripe
				put(im, x, y, shade(rp, v))


## Draw a text grid. Each char looks up a Color in pal; '.' and ' ' are skipped.
static func grid(im: Image, rows: Array, pal: Dictionary, at: Vector2i, flip := false) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or ch == " " or not pal.has(ch):
				continue
			var px := (row.length() - 1 - x) if flip else x
			put(im, at.x + px, at.y + y, pal[ch])


## Add a 1-px outline around every opaque pixel (4-neighbour), in place.
static func outline(im: Image, col := OUTLINE) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var src := im.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
					im.set_pixel(x, y, col)
					break


## Alpha-blend src onto dst at `at`.
static func blit(dst: Image, src: Image, at := Vector2i.ZERO) -> void:
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)


## Ordered (Bayer 4x4) dither threshold for x,y in 0..1
static func bayer(x: int, y: int) -> float:
	const M := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (M[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0


## Vertical gradient through a list of colours, dithered between steps.
static func dither_gradient(im: Image, rect: Rect2i, cols: Array) -> void:
	var n := cols.size() - 1
	for y in range(rect.position.y, rect.end.y):
		var t := float(y - rect.position.y) / maxf(rect.size.y - 1, 1) * n
		var i := mini(int(t), n - 1)
		var f := t - i
		for x in range(rect.position.x, rect.end.x):
			put(im, x, y, cols[i + 1] if f > bayer(x, y) else cols[i])


static func ramp(hexes: String) -> Array:
	var out := []
	for h in hexes.split(","):
		out.append(Color(h.strip_edges()))
	return out
