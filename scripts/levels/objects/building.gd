# A storefront you can stand on top of: the street runs in front of it, and
# the flat roof is a platform. With "ladder": true a fire escape on its left
# side lets you climb up (hold up / W). Real PixelLab art, one of 6 looks
# picked by "style"; each is drawn at its native 10x16-tile size (160x256px).
#   {"type": "building", "x": 100, "w": 10, "h": 16, "ladder": true, "style": "hardware"}
extends LevelObject

const CLIMB_SPEED := 95.0

const TEX := {
	"hardware": preload("res://art/sprites/buildings/hardware.png"),
	"diner": preload("res://art/sprites/buildings/diner.png"),
	"barbershop": preload("res://art/sprites/buildings/barbershop.png"),
	"post_office": preload("res://art/sprites/buildings/post_office.png"),
	"grocery": preload("res://art/sprites/buildings/grocery.png"),
	"dressmaker": preload("res://art/sprites/buildings/dressmaker.png"),
}

var w := 0.0
var top := 0.0
var ladder_x := 0.0


func _setup() -> void:
	w = o.get("w", 10) * TILE
	top = tiles_up(o.get("h", 16))
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
	var style: String = o.get("style", "hardware")
	var tex: Texture2D = TEX.get(style, TEX["hardware"])
	draw_texture_rect(tex, Rect2(0, top, w, -top), false)
	if _has_ladder():
		var lx := ladder_x
		for side in [-6.0, 6.0]:
			draw_rect(Rect2(lx + side - 1, top - 2, 3, -top + 2), Color("2a2a30"))
		var y := top + 2.0
		while y < -2.0:
			draw_rect(Rect2(lx - 6, y, 13, 2), Color("4a4a56"))
			y += 8.0
