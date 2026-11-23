# The pig pen at the end of the farm: Earl's last stand. The mud is slick,
# the pigs shove you about, and Earl's too slippery to tackle unless you
# rope him with the lasso first (E/Z), then dash into him.
# The pigs shove you about; jump over them, or bounce off their backs.
#   {"type": "pig_pen", "x": 268, "w": 30, "pigs": 2}
extends LevelObject

var w := 0.0
var pigs: Array = []        # {x, dir, t, bump}
var _t := 0.0


func _setup() -> void:
	w = o.get("w", 30) * TILE
	level.mud_zones.append([global_position.x + 8.0, global_position.x + w, "slick"])
	for k in int(o.get("pigs", 2)):
		pigs.append({"x": w * (0.3 + 0.4 * k), "dir": 1.0 if k % 2 == 0 else -1.0, "t": 0})


func step(delta: float) -> void:
	_t += delta
	var p := player()
	for pg in pigs:
		pg.t = maxi(pg.t - 1, 0)
		if pg.t == 0:
			pg.t = 50 + randi() % 120
			if randf() < 0.5:
				pg.dir = -pg.dir
		pg.x = clampf(pg.x + pg.dir * 28.0 * delta, 16.0, w - 16.0)
		if pg.x <= 16.0 or pg.x >= w - 16.0:
			pg.dir = -pg.dir
		var r := Rect2(global_position.x + pg.x - 12, global_position.y - 14, 24, 14)
		if not r.intersects(p.body_rect()):
			continue
		if p.velocity.y > 0.0 and p.global_position.y - r.position.y < 10.0:
			p.bounce()                              # boing off a pig's back
			Audio.sfx("honk", 0.5)
		elif p.is_on_floor():
			var away := signf(p.global_position.x - r.get_center().x)
			p.velocity.x = away * 150.0
			if Engine.get_physics_frames() % 30 == 0:
				Audio.sfx("honk", 0.45)
	queue_redraw()


## Test bot: hop over a pig in the way.
func bot_hint(p: Player) -> Dictionary:
	if not level.earl:
		return {}
	var toward := signf(level.earl.global_position.x - p.global_position.x)
	for pg in pigs:
		var dx: float = (global_position.x + pg.x - p.global_position.x) * toward
		if dx > 0.0 and dx < 46.0 and p.is_on_floor():
			return {"dir": toward, "jump": true}
	return {}


func _draw() -> void:
	# fence posts and rails around the pen (behind everything)
	var wood := Color("8a6a42")
	for x in range(0, int(w) + 1, 32):
		outlined_rect(Rect2(x - 2, -30, 4, 30), wood)
	outlined_rect(Rect2(0, -26, w, 3), wood.darkened(0.15))
	outlined_rect(Rect2(0, -14, w, 3), wood.darkened(0.15))
	# slick mud
	draw_rect(Rect2(8, -3, w - 8, 7), Color("6a4a2a"))
	draw_rect(Rect2(8, -3, w - 8, 1), Color("8a6a42"))
	for x in range(14, int(w) - 6, 19):
		draw_rect(Rect2(x, -2, 7, 1), Color(1, 1, 1, 0.22))
	# trough
	outlined_rect(Rect2(w - 60, -10, 30, 10), Color("6a6a72"))
	for pg in pigs:
		_pig(Vector2(pg.x, 0), pg.dir)
	if level.phase == level.Phase.SHOWDOWN and int(_t * 2.0) % 2 == 0:
		PixelFont.draw_centered(self, GameText.CR_ROPE_FIRST, w * 0.5, -96, Color("ffd23f"))


func _pig(at: Vector2, f: float) -> void:
	var pink := Color("eaa2a0")
	var dark := Color("c87878")
	var mud := Color("6a4a2a")
	draw_set_transform(at, 0.0, Vector2(f, 1))
	var bob := roundf(sin(_t * 8.0 + at.x))
	var trot := sin(_t * 10.0 + at.x) * 2.0
	draw_colored_polygon(ellipse(Vector2(0, 0), Vector2(14, 2)), Color(0, 0, 0, 0.25))
	limb(Vector2(-7, -6), Vector2(-7 - trot, -1), 2.5, dark.darkened(0.2))
	limb(Vector2(7, -6), Vector2(7 + trot, -1), 2.5, dark.darkened(0.2))
	# curly tail
	draw_arc(Vector2(-14, -12 + bob), 2.5, 0.0, 5.2, 8, OUTLINE, 3.0)
	draw_arc(Vector2(-14, -12 + bob), 2.5, 0.0, 5.2, 8, pink, 1.0)
	blob(Vector2(0, -10 + bob), Vector2(13, 7.5), pink)
	# mud splotches
	draw_colored_polygon(ellipse(Vector2(-5, -6 + bob), Vector2(4, 2)), mud)
	draw_colored_polygon(ellipse(Vector2(4, -5 + bob), Vector2(3, 1.5)), mud)
	draw_colored_polygon(ellipse(Vector2(-8, -12 + bob), Vector2(2, 1.5)), mud.lightened(0.1))
	limb(Vector2(-9, -5), Vector2(-9 + trot, 0), 2.5, dark)
	limb(Vector2(9, -5), Vector2(9 - trot, 0), 2.5, dark)
	hoof(Vector2(-9 + trot, 0), Color("4a3030"))
	hoof(Vector2(9 - trot, 0), Color("4a3030"))
	# head and snout
	blob(Vector2(12, -11 + bob), Vector2(5.5, 5), pink, 0.0, false)
	draw_colored_polygon(ellipse(Vector2(17, -10 + bob), Vector2(2.5, 3)), OUTLINE)
	draw_colored_polygon(ellipse(Vector2(17, -10 + bob), Vector2(1.6, 2.2)), Color("f4c0bc"))
	draw_rect(Rect2(17, -11 + bob, 1, 1), Color("8a4a4a"))
	draw_rect(Rect2(17, -9 + bob, 1, 1), Color("8a4a4a"))
	draw_rect(Rect2(13, -13 + bob, 1, 2), OUTLINE)                       # eye
	draw_rect(Rect2(13, -14 + bob, 1, 1), Color(1, 1, 1, 0.8))
	# floppy ear
	draw_colored_polygon(PackedVector2Array([Vector2(9, -16 + bob), Vector2(13, -17 + bob), Vector2(14, -12 + bob)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(10, -16 + bob), Vector2(12.5, -16 + bob), Vector2(13, -13 + bob)]), dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
