# Used by tools/test_swing_run.gd: lassos the first hook, pumps, lets go, reports where he lands.
extends Node
var level
var f := 0
var phase := 0
var log_lines := []
func _physics_process(_d):
	f += 1
	var s = get_tree().current_scene
	if not (s is Level) or not s.is_node_ready(): return
	if level == null:
		f = 0
	level = s
	var p: Player = level.player
	var L: Lasso = level.lasso
	if f == 5:
		p.global_position = Vector2(54*16 - 30, level.GROUND_Y)
		p.last_safe = p.global_position
		p.reset_physics_interpolation()
	if f == 30:
		Input.action_press("lasso")
	if f == 31:
		Input.action_release("lasso")
	if L.swinging():
		Input.action_press("right")
		if phase == 0:
			phase = 1
			print("swing start at x=%d L=%d goal=%d theta=%.2f" % [p.global_position.x, L.length, L.length_goal, L.theta])
		if L.theta > 0.55 and L.omega > 0.0:
			Input.action_press("jump")
			print("release at x=%d y=%d theta=%.2f omega=%.2f v=%s" % [p.global_position.x, p.global_position.y, L.theta, L.omega, p.velocity])
	if phase == 1 and not L.swinging() and p.is_on_floor():
		print("landed at x=%d (far side starts at %d) falls ok=%s" % [p.global_position.x, 60*16, p.global_position.x > 60*16])
		get_tree().quit()
	if f > 900:
		print("TIMEOUT x=%d y=%d lasso state=%d" % [p.global_position.x, p.global_position.y, L.state]); get_tree().quit()
