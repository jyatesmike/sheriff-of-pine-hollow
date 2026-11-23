# Checks checkpoints: pass the post, die, retry -> back at the post with pies kept.
# Then die in the car chase, retry -> the chase starts again.
#   godot --headless -s tools/test_checkpoint.gd
extends SceneTree
var f := 0
var step := 0
var pies_before := 0
func _initialize():
	change_scene_to_file("res://scenes/levels/level.tscn")
func _physics_process(_d):
	f += 1
	var s = current_scene
	if s == null or not s.has_method("in_chase") or not s.is_node_ready(): return false
	var p = s.player
	match step:
		0:
			if f == 10:
				p.global_position = Vector2(92.5 * 16, 207); p.reset_physics_interpolation()
				Input.action_press("right")
			if s.checkpoint_x > 0:
				Input.action_release("right")
				pies_before = s.pies_got
				print("reached checkpoint at ", s.checkpoint_x, " pies ", pies_before)
				s.pies_got += 0
				p.hearts = 1; p.invuln = 0; p.hurt_t = 0; p.hurt(p.global_position.x)
				step = 1; f = 0
		1:
			if s.finished and f == 80:
				press_jump()
			if f == 82:
				step = 2; f = 0
		2:
			if f == 10 and p.hearts == 0:
				f = 0
			elif f == 10:
				print("after retry: player x=%d (tile %.1f) earl x=%d hearts=%d pies=%d" % [p.global_position.x, p.global_position.x / 16, s.earl.global_position.x, p.hearts, s.pies_got])
				p.global_position = Vector2(178 * 16, 207); p.reset_physics_interpolation()
				s.earl.global_position = Vector2(s.truck_x + 4, 207)
				Input.action_press("right")
			if s.in_chase():
				Input.action_release("right")
				print("chase started; hearts ", p.hearts)
				step = 3; f = 0
		3:
			if f == 30:
				p.hearts = 1; p.invuln = 0; p.hurt_t = 0; p.hurt(0)
			if s.finished and f == 120:
				press_jump()
			if f == 122:
				step = 4; f = 0
		4:
			if f == 10 and p.hearts == 0:
				f = 0
			elif f == 90:
				print("after chase retry: in_chase=%s hearts=%d player x=%d earl visible=%s" % [s.in_chase(), p.hearts, p.global_position.x, s.earl.visible])
				quit()
	if f > 2000: print("timeout step ", step); quit()
	return false

func press_jump():
	var e := InputEventAction.new(); e.action = "jump"; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventAction.new(); r.action = "jump"; r.pressed = false
	Input.parse_input_event(r)
