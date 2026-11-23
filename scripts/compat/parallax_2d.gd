# Godot 4.1 doesn't have the Parallax2D node (it arrived in 4.3), so this is a
# small stand-in with the parts the game uses: scroll_scale, repeat_size,
# repeat_times and autoscroll. Children are copied side by side so the layer
# tiles across the screen.
class_name Parallax2D
extends Node2D

var scroll_scale := Vector2.ONE
var repeat_size := Vector2.ZERO
var repeat_times := 1
var autoscroll := Vector2.ZERO

var _auto := Vector2.ZERO
var _copied := false


func _ready() -> void:
	_copy_children.call_deferred()


func _copy_children() -> void:
	if _copied or repeat_size.x <= 0.0:
		return
	_copied = true
	var originals := get_children()
	for k in [-1, 1, 2]:
		for c in originals:
			var d: Node = c.duplicate()
			if d is Node2D:
				d.position.x += repeat_size.x * k
			add_child(d)
			# signboard text is drawn by a callback: hook the copy up too
			for conn in c.get_signal_connection_list("draw"):
				var cb: Callable = conn.callable
				if cb.get_bound_arguments_count() > 0:
					d.draw.connect(Callable(cb.get_object(), cb.get_method()).bind(d))
				else:
					d.draw.connect(cb)
			if d is CanvasItem:
				d.queue_redraw()


func _process(delta: float) -> void:
	_auto += autoscroll * delta
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var left: Vector2 = inv.origin            # world position of the screen's top-left
	var off := left * (Vector2.ONE - scroll_scale) + _auto
	if repeat_size.x > 0.0:
		off.x += repeat_size.x * floorf((left.x - off.x) / repeat_size.x)
	position = Vector2(off.x, off.y if scroll_scale.y != 1.0 else 0.0)
