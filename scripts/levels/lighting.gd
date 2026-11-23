# Mood lighting and ambient particles for each level: an overall tint
# (sunset, dusk, night), real 2D lights (street lamps, the fair's bulbs,
# lanterns, the train's headlamp) and drifting particles (fireflies,
# leaves, dust, pollen). Settings > FANCY EFFECTS turns it all off.
#
# The looks per level are in PRESETS below; objects can add their own
# lights with Lighting.radial() / Lighting.cone().
class_name Lighting
extends Node2D

const PRESETS := {
	"main_street":     {"tint": Color(1.0, 0.97, 0.92), "ambient": "motes"},
	"chicken_run":     {"tint": Color(1.0, 0.82, 0.68), "ambient": "leaves"},
	"rock_creek":      {"tint": Color(1.0, 0.95, 0.88), "ambient": "dust"},
	"gone_fishin":     {"tint": Color(0.95, 0.98, 1.0), "ambient": "pollen"},
	"earls_big_break": {"tint": Color(0.4, 0.44, 0.74), "ambient": "fireflies", "lamps": true},
	"county_fair":     {"tint": Color(0.66, 0.52, 0.76), "ambient": "fireflies", "lamps": true},
	"last_train":      {"tint": Color(1.0, 0.78, 0.62), "ambient": "streaks"},
}

static var _radial_tex: Texture2D
static var _cone_tex: Texture2D

var level: Node
var ambient: CPUParticles2D


func setup(l: Node) -> void:
	level = l
	if not Game.settings.get("fancy_effects", true):
		return
	var p: Dictionary = PRESETS.get(l.data.id, {})
	if p.has("tint"):
		var cm := CanvasModulate.new()
		cm.color = p.tint
		add_child(cm)
	if p.get("lamps", false):
		for lx in l.lamp_xs:
			add_child(radial(Vector2(lx, l.GROUND_Y - 62), Color(1.0, 0.85, 0.55), 1.6, 1.1))
	if p.has("ambient"):
		ambient = _particles(p.ambient)
		add_child(ambient)


func _process(_delta: float) -> void:
	if ambient and level and level.camera:
		ambient.global_position = level.camera.get_screen_center_position()


static func enabled() -> bool:
	return Game.settings.get("fancy_effects", true)


# --- light helpers --------------------------------------------------------------------------
## A soft round glow. size 1 = about 128 px across.
static func radial(at: Vector2, color: Color, size := 1.0, energy := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _radial()
	l.position = at
	l.color = color
	l.texture_scale = size
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l


## A beam (flashlight, headlamp) pointing along +x from its position; rotate the light to aim it.
static func cone(at: Vector2, color: Color, length := 1.0, energy := 1.2) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _cone()
	l.offset = Vector2(64, 0)
	l.position = at
	l.color = color
	l.texture_scale = length
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l


static func _radial() -> Texture2D:
	if _radial_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_radial_tex = t
	return _radial_tex


static func _cone() -> Texture2D:
	if _cone_tex == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d := Vector2(x, y - 64.0)
				var ang := absf(d.angle())
				var a := 0.0
				if ang < 0.3:
					a = (1.0 - d.length() / 128.0) * (1.0 - ang / 0.3)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a * 1.4, 0.0, 1.0)))
		_cone_tex = ImageTexture.create_from_image(img)
	return _cone_tex


## A one-off burst of confetti (winning a level).
static func confetti(parent: Node, at: Vector2) -> void:
	if not enabled():
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 60
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 2.2
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 260)
	p.damping_min = 20.0
	p.damping_max = 40.0
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color("e84a4a"))
	g.set_color(1, Color("4a8ae8"))
	g.add_point(0.33, Color("ffd23f"))
	g.add_point(0.66, Color("6ac06a"))
	p.color_initial_ramp = g
	p.z_index = 6
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)   # (4.1 has no "finished" signal)


# --- ambient particles --------------------------------------------------------------------------
func _particles(kind: String) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(280, 150)
	p.z_index = 4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	p.color_ramp = fade
	match kind:
		"fireflies":
			p.amount = 26
			p.lifetime = 5.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 14.0
			p.spread = 180.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 2.2
			p.color = Color(0.85, 1.0, 0.45)
			p.hue_variation_min = -0.03
			p.hue_variation_max = 0.03
		"leaves":
			p.amount = 14
			p.lifetime = 7.0
			p.gravity = Vector2(-6, 18)
			p.direction = Vector2(-1, 0.3)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 25.0
			p.angular_velocity_min = -120.0
			p.angular_velocity_max = 120.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.0
			p.color = Color(0.85, 0.45, 0.15)
			p.hue_variation_min = -0.05
			p.hue_variation_max = 0.06
		"dust":
			p.amount = 18
			p.lifetime = 6.0
			p.gravity = Vector2(-4, -2)
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 12.0
			p.direction = Vector2(-1, 0)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			p.color = Color(0.95, 0.85, 0.7, 0.6)
		"pollen":
			p.amount = 16
			p.lifetime = 7.0
			p.gravity = Vector2(3, -3)
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 8.0
			p.spread = 180.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.6
			p.color = Color(1, 1, 0.9, 0.8)
		"motes":
			p.amount = 10
			p.lifetime = 6.0
			p.gravity = Vector2(2, -1)
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 6.0
			p.spread = 180.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.5
			p.color = Color(1, 0.97, 0.85, 0.5)
		"streaks":
			# grit and cinders blowing back past the train
			p.amount = 30
			p.lifetime = 1.6
			p.gravity = Vector2.ZERO
			p.direction = Vector2(-1, 0.05)
			p.spread = 4.0
			p.initial_velocity_min = 280.0
			p.initial_velocity_max = 420.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			p.color = Color(1.0, 0.8, 0.6, 0.55)
	return p
