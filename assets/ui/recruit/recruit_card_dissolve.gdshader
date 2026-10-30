shader_type canvas_item;
render_mode unshaded, blend_mix;

// progress 0 = full card; 1 = fully dissolved (noise threshold, not whole-card alpha).
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float burn_width : hint_range(0.01, 0.45) = 0.12;
uniform float noise_scale = 11.0;
uniform float corner = 0.08;
uniform vec4 fill_color : source_color = vec4(0.93, 0.86, 0.68, 0.94);
uniform vec4 fill_inner : source_color = vec4(0.97, 0.92, 0.78, 0.55);
uniform vec4 stroke_color : source_color = vec4(0.38, 0.24, 0.12, 0.96);
uniform vec4 burn_color : source_color = vec4(1.0, 0.52, 0.14, 1.0);


float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}


float rounded_box_sdf(vec2 uv, float r) {
	vec2 p = abs(uv - vec2(0.5)) * 2.0;
	float rr = max(r, 0.001);
	vec2 q = p - (1.0 - rr);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - rr;
}


void fragment() {
	if (progress >= 0.999) {
		discard;
	}

	float sdf = rounded_box_sdf(UV, corner);
	float shape = 1.0 - smoothstep(0.0, 0.03, sdf);
	if (shape <= 0.001) {
		discard;
	}

	float n = value_noise(UV * noise_scale);
	n = n * 0.78 + value_noise(UV * noise_scale * 2.17 + vec2(3.1, 1.7)) * 0.22;

	float threshold = progress * (1.0 + burn_width);
	if (n < threshold - burn_width) {
		discard;
	}
	float edge = 1.0 - smoothstep(threshold - burn_width, threshold, n);

	float inset = 0.055;
	float inner_sdf = rounded_box_sdf(UV, max(0.02, corner - 0.02));
	float inner = (1.0 - smoothstep(0.0, 0.04, inner_sdf)) * shape;
	vec2 from_edge = abs(UV - vec2(0.5));
	inner *= step(from_edge.x, 0.5 - inset) * step(from_edge.y, 0.5 - inset);

	vec4 col = fill_color;
	col = mix(col, fill_inner, inner * 0.65);
	float stroke = (1.0 - smoothstep(0.0, 0.035, abs(sdf))) * shape;
	col = mix(col, stroke_color, stroke * 0.85);
	col.rgb = mix(col.rgb, burn_color.rgb, edge * burn_color.a);
	col.a *= shape;

	COLOR = col;
}
