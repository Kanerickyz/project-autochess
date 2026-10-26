shader_type canvas_item;
render_mode unshaded;

uniform vec2 scroll_offset = vec2(0.0);
uniform vec2 pointer_offset = vec2(0.0);
uniform float checker_cells = 14.0;
uniform float viewport_aspect = 1.0;
uniform float grid_rotation = -0.22;
uniform vec3 color_dark_a = vec3(0.07, 0.08, 0.11);
uniform vec3 color_dark_b = vec3(0.13, 0.11, 0.15);

vec2 rotate_grid(vec2 p, float angle, vec2 pivot) {
	float c = cos(angle);
	float s = sin(angle);
	vec2 d = p - pivot;
	return vec2(c * d.x - s * d.y, s * d.x + c * d.y) + pivot;
}

void fragment() {
	vec2 parallax = pointer_offset * 0.012;

	vec2 pivot = vec2(viewport_aspect * 0.5, 0.5) * checker_cells;
	vec2 base = vec2(UV.x * viewport_aspect, UV.y) * checker_cells + scroll_offset + parallax;
	vec2 p = rotate_grid(base, grid_rotation, pivot);

	ivec2 cell = ivec2(floor(p));
	float checker = float((cell.x + cell.y) & 1);
	vec3 col = mix(color_dark_a, color_dark_b, checker);

	vec2 c = UV - vec2(0.5);
	float vig = 1.0 - dot(c, c) * 0.45;
	col *= mix(0.78, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
