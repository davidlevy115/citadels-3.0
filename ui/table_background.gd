# Animated arcane-nebula table background (full-screen shader) with vignette.
class_name TableBackground
extends ColorRect

const SHADER_CODE := "
shader_type canvas_item;

uniform vec3 tint_a : source_color = vec3(0.06, 0.045, 0.11);
uniform vec3 tint_b : source_color = vec3(0.13, 0.07, 0.20);
uniform vec3 glow : source_color = vec3(0.45, 0.30, 0.75);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(13.7, 7.3);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv * 3.0;
	float t = TIME * 0.05;
	float n = fbm(p + vec2(t, -t * 0.6) + fbm(p * 1.6 - t));
	vec3 col = mix(tint_a, tint_b, n);
	// drifting arcane glow blobs
	float g1 = exp(-6.0 * length(uv - vec2(0.25 + 0.05 * sin(TIME * 0.21), 0.3)));
	float g2 = exp(-7.0 * length(uv - vec2(0.78 + 0.04 * cos(TIME * 0.17), 0.65)));
	col += glow * (g1 * 0.30 + g2 * 0.22) * (0.7 + 0.3 * sin(TIME * 0.5));
	// sparkle stars
	float star = step(0.9975, hash(floor(uv * vec2(220.0, 124.0))));
	col += vec3(0.8, 0.85, 1.0) * star * (0.4 + 0.4 * sin(TIME * 2.0 + uv.x * 40.0));
	// vignette
	float vig = smoothstep(1.05, 0.35, length(uv - 0.5) * 1.5);
	col *= mix(0.55, 1.0, vig);
	COLOR = vec4(col, 1.0);
}
"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var sm := ShaderMaterial.new()
	sm.shader = shader
	material = sm
