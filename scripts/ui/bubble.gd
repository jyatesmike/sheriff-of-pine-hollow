# Speech bubble that floats above a character's head for a few seconds.
# If `voice` is set, the line is also spoken aloud (Audio.say).
extends Node2D

@export var voice := ""

var text := ""
var t := 0
var max_chars := 26
var portrait := true          # little framed face of whoever is talking


## line_id names the voice file to play instead of text-to-speech, e.g.
## "taunt_1" plays audio/voices/<voice>/taunt_1.mp3 if it exists.
func show_text(s: String, frames := 120, line_id := "") -> void:
	text = s.to_upper()
	t = frames
	queue_redraw()
	if voice != "":
		Audio.say(voice, s, line_id)


func _physics_process(_d: float) -> void:
	if t > 0:
		t -= 1
		if t == 0:
			queue_redraw()


func _process(_d: float) -> void:
	# keep the text readable when the owner is flipped
	scale.x = 1.0 / get_parent().scale.x if get_parent().scale.x != 0.0 else 1.0
	if t > 0:
		queue_redraw()


func _draw() -> void:
	if t <= 0 or text == "":
		return
	var lines := _wrap(text)
	var w := 0
	for l in lines:
		w = maxi(w, PixelFont.width(l))
	var h := lines.size() * 7 + 5
	var r := Rect2(-w / 2.0 - 4, -h - 6, w + 8, h)
	var face := _face()
	if face.size() > 0:
		# make room for the portrait on the left
		h = maxi(h, 20)
		r = Rect2(-w / 2.0 - 4 + 11, -h - 6, w + 8, h)
	draw_rect(r.grow(1), PixelFont.OUTLINE)
	draw_rect(r, Color("fff6dc"))
	if face.size() > 0:
		var pr := Rect2(r.position.x - 21, r.position.y + (h - 20) / 2.0, 20, 20)
		draw_rect(pr.grow(1), PixelFont.OUTLINE)
		draw_rect(pr, Color("e8c890"))
		draw_rect(Rect2(pr.position, Vector2(20, 7)), Color("f4dcaa"))
		draw_texture_rect_region(face[0], pr, face[1])
	draw_rect(Rect2(-2, -6, 4, 3), Color("fff6dc"))
	draw_rect(Rect2(-1, -3, 2, 2), PixelFont.OUTLINE)
	for i in lines.size():
		PixelFont.draw_centered(self, lines[i], r.get_center().x, r.position.y + 3 + floorf((h - (lines.size() * 7 + 5)) / 2.0) + i * 7, Color("3a2414"))


func _wrap(s: String) -> Array:
	var out := []
	var cur := ""
	for word in s.split(" "):
		if cur.length() + word.length() + 1 > max_chars and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = word if cur == "" else cur + " " + word
	if cur != "":
		out.append(cur)
	return out


## [atlas texture, region] for the speaker's head, or [] if there's no sprite.
func _face() -> Array:
	if not portrait:
		return []
	var vis := get_parent().get_node_or_null("Visual") as AnimatedSprite2D
	if vis == null or vis.get("sheet") == null:
		return []
	return SpriteLib.head(vis.sheet)
