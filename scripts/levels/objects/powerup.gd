# A power-up only one character can use: Dewey's Lightning Soda, Jim's
# zero-turn mower. For anyone else it isn't there at all.
#   {"type": "powerup", "x": 40, "h": 1}
# The level adds two of these automatically if its JSON lists none
# (see Level._spawn_powerups); put your own in "objects" to choose the spots.
extends LevelObject

const KINDS := {"dewey": "soda", "jim": "mower"}

var kind := ""
var _t := 0.0
var taken := false


func _setup() -> void:
	kind = KINDS.get(level.hero, "")
	if kind == "":
		visible = false
		set_physics_process(false)
		return
	position.y -= o.get("h", 1.2) * TILE
	z_index = 2
	if Lighting.enabled():
		var glow := Lighting.radial(Vector2.ZERO, Color(1.0, 0.9, 0.4) if kind == "soda" else Color(0.6, 1.0, 0.5), 0.55, 0.6)
		add_child(glow)


func step(delta: float) -> void:
	_t += delta
	queue_redraw()
	if taken:
		return
	var r: Rect2 = player().body_rect().grow(6)
	if r.has_point(global_position):
		taken = true
		player().start_power(kind)
		level.on_powerup(kind, global_position)
		queue_free()


func _draw() -> void:
	if kind == "":
		return
	var bob := roundf(sin(_t * 3.0) * 2.0)
	# glow ring
	var a := 0.35 + 0.2 * sin(_t * 6.0)
	draw_circle(Vector2(0, bob), 13.0, Color(1, 1, 0.7, a * 0.35))
	if kind == "soda":
		_soda(Vector2(0, bob))
	else:
		_mower(Vector2(0, bob + 6))
	# twinkles
	for k in 3:
		var ang := _t * 2.0 + k * TAU / 3.0
		var p := Vector2(cos(ang) * 14.0, sin(ang) * 9.0 + bob)
		if int(_t * 8.0 + k) % 3 != 0:
			draw_rect(Rect2(p, Vector2(1, 1)), Color.WHITE)


## A glass bottle of Lightning Soda: yellow fizz, cap, a lightning-bolt label.
func _soda(c: Vector2) -> void:
	var body := Rect2(c + Vector2(-5, -6), Vector2(10, 14))
	draw_rect(Rect2(c + Vector2(-2, -13), Vector2(4, 7)).grow(1), OUTLINE)       # neck
	draw_rect(body.grow(1), OUTLINE)
	draw_rect(Rect2(c + Vector2(-2, -13), Vector2(4, 7)), Color("8ad8a0"))
	draw_rect(body, Color("8ad8a0"))
	draw_rect(Rect2(body.position + Vector2(0, 3), Vector2(10, 11)), Color("f0d040"))  # the fizz
	draw_rect(Rect2(c + Vector2(-3, -15), Vector2(6, 2)), Color("d8302a"))             # cap
	draw_rect(Rect2(c + Vector2(-3, -15), Vector2(6, 1)), Color("f07a6a"))
	draw_rect(Rect2(c + Vector2(-5, -1), Vector2(10, 7)), Color("1e3a8a"))             # label
	draw_colored_polygon(PackedVector2Array([c + Vector2(1, -1), c + Vector2(-2, 3), c + Vector2(0, 3), c + Vector2(-1, 6), c + Vector2(3, 1), c + Vector2(1, 1), c + Vector2(2, -1)]), Color("ffe060"))
	draw_rect(Rect2(body.position + Vector2(1, 1), Vector2(1, 10)), Color(1, 1, 1, 0.7))   # shine
	# bubbles rising
	for k in 3:
		var y := fmod(_t * 14.0 + k * 4.0, 10.0)
		draw_rect(Rect2(c + Vector2(-2 + k * 2, 7 - y), Vector2(1, 1)), Color(1, 1, 0.9, 0.9))


## A little zero-turn mower: red body, black seat, big back wheel.
func _mower(c: Vector2) -> void:
	Mower.draw_mower(self, c, 0.65, _t)
