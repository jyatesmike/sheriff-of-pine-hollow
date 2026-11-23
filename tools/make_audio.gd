# Built-in audio generator (editor version).
# Open this file in Godot's Script editor and choose File > Run (Ctrl+Shift+X).
# It rewrites every WAV in audio/builtin/. Your own files in audio/sfx and
# audio/music always win over these (see scripts/config/sound_files.gd).
# Command-line version: godot --headless -s tools/make_audio_cli.gd
@tool
extends EditorScript


func _run() -> void:
	preload("res://tools/gen/audio_gen.gd").run()
	get_editor_interface().get_resource_filesystem().scan()
