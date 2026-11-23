# A hay wagon hitched to a tractor at the edge of the mud field. Climb
# aboard and the tractor pulls you across (it waits if you fall off).
# Hop up the hay bales for pies, and watch out: Earl lobs eggs at you.
#   {"type": "hay_wagon", "x": 68, "to": 112}
extends LevelObject

const SPEED := 95.0
const BED_TOP := -22.0
const LEN := 104.0

var bed: AnimatableBody2D
var state := 0               # 0 parked, 1 rolling, 2 arrived
var end_x := 0.0
var off_t := 0
var _t := 0.0


func _setup() -> void:
	end_x = (o.get("to", o.x + 40) - o.x) * TILE
	bed = AnimatableBody2D.new()
	bed.sync_to_physics = true
	bed.collision_layer = 2
	bed.collision_mask = 0
	add_child(bed)
	# the bed and the bales are one-way platforms that ride with the wagon
	for r in [Rect2(0, BED_TOP, LEN, 6), Rect2(8, BED_TOP - 16, 32, 6), Rect2(62, BED_TOP - 16, 32, 6), Rect2(34, BED_TOP - 32, 32, 6)]:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.get_center()
		cs.one_way_collision = true
		bed.add_child(cs)


func aboard() -> bool:
	var p := player()
	var lx := p.global_position.x - global_position.x - bed.position.x
	return p.is_on_floor() and lx > -4.0 and lx < LEN + 4.0 and p.global_position.y < global_position.y + BED_TOP + 4.0


func step(delta: float) -> void:
	_t += delta
	var on := aboard()
	match state:
		0:
			if on:
				state = 1
				Audio.sfx("dash", 0.6)
		1:
			off_t = 0 if on else off_t + 1
			var behind: bool = player().global_position.x < global_position.x + bed.position.x
			if not (off_t > 30 and behind):            # wait for the Sheriff if he fell off
				bed.position.x = minf(bed.position.x + SPEED * delta, end_x)
			if bed.position.x >= end_x:
				state = 2
	if level.earl:
		level.earl.ai["throws"] = state == 1 and on
	queue_redraw()


func bot_hint(p: Player) -> Dictionary:
	if state == 2:
		return {}
	var wx: float = global_position.x + bed.position.x
	var lx: float = p.global_position.x - wx
	if lx > LEN + 30.0 or lx < -200.0:
		return {}
	if aboard():
		return {"dir": 1.0 if lx < 70.0 else (-1.0 if lx > 90.0 else 0.0), "hold": lx >= 70.0 and lx <= 90.0}
	# walk up to the back of the wagon and hop on
	return {"dir": 1.0, "jump": lx > -46.0 and lx < 20.0 and p.is_on_floor()}


func _draw() -> void:
	var ox := bed.position.x
	var wood := Color("a87a46")
	# tractor in front, pulling
	var tex := SpriteLib.prop("tractor")
	draw_line(Vector2(ox + LEN, BED_TOP + 6), Vector2(ox + LEN + 14, BED_TOP + 6), OUTLINE, 2.0)
	var bob := roundf(sin(_t * 18.0) * 0.6) if state == 1 else 0.0
	draw_texture(tex, Vector2(ox + LEN + 8, -tex.get_height() + bob))
	if state == 1 and int(_t * 8.0) % 2 == 0:
		draw_circle(Vector2(ox + LEN + 40, -tex.get_height() - 6 - fmod(_t * 30.0, 10.0)), 3.0, Color(0.5, 0.5, 0.5, 0.6))
	# wagon bed
	outlined_rect(Rect2(ox, BED_TOP, LEN, 8), wood)
	for k in range(0, int(LEN), 13):
		draw_rect(Rect2(ox + k, BED_TOP + 1, 1, 6), wood.darkened(0.3))
	for wx in [16.0, LEN - 16.0]:
		var c := Vector2(ox + wx, -9)
		draw_circle(c, 9.0, OUTLINE)
		draw_circle(c, 7.5, Color("5a3a22"))
		var a := -bed.position.x / 9.0
		for s in 4:
			var d := Vector2(cos(a + s * PI / 4.0), sin(a + s * PI / 4.0)) * 7.0
			draw_line(c - d, c + d, Color("8a6a42"), 1.0)
		draw_circle(c, 2.0, OUTLINE)
	# hay bales
	var hay := SpriteLib.prop("hay_bale")
	for b in [Vector2(8, BED_TOP - 16), Vector2(62, BED_TOP - 16), Vector2(34, BED_TOP - 32)]:
		draw_texture_rect(hay, Rect2(ox + b.x, b.y, 32, 16), false)
	if state == 0 and int(_t * 3.0) % 2 == 0:
		PixelFont.draw_centered(self, GameText.CR_WAGON_HINT, ox + LEN / 2.0, BED_TOP - 46, Color("ffd23f"))
