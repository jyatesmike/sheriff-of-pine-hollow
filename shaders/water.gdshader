// Water surface: mirrors whatever is drawn above the waterline (sky, set
// pieces, the Sheriff), wobbles it with ripples and fades into deep colour.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 shallow : source_color = vec4(0.24, 0.48, 0.72, 1.0);
uniform vec4 deep : source_color = vec4(0.09, 0.22, 0.38, 1.0);
uniform vec4 foam : source_color = vec4(0.78, 0.9, 1.0, 1.0);
uniform float height_px = 40.0;       // height of this rect in pixels
uniform float reflect_px = 48.0;      // how far down the reflection reaches
uniform float strength = 0.55;
uniform float width_px = 100.0;
uniform float world_x = 0.0;          // left edge in world space (keeps ripples still while scrolling)

void fragment() {
	float d = UV.y * height_px;                         // pixels below the surface
	float wx = floor(world_x + UV.x * width_px);
	d = floor(d);
	float wob = floor(sin(d * 0.9 - TIME * 3.0 + wx * 0.05) * (0.6 + d * 0.04) + 0.5);
	vec2 ruv = SCREEN_UV;
	ruv.y -= 2.0 * d * SCREEN_PIXEL_SIZE.y + SCREEN_PIXEL_SIZE.y;
	ruv.x += wob * SCREEN_PIXEL_SIZE.x;
	vec3 refl = texture(screen_tex, ruv).rgb;
	float k = clamp(d / reflect_px, 0.0, 1.0);
	vec3 base = mix(shallow.rgb, deep.rgb, clamp(d / max(height_px, 1.0) * 1.6, 0.0, 1.0));
	vec3 col = mix(base, refl * vec3(0.7, 0.85, 1.0), strength * (1.0 - k));
	// glints: short bright dashes that drift
	float g = sin(wx * 0.35 + TIME * 1.7 + floor(d / 3.0) * 2.1);
	float g2 = sin(wx * 0.11 - TIME * 0.9 + floor(d / 3.0) * 5.3);
	if (g > 0.985 && g2 > 0.4 && d < reflect_px) col = mix(col, foam.rgb, 0.7);
	// bright lip at the surface
	if (d < 1.0) col = foam.rgb;
	else if (d < 2.0) col = mix(col, foam.rgb, 0.4);
	COLOR = vec4(col, 1.0);
}
