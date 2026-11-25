# A townsperson on night watch with a flashlight. Either up in a window
# sweeping the street ("sweep": angles in degrees, 90 = straight down), or
# walking a beat with the beam pointed ahead ("walk": tile range). Get
# caught in the beam and you're spotted: a heart lost, back to the last
# checkpoint. Duck into a hiding spot (UP) and the beam passes right over.
#   {"type": "watchman", "x": 34, "h": 5, "sweep": [60, 130], "speed": 0.9}
#   {"type": "watchman", "x": 52, "walk": [52, 70]}
extends LevelObject

const HALF := 0.22           # half-width of the beam (radians)
const SPOT_TIME := 0.35      # seconds in the beam before you're spotted

var origin := Vector2.ZERO   # local position of the flashlight
var angle := 0.0
var length := 0.0
var walker := false
var wx := 0.0                # walker: local x
var wdir := 1.0
var range_x := Vector2.ZERO
var alarm := 0.0
var beam: PointLight2D
var cool := 0
var _t := 0.0



func _setup() -> void:
	walker = o.has("walk")
	if walker:
		range_x = Vector2((o.walk[0] - o.x) * TILE, (o.walk[1] - o.x) * TILE)
		length = o.get("len", 130.0)
		origin = Vector2(0, -34)
	else:
		origin = Vector2(0, tiles_up(o.get("h", 5)) + 10)
		length = o.get("len", (-origin.y) * 1.6)
	add_to_group("watchers")
	if Lighting.enabled():
		beam = Lighting.cone(origin, Color(1.0, 0.95, 0.7), length / 120.0, 1.3)
		add_child(beam)
		if not walker:
			add_child(Lighting.radial(origin + Vector2(0, -10), Color(1.0, 0.8, 0.45), 0.9, 0.9))
	_t = o.get("phase", 0.0)


func _sweep_angle() -> float:
	var a: float = deg_to_rad(o.sweep[0])
	var b: float = deg_to_rad(o.sweep[1])
	return lerpf(a, b, 0.5 + 0.5 * sin(_t * o.get("speed", 0.9)))


func step(delta: float) -> void:
	_t += delta
	cool = maxi(cool - 1, 0)
	if walker:
		wx += wdir * 34.0 * delta
		if wx > range_x.y or wx < range_x.x:
			wx = clampf(wx, range_x.x, range_x.y)
			wdir = -wdir
		origin = Vector2(wx + wdir * 6.0, -34)
		angle = deg_to_rad(12.0) if wdir > 0.0 else deg_to_rad(168.0)
	else:
		angle = _sweep_angle()
	if beam:
		beam.position = origin
		beam.rotation = angle
		beam.energy = 1.3 + alarm
	var p := player()
	if covers(p.global_position + Vector2(0, -26)) or covers(p.global_position + Vector2(0, -46)):
		alarm += delta / SPOT_TIME
		if alarm >= 1.0 and cool == 0:
			_spotted(p)
	else:
		alarm = maxf(alarm - delta * 2.0, 0.0)
	queue_redraw()


## Is this world point lit by the beam (and not hidden)?
func covers(at: Vector2) -> bool:
	if player().has_meta("hidden") and player().get_meta("hidden"):
		return false
	var v := at - (global_position + origin)
	if v.length() > length:
		return false
	return absf(wrapf(v.angle() - angle, -PI, PI)) < HALF


func _spotted(p: Player) -> void:
	alarm = 0.0
	cool = 90
	Audio.sfx("honk", 0.8)
	level.popup(p.global_position + Vector2(0, -64), GameText.NB_SPOTTED, Color("ff4a3a"))
	var k := randi() % GameText.NB_WATCH_SHOUT.size()
	Audio.say("deputy", Names.fmt(GameText.NB_WATCH_SHOUT[k]), "nb_watch_%d" % (k + 1))
	p.hurt(p.global_position.x - 10.0)
	var back: float = level.checkpoint_x if level.checkpoint_x > 0.0 else level.data.player_start * TILE
	p.global_position = Vector2(back, level.GROUND_Y)
	p.velocity = Vector2.ZERO
	pass  # (4.3 physics interpolation not in 4.1)
	level.camera.snap_to_target()


## Where the beam's centre line meets the street (world x), for the bot.
func ground_hit_x() -> float:
	var o2 := global_position + origin
	var d := Vector2.from_angle(angle)
	if d.y <= 0.05:
		return INF
	return o2.x + d.x * (level.GROUND_Y - o2.y) / d.y


## Test bot: wait just outside the beam, run through when it swings away.
func bot_hint(p: Player) -> Dictionary:
	var px := p.global_position.x
	if walker:
		var gx := global_position.x + wx
		var facing_me := signf(px - gx) == wdir
		if absf(px - gx) < length + 60.0 and facing_me:
			return {}                                   # the hiding spot handles this
		return {}
	var hx := ground_hit_x()
	if hx == INF:
		return {}
	var spread: float = (level.GROUND_Y - (global_position.y + origin.y)) * tan(HALF) + 30.0
	var in_now := absf(px - hx) < spread
	var ahead := hx - px > 0.0 and hx - px < spread + 70.0
	var near_light := absf(px - (global_position.x + origin.x)) < 260.0
	if not near_light:
		return {}
	if in_now:
		return {"dir": 1.0}
	if ahead:
		return {"dir": 0.0}
	return {}


func _draw() -> void:
	# the beam
	var o2 := origin
	var a1 := Vector2.from_angle(angle - HALF) * length
	var a2 := Vector2.from_angle(angle + HALF) * length
	var col := Color(1.0, 0.95, 0.6, 0.28 + alarm * 0.3)
	draw_colored_polygon(PackedVector2Array([o2, o2 + a1, o2 + a2]), col)
	draw_line(o2, o2 + Vector2.from_angle(angle) * length, Color(1, 0.95, 0.7, 0.1), 6.0)
	if walker:
		var tex := SpriteLib.frames("watchman").get_frame_texture("run", int(_t * 9.0) % 8)
		if tex:
			draw_set_transform(Vector2(wx, 0), 0.0, Vector2(wdir, 1))
			var sz := SpriteLib.draw_size("watchman", tex)
			draw_texture_rect(tex, Rect2(Vector2(-sz.x / 2.0, -sz.y + 2), sz), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(o2, 2.5, Color("fff0a0"))
	else:
		# a lit window with a watcher in it
		var wr := Rect2(origin.x - 12, origin.y - 24, 24, 26)
		draw_rect(wr.grow(2), OUTLINE)
		draw_rect(wr, Color("e8c060"))
		var wt := SpriteLib.frames("watchman").get_frame_texture("idle", int(_t * 6.0) % 4)
		if wt:
			var k := 1.0 / SpriteLib.art_scale("watchman")     # region in the texture's own pixels
			draw_texture_rect_region(wt.atlas, Rect2(origin.x - 12, origin.y - 24, 24, 26), Rect2(wt.region.position + Vector2(12, 6) * k, Vector2(24, 26) * k))
		draw_rect(Rect2(wr.position.x - 3, wr.end.y, wr.size.x + 6, 3), Color("5a4a3a"))
		draw_circle(o2, 2.5, Color("fff0a0"))
	if alarm > 0.05:
		PixelFont.draw_centered(self, "?" if alarm < 0.7 else "!", o2.x, o2.y - (40 if not walker else 30), Color("ff6a3a"), 2)
