// A light CRT look: faint dark scanlines every other screen pixel row,
// plus a soft darkening toward the corners. Toggle in Settings > SCANLINES.
shader_type canvas_item;

uniform float line_strength = 0.13;
uniform float vignette = 0.22;

void fragment() {
	float row = mod(floor(FRAGCOORD.y / max(1.0, floor(1.0 / SCREEN_PIXEL_SIZE.y / 270.0))), 2.0);
	float d = distance(SCREEN_UV, vec2(0.5));
	float v = smoothstep(0.45, 0.85, d) * vignette;
	COLOR = vec4(0.0, 0.0, 0.0, row * line_strength + v);
}
