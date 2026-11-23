# The townsfolk (favor-givers, fair barker, night watchman...): same body rig
# and face as the main cast, each with their own hat / hair and clothes.
extends RefCounted

const P := preload("res://tools/gen/pix.gd")
const C := preload("res://tools/gen/characters.gd")

# The shared face (12 rows), copied from the Sheriff's head below the hat.
const FACE := [
	".....rrbcccccccb....",
	".....rbcccccrrrcc...",
	".....bbcccccwwecc...",
	"....aobbccccwwecdc..",
	"....aabbcccccccccdd.",
	".....abbbcccccccna..",
	".....abbbccccmmmc...",
	"......abbbccccccc...",
	"......aabbbccccc....",
	".......aaabbbb......",
	"........abbb........",
	"........abbb........",
]

const HATS := {
	"bun": [
		"....................",
		"........gGGg........",
		".......gGGGGg.......",
		"........gGGg........",
		".....gGGGGGGGg......",
		"....gGGGGGGGGGg.....",
		"....GGGGGGGGGGGG....",
		"....gGGGGGGGGGGg....",
	],
	"slick": [
		"....................",
		"....................",
		"....................",
		"....................",
		"......hHHHHHHh......",
		".....hHHHcHHHHh.....",
		".....HHHHcHHHHHh....",
		".....HHHHHHHHHHH....",
	],
	"straw": [
		"....................",
		"....................",
		"......sSSSSSs.......",
		".....sSSSSSSSs......",
		".....SSSSSSSSS......",
		".....kkkkkkkkk......",
		"..sSSSSSSSSSSSSSSs..",
		"...ssssssssssssss...",
	],
	"bucket": [
		"....................",
		"....................",
		"......oOOOOOo.......",
		".....oOOOOOOOo......",
		".....OOOOOLOOO......",
		".....OOOOOOOOO......",
		"....oOOOOOOOOOOo....",
		"....oooooooooooo....",
	],
	"boater": [
		"....................",
		"....................",
		"....................",
		"......sSSSSSSs......",
		"......SSSSSSSS......",
		"......RRRRRRRR......",
		"...sSSSSSSSSSSSSs...",
		"....ssssssssssss....",
	],
	"conductor": [
		"....................",
		"....................",
		"......nNNNNNNn......",
		".....nNNNNNNNNn.....",
		".....NNNNYNNNNN.....",
		".....nnnnnnnnnn.....",
		".....kkkkkkkkkkkkk..",
		"....................",
	],
	"cap": [
		"....................",
		"....................",
		"......uUUUUUu.......",
		".....uUUUUUUUu......",
		".....UUUUUUUUU......",
		".....UUUUUUUUU......",
		".....uuuuuuuDDDDDu..",
		"............DDDD....",
	],
	"flatcap": [
		"....................",
		"....................",
		"....................",
		"......fFFFFFFf......",
		".....fFFFFFFFFf.....",
		".....FFFFFFFFFFF....",
		".....fffffffffffkk..",
		"....................",
	],
}

const HAT_PAL := {
	"g": Color("9a9aa2"), "G": Color("c8c8d0"),
	"h": Color("141418"), "H": Color("2a2a30"),
	"s": Color("b8963a"), "S": Color("e8c868"), "k": Color("2a1a10"),
	"o": Color("4e5a32"), "O": Color("6e7a46"), "L": Color("e85a3a"),
	"R": Color("c83a3a"),
	"n": Color("141a30"), "N": Color("24305a"), "Y": Color("f0c848"),
	"f": Color("4a3a2e"), "F": Color("6a5644"),
	"u": Color("6a6e76"), "U": Color("9a9ea8"), "D": Color("1a1e26"),
}


static func _head(hat: String, sk: Array, extra := {}, mustache := false) -> Dictionary:
	var rows: Array = HATS[hat].duplicate()
	rows.append_array(FACE)
	if mustache:
		rows[8 + 6] = ".....abbbcccHHHHc..."
	var pal := C.head_pal(sk, HAT_PAL)
	pal.merge(extra, true)
	return {
		"anchor": Vector2i(10, 19),
		"rows": rows,
		"hat_rows": 8,
		"hair_rows": [".....rrhhhhhhhr.....", "....rhhhhhhhhhhr...."],
		"pal": pal,
		"mouth_open": [[13, 14, "m"], [14, 14, "m"], [15, 14, "m"], [13, 15, "m"], [14, 15, "t"], [15, 15, "m"]],
		"smile": [[12, 14, "m"], [16, 13, "m"]],
	}


