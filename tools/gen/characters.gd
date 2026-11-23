# Cast definitions for the placeholder generator: body build, colour ramps
# (shadow, mid, light, highlight) and hand-drawn pixel-grid heads.
# Heads face right. Letters: a b c d = skin ramp, w/e = eye white/pupil,
# r = brows/hair dark, h = hair, m = mouth, t = teeth/tongue, o = outline,
# u = stubble, f = freckles; hat/cap letters are per character.
extends RefCounted

const P := preload("res://tools/gen/pix.gd")


static func skin(base := "b0704a,d8955f,f2c08f,ffe0b8") -> Array:
	return P.ramp(base)


static func head_pal(sk: Array, extra: Dictionary) -> Dictionary:
	var pal := {
		"a": sk[0], "b": sk[1], "c": sk[2], "d": sk[3],
		"w": Color("fbf7ee"), "e": Color("1b1b2e"), "r": Color("3a2414"),
		"h": Color("5a3a22"), "m": Color("7a3428"), "t": Color("f4e8e0"),
		"o": Color("24140e"), "n": sk[0], "u": Color("b0806a"), "f": Color("c86a48"),
	}
	pal.merge(extra, true)
	return pal


static func all() -> Dictionary:
	return {"sheriff": sheriff(), "earl": earl(), "dewey": dewey(), "deputy": deputy()}


static func sheriff() -> Dictionary:
	var sk := skin()
	return {
		"thigh": 11.0, "shin": 11.0, "torso": 18.0, "upper_arm": 9.0, "forearm": 9.0,
		"shoulder_w": 13.0, "hip_w": 11.0,
		"r_thigh": 3.3, "r_shin": 2.7, "r_arm": 2.4, "r_fore": 2.1, "r_hand": 2.0,
		"skin": sk,
		"shirt": P.ramp("8a7448,b8a066,dcc890,f2e6bc"),
		"sleeve": P.ramp("8a7448,b8a066,dcc890,f2e6bc"),
		"pants": P.ramp("33301f,524b38,6e6650,8a826a"),
		"boot": P.ramp("1a0f08,3a2414,5a3a22,7a5230"),
		"belt": P.ramp("1e120a,3f2a1a,5a3e26,6e5030"),
		"buckle": Color("f0c848"),
		"decals": "sheriff",
		"throws": true,
		"head": {
			"anchor": Vector2i(10, 19),
			"rows": [
				"........xxxxxx......",
				"......xyzzzzyyx.....",
				".....xyzzzzyyyyx....",
				".....xyyyyyyyyyx....",
				".....kkkkkkkkkkk....",
				"..xyyzzzzzzyyyyyyx..",
				".xyyyyyyyyyyyyyyyyxx",
				"..xxxxxxxxxxxxxxxx..",
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
			],
			"hat_rows": 8,
			"hair_rows": [
				".....rrhhhhhhhr.....",
				"....rhhhhhhhhhhr....",
			],
			"pal": head_pal(sk, {"x": Color("4a2c18"), "y": Color("7a5230"), "z": Color("a87a46"), "k": Color("2a1a10")}),
			"mouth_open": [[13, 14, "m"], [14, 14, "m"], [15, 14, "m"], [13, 15, "m"], [14, 15, "t"], [15, 15, "m"]],
			"smile": [[12, 14, "m"], [16, 13, "m"]],
		},
	}


static func earl() -> Dictionary:
	var sk := skin("a8684a,d0906a,eab48a,f8d4b0")
	var W := P.ramp("a8a8a0,d0d0c8,f0f0e8,ffffff")
	var K := P.ramp("141420,22222c,30303e,44445a")
	return {
		"thigh": 9.0, "shin": 9.0, "torso": 15.0, "upper_arm": 8.0, "forearm": 8.0,
		"shoulder_w": 11.0, "hip_w": 9.0,
		"r_thigh": 2.8, "r_shin": 2.3, "r_arm": 2.1, "r_fore": 1.9, "r_hand": 1.9,
		"skin": sk,
		"shirt": W, "shirt_stripe": K,
		"sleeve": W, "sleeve_stripe": K,
		"pants": W, "pants_stripe": K,
		"boot": P.ramp("120a06,2a1810,42281a,5a3a22"),
		"belt": K, "buckle": Color("8a8a96"),
		"decals": "earl",
		"throws": true,
		"head": {
			"anchor": Vector2i(7, 14),
			"rows": [
				"....KKKKKK......",
				"...WWWWWWWW.....",
				"..KKKKKKKKKK....",
				"..WWWWWWWWWWKK..",
				"..KKKKKKKKKKKKK.",
				"..rbcccccccc....",
				"..bbccccrrcc....",
				".aobccccwecc....",
				".aabbcccccccdd..",
				"..abbccccccccn..",
				"..abuuuuumtmu...",
				"...abuuummmu....",
				"....aauuuuu.....",
				".....abbb.......",
				".....abbb.......",
			],
			"hat_rows": 5,
			"hair_rows": ["..rrrrrrrrr.....", ".rhhhhhhhhhr...."],
			"pal": head_pal(sk, {"W": Color("f0f0e8"), "K": Color("22222c")}),
			"mouth_open": [[9, 11, "t"], [10, 11, "m"], [9, 12, "m"]],
			"smile": [],
		},
	}


