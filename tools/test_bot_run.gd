# Headless smoke test: a simple bot plays a level to the end.
#   godot --headless -s tools/test_bot_run.gd -- <level 1-7> [god]
# Exits 0 if the level is won, 1 otherwise. "god" = bot can't be hurt
# (proves the level can be finished). The bot itself lives in
# tools/bot.gd and is loaded at runtime, after the autoloads exist.
extends SceneTree


func _initialize() -> void:
	# CHAR=dewey / CHAR=jim plays as someone else
	var who := OS.get_environment("CHAR") if OS.get_environment("CHAR") != "" else "sheriff"
	(func(): root.get_node("Game").settings.character = who; root.get_node("Game").checkpoint = {}).call_deferred()
	change_scene_to_file("res://scenes/levels/level.tscn")
	var bot: Node = load("res://tools/bot.gd").new()
	bot.process_mode = Node.PROCESS_MODE_ALWAYS
	bot.process_physics_priority = -100   # press keys before the player reads them
	root.add_child.call_deferred(bot)
	if OS.get_environment("DBG") != "":
		root.add_child.call_deferred(load("res://tools/debug_trace.gd").new())
