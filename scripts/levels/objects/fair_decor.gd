# County Fair scenery: the entrance arch, a ticket booth, striped tents and
# strings of lights. Just for looks.
#   {"type": "fair_decor", "x": 8, "kind": "arch"}   kinds: arch, booth, tent, lights (with "w")
extends LevelObject

var _t := 0.0


func _setup() -> void:
	if not Lighting.enabled():
		return
	match o.get("kind", ""):
		"lights":
			var w: float = o.get("w", 20) * TILE
			for x in range(24, int(w), 64):
				add_child(Lighting.radial(Vector2(x, -110), [Color(1, 0.85, 0.5), Color(1, 0.55, 0.5), Color(0.6, 0.85, 1)][(x / 64) % 3], 0.7, 0.8))
		"arch":
			add_child(Lighting.radial(Vector2(0, -120), Color(1, 0.8, 0.45), 1.4, 0.9))
		"tent":
			add_child(Lighting.radial(Vector2(0, -30), Color(1, 0.75, 0.45), 1.0, 0.7))
		"booth":
			add_child(Lighting.radial(Vector2(0, -34), Color(1, 0.9, 0.6), 0.6, 0.8))


func step(delta: float) -> void:
	_t += delta
	if o.get("kind", "") == "lights":
		queue_redraw()


func _draw() -> void:
	match o.get("kind", "tent"):
		"arch":
			for x in [-50.0, 46.0]:
				outlined_rect(Rect2(x, -110, 6, 110), Color("c83a3a"))
			var r := Rect2(-56, -128, 114, 22)
			draw_rect(r.grow(1), OUTLINE)
			draw_rect(r, Color("f0c040"))
			PixelFont.draw_centered(self, Names.fmt(GameText.CF_ARCH), 0, -121, Color("8a2a1a"), 1)
			for k in 12:
				draw_circle(Vector2(-52 + k * 9.5, -130), 2.0, Color("ffe080") if (k + int(_t * 3.0)) % 2 == 0 else Color("c86a2a"))
		"booth":
			outlined_rect(Rect2(-18, -48, 36, 48), Color("4a8ae8"))
			draw_rect(Rect2(-12, -40, 24, 14), Color("e8e0d0"))
			draw_colored_polygon(PackedVector2Array([Vector2(-22, -48), Vector2(22, -48), Vector2(0, -62)]), Color("e84a4a"))
			PixelFont.draw_centered(self, GameText.CF_TICKETS, 0, -22, Color("fff6dc"))
		"tent":
			var col := Color(o.get("color", "#6ac06a"))
			for k in 6:
				draw_rect(Rect2(-48 + k * 16, -70, 16, 70), col if k % 2 == 0 else Color("f4ece0"))
			draw_colored_polygon(PackedVector2Array([Vector2(-54, -70), Vector2(54, -70), Vector2(0, -100)]), col.darkened(0.15))
			draw_rect(Rect2(-12, -40, 24, 40), Color("2a1a14"))
			draw_line(Vector2(0, -100), Vector2(0, -114), Color("8a6a42"), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -114), Vector2(12, -110), Vector2(0, -106)]), Color("e84a4a"))
		"lights":
			var w: float = o.get("w", 20) * TILE
			var y0 := -120.0
			for x in range(0, int(w), 12):
				var sag := sin(float(x) / w * PI) * 16.0
				var lit := (x / 12 + int(_t * 4.0)) % 3 != 0
				var cols := [Color("ffe080"), Color("ff7a6a"), Color("8ae0ff")]
				draw_circle(Vector2(x, y0 + sag), 2.0, cols[(x / 12) % 3] if lit else Color("5a4a3a"))
			draw_line(Vector2(0, y0), Vector2(w, y0), Color(0.3, 0.25, 0.2, 0.0), 1.0)
