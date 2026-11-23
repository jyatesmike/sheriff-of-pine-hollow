# A pie on the windowsill (or floating in an arc). Golden pies are worth
# 1000 points and count toward the level's golden-pie medal later.
class_name Pie
extends Node2D

var golden := false
var bonus := false         # turned up by Jim's mower: points only, not counted in the level's total
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func touches(r: Rect2) -> bool:
	return r.grow(5).has_point(global_position)


func _draw() -> void:
	var bob := roundf(sin(_t * 3.0 + position.x * 0.05))
	draw_texture(SpriteLib.prop("pie_gold" if golden else "pie"), Vector2(-8, -9 + bob))
	# sparkle
	var k := int(_t * 6.0 + position.x) % 12
	if k < 2 or golden and k < 5:
		var sx := -4.0 + (int(position.x) % 9)
		draw_rect(Rect2(sx, -11 + bob, 1, 3), Color.WHITE)
		draw_rect(Rect2(sx - 1, -10 + bob, 3, 1), Color.WHITE)
