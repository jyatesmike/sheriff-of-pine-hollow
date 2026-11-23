# The deputy's bloodhound. Once you pass "start" he's let off his rope and
# follows your scent, faster than you can run. Pick up sausages and press
# F to toss one behind you: he stops to eat it. Wade across the creek and
# he loses your scent for a bit. Past "quit" he gives up and howls.
#   {"type": "bloodhound", "x": 118, "start": 122, "quit": 232,
#    "sausages": [128, 152], "creek": [162, 170]}
extends LevelObject

enum S { KENNEL, CHASE, EAT, SNIFF, RECOIL, QUIT }

const SPEED := 205.0

var s := S.KENNEL
var hx := 0.0                # dog local x
var t := 0
var sniffed := false
var carried := 0             # sausages Earl is carrying
var pickups: Array = []      # local x of sausages on the ground (-1 = taken)
var tossed: Array = []       # {x, y, vx, vy, landed}
var creek := Vector2.ZERO
var water: Water
var dog: Node2D              # follows the dog, for the HUD meter
var _t := 0.0


func _setup() -> void:
	for sx in o.get("sausages", []):
		pickups.append((sx - o.x) * TILE)
	if o.has("creek"):
		creek = Vector2((o.creek[0] - o.x) * TILE, (o.creek[1] - o.x) * TILE)
		water = Water.make(level.world, Rect2(global_position.x + creek.x, global_position.y - 3.0, creek.y - creek.x, 9.0), Color("2e5e8e"), Color("1e4470"))
		level.mud_zones.append([global_position.x + creek.x, global_position.x + creek.y, "creek"])
	dog = Node2D.new()
	add_child(dog)


func step(delta: float) -> void:
	_t += delta
	t = maxi(t - 1, 0)
	var p := player()
	var px := p.global_position.x - global_position.x
	# sausage pickups
	for i in pickups.size():
		if pickups[i] >= 0.0 and absf(px - pickups[i]) < 14.0 and p.global_position.y > global_position.y - 60.0:
			pickups[i] = -1.0
			carried += 1
			level.popup(p.global_position + Vector2(0, -60), GameText.NB_SAUSAGE, Color("e8a070"))
			Audio.sfx("pickup", 0.9)
	# toss one
	if carried > 0 and s != S.KENNEL and s != S.QUIT and Input.is_action_just_pressed("throw"):
		carried -= 1
		tossed.append({"x": px, "y": -30.0, "vx": -150.0, "vy": -220.0, "landed": false})
		Audio.sfx("throw", 1.1)
	for z in tossed:
		if not z.landed:
			z.vy += 900.0 * delta
			z.x += z.vx * delta
			z.y += z.vy * delta
			if z.y >= -3.0:
				z.y = -3.0
				z.landed = true
	match s:
		S.KENNEL:
			if px > (o.start - o.x) * TILE:
				s = S.CHASE
				hx = minf(hx, px - 200.0)
				Audio.say("deputy", Names.fmt(GameText.NB_SIC_EM), "nb_sic_em")
				level.popup(global_position + Vector2(hx, -60), Names.fmt(GameText.NB_SIC_EM), Color("ffd23f"))
				Audio.sfx("honk", 0.5)
				level.chaser = dog
		S.CHASE:
			var target := px
			for z in tossed:
				if z.landed and z.x > hx - 40.0:
					target = z.x                    # sausage!
			var sp := SPEED
			if _in_creek(hx):
				if not sniffed and px > creek.y:
					sniffed = true
					s = S.SNIFF
					t = 200
					level.popup(global_position + Vector2(hx, -50), GameText.NB_LOST_SCENT, Color("c8e0ff"))
				sp = 80.0
			hx = move_toward(hx, target, sp * delta)
			for z in tossed:
				if z.landed and absf(z.x - hx) < 8.0:
					tossed.erase(z)
					s = S.EAT
					t = 160
					Audio.sfx("pickup", 0.5)
					break
			if absf(hx - px) < 16.0 and p.global_position.y > global_position.y - 40.0 and s == S.CHASE:
				if p.hurt(global_position.x + hx):
					Audio.sfx("honk", 0.5)
				s = S.RECOIL
				t = 70
			if px > (o.quit - o.x) * TILE:
				s = S.QUIT
				level.chaser = null
				level.popup(global_position + Vector2(hx, -50), GameText.NB_HOWL, Color("c8c0b0"))
		S.EAT, S.SNIFF, S.RECOIL:
			if t == 0:
				s = S.CHASE
		S.QUIT:
			pass
	dog.position = Vector2(hx, 0)
	queue_redraw()


