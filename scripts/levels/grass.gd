# Swaying grass along the top of the ground: blades lean with the breeze
# and part around anyone walking through. Only the on-screen stretch is drawn.
class_name GrassFringe
extends Node2D

const COLORS := {
	"farm": [Color("3e7a2a"), Color("5a9a36"), Color("86c04a"), Color("e8d070")],
	"lake": [Color("2e6a3a"), Color("4a8a46"), Color("74b05a"), Color("d8e0a0")],
	"quarry": [Color("8a7a3a"), Color("a8964a"), Color("c8b46a"), Color("e8d890")],
	"night": [Color("1e3a2a"), Color("2a4e36"), Color("3a6646"), Color("8a9a70")],
}

var level: Node
var segs: Array = []
var cols: Array = []
var _t := 0.0
var mowed := {}             # 3-px column index -> true once Jim's mower has been over it


func setup(l: Node) -> void:
	level = l
	cols = COLORS.get(l.data.get("theme", ""), [])
	for seg in l.data.ground:
		segs.append(Vector2(seg[0] * 16.0, seg[1] * 16.0))
	z_index = 3


## Cut the grass between world x a and b. True if any of it was still long.
func mow(a: float, b: float) -> bool:
	var fresh := false
	var i := int(floorf(a / 3.0))
	while i * 3.0 <= b:
		if not mowed.has(i):
			mowed[i] = true
			fresh = true
		i += 1
	return fresh


func _process(delta: float) -> void:
	if cols.is_empty():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if cols.is_empty() or level == null:
		return
	var xf := get_viewport().get_canvas_transform().affine_inverse()
	var left: float = xf.origin.x - 8.0
	var right: float = left + get_viewport_rect().size.x / get_viewport().get_canvas_transform().get_scale().x + 16.0
	var gy: float = level.GROUND_Y
	var movers := []
	for n in [level.player, level.get("earl"), level.get("deputy")]:
		if n is Node2D and n.visible:
			movers.append(n.global_position.x)
	for seg in segs:
		var a := maxf(seg.x + 2.0, floorf(left / 3.0) * 3.0)
		var b := minf(seg.y - 2.0, right)
		var x := a
		while x < b:
			if mowed.has(int(x / 3.0)):
				# neat mowed stripes: alternating light and dark bands
				var band := int(x / 24.0) % 2 == 0
				draw_rect(Rect2(x, gy - 1, 3, 2), cols[2] if band else cols[1])
				x += 3.0
				continue
			var h := 2.0 + float(int(x * 7.31) % 5)
			if int(x * 13.7) % 4 == 0:
				h += 2.0
			var lean := sin(_t * 1.8 + x * 0.045) * 1.2 + sin(_t * 3.7 + x * 0.21) * 0.4
			for m in movers:
				var d: float = x - m
				if absf(d) < 12.0:
					lean += signf(d) * (12.0 - absf(d)) * 0.35
			var c: Color = cols[int(x * 3.7) % 3]
			var tip := Vector2(x + lean, gy - h)
			draw_line(Vector2(x, gy + 1), tip, c, 1.0)
			if h >= 5.0 and int(x * 5.3) % 3 == 0:
				draw_rect(Rect2(tip, Vector2(1, 1)), cols[3])          # seed head / flower
			x += 3.0
