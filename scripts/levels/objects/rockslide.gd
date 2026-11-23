# A rockslide down the canyon wall. Once the Sheriff walks in, boulders
# come bouncing down the trail toward him. Jump them, shelter under the
# rock overhangs (the boulders bounce over the top), or smash one with a
# thrown rock.
#   {"type": "rockslide", "x": 48, "w": 44, "shelters": [58, 72, 84]}
extends LevelObject

const ROLL := 150.0
const RADIUS := 10.0
const SHELTER_H := 3.6       # tiles: underside of an overhang (the Sheriff fits under)
const SHELTER_W := 3.0       # tiles

var w := 0.0
var shelters: Array = []     # local x of each overhang's left edge
var boulders: Array = []     # {x, y (height above the trail), vy, spin, dead}
var spawn_t := 30
var active := false
var warned := false
var _t := 0.0


func _setup() -> void:
	w = o.get("w", 40) * TILE
	for sx in o.get("shelters", []):
		var lx: float = (sx - o.x) * TILE
		shelters.append(lx)
		add_box(Rect2(lx, tiles_up(SHELTER_H) - 10, SHELTER_W * TILE, 10), 2, true)   # stand on top, too
	level.rock_targets.append(self)


## Height of the boulders' path at local x: the trail, or the top of an overhang.
func _surface(lx: float) -> float:
	for sx in shelters:
		var a: float = sx - 12.0
		var b: float = sx + SHELTER_W * TILE + 4.0
		if lx >= a and lx <= b:
			var top := SHELTER_H * TILE + 10.0
			if lx > sx + SHELTER_W * TILE - 6.0:
				return lerpf(top, top * 0.4, (lx - (sx + SHELTER_W * TILE - 6.0)) / 10.0)   # rubble ramp on the right
			return top
	return 0.0


func step(delta: float) -> void:
	_t += delta
	var p := player()
	var lx := p.global_position.x - global_position.x
	active = lx > -40.0 and lx < w + 20.0 and not level.finished
	if active and not warned:
		warned = true
		if level.earl:
			level.earl.say(GameText.RC_EARL_SLIDE, 100, "rc_slide")
	if active:
		spawn_t -= 1
		if spawn_t <= 0:
			spawn_t = 70 + randi() % 50
			boulders.append({"x": w + 30.0, "y": 70.0, "vy": 0.0, "spin": 0.0, "dead": false, "size": randf_range(0.8, 1.2)})
	var pr := p.body_rect()
	for b in boulders:
		if b.dead:
			b.vy -= 900.0 * delta
			b.y += b.vy * delta
			continue
		b.x -= ROLL * delta
		b.spin -= ROLL * delta / RADIUS
		b.vy -= 900.0 * delta
		b.y += b.vy * delta
		var floor_h := _surface(b.x)
		if b.y <= floor_h:
			b.y = floor_h
			b.vy = 170.0 if randf() < 0.5 else 110.0       # bounce along
		var rad: float = RADIUS * b.size
		var c := global_position + Vector2(b.x, -b.y - rad)
		if Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0).grow(-2).intersects(pr):
			p.hurt(c.x)
		if b.x < -60.0:
			b.dead = true
			b.vy = -50.0
	boulders = boulders.filter(func(b): return not b.dead or b.y > -300.0)
	queue_redraw()


## A thrown rock smashes a rolling boulder.
func rock_hit(r: Rect2) -> bool:
	for b in boulders:
		if b.dead:
			continue
		var rad: float = RADIUS * b.size
		var c := global_position + Vector2(b.x, -b.y - rad)
		if r.grow(rad).has_point(c):
			b.dead = true
			b.vy = 0.0
			level.dust(c, 12, Color("a8988a"))
			level.score += 75
			level.popup(c + Vector2(0, -16), "SMASH! +75")
			Audio.sfx("break")
			return true
	return false


## Test bot: hop boulders that are about to reach it; wait under an overhang if one's close.
func bot_hint(p: Player) -> Dictionary:
	var lx := p.global_position.x - global_position.x
	if lx < -40.0 or lx > w + 20.0:
		return {}
	for b in boulders:
		var dx: float = b.x - lx
		if not b.dead and dx > 0.0 and dx < 70.0 and b.y < 30.0 and p.is_on_floor():
			return {"dir": 1.0, "jump": true}
	return {}


func _draw() -> void:
	# the slope the boulders come down (behind everything)
	var rock := Color("8a7060")
	var pts := PackedVector2Array([Vector2(w - 40, 0), Vector2(w + 80, 0), Vector2(w + 80, -150), Vector2(w + 20, -120), Vector2(w - 10, -60)])
	draw_colored_polygon(pts, rock.darkened(0.25))
	for k in 6:
		draw_circle(Vector2(w + 10 + k * 12, -100 + (k % 3) * 18), 6.0, rock.darkened(0.1))
	# overhangs
	for sx in shelters:
		var top := tiles_up(SHELTER_H)
		var sw := SHELTER_W * TILE
		draw_rect(Rect2(sx + sw - 8, top, 14, -top), OUTLINE)
		draw_rect(Rect2(sx + sw - 7, top, 12, -top), rock)                      # rock pillar on the right
		draw_rect(Rect2(sx - 4, top - 11, sw + 12, 12), OUTLINE)
		draw_rect(Rect2(sx - 3, top - 10, sw + 10, 10), rock.lightened(0.1))    # the overhang slab
		draw_rect(Rect2(sx - 3, top - 10, sw + 10, 2), rock.lightened(0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(sx + sw + 5, top - 10), Vector2(sx + sw + 16, top * 0.4), Vector2(sx + sw + 16, 0), Vector2(sx + sw + 5, 0)]), rock.darkened(0.15))
		draw_rect(Rect2(sx, top, sw - 8, -top), Color(0, 0, 0, 0.18))           # shade underneath
	# boulders
	var tex := SpriteLib.prop("boulder")
	for b in boulders:
		var rad: float = RADIUS * b.size
		draw_set_transform(Vector2(b.x, -b.y - rad), b.spin, Vector2.ONE * b.size * 0.7)
		draw_texture(tex, -tex.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