func _in_creek(x: float) -> bool:
	return creek != Vector2.ZERO and x > creek.x and x < creek.y


## Test bot: toss a sausage when the dog is right behind.
func bot_hint(p: Player) -> Dictionary:
	if s != S.CHASE:
		return {}
	var px := p.global_position.x - global_position.x
	if carried > 0 and px - hx < 70.0 and px > hx:
		return {"cast": true}
	return {}


func _draw() -> void:
	# creek
	if creek != Vector2.ZERO and water == null:
		draw_rect(Rect2(creek.x, -3, creek.y - creek.x, 8), Color("2a5a8a"))
		draw_rect(Rect2(creek.x, -3, creek.y - creek.x, 1), Color("7ab0e0"))
		for x in range(int(creek.x) + 4, int(creek.y) - 4, 13):
			draw_rect(Rect2(x + fmod(_t * 12.0, 8.0), -1, 5, 1), Color("5a90c8"))
	# kennel
	outlined_rect(Rect2(-18, -24, 36, 24), Color("8a4a2a"))
	for k in 6:
		draw_line(Vector2(-18, -20 + k * 4), Vector2(18, -20 + k * 4), Color("6a3820"), 1.0)
	draw_rect(Rect2(-18, -24, 4, 24), Color("a85e36"))
	draw_colored_polygon(PackedVector2Array([Vector2(-24, -23), Vector2(24, -23), Vector2(0, -40)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -24), Vector2(22, -24), Vector2(0, -38)]), Color("5a3020"))
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -24), Vector2(-4, -24), Vector2(0, -38)]), Color("7a4228"))
	for k in 3:
		var yy := -27.0 - k * 4.0
		var w2 := 18.0 - k * 5.5
		draw_line(Vector2(-w2, yy), Vector2(w2, yy), Color("40200f"), 1.0)
	draw_colored_polygon(ellipse(Vector2(0, -11), Vector2(7, 8)), OUTLINE)
	draw_rect(Rect2(-7, -11, 14, 11), Color("1a0e08"))
	draw_colored_polygon(ellipse(Vector2(0, -11), Vector2(6, 7)), Color("1a0e08"))
	# name board and food bowl
	var nw := PixelFont.width(GameText.NB_HOUND_NAME.to_upper()) + 4.0
	outlined_rect(Rect2(-nw / 2.0, -36, nw, 9), Color("e8d8b0"))
	PixelFont.draw_centered(self, GameText.NB_HOUND_NAME, 0, -34, Color("5a3020"))
	draw_colored_polygon(ellipse(Vector2(24, -2), Vector2(5, 2.5)), OUTLINE)
	draw_rect(Rect2(19, -4, 10, 3), Color("c83a3a"))
	draw_rect(Rect2(20, -4, 8, 1), Color("e87a6a"))
	# sausages on the ground and in the air
	for sx in pickups:
		if sx >= 0.0:
			_sausage(Vector2(sx, -4 - absf(sin(_t * 3.0 + sx)) * 3.0))
	for z in tossed:
		_sausage(Vector2(z.x, z.y))
	if carried > 0:
		var p := player()
		PixelFont.draw_centered(self, GameText.NB_CARRYING % carried, p.global_position.x - global_position.x, p.global_position.y - global_position.y - 74, Color("e8a070"))
	_dog()


func _sausage(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-6, -3), Vector2(12, 5)), OUTLINE)
	draw_rect(Rect2(at + Vector2(-5, -2), Vector2(10, 3)), Color("c8603a"))
	draw_rect(Rect2(at + Vector2(-4, -2), Vector2(6, 1)), Color("e8906a"))


