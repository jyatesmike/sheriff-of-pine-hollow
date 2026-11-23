# Generates art/sprites/duck.png (and its entry in data/sprites.json) without
# touching any other art.   godot --headless -s tools/make_ducks.gd
extends SceneTree

const P := preload("res://tools/gen/pix.gd")
const Animals := preload("res://tools/gen/animals.gd")
const Gen := preload("res://tools/gen/generate.gd")


func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
	var sheet := P.img(Animals.W * Gen.COLS, Animals.H * Animals.ANIMS.size())
	for row in Animals.ANIMS.size():
		for i in Animals.ANIMS[row][1]:
			P.blit(sheet, Animals.frame("duck", Animals.ANIMS[row][0], i), Vector2i(i * Animals.W, row * Animals.H))
	Gen._save(sheet, "res://art/sprites/duck.png")
	data.sheets["duck"] = Gen._layout(Animals.ANIMS, Vector2i(Animals.W, Animals.H))
	Gen._write_json("res://data/sprites.json", data)
	print("made duck")
	quit()
