# Draws the level's props from the props atlas: crates, awnings with posts,
# the end gate, the town-limit sign (with the player's town name) and
# sidewalk furniture (lamps, benches, planters...) placed on solid ground.
# The ground itself is a TileMapLayer built by level.gd; pits are drawn by
# draw_pits() on a node that sits behind the tiles (dark ditches, or water
# on the lake level). At night, lamps cast light cones (the deputy spots
# you faster in them).
extends Node2D

const TILE := 16
const OUTLINE := Color("24140e")
const FURNITURE := {
	"town": ["lamp", "bench", "planter", "hydrant", "lamp", "mailbox", "barrel", "planter"],
	"night": ["lamp", "bench", "lamp", "mailbox", "lamp", "barrel"],
	"farm": ["barrel", "planter"],
	"quarry": ["barrel"],
	"lake": ["barrel", "bench"],
}

var data: Dictionary
var text: Dictionary
var gy := 0.0
var _items: Array = []      # [prop name, x]
var _t := 0.0


func setup(d: Dictionary, ground_y: float, level_text: Dictionary) -> void:
	data = d
	text = level_text
	gy = ground_y
	_place_furniture()
	queue_redraw()


func lamp_xs() -> Array:
	var out := []
	for it in _items:
		if it[0] == "lamp":
			out.append(it[1])
	return out


func _process(delta: float) -> void:
	if data.get("water", false):
		_t += delta


## Dark ditches (or lake water) between ground segments, behind the tiles.
func draw_pits(ci: CanvasItem) -> void:
	var width: float = data.width_tiles * TILE
	if data.get("water", false):
		_draw_water(ci, width)
		return
	var x := -TILE * 1.0
	for seg in data.ground:
		var a: float = seg[0] * TILE
		if a > x:
			ci.draw_rect(Rect2(x, gy + 12, a - x, 300), Color("1a100c"))
			ci.draw_rect(Rect2(x, gy + 4, a - x, 8), Color("2e2018"))
		x = seg[1] * TILE
	if x < width + TILE:
		ci.draw_rect(Rect2(x, gy + 4, width + TILE - x, 300), Color("1a100c"))


func _draw_water(ci: CanvasItem, width: float) -> void:
	var top := gy + 10.0
	ci.draw_rect(Rect2(-TILE, top, width + TILE * 2, 300), Color("1e4a78"))
	ci.draw_rect(Rect2(-TILE, top + 10, width + TILE * 2, 300), Color("163a62"))
	ci.draw_rect(Rect2(-TILE, top, width + TILE * 2, 2), Color("6aa8e0"))
	var x := -TILE * 1.0
	while x < width + TILE:
		ci.draw_rect(Rect2(x, top + 4 + int(x / 23.0) % 3 * 3, 6, 1), Color("4a88c0"))
		x += 17.0


func _draw() -> void:
	if data.is_empty():
		return
	if data.get("theme", "") == "night":
		for lx in lamp_xs():
			var cone := PackedVector2Array([Vector2(lx - 3, gy - 74), Vector2(lx + 3, gy - 74), Vector2(lx + 40, gy), Vector2(lx - 40, gy)])
			draw_colored_polygon(cone, Color(1.0, 0.86, 0.5, 0.16))
			draw_rect(Rect2(lx - 40, gy - 2, 80, 3), Color(1.0, 0.9, 0.6, 0.25))
	for it in _items:
		var tex := SpriteLib.prop(it[0])
		draw_texture(tex, Vector2(roundf(it[1] - tex.get_width() / 2.0), gy - tex.get_height() + 2))
	for p in data.platforms:
		_awning(p.x * TILE, gy - p.h * TILE, p.w * TILE)
	var signs: Array = []
	for hk in data.get("hooks", []):
		var ring := Vector2(hk[0] * TILE + 8, gy - hk[1] * TILE)
		if hk.size() > 2 and hk[2] == "sign":
			signs.append(ring)
		else:
			_hook(ring)
	if not signs.is_empty():
		_sign_hooks(signs)
	for c in data.crates:
		draw_texture(SpriteLib.prop("crate"), Vector2(c.x * TILE, gy - 32.0 * (c.stack + 1)))
	if data.get("train", false):
		return                 # no gate or town sign on top of a moving train
	var gate := SpriteLib.prop("gate")
	draw_texture(gate, Vector2(data.fence_x * TILE, gy - gate.get_height()))
	_town_sign(2 * TILE)


## A lasso hook: a ring hanging from an arm on a post that stands on the
## nearest solid ground to the left (iron in town, wood elsewhere).
func _hook(ring: Vector2) -> void:
	var post_x := ring.x - 40.0
	for seg in data.ground:
		var edge: float = seg[1] * TILE
		if edge <= ring.x and ring.x - edge < 120.0:
			post_x = edge - 8.0
	var town: bool = data.get("theme", "town") in ["town", "night"]
	var dark := Color("24242c") if town else Color("3a2414")
	var mid := Color("3a3a46") if town else Color("7a5230")
	var arm_y := ring.y - 14.0
	draw_rect(Rect2(post_x - 2, arm_y - 2, 5, gy - arm_y + 2), OUTLINE)
	draw_rect(Rect2(post_x - 1, arm_y - 1, 3, gy - arm_y + 1), mid)
	draw_rect(Rect2(post_x - 1, arm_y - 3, ring.x - post_x + 3, 4), OUTLINE)
	draw_rect(Rect2(post_x, arm_y - 2, ring.x - post_x + 1, 2), mid)
	draw_line(Vector2(post_x + 1, arm_y + 10), Vector2(post_x + 14, arm_y), dark, 2.0)   # brace
	for k in 3:
		draw_rect(Rect2(ring.x - 1, arm_y + k * 3, 2, 2), dark)                           # chain
	var tex := SpriteLib.prop("hook_ring")
	draw_texture(tex, ring - tex.get_size() / 2.0)


