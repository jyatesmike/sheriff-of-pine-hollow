# Rock Creek's finale: Earl scrambles up a rock pillar by the creek and
# pelts you with stones. Throw rocks back (F/X: they lob up at him
# automatically). Three hits knock him off, dazed; then tackle him.
#   {"type": "rock_pillar", "x": 292, "h": 6}
extends LevelObject

var deck := 0.0


func _setup() -> void:
	deck = tiles_up(o.get("h", 6))
	level.tower = self


func ladder_x() -> float:
	return global_position.x - 22.0


func deck_y() -> float:
	return global_position.y + deck


func spray(_from_x: float) -> void:
	pass


## Test bot: stand back from the pillar, pick up stones, and throw them up at Earl.
func bot_hint(p: Player) -> Dictionary:
	var e: Node2D = level.earl
	if e == null or e.state != Earl.State.TOWER:
		return {}
	var spot := global_position.x - 150.0
	if p.rocks == 0:
		var best := INF
		for spr in level.pies.get_children():
			if spr.has_meta("stone") and not spr.is_queued_for_deletion():
				var sx: float = spr.get_meta("stone").x
				if absf(sx - p.global_position.x) < absf(best - p.global_position.x):
					best = sx
		if best < INF:
			return {"dir": signf(best - p.global_position.x)}
		return {"dir": 0.0}
	var dx := spot - p.global_position.x
	if absf(dx) > 30.0:
		return {"dir": signf(dx)}
	if p.facing < 0:
		return {"dir": 1.0}
	return {"dir": 0.0, "throw": true}


func _draw() -> void:
	var rock := Color("9a7a62")
	var pts := PackedVector2Array([Vector2(-26, 0), Vector2(28, 0), Vector2(20, deck * 0.5), Vector2(22, deck), Vector2(-18, deck), Vector2(-22, deck * 0.55)])
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + Vector2(signf(q.x), 0) * 1.5)
	draw_colored_polygon(out, OUTLINE)
	draw_colored_polygon(pts, rock)
	for k in range(1, 6):
		var y := deck * k / 6.0
		draw_line(Vector2(-18, y), Vector2(16, y + 3), rock.darkened(0.2), 1.0)
	draw_rect(Rect2(-18, deck - 2, 40, 3), rock.lightened(0.25))
	# rope ladder up the left side
	var rope := Color("c8a060")
	draw_line(Vector2(-28, deck), Vector2(-28, 0), rope, 1.0)
	draw_line(Vector2(-18, deck), Vector2(-18, 0), rope, 1.0)
	var y2 := deck + 4.0
	while y2 < 0.0:
		draw_line(Vector2(-28, y2), Vector2(-18, y2), rope, 1.0)
		y2 += 8.0
