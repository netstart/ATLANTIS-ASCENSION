shader_type canvas_item;
// Superfície do Atlântico vista de cima (capítulo 1): gradiente de profundidade, cáusticas e cristas
// procedurais, sem texturas. `scroll` vem da simulação (unidades do campo), então a água anda junto
// com a fase. `shallow` (0..1) é o Ocean Shift: a água baixa e clareia quando as ruínas emergem.
// Compatível com o renderer Compatibility (GLES3).

uniform float scroll = 0.0;
uniform float shallow : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 2.0) = 2.0;
uniform vec2 view_size = vec2(305.0, 678.0);
uniform vec4 deep : source_color = vec4(0.024, 0.071, 0.165, 1.0);
uniform vec4 mid : source_color = vec4(0.043, 0.157, 0.302, 1.0);
uniform vec4 shoal : source_color = vec4(0.051, 0.235, 0.290, 1.0);
uniform vec4 foam : source_color = vec4(0.700, 0.950, 1.000, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Cáustica: rede de linhas finas a partir de dois ruídos defasados.
float caustic(vec2 p, float t) {
	float a = noise(p + vec2(t * 0.11, t * 0.07));
	float b = noise(p * 1.7 - vec2(t * 0.05, t * 0.13));
	return pow(1.0 - abs(a - b), 14.0);
}

void fragment() {
	vec2 world = UV * view_size;
	world.y -= scroll;
	float t = TIME;
	float depth = 0.5 + 0.5 * noise(world * 0.006);
	vec3 col = mix(deep.rgb, mid.rgb, depth * 0.8);
	col = mix(col, shoal.rgb, shallow * (0.45 + 0.35 * depth));
	if (detail > 0.5) {
		float c = caustic(world * 0.035, t);
		col += foam.rgb * c * (0.05 + 0.06 * shallow);
	}
	if (detail > 1.5) {
		float crest = smoothstep(0.82, 0.97, noise(vec2(world.x * 0.05, world.y * 0.012 + t * 0.2)));
		col = mix(col, foam.rgb, crest * 0.08);
	}
	// Pixel art: quantiza um pouco a cor para casar com os sprites.
	col = floor(col * 48.0) / 48.0;
	COLOR = vec4(col, 1.0);
}
