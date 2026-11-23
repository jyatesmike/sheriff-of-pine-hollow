# Turns a PixelLab character export into a game sprite sheet.
#
#   godot --headless -s tools/import_pixellab.gd -- <export folder> <sheet> [direction]
#   e.g.  godot --headless -s tools/import_pixellab.gd -- ~/Downloads/Sheriff sheriff
#
# <export folder> is the unzipped PixelLab download (the one with metadata.json).
# <sheet> is the character it replaces: sheriff, earl, dewey, deputy, aunt, ...
# [direction] is which way the art faces; the game mirrors it for the other way.
#   Default "east" (side view, facing right). "south-east" gives a 3/4 view.
#
# Every PixelLab animation whose name matches a game animation (see MATCH below)
# is used. Anything missing is faked from the idle pose with a little motion so
# the game still plays: add more PixelLab animations and run this again.
# The original built-in art is kept in art/sprites/generated/<sheet>.png.
extends SceneTree

const P := preload("res://tools/gen/pix.gd")
const Rig := preload("res://tools/gen/rig.gd")
const Poses := preload("res://tools/gen/poses.gd")
const Gen := preload("res://tools/gen/generate.gd")

## Game animation -> PixelLab animation names to look for (first match wins,
## matched as "contains", ignoring case, spaces and dashes).
const MATCH := {
	"idle": ["idle", "breathing"],
	"run": ["run", "sprint", "walk"],
	"jump": ["jump"],
	"fall": ["fall", "jump"],
	"land": ["land", "jump"],
	"skid": ["skid", "stop"],
	"throw": ["throw", "punch"],
	"hurt": ["hurt", "hit", "damage", "takepunch", "fallingback"],
	"victory": ["victory", "celebrate", "cheer", "dance"],
	"slide": ["slide", "crouch", "duck"],
	"tiphat": ["tiphat", "wave", "salute", "bow"],
	"taunt": ["taunt", "laugh", "wave"],
	"stunned": ["stun", "dizzy"],
	"cuffed": ["cuff", "sad", "defeat"],
	"aim": ["aim", "throw"],
	"fumble": ["fumble", "juggle"],
	"climb": ["climb", "ladder"],
	"climb_idle": ["climb", "ladder"],
}

var root_dir := ""
var direction := "east"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		printerr("usage: -- <pixellab export folder> <sheet> [direction]")
		quit(1)
		return
	root_dir = a[0].replace("~", OS.get_environment("HOME")).trim_suffix("/")
	var sheet: String = a[1]
	if a.size() > 2:
		direction = a[2]
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root_dir + "/metadata.json"))
	if meta == null:
		printerr("no metadata.json in ", root_dir)
		quit(1)
		return

	# collect every animation (and the idle rotation) for our direction
	var anims := {}          # pixellab name -> Array[Image]
	var base: Image = null
	for st in meta.get("states", [meta]):
		var folder: String = st.get("folder", "")
		var fr: Dictionary = st.get("frames", {})
		var rot: Dictionary = fr.get("rotations", {})
		if base == null and rot.has(direction):
			base = _load(rot[direction])
		var an: Dictionary = fr.get("animations", {})
		for name in an:
			var by_dir = an[name]
			var paths: Array = []
			if by_dir is Dictionary and by_dir.has(direction):
				paths = by_dir[direction]
			elif by_dir is Array:
				paths = by_dir
			var imgs: Array = []
			for p in paths:
				var im := _load(p)
				if im:
					imgs.append(im)
			if not imgs.is_empty():
				anims[_key(folder + name)] = imgs
				anims[_key(name)] = imgs
	if base == null and not anims.is_empty():
		base = anims.values()[0][0]
	if base == null:
		printerr("couldn't find any '%s' frames in the export" % direction)
		quit(1)
		return

	# one shared crop/scale for every frame, so feet and head line up
	var box := _bbox(base)
	for k in anims:
		for im in anims[k]:
			box = box.merge(_bbox(im))
	var cell := Vector2i(Rig.W, Rig.H)
	var scale := minf(float(cell.y) / box.size.y, float(cell.x) / box.size.x)
	var idle_h := float(_bbox(base).size.y)
	scale = minf(scale, (cell.y - 1.0) / idle_h)          # idle pose fills the frame height
	print("source box ", box, "  scale 1/%.2f" % (1.0 / scale))

	var sheet_img := P.img(Rig.W * Gen.COLS, Rig.H * Poses.ANIMS.size())
	var used := []
	for row in Poses.ANIMS.size():
		var game: String = Poses.ANIMS[row][0]
		var count: int = Poses.ANIMS[row][1]
		var src: Array = _find(anims, game)
		if not src.is_empty():
			used.append("%s <- pixellab" % game)
		for i in count:
			var frame: Image
			var nudge := Vector2i.ZERO
			if not src.is_empty():
				var j := i * src.size() / count
				if game == "jump":
					j = mini(src.size() / 3, src.size() - 1)
				elif game == "fall":
					j = mini(src.size() * 2 / 3, src.size() - 1)
				elif game == "land":
					j = src.size() - 1
				frame = src[clampi(j, 0, src.size() - 1)]
			else:
				frame = base
				nudge = _fake(game, i)
			var small := _shrink(frame, box, scale)
			var at := Vector2i(i * Rig.W + (Rig.W - small.get_width()) / 2, row * Rig.H + Rig.H - small.get_height()) + nudge
			sheet_img.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), at)
	var out := "res://art/sprites/%s.png" % sheet
	var keep := "res://art/sprites/generated/%s.png" % sheet
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/sprites/generated"))
	if FileAccess.file_exists(out) and not FileAccess.file_exists(keep):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(out), ProjectSettings.globalize_path(keep))
	sheet_img.save_png(ProjectSettings.globalize_path(out))
	print("wrote ", out)
	print("from PixelLab: ", used if not used.is_empty() else "idle pose only")
	print("faked from the idle pose: ", Poses.ANIMS.map(func(r): return r[0]).filter(func(n): return not used.has("%s <- pixellab" % n)))
	quit()


