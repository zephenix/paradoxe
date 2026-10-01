shader_type canvas_item;
// Brume au ras du sol (essai graphique) : une nappe qui s'épaissit vers le bas,
// faite de volutes qui dérivent lentement. Les volutes viennent d'un bruit
// « fractal » : plusieurs couches de bruit, chacune deux fois plus fine.

uniform vec4 fog_color : source_color = vec4(0.5, 0.62, 0.66, 0.35);
uniform vec2 world_size = vec2(1280.0, 160.0);
uniform float drift = 8.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return total;
}

void fragment() {
	vec2 p = UV * world_size / vec2(220.0, 70.0);
	float wisps = fbm(p + vec2(TIME * drift / 220.0, 0.0)) * 0.7 + fbm(p * 0.5 - vec2(TIME * drift / 500.0, 0.0)) * 0.6;
	float depth = smoothstep(0.0, 1.0, UV.y);
	COLOR = vec4(fog_color.rgb, fog_color.a * depth * clamp(wisps, 0.0, 1.0));
}
