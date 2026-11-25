# Animated sprite for any character. Feet sit at the node's origin.
# Facing is done with flip_h (never by flipping the node's scale, which
# made turning characters flicker with physics interpolation on).
# The owner calls play_anim() each frame; squash() adds squash and stretch.
extends AnimatedSprite2D

@export var sheet := "sheriff"

var facing := 1:
	set(v):
		facing = v
		flip_h = v < 0
var _squash := Vector2.ONE
var _squash_v := Vector2.ZERO
var air_stretch := true          # stretch a little with fall/rise speed


func _ready() -> void:
	set_sheet(sheet)


func set_sheet(name: String) -> void:
	sheet = name
	sprite_frames = SpriteLib.frames(sheet)
	scale = Vector2.ONE * SpriteLib.art_scale(sheet)
	centered = true
	# offset is in the texture's own pixels (twice as many for double-resolution art)
	offset = Vector2(0, -SpriteLib.frame_size(sheet).y / 2.0 / SpriteLib.art_scale(sheet))
	play("idle" if sprite_frames.has_animation("idle") else sprite_frames.get_animation_names()[0])


func play_anim(name: String) -> void:
	if animation != name and sprite_frames.has_animation(name):
		play(name)


func squash(s: Vector2) -> void:
	_squash = s


func _process(delta: float) -> void:
	# a springy return to normal: overshoots once, so landings wobble
	var dt := minf(delta, 0.05)
	_squash_v += ((Vector2.ONE - _squash) * 520.0 - _squash_v * 26.0) * dt
	_squash += _squash_v * dt
	var s := _squash
	if air_stretch and Lighting.enabled():
		var body := get_parent() as CharacterBody2D
		if body and not body.is_on_floor():
			var k := clampf(absf(body.velocity.y) / 900.0, 0.0, 0.12)
			s *= Vector2(1.0 - k * 0.6, 1.0 + k)
	scale = s * SpriteLib.art_scale(sheet)
