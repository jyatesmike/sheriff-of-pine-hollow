# A townsperson's favor: the one optional mini-goal in each level. Find the
# thing they've lost and bring it back to them. Who they are, what they say
# and what they've lost are in scripts/config/game_text.gd (FAVORS).
#   {"type": "favor", "x": 12, "npc": "aunt", "item": "pie_tin", "item_x": 113, "item_h": 8.6}
extends LevelObject

var state := 0               # 0 lost, 1 carrying it, 2 returned
var asked := false
var item_pos := Vector2.ZERO
var talk_t := 0
var talk := ""
var _t := 0.0


func _setup() -> void:
	item_pos = Vector2(o.item_x * TILE + 8, level.GROUND_Y - o.get("item_h", 1.0) * TILE)
	level.favor_obj = self
	z_index = 1


func _text(k: String) -> String:
	return Names.fmt(GameText.FAVORS.get(level.data.id, {}).get(k, ""))


func step(delta: float) -> void:
	_t += delta
	talk_t = maxi(talk_t - 1, 0)
	var p := player()
	var near := absf(p.global_position.x - global_position.x) < 40.0 and absf(p.global_position.y - global_position.y) < 60.0
	if state == 0:
		if near and not asked:
			asked = true
			_say(_text("ask"), "ask")
		var r := Rect2(item_pos - Vector2(10, 10), Vector2(20, 20))
		if r.intersects(p.body_rect()):
			state = 1
			level.popup(item_pos + Vector2(0, -14), _text("got"), Color("8ae08a"))
			Audio.sfx("pickup", 0.8)
	elif state == 1 and near:
		state = 2
		level.favor_done = true
		level.score += 750
		_say(_text("thanks"), "thanks")
		level.popup(global_position + Vector2(0, -70), GameText.UI.favor_done, Color("ffd23f"))
		Audio.sfx("win", 1.3)
	queue_redraw()


func _say(t: String, id: String) -> void:
	talk = t
	talk_t = 200
	var who: String = o.get("npc", "aunt")
	Audio.say(who, t, "%s_favor_%s" % [level.data.id, id])


## Resuming from a checkpoint: restore what had happened.
func restore(st: int) -> void:
	state = st
	asked = st > 0
	level.favor_done = st == 2


func _draw() -> void:
	_person(o.get("npc", "aunt"))
	if state == 0 and not asked and int(_t * 2.0) % 2 == 0:
		PixelFont.draw_centered(self, "!", 0, -66, Color("ffd23f"), 2)
	if talk_t > 0 and talk != "":
		var w := PixelFont.width(talk.to_upper()) + 8
		var r := Rect2(-w / 2.0 + 11, -86, w, 20)
		draw_rect(r.grow(1), OUTLINE)
		draw_rect(r, Color("fff6dc"))
		PixelFont.draw_centered(self, talk, r.get_center().x, -79, Color("3a2414"))
		var face := SpriteLib.head(o.get("npc", "aunt"))
		if face.size() > 0:
			var pr := Rect2(r.position.x - 21, r.position.y, 20, 20)
			draw_rect(pr.grow(1), OUTLINE)
			draw_rect(pr, Color("e8c890"))
			draw_rect(Rect2(pr.position, Vector2(20, 7)), Color("f4dcaa"))
			draw_texture_rect_region(face[0], pr, face[1])
	if state == 2:
		PixelFont.draw_centered(self, "", 0, -60, Color.WHITE)
	# the lost item (in the world, or bobbing over the Sheriff's head)
	var at := item_pos - global_position
	if state == 1:
		at = player().global_position - global_position + Vector2(0, -62 + sin(_t * 5.0) * 1.5)
	elif state == 2:
		at = Vector2(12, -26)
	_item(o.get("item", "pie_tin"), at)
	if state == 0:
		var k := sin(_t * 3.0)
		draw_arc(at, 10.0 + k, 0, TAU, 16, Color(1, 0.9, 0.4, 0.5), 1.0)


func _person(kind: String) -> void:
	# townsfolk sheets live in art/sprites/<npc>.png (same layout as the cast)
	var anim := "victory" if state == 2 and talk_t > 0 else "idle"
	var sf := SpriteLib.frames(kind if ResourceLoader.exists("res://art/sprites/%s.png" % kind) else "aunt")
	var n := sf.get_frame_count(anim)
	var tex := sf.get_frame_texture(anim, int(_t * sf.get_animation_speed(anim)) % n)
	if tex == null:
		return
	var face := 1.0 if player() == null or player().global_position.x >= global_position.x else -1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height() + 2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _item(kind: String, at: Vector2) -> void:
	match kind:
		"pie_tin":
			draw_circle(at, 7.0, OUTLINE)
			draw_circle(at, 6.0, Color("c0c4cc"))
			draw_circle(at, 3.5, Color("9aa0aa"))
		"horseshoe":
			draw_arc(at, 6.0, 0.3, PI * 2.0 - 0.3 + PI, 12, OUTLINE, 4.0)
			draw_arc(at, 6.0, PI * 0.6, PI * 2.4, 12, Color("a8a8b0"), 2.0)
		"hat":
			draw_rect(Rect2(at + Vector2(-9, 1), Vector2(18, 3)), OUTLINE)
			draw_rect(Rect2(at + Vector2(-5, -6), Vector2(10, 8)), OUTLINE)
			draw_rect(Rect2(at + Vector2(-8, 1), Vector2(16, 2)), Color("3a3a46"))
			draw_rect(Rect2(at + Vector2(-4, -5), Vector2(8, 6)), Color("3a3a46"))
			draw_rect(Rect2(at + Vector2(-4, -1), Vector2(8, 1)), Color("c83a3a"))
		"lure":
			draw_line(at + Vector2(0, -8), at + Vector2(0, -2), Color("c8c8c8"), 1.0)
			draw_rect(Rect2(at + Vector2(-4, -3), Vector2(8, 6)), OUTLINE)
			draw_rect(Rect2(at + Vector2(-3, -2), Vector2(6, 4)), Color("e85a3a"))
			draw_rect(Rect2(at + Vector2(1, -2), Vector2(2, 4)), Color("f0e060"))
		"scissors":
			draw_line(at + Vector2(-6, -5), at + Vector2(6, 5), OUTLINE, 3.0)
			draw_line(at + Vector2(6, -5), at + Vector2(-6, 5), OUTLINE, 3.0)
			draw_line(at + Vector2(-6, -5), at + Vector2(6, 5), Color("c8c8d0"), 1.0)
			draw_line(at + Vector2(6, -5), at + Vector2(-6, 5), Color("c8c8d0"), 1.0)
			draw_circle(at + Vector2(-6, 5), 2.5, Color("c83a3a"))
			draw_circle(at + Vector2(6, 5), 2.5, Color("c83a3a"))
		"megaphone":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -2), at + Vector2(6, -7), at + Vector2(6, 7), at + Vector2(-7, 2)]), OUTLINE)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -1), at + Vector2(5, -6), at + Vector2(5, 6), at + Vector2(-6, 1)]), Color("e8c040"))
		"lantern":
			draw_rect(Rect2(at + Vector2(-5, -7), Vector2(10, 13)), OUTLINE)
			draw_rect(Rect2(at + Vector2(-4, -6), Vector2(8, 11)), Color("ffd060"))
			draw_rect(Rect2(at + Vector2(-2, -10), Vector2(4, 3)), Color("5a5a66"))
