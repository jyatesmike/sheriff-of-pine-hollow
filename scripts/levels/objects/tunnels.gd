# Tunnels on The Last Train. Every so often "TUNNEL!" flashes and a tunnel
# comes sweeping down the train. Inside, the roof is low: get down off the
# boxcars and tank cars onto a flat deck (or a gap between roofs) before it
# reaches you, or it knocks you flat.
#   {"type": "tunnels", "x": 6, "every": 9.0, "ceil": 4.2, "len": 30}
extends LevelObject

const WARN := 2.2

var t := 0.0
var state := 0               # 0 waiting, 1 warning, 2 passing
var tx := 0.0                # tunnel's left edge (world x)
var length := 0.0
var ceil_y := 0.0            # world y of the tunnel roof
var speed := 260.0
var _t := 0.0


func _setup() -> void:
	length = o.get("len", 30) * TILE
	ceil_y = level.GROUND_Y - o.get("ceil", 4.2) * TILE
	speed = level.data.get("train_speed", 260.0)
	t = o.get("first", 5.0)
	z_index = 3


func step(delta: float) -> void:
	_t += delta
	var p := player()
	var cam_x: float = level.camera.get_screen_center_position().x
	match state:
		0:
			if p.global_position.x > global_position.x:
				t -= delta
			if t <= 0.0:
				state = 1
				t = WARN
				Audio.sfx("honk", 0.35)
		1:
			t -= delta
			if t <= 0.0:
				state = 2
				tx = cam_x + 260.0
		2:
			tx -= speed * delta
			if tx + length < cam_x - 260.0:
				state = 0
				t = o.get("every", 9.0)
	if state == 2:
		var px := p.global_position.x
		if px > tx and px < tx + length:
			var head := p.global_position.y - (22.0 if p.sliding else 50.0)
			if head < ceil_y and p.invuln == 0:
				p.hurt(px + 20.0)
				p.velocity = Vector2(-160.0, 120.0)
				level.popup(p.global_position + Vector2(0, -60), GameText.LT_BONK, Color("ff6a4a"))
	queue_redraw()


## Test bot: when a tunnel's on its way, get down onto a deck and wait it out.
func bot_hint(p: Player) -> Dictionary:
	if state == 0:
		return {}
	var low: bool = p.global_position.y > level.GROUND_Y - 6.0
	if low and p.is_on_floor():
		return {"dir": 0.0}
	if not p.is_on_floor():
		return {}
	# up on a roof: walk off the nearer end onto the deck
	var cars_obj: Node2D = null
	for ob in get_parent().get_children():
		if ob.has_method("deck_spots"):
			cars_obj = ob
	if cars_obj == null:
		return {}
	var spots: Array = cars_obj.deck_spots(p.global_position.x)
	if spots.is_empty():
		return {}
	var px := p.global_position.x
	var target: float = spots[0] if absf(spots[0] - px) < absf(spots[1] - px) else spots[1]
	return {"dir": signf(target - px)}


func _draw() -> void:
	var cam: Vector2 = level.camera.get_screen_center_position() - global_position
	if state == 1 and int(_t * 6.0) % 2 == 0:
		var x := cam.x + 200.0
		var y := cam.y - 60.0
		draw_rect(Rect2(x - 44, y - 6, 88, 16).grow(1), OUTLINE)
		draw_rect(Rect2(x - 44, y - 6, 88, 16), Color("c83a3a"))
		PixelFont.draw_centered(self, GameText.LT_TUNNEL, x, y - 1, Color("fff6dc"))
		PixelFont.draw_centered(self, GameText.LT_GET_LOW, cam.x, cam.y - 100, Color("ffd23f"))
	if state == 2:
		var a := tx - global_position.x
		var top := ceil_y - global_position.y
		# darkness inside the tunnel and the rock roof
		draw_rect(Rect2(a, top - 300, length, 600), Color(0.02, 0.01, 0.03, 0.62))
		draw_rect(Rect2(a, top - 300, length, 300), Color("3a2e28"))
		for k in range(0, int(length), 18):
			draw_rect(Rect2(a + k, top - 8, 12, 6), Color("4a3c34"))
		draw_rect(Rect2(a, top - 2, length, 2), Color("1a120e"))
		# stone mouths at both ends
		for ex in [a, a + length]:
			draw_rect(Rect2(ex - 8, top - 300, 16, 340), Color("5a4c44"))
			draw_rect(Rect2(ex - 8, top - 300, 2, 340), Color("7a6c64"))
