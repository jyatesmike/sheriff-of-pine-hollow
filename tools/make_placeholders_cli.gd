# Command-line placeholder generator:
#   godot --headless -s tools/make_placeholders_cli.gd
# then run `godot --headless --import` (or open the editor) to import the PNGs.
extends SceneTree


func _initialize() -> void:
	load("res://tools/gen/generate.gd").run()
	quit()
