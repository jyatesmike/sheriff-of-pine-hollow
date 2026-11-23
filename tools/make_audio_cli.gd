# Command-line built-in audio generator:
#   godot --headless -s tools/make_audio_cli.gd
extends SceneTree


func _initialize() -> void:
	load("res://tools/gen/audio_gen.gd").run()
	quit()
