# Makes art_templates/<sheet>_template.png: an empty sprite sheet with the
# exact grid the game expects (one row per animation, frames left to right),
# each row labelled, plus the current art faintly underneath as a guide.
# Draw your own frames over it (Aseprite, PixelLab...), save it as
# art/sprites/<sheet>.png, and the game uses it.
#   godot --headless -s tools/make_sprite_template.gd
extends SceneTree


func _initialize() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json")).sheets
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art_templates"))
	for sheet in ["sheriff", "earl", "deputy", "dewey"]:
		var lay: Dictionary = layout[sheet]
		var fw: int = lay.frame[0]
		var fh: int = lay.frame[1]
		var anims: Array = lay.anims
		var cols := 0
		for a in anims:
			cols = maxi(cols, int(a.frames))
		var img := Image.create(fw * cols, fh * anims.size(), false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var cur := Image.load_from_file(ProjectSettings.globalize_path("res://art/sprites/%s.png" % sheet))
		for r in anims.size():
			for c in cols:
				var used: bool = c < int(anims[r].frames)
				var rect := Rect2i(c * fw, r * fh, fw, fh)
				img.fill_rect(rect, Color(0.2, 0.6, 1.0, 0.08) if used else Color(0.5, 0.5, 0.5, 0.25))
				if used and cur:
					# the current frame, faint, as a size/position guide
					for y in fh:
						for x in fw:
							var px := cur.get_pixel(rect.position.x + x, rect.position.y + y)
							if px.a > 0.0:
								img.set_pixel(rect.position.x + x, rect.position.y + y, Color(px.r, px.g, px.b, 0.25))
				# frame border and the feet line (the bottom of the frame is where the feet go)
				for x in fw:
					img.set_pixel(rect.position.x + x, rect.position.y, Color(1, 0, 1, 0.6))
					img.set_pixel(rect.position.x + x, rect.end.y - 1, Color(1, 0.3, 0.3, 0.9))
				for y in fh:
					img.set_pixel(rect.position.x, rect.position.y + y, Color(1, 0, 1, 0.6))
		img.save_png(ProjectSettings.globalize_path("res://art_templates/%s_template.png" % sheet))
		var guide := "%s: frames %dx%d px, %d columns x %d rows\n" % [sheet, fw, fh, cols, anims.size()]
		for r in anims.size():
			guide += "  row %2d  %-11s %d frames  (%d fps%s)\n" % [r + 1, anims[r].name, anims[r].frames, anims[r].fps, ", loops" if anims[r].loop else ""]
		var f := FileAccess.open("res://art_templates/%s_rows.txt" % sheet, FileAccess.WRITE)
		f.store_string(guide)
		print(guide)
	quit()
