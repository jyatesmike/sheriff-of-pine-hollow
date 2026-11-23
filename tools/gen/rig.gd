# Humanoid rig: draws one 48x64 frame of a character in a pose.
# Each body part is drawn on its own layer and outlined separately, then
# layered back-to-front, so overlapping limbs get crisp dark edges.
# Angles: 0 = straight down, positive = toward the facing side (right).
#   legs: knee bend rotates the shin backward;  arms: elbow bends forward.
extends RefCounted

const P := preload("res://tools/gen/pix.gd")
const W := 48
const H := 64
const GROUND := 63.0


static func dir(a: float) -> Vector2:
	return Vector2(sin(a), cos(a))


static func render(ch: Dictionary, pose: Dictionary) -> Image:
	var lean: float = pose.get("lean", 0.0)
	var up := Vector2(sin(lean), -cos(lean))
	var right := Vector2(cos(lean), sin(lean))
	var legs := {"b": pose.get("leg_b", Vector2(0, 0)), "f": pose.get("leg_f", Vector2(0, 0))}

	# --- place the hip: on the ground (lowest foot touches) or at a fixed height
	var hip := Vector2(pose.get("hip_x", 24.0), 0.0)
	if pose.has("hip_y"):
		hip.y = pose.hip_y
	else:
		var lowest := 0.0
		for k in legs:
			var g := _leg_points(ch, Vector2.ZERO, legs[k])
			lowest = maxf(lowest, maxf(g[2].y, g[3].y) + ch.r_shin)
		hip.y = GROUND - lowest
	hip.y += pose.get("bob", 0.0)
	var neck: Vector2 = hip + up * ch.torso
	var sh_b: Vector2 = neck + right * (-ch.shoulder_w * 0.22) - up * 3.0
	var sh_f: Vector2 = neck + right * (ch.shoulder_w * 0.18) - up * 3.0

	var out := P.img(W, H)
	# back to front: back arm, back leg, front leg, torso, head, front arm
	_layer(out, func(im): _arm(im, ch, sh_b, pose.get("arm_b", Vector2(0, 0.2)), true, pose, false))
	_layer(out, func(im): _leg(im, ch, hip + right * -1.5, legs.b, true))
	_layer(out, func(im): _leg(im, ch, hip + right * 1.5, legs.f, false))
	_layer(out, func(im): _torso(im, ch, hip, neck, up, right))
	_layer(out, func(im): _head(im, ch, neck + Vector2(0, pose.get("head_dy", 0.0)), pose))
	_layer(out, func(im): _arm(im, ch, sh_f, pose.get("arm_f", Vector2(0, 0.2)), false, pose, true))
	return out


static func _layer(out: Image, painter: Callable) -> void:
	var im := P.img(W, H)
	painter.call(im)
	P.outline(im)
	P.blit(out, im)


# returns [hip, knee, ankle, toe]
static func _leg_points(ch: Dictionary, hip: Vector2, ang: Vector2) -> Array:
	var knee: Vector2 = hip + dir(ang.x) * ch.thigh
	var shin_a: float = ang.x - ang.y
	var ankle: Vector2 = knee + dir(shin_a) * ch.shin
	var foot_dir := Vector2(cos(shin_a), -sin(shin_a))   # perpendicular, pointing forward
	var toe := ankle + foot_dir * 4.5 + Vector2(0, 0.5)
	return [hip, knee, ankle, toe]


static func _leg(im: Image, ch: Dictionary, hip: Vector2, ang: Vector2, back: bool) -> void:
	var g := _leg_points(ch, hip, ang)
	var pants: Array = ch.pants if not back else _darker(ch.pants)
	var stripe: Array = ch.get("pants_stripe", [])
	P.capsule(im, g[0], g[1], ch.r_thigh, pants, stripe)
	P.capsule(im, g[1], g[2], ch.r_shin, pants, stripe)
	P.capsule(im, g[2] + Vector2(-1, 0), g[3], ch.r_shin * 0.95, ch.boot)
	# trouser cuff / boot top
	P.capsule(im, g[2] - dir(ang.x - ang.y) * 2.0, g[2] - dir(ang.x - ang.y) * 1.0, ch.r_shin + 0.3, ch.boot)


