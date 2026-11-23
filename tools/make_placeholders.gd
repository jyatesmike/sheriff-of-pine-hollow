# Placeholder art generator (editor version).
# Open this file in Godot's Script editor and choose File > Run (Ctrl+Shift+X).
# It rewrites every PNG under art/ plus data/sprites.json, data/props.json and
# data/backgrounds.json. Replace any PNG by hand afterwards (same size and
# layout, see art/README.md) and the game uses it with no code changes.
# Command-line version: godot --headless -s tools/make_placeholders_cli.gd
@tool
extends EditorScript


func _run() -> void:
	preload("res://tools/gen/generate.gd").run()
	get_editor_interface().get_resource_filesystem().scan()
