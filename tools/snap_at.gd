# Screenshot set pieces: teleports the Sheriff to tile x and saves a frame.
#   godot -s tools/snap_at.gd -- <level index 0-6> <out prefix> <tile x> [<tile x>...]
extends SceneTree

var f := 0
var xs := []
var i := 0
var prefix := ""
var wait := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	root.get_node("Game").level_index = int(a[0])
	prefix = a[1]
	for k in range(2, a.size()):
		xs.append(float(a[k]))
	change_scene_to_file("res://scenes/levels/level.tscn")


func _process(_d: float) -> bool:
	f += 1
	var s = current_scene
	if paused:
		root.get_node("Game").set_paused(false)
	if s == null or not s.has_method("in_chase") or not s.is_node_ready() or f < 30:
		return false
	if i >= xs.size():
		quit()
		return false
	if wait == 0:
		s.camera._intro_t = 0.0
		s.hud.intro_t = 0.0
		if s.intro_frozen:
			s._intro_freeze(false)
		s.player.global_position = Vector2(xs[i] * 16.0, s.GROUND_Y - 4)
		s.player.velocity = Vector2.ZERO
		if s.get("deputy") and s.deputy:
			s.deputy.global_position = s.player.global_position + Vector2(-30, 0)
	wait += 1
	if wait == 45:
		root.get_texture().get_image().save_png("/home/claude/%s_%d.png" % [prefix, int(xs[i])])
		i += 1
		wait = 0
	return false