## Shop signs hanging from a wire strung across a gap: lasso the rings.
func _sign_hooks(rings: Array) -> void:
	var left: float = rings[0].x - 60.0
	var right: float = rings[-1].x + 60.0
	for seg in data.ground:          # poles stand on the gap's edges
		if seg[1] * TILE <= rings[0].x:
			left = seg[1] * TILE - 6.0
		if seg[0] * TILE >= rings[-1].x and right == rings[-1].x + 60.0:
			right = seg[0] * TILE + 6.0
	var wire_y: float = rings[0].y - 18.0
	for px in [left, right]:
		draw_rect(Rect2(px - 3, wire_y - 4, 6, gy - wire_y + 4), OUTLINE)
		draw_rect(Rect2(px - 2, wire_y - 3, 4, gy - wire_y + 3), Color("5a3a22"))
	var pts := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		pts.append(Vector2(lerpf(left, right, t), wire_y + sin(t * PI) * 6.0))
	draw_polyline(pts, Color("1a1410"), 1.0)
	var tex := SpriteLib.prop("hook_ring")
	var i := 0
	for r in rings:
		var t: float = (r.x - left) / (right - left)
		var wy := wire_y + sin(t * PI) * 6.0
		draw_line(Vector2(r.x, wy), r, Color("3a3a46"), 1.0)
		draw_texture(tex, r - tex.get_size() / 2.0)
		# the shop sign hangs below the ring
		var name: String = Names.signs[(i * 5 + 2) % Names.signs.size()].to_upper()
		var w := PixelFont.width(name) + 10
		var top: float = r.y + 8.0
		draw_line(r + Vector2(-w / 2.0 + 3, 4), Vector2(r.x - w / 2.0 + 3, top), Color("3a3a46"), 1.0)
		draw_line(r + Vector2(w / 2.0 - 3, 4), Vector2(r.x + w / 2.0 - 3, top), Color("3a3a46"), 1.0)
		draw_rect(Rect2(r.x - w / 2.0 - 1, top - 1, w + 2, 13), OUTLINE)
		draw_rect(Rect2(r.x - w / 2.0, top, w, 11), Color("2e6a3e"))
		PixelFont.draw_centered(self, name, r.x, top + 3, Color("f4f0e6"))
		i += 1


func _awning(x: float, y: float, w: float) -> void:
	var post := SpriteLib.prop("awning_post")
	for px in [x + 2, x + w - 6]:
		draw_texture_rect(post, Rect2(px, y + 10, 4, gy - y - 10), true)
	var n := int(w / 16)
	for i in n:
		var part := "awning_m"
		if i == 0:
			part = "awning_l"
		elif i == n - 1:
			part = "awning_r"
		draw_texture(SpriteLib.prop(part), Vector2(x + i * 16, y - 1))


func _town_sign(x: float) -> void:
	var lines: Array = text.get("sign", ["{TOWN}", "TOWN LIMIT"])
	var board := SpriteLib.prop("signboard")
	var post := SpriteLib.prop("awning_post")
	var top := gy - 58
	draw_texture_rect(post, Rect2(x + 10, top + 10, 4, 48), true)
	draw_texture_rect(post, Rect2(x + board.get_width() - 14, top + 10, 4, 48), true)
	draw_texture(board, Vector2(x, top))
	var cx := x + board.get_width() / 2.0
	PixelFont.draw_centered(self, Names.fmt(lines[0]).to_upper(), cx, top + 4, Color("f4f0e6"))
	PixelFont.draw_centered(self, Names.fmt(lines[1]).to_upper(), cx, top + 12, Color("f4f0e6"))


## Deterministic sidewalk furniture: every ~150 px of solid ground, skipping
## crates, boulders, segment edges, the start sign and the end gate.
func _place_furniture() -> void:
	_items.clear()
	var kinds: Array = FURNITURE.get(data.get("theme", "town"), [])
	if kinds.is_empty() or data.get("train", false):
		return
	var i := 0
	for seg in data.ground:
		var x: float = seg[0] * TILE + 40.0
		while x < seg[1] * TILE - 40.0:
			if x > 120.0 and x < (data.fence_x - 6) * TILE and not _near_crate(x):
				_items.append([kinds[i % kinds.size()], x])
				i += 1
			x += 150.0 + float((i * 37) % 60)


func _near_crate(x: float) -> bool:
	for c in data.crates:
		if absf(c.x * TILE + 16 - x) < 48.0:
			return true
	for b in data.get("boulders", []):
		if absf(b * TILE + 16 - x) < 48.0:
			return true
	return false