func _dog() -> void:
	var f := 1.0 if player().global_position.x - global_position.x >= hx else -1.0
	var tan := Color("b8763a")
	var dark := Color("6a3e1e")
	var run := s == S.CHASE
	var bob := roundf(sin(_t * 22.0)) if run else 0.0
	draw_set_transform(Vector2(hx, 0), 0.0, Vector2(f, 1))
	draw_colored_polygon(ellipse(Vector2(0, 0), Vector2(15, 2)), Color(0, 0, 0, 0.3))
	var leg := sin(_t * 22.0) * 4.0 if run else 0.0
	var lying := s == S.KENNEL or s == S.QUIT or s == S.RECOIL
	var wag := sin(_t * (14.0 if not lying else 4.0)) * 3.0
	if lying:
		limb(Vector2(-12, -6), Vector2(-18, -4 + wag * 0.3), 2.0, tan)
		blob(Vector2(-1, -6), Vector2(12, 5), tan)
		limb(Vector2(6, -2), Vector2(13, -2), 2.5, tan)                  # front paws out
	else:
		limb(Vector2(-8, -10 + bob), Vector2(-8 - leg, -1), 2.5, dark)
		limb(Vector2(8, -10 + bob), Vector2(8 + leg, -1), 2.5, dark)
		limb(Vector2(-12, -15 + bob), Vector2(-18, -21 + bob + wag), 2.0, tan)   # tail
		blob(Vector2(0, -14 + bob), Vector2(13, 6), tan)
		draw_colored_polygon(ellipse(Vector2(-2, -17 + bob), Vector2(7, 3)), dark.lightened(0.1))  # saddle patch
		limb(Vector2(-10, -10 + bob), Vector2(-10 + leg, -1), 2.5, tan)
		limb(Vector2(9, -10 + bob), Vector2(9 - leg, -1), 2.5, tan)
	var head := Vector2(14, -20 + bob)
	if s == S.SNIFF or s == S.EAT:
		head = Vector2(16, -7)
	elif lying:
		head = Vector2(14, -8)
	# droopy head: skull, long muzzle, jowls, big ear
	blob(head, Vector2(5.5, 4.5), tan, 0.0, false)
	blob(head + Vector2(5, 2), Vector2(4.5, 3), tan.lightened(0.08), 0.0, false)
	draw_colored_polygon(ellipse(head + Vector2(5, 5), Vector2(3, 2)), dark.lightened(0.2))      # jowl
	draw_colored_polygon(ellipse(head + Vector2(9, 1), Vector2(1.8, 1.5)), OUTLINE)               # nose
	draw_rect(Rect2(head + Vector2(1, -2), Vector2(2, 1)), dark)                                  # droopy lid
	draw_rect(Rect2(head + Vector2(1, -1), Vector2(2, 1)), OUTLINE)
	var ear := PackedVector2Array([head + Vector2(-3, -3), head + Vector2(1, -2), head + Vector2(0, 8), head + Vector2(-4, 7)])
	var ear_o := PackedVector2Array()
	for q in ear:
		ear_o.append(head + (q - head) * 1.2)
	draw_colored_polygon(ear_o, OUTLINE)
	draw_colored_polygon(ear, dark)
	if s == S.EAT and int(_t * 8.0) % 2 == 0:
		draw_rect(Rect2(head + Vector2(6, 4), Vector2(3, 1)), Color("c8603a"))
	# collar with a brass tag
	draw_line(head + Vector2(-5, 1), head + Vector2(-4, 6), Color("c83a3a"), 2.0)
	draw_circle(head + Vector2(-3, 7), 1.2, Color("f0c848"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if s == S.SNIFF or s == S.EAT:
		PixelFont.draw_centered(self, "sniff" if s == S.SNIFF else "munch", hx, -34, Color("e8e0d0"))
	if s == S.QUIT:
		PixelFont.draw_centered(self, "AROOO!", hx, -30, Color("c8c0b0"))
