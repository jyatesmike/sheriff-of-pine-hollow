# A clothesline strung from a rooftop down to the street: jump into its high
# end and you slide down it (jump to let go early).
#   {"type": "zipline", "x": 133, "h": 7.5, "x2": 150, "h2": 1.5}
extends LevelObject

var a := Vector2.ZERO        # high end (local)
var b := Vector2.ZERO        # low end
var t := 0.0
var speed := 0.0
var cooldown := 0


func _setup() -> void:
	a = Vector2(0, tiles_up(o.get("h", 7.5)))
	b = Vector2((o.get("x2", 150) - o.get("x", 133)) * TILE, tiles_up(o.get("h2", 1.5)))


func step(_delta: float) -> void:
	cooldown = maxi(cooldown - 1, 0)
	var p := player()
	if p.ride != null or cooldown > 0:
		return
	# grab when the line crosses the Sheriff's upper body (anywhere but the very end)
	var feet := p.global_position - global_position
	var seg := b - a
	var k := (feet.x - a.x) / seg.x
	if k < 0.0 or k > 0.85:
		return
	var line_y := a.y + seg.y * k
	if line_y > feet.y - 50.0 and line_y < feet.y - 12.0:
		t = k
		speed = maxf(150.0, absf(p.velocity.x))
		p.start_ride(self)
		Audio.sfx("dash", 1.3)


func ride_step(p: Player, delta: float) -> bool:
	var seg := b - a
	speed = minf(speed + 300.0 * delta, 340.0)
	t += speed * delta / seg.length()
	p.global_position = global_position + a + seg * minf(t, 1.0) + Vector2(0, 46)
	p.velocity = seg.normalized() * speed
	p.facing = 1 if seg.x > 0.0 else -1
	p.anim = "climb_idle"
	if Input.is_action_just_pressed("jump") or t >= 1.0:
		p.velocity = seg.normalized() * speed * 0.8 + Vector2(0, -180.0)
		cooldown = 30
		return false
	return true


func _draw() -> void:
	for e in [a, b]:
		outlined_rect(Rect2(e.x - 2, e.y - 4, 4, -e.y + 4), Color("7a5230"))
	draw_line(a, b, Color("e8e0cc"), 1.0)
	draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color("a8a090"), 1.0)
