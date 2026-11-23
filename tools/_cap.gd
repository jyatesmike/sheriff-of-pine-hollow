extends SceneTree
var f := 0
var shots := {}
func _initialize():
	change_scene_to_file("res://scenes/levels/level.tscn")
	root.add_child.call_deferred(load("res://tools/bot.gd").new())
func snap(name):
	if shots.has(name): return
	shots[name] = true
	root.get_texture().get_image().save_png("/home/claude/ms_%s.png" % name)
func _process(_d):
	f += 1
	var s = current_scene
	if s and s.has_method("in_chase") and s.is_node_ready():
		var p = s.player
		var x: float = p.global_position.x
		if f == 150: snap("a_start")
		if x > 520 and x < 560: snap("b_pots")
		if x > 870 and x < 900: snap("c_laundry")
		if p.lasso and p.lasso.swinging(): snap("d_swing")
		if x > 2300 and x < 2340: snap("e_grocer")
		if s.in_chase():
			var c = s.chase
			if c.x > 1100 and c.x < 1150: snap("f_curve")
			if c.airborne and c.height > 20: snap("g_air")
			if c.x > 3950 and c.x < 4000: snap("h_ramp")
			if c.x > 6500 and c.x < 6560: snap("i_stand")
			if c.x > 5150 and c.x < 5250: snap("j_traffic")
		if s.earl and s.earl.state == Earl.State.TOWER and s.earl.throw_t > 0: snap("k_tower")
		if s.tower and s.tower.spray_t > 30: snap("l_hose")
		if s.phase == 1 and s.earl.tackles == 1: snap("m_showdown")
	if f > 9000 or shots.size() >= 13: quit()
	return false
