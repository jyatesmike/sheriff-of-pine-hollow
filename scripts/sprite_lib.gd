# SpriteLib: turns the sprite sheets in art/sprites/ into SpriteFrames,
# using the layouts in data/sprites.json (one row per animation). Also hands
# out props from the props atlas and builds terrain TileSets.
# Swap any PNG for hand-drawn art with the same layout: no code changes.
class_name SpriteLib
extends RefCounted

static var _frames := {}
static var _props := {}
static var _layouts := {}
static var _regions := {}
static var _tilesets := {}
static var _heads := {}
static var _scales := {}   # sheet -> 0.5 when its double-resolution art is in use


## Double-resolution art: art/sprites/<sheet>@2x.png, the same rows with frames
## twice the size (96x128 for the characters). Used only when the display shows
## at least 2 screen pixels per world pixel (the handheld display, see
## Game._setup_display()), and drawn at half scale, so sizes and gameplay don't
## change: the extra pixels become extra detail. Computers keep the normal art.
static func hires_on() -> bool:
	var g = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Game") if Engine.get_main_loop() is SceneTree else null
	return g != null and g.get("handheld") and int(g.get("world_scale")) >= 2


## 0.5 if the sheet is drawn from its double-resolution art, else 1.0. Anything
## that draws a frame texture directly scales it by this.
static func art_scale(sheet: String) -> float:
	frames(sheet)
	return _scales.get(sheet, 1.0)


## The size to draw a frame texture of this sheet at, in world pixels (48x64 for
## the characters, whatever the art's resolution). Use with draw_texture_rect().
static func draw_size(sheet: String, tex: Texture2D) -> Vector2:
	return tex.get_size() * art_scale(sheet)


## [atlas, region] framing a character's head (from its first idle frame),
## for speech-bubble portraits. [] if the sheet has no idle animation.
static func head(sheet: String) -> Array:
	if _heads.has(sheet):
		return _heads[sheet]
	var out := []
	if ResourceLoader.exists("res://art/sprites/%s.png" % sheet):
		var sf := frames(sheet)
		if sf.has_animation("idle"):
			var at := sf.get_frame_texture("idle", 0) as AtlasTexture
			var img := at.atlas.get_image()
			var top := 0
			if img:
				if img.is_compressed():
					img.decompress()
				var reg := Rect2i(at.region)
				var found := false
				for y in reg.size.y:
					for x in reg.size.x:
						if img.get_pixel(reg.position.x + x, reg.position.y + y).a > 0.5:
							found = true
							break
					if found:
						top = y
						break
			var k := 1.0 / art_scale(sheet)
			out = [at.atlas, Rect2(at.region.position + Vector2(13 * k, maxf(top - k, 0)), Vector2(22, 22) * k)]
	_heads[sheet] = out
	return out


static func frames(sheet: String) -> SpriteFrames:
	if _frames.has(sheet):
		return _frames[sheet]
	if _layouts.is_empty():
		_layouts = _json("res://data/sprites.json").sheets
	var lay: Dictionary = _layouts[sheet]
	var tex: Texture2D = load("res://art/sprites/%s.png" % sheet)
	var fw: int = lay.frame[0]
	var fh: int = lay.frame[1]
	var hires := "res://art/sprites/%s@2x.png" % sheet
	if hires_on() and ResourceLoader.exists(hires):
		tex = load(hires)
		fw *= 2
		fh *= 2
		_scales[sheet] = 0.5
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for row in lay.anims.size():
		var a: Dictionary = lay.anims[row]
		sf.add_animation(a.name)
		sf.set_animation_speed(a.name, a.fps)
		sf.set_animation_loop(a.name, a.loop)
		for i in int(a.frames):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, row * fh, fw, fh)
			sf.add_frame(a.name, at)
	_frames[sheet] = sf
	return sf


static func frame_size(sheet: String) -> Vector2:
	frames(sheet)
	var f: Array = _layouts[sheet].frame
	return Vector2(f[0], f[1])


static func prop(name: String) -> Texture2D:
	if _props.has(name):
		return _props[name]
	if _regions.is_empty():
		_regions = _json("res://data/props.json")
	var r: Array = _regions[name]
	var at := AtlasTexture.new()
	at.atlas = load("res://art/sprites/props.png")
	at.region = Rect2(r[0], r[1], r[2], r[3])
	_props[name] = at
	return at


## TileSet with one "ground" terrain (match sides) from art/tiles/<area>.png.
## The atlas is 4x4 tiles; tile (mask % 4, mask / 4) has a neighbour on
## the top/right/bottom/left side when mask bit 1/2/4/8 is set.
static func terrain_tileset(area: String) -> TileSet:
	if _tilesets.has(area):
		return _tilesets[area]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	ts.add_terrain(0)
	ts.set_terrain_name(0, 0, "ground")
	var src := TileSetAtlasSource.new()
	src.texture = load("res://art/tiles/%s.png" % area)
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	var sides := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]
	for mask in 16:
		var c := Vector2i(mask % 4, mask / 4)
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.terrain_set = 0
		td.terrain = 0
		for b in 4:
			td.set_terrain_peering_bit(sides[b], 0 if mask & (1 << b) else -1)
	_tilesets[area] = ts
	return ts


static func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