func _load(rel: String) -> Image:
	var path := root_dir + "/" + rel
	var im := Image.load_from_file(path)
	if im == null:
		printerr("missing ", path)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


static func _key(s: String) -> String:
	return s.to_lower().replace(" ", "").replace("-", "").replace("_", "")


func _find(anims: Dictionary, game: String) -> Array:
	for want in MATCH.get(game, [game]):
		for k in anims:
			if (k as String).contains(_key(want)):
				return anims[k]
	return []


static func _bbox(im: Image) -> Rect2i:
	return im.get_used_rect()


## Motion for rows PixelLab didn't supply, so the game is playable meanwhile.
static func _fake(game: String, i: int) -> Vector2i:
	match game:
		"run":
			return Vector2i(0, [0, -1, -2, -1, 0, -1, -2, -1][i % 8])
		"idle", "taunt", "victory":
			return Vector2i(0, -1 if i % 2 == 1 else 0)
		"hurt", "stunned", "fumble":
			return Vector2i(-1 if i % 2 == 0 else 1, 0)
		"climb":
			return Vector2i(0, -1 if i % 2 == 0 else 0)
	return Vector2i.ZERO


## Pixel-art downscale: each output pixel takes the most common colour of its
## block, and dark outline pixels win when they cover a fair share of it.
static func _shrink(im: Image, box: Rect2i, s: float) -> Image:
	var w := maxi(1, roundi(box.size.x * s))
	var h := maxi(1, roundi(box.size.y * s))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var step := 1.0 / s
	for y in h:
		for x in w:
			var x0 := box.position.x + int(x * step)
			var x1 := maxi(box.position.x + int((x + 1) * step), x0 + 1)
			var y0 := box.position.y + int(y * step)
			var y1 := maxi(box.position.y + int((y + 1) * step), y0 + 1)
			var total := 0
			var opaque := []
			var dark := []
			for yy in range(y0, mini(y1, im.get_height())):
				for xx in range(x0, mini(x1, im.get_width())):
					total += 1
					var c := im.get_pixel(xx, yy)
					if c.a > 0.5:
						opaque.append(c)
						if c.r + c.g + c.b < 0.47:
							dark.append(c)
			if total == 0 or opaque.size() < total * 0.4:
				continue
			if dark.size() >= opaque.size() * 0.34:
				out.set_pixel(x, y, _mode(dark))
			else:
				out.set_pixel(x, y, _mode(opaque))
	return out


static func _mode(cols: Array) -> Color:
	var bins := {}
	for c in cols:
		var k := Vector3i(int(c.r * 21.0), int(c.g * 21.0), int(c.b * 21.0))
		if not bins.has(k):
			bins[k] = []
		bins[k].append(c)
	var best: Array = []
	for k in bins:
		if bins[k].size() > best.size():
			best = bins[k]
	var sum := Vector3.ZERO
	for c in best:
		sum += Vector3(c.r, c.g, c.b)
	sum /= best.size()
	return Color(sum.x, sum.y, sum.z, 1.0)
