# The jailhouse Earl just broke out of (decoration at the start of a level).
# The real art already shows the door hanging open.
#   {"type": "jailhouse", "x": 0}
extends LevelObject

const W := 176.0
const H := 256.0
const FACADE := preload("res://art/sprites/buildings/jailhouse.png")


func _draw() -> void:
	draw_texture(FACADE, Vector2(0, -H))
	# the dynamic "{TOWN} JAIL" sign, between the roofline and the barred windows
	var t := Names.fmt(GameText.JAIL_SIGN).to_upper()
	var sw := PixelFont.width(t) + 10
	draw_rect(Rect2(W / 2 - sw / 2.0 - 1, -H + 19, sw + 2, 13), OUTLINE)
	draw_rect(Rect2(W / 2 - sw / 2.0, -H + 20, sw, 11), Color("f4ecd4"))
	PixelFont.draw_centered(self, t, W / 2, -H + 23, Color("3a2414"))
