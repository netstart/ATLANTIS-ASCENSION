shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// Feixe inimigo (scripts/view/hostile_beams.gd): um quad por feixe, girado na direção dele. UV.x atravessa o feixe,
// UV.y vai da boca do emissor (0) até além da borda do campo (1). Irmão do Laser do jogador
// (shaders/energy_stream.gdshader), em vermelho e magenta hostis: núcleo branco-quente, corpo na cor, halo macio e
// ondas que correm da boca para fora, com cintilação leve (shimmer 0,35 com "menos clarões").
// Alfa pré-multiplicado: a cor soma luz e o alfa escurece um pouco o fundo em volta do corpo, um contorno escuro que
// separa o feixe de céu claro, espuma ou nuvem sem precisar de outro quad.

uniform vec3 core_color : source_color = vec3(1.0, 0.97, 0.95);
uniform vec3 body_color : source_color = vec3(1.0, 0.2, 0.42);
uniform vec3 halo_color : source_color = vec3(0.85, 0.05, 0.6);
// Comprimento e largura do quad em unidades do campo.
uniform float length_u = 400.0;
uniform float width_u = 60.0;
// Núcleo e corpo em fração da meia-largura do quad (o corpo é a largura que fere).
uniform float core_w = 0.09;
uniform float body_w = 0.22;
// 0..1: abre e fecha o feixe (rampa curta, sem estalo).
uniform float intensity = 1.0;
uniform float halo = 0.42;
uniform float shade = 0.32;
uniform float shimmer = 1.0;
uniform float seed = 0.0;
uniform float t = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

void fragment() {
	// d: distância da boca, em unidades; x: -1..1 através do feixe.
	float d = UV.y * length_u;
	float x = UV.x * 2.0 - 1.0;
	float flow = d - t * 300.0;
	// Bordas que ondulam devagar e boca que nasce estreita e abre em poucas unidades.
	x += (noise(vec2(flow * 0.025, seed)) - 0.5) * 0.06 * shimmer;
	float open = mix(0.4, 1.0, smoothstep(0.0, 14.0, d)) * mix(0.55, 1.0, intensity);
	float ax = abs(x) / open;
	float core = exp(-pow(ax / core_w, 2.0));
	float body = exp(-pow(ax / body_w, 2.0));
	float glow = exp(-pow(ax / 0.55, 2.0)) * (1.0 - smoothstep(0.78, 1.0, abs(x)));
	float bands = noise(vec2(x * 3.0 + seed, flow * 0.05)) * 0.6 + noise(vec2(x * 6.0 + 7.0, flow * 0.12)) * 0.4;
	float streaks = mix(1.0, 0.6 + 0.8 * bands, 0.7 * shimmer);
	// Pulso que corre para fora ao longo do feixe e uma cintilação suave do todo.
	float pulse = 1.0 + shimmer * (0.16 * sin(d * 0.07 - t * 20.0) + 0.05 * sin(t * 47.0 + seed * 3.0));
	float along = smoothstep(0.0, 3.0, d) * smoothstep(0.0, 18.0, length_u - d);
	vec3 col = halo_color * glow * halo * pulse
			+ body_color * body * 0.95 * streaks * pulse
			+ core_color * core * (0.92 + 0.12 * bands * shimmer);
	float k = intensity * along;
	float dark = shade * exp(-pow(ax / (body_w * 2.1), 2.0)) * k;
	COLOR = vec4(col * k, dark);
}
