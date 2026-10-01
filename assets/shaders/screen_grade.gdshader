shader_type canvas_item;
// Finition de l'image (essai graphique) : bords de l'écran assombris (vignettage)
// et léger grain qui bouge, comme une pellicule. Ce rectangle est posé par-dessus
// le jeu : il ne fait qu'ajouter du noir plus ou moins transparent.

uniform float vignette = 0.4;
uniform float grain = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV - 0.5;
	float edge = smoothstep(0.35, 0.85, length(centered * vec2(1.0, 0.75)) * 1.4);
	float speckle = hash(floor(FRAGCOORD.xy / 2.0) + floor(TIME * 24.0)) * grain;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(edge * vignette + speckle, 0.0, 1.0));
}
