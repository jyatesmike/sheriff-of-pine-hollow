# Base for set-piece objects placed from a level's "objects" list, e.g.
#   {"type": "flowerpot", "x": 20, "h": 6}
# The type picks scripts/levels/objects/<type>.gd. Positions are in tiles
# (16 px); "h" is tiles above the ground line. Each object draws itself,
# builds any collision it needs, and reacts to the player in step().
class_name LevelObject
extends Node2D

const TILE := 16.0
const OUTLINE := Color("24140e")

var level: Node
var o: Dictionary
var gy := 0.0


func setup(l: Node, d: Dictionary) -> void:
	level = l
	o = d
	gy = l.GROUND_Y
	position = Vector2(d.get("x", 0) * TILE, gy)
	_setup()
	queue_redraw()


## Override: build collision, etc. `position` is at the object's x on the ground line.
func _setup() -> void:
	pass


## Override: called every physics frame while the level is running.
func step(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if level and not level.finished and not level.in_chase():
		step(delta)


# --- helpers -------------------------------------------------------------------
func player() -> Player:
	return level.player


func tiles_up(h: float) -> float:
	return -h * TILE


## Collision rectangle in this object's local space.
func add_box(rect: Rect2, layer: int, one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.get_center()
	cs.one_way_collision = one_way
	body.add_child(cs)
	add_child(body)
	return body


func global_rect(r: Rect2) -> Rect2:
	return Rect2(r.position + global_position, r.size)


func outlined_rect(r: Rect2, c: Color) -> void:
	draw_rect(r.grow(1), OUTLINE)
	draw_rect(r, c)


# --- shaded shapes (rounded, lit from the upper left) ----------------------------
static func ellipse(c: Vector2, r: Vector2, rot := 0.0, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


## An outlined ellipse with a shadowed belly, a lit top and a small highlight.
func blob(c: Vector2, r: Vector2, col: Color, rot := 0.0, shine := true) -> void:
	draw_colored_polygon(ellipse(c, r + Vector2(1, 1), rot), OUTLINE)
	draw_colored_polygon(ellipse(c, r, rot), col.darkened(0.28))
	draw_colored_polygon(ellipse(c + Vector2(-0.12 * r.x, -0.16 * r.y).rotated(rot), r * Vector2(0.86, 0.78), rot), col)
	if shine:
		draw_colored_polygon(ellipse(c + Vector2(-0.3 * r.x, -0.45 * r.y).rotated(rot), r * Vector2(0.45, 0.28), rot, 10), col.lightened(0.28))


## An outlined round-ended stroke (legs, necks, tails).
func limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, OUTLINE, w + 2.0)
	draw_circle(a, (w + 2.0) * 0.5, OUTLINE)
	draw_circle(b, (w + 2.0) * 0.5, OUTLINE)
	draw_line(a, b, col, w)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)


func hoof(at: Vector2, col := Color("2a1e18")) -> void:
	draw_rect(Rect2(at + Vector2(-2, -2), Vector2(5, 3)), OUTLINE)
	draw_rect(Rect2(at + Vector2(-1, -1), Vector2(3, 1)), col)
