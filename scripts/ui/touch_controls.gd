# On-screen buttons for phones/tablets. TouchScreenButton feeds the same
# Input Map actions as the keyboard, and only shows on touch screens.
extends CanvasLayer

const SIZE := 30
const FILL := Color(1, 0.95, 0.75, 0.35)
const EDGE := Color(0.14, 0.08, 0.05, 0.6)
const MARK := Color(0.14, 0.08, 0.05, 0.85)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button("left", Vector2(10, 228), "<")
	_button("right", Vector2(46, 228), ">")
	_button("action", Vector2(404, 228), "D")
	_button("lasso", Vector2(404, 192), "O")
	_button("jump", Vector2(440, 214), "^")
	_button("pause", Vector2(446, 22), "=")


func _button(action: String, pos: Vector2, mark: String) -> void:
	var b := TouchScreenButton.new()
	b.action = action
	b.position = pos
	b.passby_press = true            # slide a thumb between left/right
	b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	b.texture_normal = _make_texture(mark, false)
	b.texture_pressed = _make_texture(mark, true)
	add_child(b)


func _make_texture(mark: String, pressed: bool) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c := (SIZE - 1) / 2.0
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x - c, y - c).length()
			if d <= c - 1:
				img.set_pixel(x, y, FILL.lightened(0.3) if pressed else FILL)
			elif d <= c:
				img.set_pixel(x, y, EDGE)
	# simple pixel glyphs
	for i in 7:
		match mark:
			"<":
				for j in range(-i, i + 1):
					img.set_pixel(11 + i, 15 + j / 1, MARK)
			">":
				for j in range(-i, i + 1):
					img.set_pixel(18 - i, 15 + j, MARK)
			"^":
				for j in range(-i, i + 1):
					img.set_pixel(15 + j, 11 + i, MARK)
			"D":
				img.set_pixel(9 + i * 2, 18, MARK); img.set_pixel(10 + i * 2, 18, MARK)
				img.set_pixel(9 + i * 2, 19, MARK); img.set_pixel(10 + i * 2, 19, MARK)
			"O":
				for a in 16:
					var t := a / 16.0 * TAU
					img.set_pixel(15 + int(cos(t) * 5), 15 + int(sin(t) * 5), MARK)
			"=":
				img.set_pixel(12, 11 + i, MARK); img.set_pixel(13, 11 + i, MARK)
				img.set_pixel(17, 11 + i, MARK); img.set_pixel(18, 11 + i, MARK)
	return ImageTexture.create_from_image(img)