static func _body(build: float, shirt: Array, pants: Array, head: Dictionary, sk: Array, extra := {}) -> Dictionary:
	var b := {
		"thigh": 10.0 * build, "shin": 10.0 * build, "torso": 17.0, "upper_arm": 9.0, "forearm": 8.0,
		"shoulder_w": 12.0, "hip_w": 10.0,
		"r_thigh": 3.0, "r_shin": 2.5, "r_arm": 2.2, "r_fore": 2.0, "r_hand": 1.9,
		"skin": sk, "shirt": shirt, "sleeve": shirt, "pants": pants,
		"boot": P.ramp("1a0f08,3a2414,5a3a22,7a5230"),
		"belt": P.ramp("1e120a,3f2a1a,5a3e26,6e5030"), "buckle": Color("c8a040"),
		"decals": "none", "throws": false, "head": head,
	}
	b.merge(extra, true)
	return b


static func all() -> Dictionary:
	var sk1 := C.skin("b0704a,d8955f,f2c08f,ffe0b8")
	var sk2 := C.skin("8a5a3a,b07850,d8a070,f0c49a")
	var sk3 := C.skin("a86a4a,d0906a,eab48a,f8d4b0")
	return {
		"aunt": _body(0.95, P.ramp("8a3a5a,b85a7a,d87a9a,f0a8c0"), P.ramp("8a3a5a,b85a7a,d87a9a,f0a8c0"),
			_head("bun", sk1, {"r": Color("8a8a92"), "h": Color("b8b8c0")}), sk1,
			{"shoulder_w": 11.0, "hip_w": 12.0, "r_thigh": 3.6, "boot": P.ramp("2a1a1a,4a2a2a,6a3a3a,8a4a4a")}),
		"barber": _body(1.0, P.ramp("a8a8a8,d0d0d0,f0f0f0,ffffff"), P.ramp("1e1e26,2e2e3a,40404e,545466"),
			_head("slick", sk2, {"r": Color("141418")}, true), sk2),
		"farmer": _body(1.05, P.ramp("6a1e1a,9a2e24,c84a3a,e8786a"), P.ramp("1e3e6a,2a5a94,3d7fc4,6aa8e0"),
			_head("straw", sk3, {}, true), sk3, {"shoulder_w": 14.0, "torso": 18.0}),
		"fisherman": _body(1.0, P.ramp("4a5a2a,6a7a3a,8a9a52,aab872"), P.ramp("6a5a3a,8a7a52,aa9a6e,c8b88a"),
			_head("bucket", sk1), sk1, {"boot": P.ramp("1a2a1a,2a4a2a,3a6a3a,4a8a4a")}),
		"barker": _body(1.0, P.ramp("8a1e1e,c83a3a,e86a5a,f4a090"), P.ramp("141418,24242c,34343e,48485a"),
			_head("boater", sk2, {}, true), sk2, {"shirt_stripe": P.ramp("c8c0b0,e8e0d0,f8f4ea,ffffff"), "sleeve_stripe": P.ramp("c8c0b0,e8e0d0,f8f4ea,ffffff")}),
		"conductor": _body(1.0, P.ramp("141a30,1e2848,2a3a66,3e5288"), P.ramp("141a30,1e2848,2a3a66,3e5288"),
			_head("conductor", sk3, {}, true), sk3, {"buckle": Color("f0c848")}),
		"jim": _body(1.0, P.ramp("141e3a,1e2c5a,2e4282,4a62aa"), P.ramp("8a7a52,aa9a6e,c8b88a,e0d4a8"),
			_head("cap", sk3, {"r": Color("8a8a92"), "h": Color("a8a8b0")}), sk3,
			{"boot": P.ramp("8a8a8a,b8b8b8,dcdcdc,f4f4f4")}),
		"watchman": _body(1.0, P.ramp("2a2018,4a3828,6a5038,8a6a4a"), P.ramp("2a2a30,3e3e48,54545e,6a6a76"),
			_head("flatcap", sk1), sk1),
	}
