// Transmissão dos retratos (Portraits, 1.15.1). Código próprio do projeto (MIT). Inspirado na ideia de
// efeitos públicos de holograma, VHS, aura e dissolução, sem copiar código de nenhum deles.
// Três modos, um por tipo de voz:
//   0 rádio (Maré, Farol, Duarte): linhas de varredura que rolam, cintilação e grão leves, faixa de
//     zumbido descendo devagar e um brilho ciano tênue na borda;
//   1 etéreo (Thalassa): a imagem ondula como vista através da água, cáusticas suaves passam sobre a
//     figura, os pontos mais claros (olhos, glifo) pulsam e uma aura violeta respira nas bordas;
//   2 glitch (Leviathan Protocol): separação RGB puxada para o vermelho, rajadas de fatias deslocadas,
//     varredura mais marcada e a lente vermelha com brilho pulsante.
// `tune` (1 -> 0 em ~0,35 s, animado por Portraits.tune_in) é a sintonia de cada fala nova: aberração
// cromática forte, faixas horizontais deslocadas e a imagem entrando de cima para baixo em pixels, com
// chiado no lugar do que ainda não chegou. `still` (reduzir movimento ou reduzir flashes) congela tudo:
// sobram só as linhas de varredura paradas e o brilho da borda, sem nada piscando.
// Custo: até 5 leituras de textura por pixel num retrato de no máximo ~128 px; não lê a tela.
shader_type canvas_item;

uniform int mode : hint_range(0, 2) = 0;
// Linhas de varredura na altura do retrato (Portraits escolhe pelo tamanho: ~8 na HUD, mais na história).
uniform float lines = 24.0;
uniform float tune : hint_range(0.0, 1.0) = 0.0;
uniform bool still = false;
uniform vec4 tint : source_color = vec4(0.56, 0.91, 1.0, 1.0);
// Glitch: rajadas por segundo e fração de cada ciclo em que a rajada dura.
uniform float glitch_rate = 0.85;
uniform float glitch_length : hint_range(0.0, 1.0) = 0.22;
// Centro da lente do Protocolo em UV (70,5 x 43,5 no retrato de 96 px).
uniform vec2 lens = vec2(0.734, 0.453);
// Desfasa o ruído entre retratos na tela.
uniform float seed = 0.0;

// Cor de vértice (inclui o modulate da árvore: o retrato some e surge junto com a moldura).
varying vec4 tint_vertex;

void vertex() {
	tint_vertex = COLOR;
}

float hash(float n) {
	return fract(sin(n * 12.9898 + seed * 7.13) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 3.7) * 43758.5453);
}

void fragment() {
	float t = still ? 0.0 : TIME;
	float tn = still ? 0.0 : tune;
	vec2 uv = UV;
	// Sintonia: faixas horizontais deslocadas, mais fortes no começo.
	if (tn > 0.0) {
		float band = floor(uv.y * 14.0);
		uv.x += (hash(band + floor(t * 40.0)) - 0.5) * 0.22 * tn * tn;
	}
	float burst = 0.0;
	if (!still) {
		if (mode == 1) {
			uv.x += sin(uv.y * 17.0 + t * 2.1) * 0.006;
			uv.y += sin(uv.x * 13.0 + t * 1.6) * 0.004;
		} else if (mode == 2) {
			float slot = floor(t * glitch_rate);
			burst = step(fract(t * glitch_rate), glitch_length) * step(0.3, hash(slot));
			float block = floor(uv.y * 9.0 + hash(slot * 1.7) * 4.0);
			uv.x += (hash(block + slot * 7.0) - 0.5) * 0.16 * burst * step(0.5, hash(block * 3.1 + slot));
		}
	}
	float split = tn * 0.035 + burst * 0.025 + (mode == 2 ? 0.006 : 0.002) * (still ? 0.0 : 1.0);
	vec4 c = texture(TEXTURE, uv);
	vec3 col = c.rgb;
	if (split > 0.0) {
		col.r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
		col.b = texture(TEXTURE, uv - vec2(split * (mode == 2 ? 0.4 : 1.0), 0.0)).b;
	}
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	// Linhas de varredura (rolam devagar fora do modo parado).
	float scan = 0.5 + 0.5 * sin((UV.y * lines + t * 1.5) * 6.2831853);
	float depth = mode == 2 ? 0.30 : 0.17;
	col *= 1.0 - depth * (1.0 - scan);
	// Borda: luz da cor da fala por dentro do quadro.
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float rim = smoothstep(0.09, 0.0, edge);
	if (!still) {
		float frame_t = floor(t * 24.0);
		col *= 1.0 + (hash(frame_t) - 0.5) * (mode == 2 ? 0.10 : 0.05);
		col += (hash2(floor(UV * 96.0) + frame_t) - 0.5) * 0.06;
		float hum = fract(UV.y - t * 0.14);
		col += tint.rgb * smoothstep(0.08, 0.0, abs(hum - 0.5)) * 0.05;
	}
	if (mode == 1) {
		float pulse = still ? 0.5 : 0.5 + 0.5 * sin(t * 2.4);
		if (!still) {
			vec2 p = UV * 7.0;
			float k = sin(p.x * 1.9 + t * 0.9 + sin(p.y * 1.3 + t * 0.6) * 1.6)
					* sin(p.y * 2.3 - t * 0.7 + sin(p.x * 1.1 - t * 0.5) * 1.4);
			col += vec3(0.55, 0.85, 1.0) * pow(abs(k), 5.0) * 0.22 * smoothstep(0.2, 0.6, luma);
		}
		col += vec3(0.85, 0.65, 1.0) * smoothstep(0.72, 0.95, luma) * (0.15 + 0.3 * pulse);
		col += tint.rgb * rim * (0.35 + 0.35 * pulse);
	} else if (mode == 2) {
		float pulse = still ? 0.5 : 0.5 + 0.5 * sin(t * 5.0);
		float d = distance(UV, lens);
		col += vec3(1.0, 0.16, 0.14) * smoothstep(0.14, 0.0, d) * (0.18 + 0.32 * pulse);
		col += vec3(1.0, 0.25, 0.25) * rim * 0.3;
		col = mix(col, col * vec3(1.25, 0.85, 0.85), burst * 0.6);
	} else {
		col += tint.rgb * rim * 0.22;
	}
	// Sintonia: a imagem entra de cima para baixo em pixels; o que falta é chiado.
	if (tn > 0.0) {
		float cell = hash2(floor(UV * 32.0));
		float shown = step(cell * 0.6 + UV.y * 0.55, 1.15 * (1.0 - tn));
		vec3 snow = vec3(hash2(floor(UV * 48.0) + floor(t * 30.0))) * 0.55 + tint.rgb * 0.15;
		col = mix(snow, col, shown);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), c.a) * tint_vertex;
}
