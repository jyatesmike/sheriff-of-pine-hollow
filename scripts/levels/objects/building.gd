# A storefront you can stand on top of: the street runs in front of it, and
# the flat roof is a platform. With "ladder": true a fire escape on its left
# side lets you climb up (hold up / W).
#   {"type": "building", "x": 100, "w": 10, "h": 7, "ladder": true, "style": "brick"}
extends LevelObject

const CLIMB_SPEED := 95.0

var w := 0.0
var top := 0.0
var ladder_x := 0.0


func _setup() -> void:
	w = o.get("w", 10) * TILE
	top = tiles_up(o.get("h", 7))
	add_box(Rect2(0, top, w, 6), 2, true)
	ladder_x = 10.0


func _has_ladder() -> bool:
	return o.get("ladder", false)


func step(_delta: float) -> void:
	if not _has_ladder():
		return
	var p := player()
	if p.ride != null or p.lasso and p.lasso.swinging():
		return
	var lx := p.global_position.x - (global_position.x + ladder_x)
	var feet := p.global_position.y - global_position.y
	if absf(lx) < 10.0 and feet > top + 2.0 and feet <= 1.0 and Input.is_action_pressed("up"):
		p.start_ride(self)


## Player.ride callback: climb the fire escape. Return false when done.
func ride_step(p: Player, delta: float) -> bool:
	var dir := Input.get_axis("up", "down")
	p.global_position.x = move_toward(p.global_position.x, global_position.x + ladder_x, 120.0 * delta)
	p.global_position.y += dir * CLIMB_SPEED * delta
	p.velocity = Vector2.ZERO
	p.anim = "climb" if dir != 0.0 else "climb_idle"
	var feet := p.global_position.y - global_position.y
	if feet <= top:
		p.global_position.y = global_position.y + top - 1.0
		return false                       # stepped onto the roof
	if feet >= 0.0 and dir > 0.0:
		p.global_position.y = global_position.y
		return false                       # back on the street
	if Input.is_action_just_pressed("jump"):
		p.velocity = Vector2(p.facing * 130.0, -320.0)
		return false
	return true


func _draw() -> void:
	var style: String = o.get("style", "brick")
	var base := Color("9a4a32") if style == "brick" else (Color("8aa0b8") if style == "blue" else Color("c8b488"))
	draw_rect(Rect2(-1, top - 1, w + 2, -top + 1), OUTLINE)
	draw_rect(Rect2(0, top, w, -top), base)
	if style == "brick":
		for y in range(int(top) + 2, 0, 4):
			draw_rect(Rect2(0, y, w, 1), base.darkened(0.25))
	else:
		for y in range(int(top) + 2, 0, 5):
			draw_rect(Rect2(0, y, w, 1), base.lightened(0.2))
	draw_rect(Rect2(-3, top - 4, w + 6, 5), base.darkened(0.4))           # roof edge
	draw_rect(Rect2(-3, top - 4, w + 6, 1), base.lightened(0.3))
	var floors := int(-top / 48.0)
	for f in floors:
		for k in int(w / 40.0):
			var wx := 22.0 + k * 40.0
			var wy := top + 12.0 + f * 48.0
			if wx + 16 < w:
				draw_rect(Rect2(wx - 1, wy - 1, 18, 22), Color("e8e0cc"))
				draw_rect(Rect2(wx, wy, 16, 20), Color("2a3a5a"))
				draw_rect(Rect2(wx + 2, wy + 2, 4, 16), Color("6a8ab0"))
	# shop front at street level
	draw_rect(Rect2(8, -34, w - 16, 34), Color("3a2414"))
	draw_rect(Rect2(10, -32, w - 20, 22), Color("2e4060"))
	draw_rect(Rect2(12, -30, 6, 18), Color("8ab0d0"))
	if _has_ladder():
		var lx := ladder_x
		for side in [-6.0, 6.0]:
			draw_rect(Rect2(lx + side - 1, top - 2, 3, -top + 2), Color("2a2a30"))
		var y := top + 2.0
		while y < -2.0:
			draw_rect(Rect2(lx - 6, y, 13, 2), Color("4a4a56"))
			y += 8.0
