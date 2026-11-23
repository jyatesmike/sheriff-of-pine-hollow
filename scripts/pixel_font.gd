# PixelFont: the 3x5 bitmap font from the browser version, drawn with rects.
# Crisp at any integer scale; used for signs and HUD text until a
# proper pixel-font resource lands in milestone 3.
class_name PixelFont
extends RefCounted

const OUTLINE := Color("24140e")
# Each glyph: 5 rows, 3 bits per row (bit 2 = left column).
const GLYPHS := {
	"A": [2,5,7,5,5], "B": [6,5,6,5,6], "C": [3,4,4,4,3], "D": [6,5,5,5,6], "E": [7,4,6,4,7],
	"F": [7,4,6,4,4], "G": [3,4,5,5,3], "H": [5,5,7,5,5], "I": [7,2,2,2,7], "J": [1,1,1,5,2],
	"K": [5,5,6,5,5], "L": [4,4,4,4,7], "M": [5,7,7,5,5], "N": [6,5,5,5,5], "O": [2,5,5,5,2],
	"P": [6,5,6,4,4], "Q": [2,5,5,6,3], "R": [6,5,6,5,5], "S": [3,4,2,1,6], "T": [7,2,2,2,2],
	"U": [5,5,5,5,7], "V": [5,5,5,5,2], "W": [5,5,5,7,5], "X": [5,5,2,5,5], "Y": [5,5,2,2,2],
	"Z": [7,1,2,4,7], "&": [2,5,2,5,3], ".": [0,0,0,0,2], "!": [2,2,2,0,2], "'": [2,2,0,0,0], "\"": [5,5,0,0,0], "·": [0,0,2,0,0],
	" ": [0,0,0,0,0], ":": [0,2,0,2,0], "-": [0,0,7,0,0], "/": [1,1,2,4,4], ",": [0,0,0,2,4],
	"?": [6,1,2,0,2], "(": [1,2,2,2,1], ")": [4,2,2,2,4], "+": [0,2,7,2,0], "=": [0,7,0,7,0],
	"0": [7,5,5,5,7], "1": [2,6,2,2,7], "2": [6,1,2,4,7], "3": [6,1,2,1,6], "4": [5,5,7,1,1],
	"5": [7,4,6,1,6], "6": [3,4,7,5,7], "7": [7,1,1,2,2], "8": [7,5,7,5,7], "9": [7,5,7,1,6],
}


static func width(text: String, scale := 1) -> int:
	return maxi(0, text.length() * 4 - 1) * scale


## Draw text (upper-cased) at pos with a 1-px drop shadow in the outline colour.
static func draw(ci: CanvasItem, text: String, pos: Vector2, color: Color, scale := 1, shadow := true) -> void:
	text = text.to_upper()
	if shadow:
		_draw_raw(ci, text, pos + Vector2(scale, scale), OUTLINE, scale)
	_draw_raw(ci, text, pos, color, scale)


static func draw_centered(ci: CanvasItem, text: String, center_x: float, y: float, color: Color, scale := 1) -> void:
	draw(ci, text, Vector2(roundf(center_x - width(text, scale) / 2.0), y), color, scale)


static func _draw_raw(ci: CanvasItem, text: String, pos: Vector2, color: Color, scale: int) -> void:
	var x := pos.x
	for ch in text:
		var g: Array = GLYPHS.get(ch, GLYPHS["?"])
		for r in 5:
			for b in 3:
				if int(g[r]) & (4 >> b):
					ci.draw_rect(Rect2(x + b * scale, pos.y + r * scale, scale, scale), color)
		x += 4 * scale
