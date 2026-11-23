# A laundry line between two poles.
#   {"type": "clothesline", "x": 54, "w": 8, "h": 3, "sheets": true}
#       sheets hang low: slide (dash) underneath. Earl just ducks through.
#   {"type": "clothesline", "x": 64, "w": 7, "h": 4, "spring": true}
#       a taut line you can bounce on (hold jump to go higher)
extends LevelObject

const LAYER_SHEETS := 64          # only the player collides with sheets
const BOUNCE := -700.0
const BOUNCE_HELD := -820.0

var w := 0.0
var line_y := 0.0
var wobble := 0.0
var _t := 0.0


func _setup() -> void:
	w = o.get("w", 8) * TILE
	line_y = tiles_up(o.get("h", 3))
	if o.get("sheets", false):
		# hanging sheets: bottom edge 26 px above the ground
		add_box(Rect2(8, line_y, w - 16, -26.0 - line_y), LAYER_SHEETS)
	if o.get("spring", false):
		add_box(Rect2(4, line_y, w - 8, 4), 2, true)


func step(delta: float) -> void:
	_t += delta
	wobble = move_toward(wobble, 0.0, 30.0 * delta)
	if not o.get("spring", false):
		return
	var p := player()
	var lx := p.global_position.x - global_position.x
	if p.is_on_floor() and lx > 4.0 and lx < w - 4.0 and absf(p.global_position.y - (global_position.y + line_y)) < 3.0:
		var held := Input.is_action_pressed("jump")
		p.velocity.y = BOUNCE_HELD if held else BOUNCE
		p.jumping = false
		p.visual.squash(Vector2(0.8, 1.25))
		wobble = 6.0
		Audio.sfx("jump", 0.7)
	queue_redraw()


func _draw() -> void:
	var wood := Color("7a5230")
	for px in [0.0, w]:
		outlined_rect(Rect2(px - 2, line_y - 6, 4, -line_y + 6), wood)
		outlined_rect(Rect2(px - 6, line_y - 6, 12, 3), wood)
	# the line sags (and wobbles when bounced on)
	var pts := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		var sag := sin(t * PI) * (2.0 + wobble * sin(_t * 30.0))
		pts.append(Vector2(t * w, line_y + sag))
	draw_polyline(pts, Color("e8e0cc"), 1.0)
	if o.get("sheets", false):
		var cols := [Color("f4f0e6"), Color("d8e4f4"), Color("f4d8d8"), Color("e4f0d8")]
		var x := 8.0
		var i := 0
		while x < w - 16.0:
			var sw := minf(22.0, w - 16.0 - x)
			var sway := sin(_t * 2.0 + i) * 1.5
			var r := Rect2(x, line_y + 1, sw - 2, -27.0 - line_y)
			draw_rect(r.grow(1), OUTLINE)
			draw_rect(r, cols[i % cols.size()])
			draw_line(Vector2(x + 2 + sway, line_y + 6), Vector2(x + 4 + sway, -30), Color(0, 0, 0, 0.12), 1.0)
			draw_rect(Rect2(x + 3, line_y - 1, 2, 4), Color("a87a46"))     # pegs
			x += sw
			i += 1
	queue_redraw()