static func _arm(im: Image, ch: Dictionary, sh: Vector2, ang: Vector2, back: bool, pose: Dictionary, front: bool) -> void:
	var elbow: Vector2 = sh + dir(ang.x) * ch.upper_arm
	var hand: Vector2 = elbow + dir(ang.x + ang.y) * ch.forearm
	var sleeve: Array = ch.sleeve if not back else _darker(ch.sleeve)
	var stripe: Array = ch.get("sleeve_stripe", [])
	P.capsule(im, sh, elbow, ch.r_arm, sleeve, stripe)
	P.capsule(im, elbow, hand, ch.r_fore, sleeve, stripe)
	P.disc(im, hand, ch.r_hand, ch.skin)
	if front and pose.get("item", "") == "rock":
		P.disc(im, hand + Vector2(1, -2), 2.4, P.ramp("5e5850,8a8478,b0aa9c,d4cec0"))
	if front and pose.get("item", "") == "popgun":
		var wood := P.ramp("4a2c18,7a5230,a87a46,c89a66")
		P.capsule(im, hand + Vector2(-3, 1), hand + Vector2(9, -1), 1.6, wood)
		P.capsule(im, hand + Vector2(9, -1), hand + Vector2(11, -1.3), 1.2, P.ramp("6a6a70,9a9aa4,c0c0c8,e0e0e8"))
		if pose.get("cork", true):
			P.disc(im, hand + Vector2(12.5, -1.5), 1.4, P.ramp("8a5a30,c08a50,e0b070,f0d090"))


static func _torso(im: Image, ch: Dictionary, hip: Vector2, neck: Vector2, up: Vector2, right: Vector2) -> void:
	var hw: float = ch.hip_w * 0.5
	var sw: float = ch.shoulder_w * 0.5
	# pelvis (trousers)
	var pelvis := PackedVector2Array([
		hip - up * 3.0 - right * hw, hip - up * 3.0 + right * hw,
		hip + up * 3.0 + right * hw, hip + up * 3.0 - right * hw])
	P.poly(im, pelvis, ch.pants, hip, right, hw, ch.get("pants_stripe", []))
	# shirt / chest
	var chest := PackedVector2Array([
		hip + up * 2.0 - right * hw, hip + up * 2.0 + right * hw,
		hip + up * (ch.torso * 0.62) + right * (sw + 0.5),
		neck - up * 1.0 + right * (sw - 1.0), neck + right * 2.0, neck - right * 2.0,
		neck - up * 1.0 - right * (sw - 1.0),
		hip + up * (ch.torso * 0.62) - right * (sw + 0.5)])
	var mid := (hip + neck) * 0.5
	P.poly(im, chest, ch.shirt, mid, right, sw, ch.get("shirt_stripe", []))
	# belt
	var belt := PackedVector2Array([
		hip + up * 1.0 - right * hw, hip + up * 1.0 + right * hw,
		hip + up * 3.0 + right * hw, hip + up * 3.0 - right * hw])
	P.poly(im, belt, ch.belt, hip, right, hw)
	var bk: Vector2 = hip + up * 2.0 + right * (hw * 0.45)
	P.put(im, int(bk.x), int(bk.y), ch.buckle)
	P.put(im, int(bk.x) + 1, int(bk.y), ch.buckle)
	_decals(im, ch, hip, neck, up, right)


