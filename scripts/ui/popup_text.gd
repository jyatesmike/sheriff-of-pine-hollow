# Floating score / combo text that rises and fades.
extends Node2D

var text := ""
var color := Color("ffd23f")
var life := 0.9
var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	position.y -= 26.0 * delta
	modulate.a = clampf(1.0 - (_age - life * 0.6) / (life * 0.4), 0.0, 1.0)
	if _age >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	PixelFont.draw_centered(self, text, 0, 0, color)
