# Reflective water: a rectangle (top edge = waterline) drawn with
# shaders/water.gdshader. Drawn above actors so their reflections show.
# With "fancy effects" off it falls back to flat colour.
class_name Water
extends ColorRect

const SHADER := preload("res://shaders/water.gdshader")


static func make(parent: Node, r: Rect2, shallow := Color("3d7ab8"), deep := Color("163a62"), z := 4) -> Water:
	var w := Water.new()
	w.position = r.position
	w.size = r.size
	w.z_index = z
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.color = shallow
	if Lighting.enabled():
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("shallow", shallow)
		m.set_shader_parameter("deep", deep)
		m.set_shader_parameter("height_px", r.size.y)
		m.set_shader_parameter("width_px", r.size.x)
		m.set_shader_parameter("world_x", r.position.x)
		m.set_shader_parameter("reflect_px", minf(r.size.y, 56.0))
		w.material = m
	parent.add_child(w)
	return w
