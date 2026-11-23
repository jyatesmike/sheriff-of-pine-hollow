# Hens, geese and ducks: 32x24 frames, feet at the bottom row, facing right.
# Rows: walk (4), peck (3), flap (2), tumble (2)  — see data/sprites.json.
extends RefCounted

const P := preload("res://tools/gen/pix.gd")
const W := 32
const H := 24
const ANIMS := [["walk", 4], ["peck", 3], ["flap", 2], ["tumble", 2]]

const BODY := [
	"....................",
	"....................",
	"....................",
	"....................",
	".TT.................",
	"TTVT................",
	"TVVTT...............",
	".TVVWWWWWWWWWWWW....",
	"..VWWWWWWWWWWWWWW...",
	"..VWWVVVVVVWWWWWW...",
	"..VWVVSSSVVVWWWWW...",
	"...VWVVVVVVVWWWW....",
	"....VWWWWWWWWWVV....",
	".....VVWWWWWVVV.....",
	".......VVVVVV.......",
]
const HEN_HEAD := [
	"...RR....",
	"..RRRR...",
	".WWWWWW..",
	".WWWeWWY.",
	".WWWWWWYY",
	"WWWWWRR..",
	"WWWWWR...",
]
const GOOSE_HEAD := [
	"..KKK....",
	".KKeKK...",
	".KWKKKYY.",
	".KWWKKYYY",
	"..KKK....",
	"..KKK....",
	"..KK.....",
	"..KK.....",
	"..KK.....",
	"..KKK....",
	".KKKK....",
]
const DUCK_HEAD := [
	"..GGG....",
	".GGeGG...",
	".GGGGGYYY",
	".GGGGGYYY",
	"..LLL....",
	"..WWW....",
]
const WING_UP := [
	"....VVV.....",
	"..VWWWVV....",
	".VWWWWWWV...",
	"VWWWWWWVV...",
]
const WING_DOWN := [
	"VWWWWWWV",
	".VWWWWV.",
	"..VVVV..",
]


static func palette(kind: String) -> Dictionary:
	if kind == "duck":
		# a mallard drake: green head, white collar, chestnut and grey body
		return {"W": Color("b8a890"), "V": Color("7a5a3e"), "S": Color("4a3a2e"), "T": Color("2a2a30"),
			"K": Color("1e1e22"), "Y": Color("f0c020"), "R": Color("d8342a"), "e": Color("101010"),
			"G": Color("1e7a3a"), "L": Color("f4f0e6")}
	if kind == "goose":
		return {"W": Color("b8ab98"), "V": Color("8a7a66"), "S": Color("5e5246"), "T": Color("2a2a2e"),
			"K": Color("1e1e22"), "Y": Color("f2a81c"), "R": Color("d8342a"), "e": Color("f4f0e6")}
	return {"W": Color("f6f2e8"), "V": Color("cfd2dc"), "S": Color("a4a8b8"), "T": Color("c4c0b4"),
		"K": Color("1e1e22"), "Y": Color("f2a81c"), "R": Color("d8342a"), "e": Color("1b1b2e")}


static func frame(kind: String, anim: String, i: int) -> Image:
	var pal := palette(kind)
	var im := P.img(W, H)
	var body_at := Vector2i(6, 5)
	var bob := 0
	if anim == "walk":
		bob = [0, -1, 0, -1][i]
	var at := body_at + Vector2i(0, bob)
	# legs
	var leg := Color("f08a1a") if kind == "duck" else Color("e0901a")
	if anim != "tumble":
		var spread: Array = [[0, 0], [2, -1], [0, 0], [-1, 2]][i % 4] if anim == "walk" else [0, 0]
		for k in 2:
			var lx: int = at.x + 9 + k * 4 + spread[k]
			for y in range(at.y + 15, 24):
				P.put(im, lx, y, leg)
			P.put(im, lx + 1, 23, leg)
			P.put(im, lx - 1, 23, leg)
	P.grid(im, BODY, pal, at)
	# head
	var head: Array = GOOSE_HEAD if kind == "goose" else (DUCK_HEAD if kind == "duck" else HEN_HEAD)
	var head_at := at + (Vector2i(11, -4) if kind == "goose" else (Vector2i(11, 1) if kind == "duck" else Vector2i(11, 0)))
	if anim == "peck":
		head_at += [Vector2i(1, 3), Vector2i(2, 6), Vector2i(1, 3)][i]
	P.grid(im, head, pal, head_at)
	# wings
	if anim == "flap" or anim == "tumble":
		if i == 0 or anim == "tumble":
			P.grid(im, WING_UP, pal, at + Vector2i(2, 2 if anim == "flap" else 4))
		else:
			P.grid(im, WING_DOWN, pal, at + Vector2i(3, 11))
	if anim == "tumble":
		# loose feathers
		P.put(im, 3 + i * 2, 4, pal.W); P.put(im, 27 - i, 6 + i, pal.W); P.put(im, 5, 18 - i, pal.V)
	P.outline(im)
	return im
