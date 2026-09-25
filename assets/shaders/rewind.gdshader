// Effet « temps figé / temps qui remonte » (J4), posé sur tout l'écran.
// strength = 0 : image normale ; 0,5 : temps figé (image désaturée) ;
// 1 : rembobinage (désaturée, teintée, lignes qui défilent, léger tremblement).
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	// Tremblement horizontal, comme une bande magnétique qu'on rembobine.
	uv.x += sin(uv.y * 90.0 + TIME * 25.0) * 0.0025 * strength * strength;
	vec3 color = texture(screen_texture, uv).rgb;
	float gray = dot(color, vec3(0.3, 0.59, 0.11));
	vec3 cold = vec3(gray) * vec3(0.78, 1.05, 1.02);
	color = mix(color, cold, clamp(strength * 1.4, 0.0, 1.0));
	// Lignes de balayage qui défilent vers le haut.
	float lines = 0.9 + 0.1 * sin(SCREEN_UV.y * 540.0 + TIME * 60.0);
	color *= mix(1.0, lines, strength);
	COLOR = vec4(color, 1.0);
}
