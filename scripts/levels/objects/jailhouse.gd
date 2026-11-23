# The jailhouse Earl just broke out of (decoration at the start of a level).
#   {"type": "jailhouse", "x": 0}
extends LevelObject

const W := 112.0
const H := 104.0


func _draw() -> void:
	var stone := [Color("6a6458"), Color("8a8474"), Color("a8a290")]
	draw_rect(Rect2(-1, -H - 1, W + 2, H + 1), OUTLINE)
	for y in int(H / 8):
		for x in int(W / 16) + 1:
			var off := 8.0 if y % 2 else 0.0
			var r := Rect2(x * 16 - off, -H + y * 8, 15, 7).intersection(Rect2(0, -H, W, H))
			if r.size.x > 0:
				draw_rect(r, stone[(x + y) % 3])
	draw_rect(Rect2(-4, -H - 6, W + 8, 6), Color("4a463c"))
	# barred windows
	for wx in [12.0, 76.0]:
		draw_rect(Rect2(wx - 1, -H + 22, 26, 22), OUTLINE)
		draw_rect(Rect2(wx, -H + 23, 24, 20), Color("1a1a24"))
		for b in 5:
			draw_rect(Rect2(wx + 2 + b * 5, -H + 23, 2, 20), Color("8a8a96"))
	# the door, hanging open
	draw_rect(Rect2(43, -48, 26, 48), OUTLINE)
	draw_rect(Rect2(44, -47, 24, 47), Color("120c08"))
	draw_colored_polygon(PackedVector2Array([Vector2(68, -47), Vector2(80, -43), Vector2(80, -2), Vector2(68, 0)]), Color("5a3a22"))
	# sign
	var t := Names.fmt(GameText.JAIL_SIGN).to_upper()
	var sw := PixelFont.width(t) + 10
	draw_rect(Rect2(W / 2 - sw / 2.0 - 1, -H + 4, sw + 2, 13), OUTLINE)
	draw_rect(Rect2(W / 2 - sw / 2.0, -H + 5, sw, 11), Color("f4ecd4"))
	PixelFont.draw_centered(self, t, W / 2, -H + 8, Color("3a2414"))
