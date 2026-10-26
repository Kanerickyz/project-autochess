shader_type canvas_item;
render_mode unshaded;

uniform sampler2D bg_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 pointer_offset = vec2(0.0);
uniform float scroll_speed = 0.11;
uniform float grid_scale = 28.0;
uniform float grid_strength = 0.38;
uniform float grid_line_width = 0.055;

// 右上 → 左下（持续漂移）
const vec2 SCROLL_DIR = vec2(-1.0, 1.0);

float line_mask(float coord, float width) {
	float f = fract(coord);
	float d = min(f, 1.0 - f);
	return 1.0 - smoothstep(0.0, width, d);
}

float plaid_grid(vec2 uv, float width) {
	float h = line_mask(uv.x, width);
	float v = line_mask(uv.y, width);
	float d1 = line_mask(uv.x + uv.y, width * 0.85);
	float d2 = line_mask(uv.x - uv.y, width * 0.85);
	float ortho = max(h, v);
	float diag = max(d1, d2) * 0.65;
	return clamp(max(ortho, diag), 0.0, 1.0);
}

void fragment() {
	vec2 dir = normalize(SCROLL_DIR);
	vec2 scroll = dir * TIME * scroll_speed;
	vec2 parallax = pointer_offset * 0.018;

	vec2 bg_uv = UV + scroll * 0.22 + parallax;
	vec4 base = texture(bg_texture, bg_uv);

	vec2 grid_uv = UV * grid_scale + scroll * grid_scale;
	float grid = plaid_grid(grid_uv, grid_line_width);
	vec2 grid_uv2 = grid_uv * 0.55 + vec2(7.0, 3.0) + scroll * grid_scale * 0.35;
	grid = max(grid, plaid_grid(grid_uv2, grid_line_width * 1.15) * 0.55);

	vec3 paper = vec3(0.92, 0.82, 0.62);
	vec3 ink = vec3(0.12, 0.1, 0.14);
	vec3 grid_col = mix(paper, ink, grid);
	vec3 col = mix(base.rgb, grid_col, grid_strength * grid);

	// 轻暗角，保证中央 Logo 区对比
	vec2 c = UV - vec2(0.5);
	float vig = 1.0 - dot(c, c) * 0.55;
	col *= mix(0.72, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