static func _decals(im: Image, ch: Dictionary, hip: Vector2, neck: Vector2, up: Vector2, right: Vector2) -> void:
	var shirt: Array = ch.shirt
	var fold: Color = shirt[0]
	match ch.decals:
		"sheriff":
			# button placket, pocket, cloth folds, collar, gold star badge
			for i in range(3, int(ch.torso) - 2, 3):
				var p: Vector2 = hip + up * i + right * 2.0
				P.put(im, int(p.x), int(p.y), fold)
			_line(im, neck - up * 5.0 - right * 4.0, neck - up * 5.0 - right * 1.0, fold)
			_line(im, hip + up * 11.0 - right * 4.5, hip + up * 7.0 - right * 2.0, fold)
			_line(im, hip + up * 6.0 + right * 4.0, hip + up * 4.0 + right * 2.0, fold)
			_line(im, neck - right * 2.0, neck + right * 0.0 - up * 2.0, shirt[3])
			_star(im, neck - up * 6.0 + right * 3.5)
		"earl":
			# a number patch on the chest
			var c: Vector2 = neck - up * 6.0 + right * 2.0
			for y in 3:
				for x in 4:
					P.put(im, int(c.x) + x - 1, int(c.y) + y, Color("fbf7ee"))
			P.put(im, int(c.x), int(c.y) + 1, Color("22222c"))
			P.put(im, int(c.x) + 1, int(c.y) + 1, Color("22222c"))
		"dewey":
			# overall bib + straps + red rag in back pocket
			var bib_top: Vector2 = neck - up * 6.0
			for i in 7:
				var p: Vector2 = bib_top - up * i
				for dx in [-2, -1, 0, 1, 2, 3]:
					var q: Vector2 = p + right * dx
					P.put(im, int(q.x), int(q.y), shirt[2] if dx > -2 else shirt[1])
			_line(im, neck - right * 3.0, bib_top - right * 3.0, shirt[3])
			_line(im, neck + right * 3.0, bib_top + right * 3.0, shirt[0])
			var rag: Vector2 = hip + up * 1.0 - right * (ch.hip_w * 0.5 + 0.5)
			for y in 4:
				P.put(im, int(rag.x), int(rag.y) + y, Color("d8342a"))
				P.put(im, int(rag.x) - 1, int(rag.y) + y + 1, Color("9a2218"))
		"deputy":
			# Sam Browne strap, badge, shirt pocket
			_line(im, neck + right * 3.0 - up * 1.0, hip + up * 3.0 - right * 3.0, Color("5a3e26"))
			_star(im, neck - up * 5.0 + right * 3.0)


static func _star(im: Image, c: Vector2) -> void:
	var g := Color("ffd23f")
	var d := Color("c8901c")
	var x := int(c.x)
	var y := int(c.y)
	P.put(im, x, y - 2, g)
	for i in range(-2, 3):
		P.put(im, x + i, y - 1, g if i < 1 else d)
	P.put(im, x - 1, y, g); P.put(im, x, y, Color("fff6c0")); P.put(im, x + 1, y, d)
	P.put(im, x - 1, y + 1, d); P.put(im, x + 1, y + 1, d)


static func _line(im: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n:
		var p := a.lerp(b, float(i) / maxf(n - 1, 1))
		P.put(im, int(p.x), int(p.y), c)


static func _head(im: Image, ch: Dictionary, neck: Vector2, pose: Dictionary) -> void:
	var hd: Dictionary = ch.head
	var pal: Dictionary = hd.pal.duplicate()
	if pose.get("blink", false):
		pal["w"] = pal["c"]
		pal["e"] = pal["a"]
	var at := Vector2i(roundi(neck.x) - hd.anchor.x, roundi(neck.y) - hd.anchor.y)
	var rows: Array = hd.rows
	var hat_n: int = hd.hat_rows
	if pose.get("hat_up", false):
		# hat lifted: draw hair where the hat was, then the hat raised and tilted back
		var face := rows.slice(hat_n)
		P.grid(im, face, pal, at + Vector2i(0, hat_n))
		P.grid(im, hd.hair_rows, pal, at + Vector2i(0, hat_n - hd.hair_rows.size()))
		P.grid(im, rows.slice(0, hat_n), pal, at + Vector2i(-1, -4))
	else:
		P.grid(im, rows, pal, at)
	var overlay: Array = []
	if pose.get("mouth", "") == "open":
		overlay = hd.mouth_open
	elif pose.get("mouth", "") == "smile":
		overlay = hd.smile
	for o in overlay:
		P.put(im, at.x + o[0], at.y + o[1], pal[o[2]])


static func _darker(ramp: Array) -> Array:
	return [ramp[0].darkened(0.15), ramp[0], ramp[1], ramp[2]]
