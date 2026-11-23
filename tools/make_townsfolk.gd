# Generates the townsfolk sprite sheets (art/sprites/<name>.png) and adds
# them to data/sprites.json, without touching any other art.
#   godot --headless -s tools/make_townsfolk.gd
extends SceneTree

const P := preload("res://tools/gen/pix.gd")
const Rig := preload("res://tools/gen/rig.gd")
const Poses := preload("res://tools/gen/poses.gd")
const Gen := preload("res://tools/gen/generate.gd")
const Folk := preload("res://tools/gen/townsfolk.gd")


func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
	var layout := Gen._layout(Poses.ANIMS, Vector2i(Rig.W, Rig.H))
	var cast := Folk.all()
	for name in cast:
		var sheet := P.img(Rig.W * Gen.COLS, Rig.H * Poses.ANIMS.size())
		for row in Poses.ANIMS.size():
			var anim: String = Poses.ANIMS[row][0]
			for i in Poses.ANIMS[row][1]:
				P.blit(sheet, Rig.render(cast[name], Poses.pose(anim, i, cast[name])), Vector2i(i * Rig.W, row * Rig.H))
		Gen._save(sheet, "res://art/sprites/%s.png" % name)
		data.sheets[name] = layout
		print("made ", name)
	Gen._write_json("res://data/sprites.json", data)
	quit()
