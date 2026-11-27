# A town-square stone fountain, splashing on a loop. Decoration only, no
# collision.   {"type": "fountain", "x": 160}
extends LevelObject

const FRAMES := [
	preload("res://art/sprites/props/fountain/frame_0.png"),
	preload("res://art/sprites/props/fountain/frame_1.png"),
	preload("res://art/sprites/props/fountain/frame_2.png"),
	preload("res://art/sprites/props/fountain/frame_3.png"),
	preload("res://art/sprites/props/fountain/frame_4.png"),
	preload("res://art/sprites/props/fountain/frame_5.png"),
	preload("res://art/sprites/props/fountain/frame_6.png"),
]
const FPS := 10.0
const TEX_OFFSET := Vector2(-64, -128)

var _t := 0.0


func step(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var idx := int(_t * FPS) % FRAMES.size()
	draw_texture(FRAMES[idx], TEX_OFFSET)
