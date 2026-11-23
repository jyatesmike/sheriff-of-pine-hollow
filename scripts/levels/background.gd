# Area backdrop: a screen-space sky plus four Parallax2D layers loaded from
# art/backgrounds/<area>/ (far 0.15, mid 0.3, main 0.55, near 0.8). Each layer
# tiles horizontally and its bottom edge sits on the ground line. Shop names
# are drawn onto the blank signboards of the main layer, from Names.signs.
extends Node2D

# [layer, scroll speed, y offset, tint]. Tints push distant layers back with a
# little atmosphere so the playable awnings and crates read as foreground.
const LAYERS := [
	["far", 0.15, 0.0, Color(0.85, 0.9, 1.0)],
	["mid", 0.3, 0.0, Color(0.85, 0.9, 1.0)],
	["main", 0.55, 2.0, Color(0.78, 0.8, 0.9)],
	["near", 0.8, 4.0, Color(0.85, 0.85, 0.9)],
]

var gy := 0.0
var signs: Array = []


func setup(data: Dictionary, _width: float, ground_y: float) -> void:
	gy = ground_y
	var area: String = data.get("theme", "town")
	var dir := "res://art/backgrounds/%s/" % area
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/backgrounds.json"))
	if meta is Dictionary and meta.has(area):
		signs = meta[area].signs

	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	var sky := TextureRect.new()
	sky.texture = load(dir + "sky.png")
	sky.size = Vector2(480, 270)
	sky_layer.add_child(sky)

	for l in LAYERS:
		var tex: Texture2D = load(dir + l[0] + ".png")
		var px := Parallax2D.new()
		px.scroll_scale = Vector2(l[1], 1.0)
		px.repeat_size = Vector2(tex.get_width(), 0)
		px.repeat_times = 3
		px.modulate = l[3]
		if data.has("train_speed"):
			px.autoscroll = Vector2(-float(data.train_speed) * l[1], 0)   # the world rushing past the train
		add_child(px)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.position = Vector2(0, gy + l[2] - tex.get_height())
		px.add_child(spr)
		if l[0] == "main" and not signs.is_empty():
			var text := Node2D.new()
			text.position = Vector2(0, gy + l[2])
			text.draw.connect(_draw_signs.bind(text))
			px.add_child(text)
			text.queue_redraw()


func _draw_signs(c: Node2D) -> void:
	for s in signs:
		var name: String = Names.signs[int(s.i) % Names.signs.size()].to_upper()
		var scale := 2 if PixelFont.width(name, 2) <= s.w - 6 else 1
		var y: float = s.y + (s.h - 5 * scale) / 2.0
		PixelFont.draw(c, name, Vector2(roundf(s.x + (s.w - PixelFont.width(name, scale)) / 2.0), roundf(y)), Color("8a2a1e"), scale, false)
