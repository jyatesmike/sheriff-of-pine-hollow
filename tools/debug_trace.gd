# Prints a status line every 2 s during a bot run: DBG=1 godot --headless -s tools/test_bot_run.gd -- 1
extends Node
var f := 0
func _physics_process(_d):
	f += 1
	var s = get_tree().current_scene
	if s == null or not s.has_method("in_chase") or not s.is_node_ready(): return
	if f % 120 == 0 or (s.phase == 1 and f % 15 == 0):
		var p = s.player
		var e = s.earl if s.earl else s.deputy
		var extra := ""
		if s.in_chase():
			var c = s.chase
			extra = " CHASE x=%d v=%d lane=%d h=%d air=%s truck=%d bumps=%d hearts=%d" % [c.x, c.speed, c.lane, c.height, c.airborne, c.truck.x, c.bumps, p.hearts]
		printerr("t=%d p=(%d,%d) floor=%s ride=%s swing=%s earl=(%d,%d %s) phase=%d roped=%d face=%d lasso=%d tackles=%d%s" % [f/60, p.global_position.x, p.global_position.y, p.is_on_floor(), p.ride != null, p.lasso.swinging() if p.lasso else false, e.global_position.x, e.global_position.y, e.State.keys()[e.state], s.phase, e.get("roped_t") if e.get("roped_t") != null else 0, p.facing, p.lasso.state if p.lasso else -1, (e.get("tackles") if e.get("tackles") != null else 0), extra])
