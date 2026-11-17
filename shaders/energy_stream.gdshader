shader_type canvas_item;
render_mode blend_add, unshaded;
// Fluxo de energia que sai do bico da nave (scripts/view/energy_stream.gd): o Laser e o fluxo do
// Mergulho Solar. Um quad só: UV.x atravessa o feixe, UV.y vai do topo (0) ao bico (1). O perfil é
// gaussiano (núcleo claro, corpo na cor, halo que some até zero na borda do quad, sem aresta), nasce
// estreito no bico e abre em poucas unidades, apaga macio na ponta e tem faixas de ruído subindo.
// Luz aditiva: só soma, e o halo é fraco para as balas inimigas (desenhadas por cima) continuarem legíveis.

uniform vec3 core_color : source_color = vec3(1.0);
uniform vec3 body_color : source_color = vec3(0.45, 0.95, 1.0);
uniform vec3 halo_color : source_color = vec3(0.2, 0.6, 1.0);
// Comprimento e largura do quad em unidades do campo (escala das faixas e do afunilamento).
uniform float length_u = 100.0;
uniform float width_u = 40.0;
// Largura do núcleo e do corpo em fração da meia-largura do quad.
uniform float core_w = 0.12;
uniform float body_w = 0.32;
uniform float intensity = 1.0;
uniform float halo = 0.28;
// Unidades em que o feixe abre a partir do bico e em que apaga na ponta.
uniform float root_u = 14.0;
uniform float tip_u = 10.0;
// Velocidade das faixas (unidades/s) e força da cintilação (0 com "menos clarões").
uniform float flow_speed = 360.0;
uniform float shimmer = 1.0;
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
	// d: distância ao bico, em unidades; x: -1..1 através do feixe.
	float d = (1.0 - UV.y) * length_u;
	float x = UV.x * 2.0 - 1.0;
	float flow = d - t * flow_speed;
	// As bordas ondulam devagar; no bico o feixe nasce fino e abre (sem corte reto).
	x += (noise(vec2(flow * 0.03, 3.0)) - 0.5) * 0.05 * shimmer;
	float open = mix(0.28, 1.0, smoothstep(0.0, root_u, d));
	float ax = abs(x) / open;
	float core = exp(-pow(ax / core_w, 2.0));
	float body = exp(-pow(ax / body_w, 2.0));
	float glow = exp(-pow(ax / 0.62, 2.0)) * (1.0 - smoothstep(0.75, 1.0, abs(x)));
	// Faixas que sobem: ruído alongado no sentido do fluxo, mais forte no corpo que no núcleo.
	float bands = noise(vec2(x * 2.5, flow * 0.06)) * 0.6 + noise(vec2(x * 5.0 + 7.0, flow * 0.13)) * 0.4;
	float streaks = mix(1.0, 0.55 + 0.9 * bands, 0.75 * shimmer);
	float pulse = 1.0 + 0.08 * shimmer * sin(t * 31.0 + d * 0.02);
	// Entra no bico (sem degrau) e apaga na ponta.
	float along = smoothstep(-1.0, 3.0, d) * smoothstep(0.0, tip_u, length_u - d);
	vec3 col = halo_color * glow * halo
			+ body_color * body * 0.75 * streaks
			+ core_color * core * (0.85 + 0.15 * bands * shimmer);
	COLOR = vec4(col * intensity * pulse * along, 1.0);
}