static func dewey() -> Dictionary:
	var sk := skin("b07850,d89a68,f4c494,ffe2bc")
	var blue := P.ramp("1e3e6a,2a5a94,3d7fc4,6aa8e0")
	return {
		"thigh": 12.0, "shin": 12.0, "torso": 17.0, "upper_arm": 10.0, "forearm": 9.0,
		"shoulder_w": 12.0, "hip_w": 9.0,
		"r_thigh": 2.7, "r_shin": 2.3, "r_arm": 2.0, "r_fore": 1.8, "r_hand": 1.9,
		"skin": sk, "shirt": blue, "sleeve": blue, "pants": blue,
		"boot": P.ramp("1a0f08,3a2414,5a3a22,7a5230"),
		"belt": P.ramp("1a3460,24487a,2e5a94,3a6aa8"), "buckle": Color("c8c8d0"),
		"decals": "dewey",
		"throws": false,
		"head": {
			"anchor": Vector2i(8, 14),
			"rows": [
				".....RRRRRR......",
				"....RRSSSSRR.....",
				"...RRRRRRRRRR....",
				"...RRRRRRRRRRQQQ.",
				"...rbbcccccccc...",
				"..aabcccccrrcc...",
				".aaoobcccwwecc...",
				".aaaobcccwwecd...",
				".aaabbcccccccdd..",
				"..aabbccccccccc..",
				"...abbccmmmmmc...",
				"....abbcctttc....",
				"....aabbcccc.....",
				"......abbb.......",
				"......abbb.......",
			],
			"hat_rows": 4,
			"hair_rows": ["...rhhhhhhhh.....", "..rhhhhhhhhhh...."],
			"pal": head_pal(sk, {"R": Color("d8342a"), "S": Color("f06a50"), "Q": Color("9a2218")}),
			"mouth_open": [[9, 11, "m"], [10, 11, "t"], [11, 11, "m"], [10, 12, "m"]],
			"smile": [],
		},
	}


static func deputy() -> Dictionary:
	var sk := skin("b8785a,e0a07a,f6c8a0,ffe4c8")
	var navy := P.ramp("141c38,24407a,3a5a9a,5a7aba")
	return {
		"thigh": 12.0, "shin": 12.0, "torso": 18.0, "upper_arm": 10.0, "forearm": 9.0,
		"shoulder_w": 12.0, "hip_w": 9.0,
		"r_thigh": 2.6, "r_shin": 2.2, "r_arm": 2.0, "r_fore": 1.8, "r_hand": 1.9,
		"skin": sk, "shirt": navy, "sleeve": navy,
		"pants": P.ramp("101630,1c2c5a,2a4078,3a5490"),
		"boot": P.ramp("0e0a08,201814,34281e,4a3a2a"),
		"belt": P.ramp("1e120a,3f2a1a,5a3e26,6e5030"), "buckle": Color("f0c848"),
		"decals": "deputy",
		"throws": false,
		"head": {
			"anchor": Vector2i(8, 15),
			"rows": [
				"....NNNNNNN......",
				"...NMMMMMMMN.....",
				"...NNNNNNNNNN....",
				"...gggggggggg....",
				"..NNNNNNNNNNNNNN.",
				"..hhbbccccccc....",
				"..hbbcccccrrcc...",
				".aobbcccfwwecc...",
				".aobbccfcwweccdd.",
				"..abbcccfccccdddd",
				"..abbcccccccccdd.",
				"...abbccmmmmc....",
				"....abbcccccc....",
				".....aabbbb......",
				"......abbb.......",
				"......abbb.......",
			],
			"hat_rows": 5,
			"hair_rows": ["...hhhhhhhhh.....", "..hhhhhhhhhhh...."],
			"pal": head_pal(sk, {"N": Color("1c2850"), "M": Color("3a5a9a"), "g": Color("f0c848"), "h": Color("e07a30")}),
			"mouth_open": [[10, 12, "t"], [11, 12, "m"], [10, 13, "m"]],
			"smile": [],
		},
	}
