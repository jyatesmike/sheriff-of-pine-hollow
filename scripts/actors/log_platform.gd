# A log drifting back and forth across a stretch of water. Stand on it to
# ride (it's a one-way platform, so you can jump up through it).
extends AnimatableBody2D

const SPEED := 42.0

var from_x := 0.0
var to_x := 0.0
var dir := 1.0
var base_y := 0.0
var _t := 0.0


func setup(a: float, b: float, y: float, start_dir: float) -> void:
	from_x = a
	to_x = b
	base_y = y
	dir = start_dir
	position = Vector2(a if start_dir > 0 else b, y)
	sync_to_physics = true
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(92, 8)
	cs.shape = shape
	cs.position = Vector2(48, 4)
	cs.one_way_collision = true
	add_child(cs)
	var spr := Sprite2D.new()
	spr.texture = SpriteLib.prop("log")
	spr.centered = false
	spr.position = Vector2(0, -2)
	add_child(spr)


func _physics_process(delta: float) -> void:
	_t += delta
	var x := position.x + dir * SPEED * delta
	if x > to_x:
		x = to_x
		dir = -1.0
	elif x < from_x:
		x = from_x
		dir = 1.0
	position = Vector2(x, base_y + roundf(sin(_t * 2.2)))
