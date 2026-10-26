shader_type canvas_item;
render_mode unshaded;

uniform vec2 pointer_offset = vec2(0.0);
uniform float scroll_speed = 0.038;
uniform float checker_cells = 14.0;
uniform vec3 color_dark_a = vec3(0.07, 0.08, 0.11);
uniform vec3 color_dark_b = vec3(0.13, 0.11, 0.15);

// 右上 → 左下
const vec2 SCROLL_DIR = vec2(-1.0, 1.0);

void fragment() {
	vec2 dir = normalize(SCROLL_DIR);
	vec2 scroll = dir * TIME * scroll_speed;
	vec2 parallax = pointer_offset * 0.012;

	vec2 p = UV * checker_cells + scroll + parallax;
	ivec2 cell = ivec2(floor(p));
	float checker = float((cell.x + cell.y) & 1);
	vec3 col = mix(color_dark_a, color_dark_b, checker);

	vec2 c = UV - vec2(0.5);
	float vig = 1.0 - dot(c, c) * 0.45;
	col *= mix(0.78, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
