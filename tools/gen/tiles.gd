# 16x16 terrain tilesets, one per area. Each atlas is 4x4 tiles = every
# combination of "has a neighbour" on the four sides (Godot terrain mode
# "match sides"). Tile index = mask: 1 top, 2 right, 4 bottom, 8 left;
# atlas coords = (mask % 4, mask / 4).
extends RefCounted

const P := preload("res://tools/gen/pix.gd")
const T := 16

# top: list of [height, ramp, pattern]; fill: [ramp, pattern]
const THEMES := {
	"town": {
		"top": [[1, "f8f2e2,f8f2e2,f8f2e2,f8f2e2", "flat"], [6, "b8b0a0,d0c8b6,e0d8c6,eee6d4", "slab"],
			[1, "8a8478,8a8478,8a8478,8a8478", "flat"], [2, "9a948a,b4aea4,c8c2b6,d8d2c6", "flat"],
			[1, "3a3a40,3a3a40,3a3a40,3a3a40", "flat"]],
		"fill": ["2e2e34,3c3c44,4a4a52,5a5a64", "asphalt"],
	},
	"night": {
		"top": [[1, "8a90b0,8a90b0,8a90b0,8a90b0", "flat"], [6, "4a5068,5a6080,6a7090,7a80a0", "slab"],
			[1, "30344a,30344a,30344a,30344a", "flat"], [2, "40465e,4a5068,565c76,62688a", "flat"],
			[1, "161820,161820,161820,161820", "flat"]],
		"fill": ["14161e,1c1e28,242632,2c2e3c", "asphalt"],
	},
	"farm": {
		"top": [[2, "4a8a2c,6aaa3a,8ac84a,a8e060", "grass"], [3, "2e6a2a,3e7a30,4a8a34,5a9a3a", "grass"]],
		"fill": ["5a3418,7a4a24,946034,a87a46", "dirt"],
	},
	"quarry": {
		"top": [[2, "c8a070,dcb888,ecd0a0,f8e4bc", "flat"], [4, "a87a4a,c09060,d4a874,e4c08c", "rock"]],
		"fill": ["7a5030,946640,a87a4e,bc8e60", "strata"],
	},
	"lake": {
		"top": [[7, "5a3a22,7a5230,a07040,c09060", "planks"], [1, "2a1a10,2a1a10,2a1a10,2a1a10", "flat"]],
		"fill": ["3a2a1c,4a3624,5a4430,6a5240", "dirt"],
	},
}


static func atlas(theme: String) -> Image:
	var th: Dictionary = THEMES[theme]
	var im := P.img(T * 4, T * 4)
	for mask in 16:
		var ox := (mask % 4) * T
		var oy := (mask / 4) * T
		_tile(im, ox, oy, mask, th)
	return im


static func _tile(im: Image, ox: int, oy: int, mask: int, th: Dictionary) -> void:
	var fill := P.ramp(th.fill[0])
	for y in T:
		for x in T:
			P.put(im, ox + x, oy + y, _pattern(fill, th.fill[1], x, y))
	if mask & 1 == 0:
		var y := 0
		for band in th.top:
			var r := P.ramp(band[1])
			for k in band[0]:
				for x in T:
					P.put(im, ox + x, oy + y, _pattern(r, band[2], x, y))
				y += 1
	var edge := Color("24140e")
	if mask & 8 == 0:
		for y in T:
			P.put(im, ox, oy + y, edge)
			P.put(im, ox + 1, oy + y, im.get_pixel(ox + 1, oy + y).lightened(0.15))
	if mask & 2 == 0:
		for y in T:
			P.put(im, ox + T - 1, oy + y, edge)
			P.put(im, ox + T - 2, oy + y, im.get_pixel(ox + T - 2, oy + y).darkened(0.2))


## Seamless 16-periodic surface textures.
static func _pattern(r: Array, kind: String, x: int, y: int) -> Color:
	var h := _hash(x, y)
	match kind:
		"slab":
			if x == 15:
				return r[0]
			if x == 0 or y == 1:
				return r[3]
			return r[2] if h > 0.25 else r[1]
		"asphalt":
			if h > 0.93:
				return r[3]
			if h > 0.7:
				return r[2]
			return r[1] if h > 0.15 else r[0]
		"grass":
			return r[3] if h > 0.8 else (r[2] if h > 0.45 else (r[1] if h > 0.1 else r[0]))
		"dirt":
			if h > 0.94:
				return r[3]
			return r[2] if h > 0.6 else (r[1] if h > 0.12 else r[0])
		"rock":
			if (x + y * 3) % 11 == 0:
				return r[0]
			return r[3] if h > 0.85 else (r[2] if h > 0.35 else r[1])
		"strata":
			var band := (y / 4) % 2
			if h > 0.92:
				return r[0]
			return r[2] if band == 0 else r[1]
		"planks":
			if x % 8 == 7:
				return r[0]
			if (x % 8 == 1) and (y == 2 or y == 5):
				return Color("2a2a30")
			return r[3] if y == 0 else (r[2] if h > 0.4 else r[1])
	return r[1]


static func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 1000) / 1000.0
