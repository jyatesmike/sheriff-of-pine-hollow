# Headless check that the lasso swing carries the Sheriff across the first gap.
#   godot --headless -s tools/test_swing_run.gd
extends SceneTree
func _initialize():
	change_scene_to_file("res://scenes/levels/level.tscn")
	root.add_child.call_deferred(load("res://tools/swing_check.gd").new())
