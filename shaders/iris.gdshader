// Iris wipe: everything outside a circle goes black. radius in pixels.
shader_type canvas_item;
uniform vec2 center = vec2(240.0, 135.0);
uniform float radius = 600.0;
uniform vec2 screen = vec2(480.0, 270.0);

void fragment() {
	vec2 p = UV * screen;
	float d = distance(floor(p), center);
	COLOR = vec4(0.06, 0.03, 0.02, d > radius ? 1.0 : 0.0);
	// a thin gold ring at the edge
	if (d > radius - 1.5 && d <= radius && radius > 2.0) COLOR = vec4(0.94, 0.78, 0.28, 1.0);
}
