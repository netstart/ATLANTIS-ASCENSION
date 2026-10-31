// Fundo vivo dos menus (redesenho 1.6): o mar profundo de Atlântida em profundidade 2,5D.
// Gradiente de água, raios de luz que descem da superfície, cáusticas, três camadas de ruínas
// (longe, meio, perto) em parallax e neve marinha. Tudo procedural: nenhuma textura, um retângulo só.
// Roda num SubViewport na resolução lógica (≈ 0,2 MP), então custa pouco até em celular de entrada.
shader_type canvas_item;

uniform vec2 view_size = vec2(305.0, 678.0);
// Deslocamento de parallax (-1..1 por eixo): dedo, mouse ou acelerômetro.
uniform vec2 parallax = vec2(0.0);
// Rolagem vertical em pontos lógicos (o mapa da campanha move as camadas em velocidades diferentes).
uniform float scroll = 0.0;
uniform vec4 water_top : source_color = vec4(0.06, 0.24, 0.33, 1.0);
uniform vec4 water_deep : source_color = vec4(0.02, 0.043, 0.10, 1.0);
uniform vec4 accent : source_color = vec4(0.18, 0.95, 0.88, 1.0);
uniform float rays_strength : hint_range(0.0, 1.0) = 0.55;
uniform float ruins_strength : hint_range(0.0, 1.0) = 1.0;
// Tempo próprio (o nó para o relógio em "reduzir movimento" e quando a tela está oculta).
uniform float clock = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Ruína atlante numa célula do terraço. fx: 0..1 na largura da célula; hy: altura acima do chão em
// larguras de célula (negativo = dentro do leito). Devolve (silhueta, luz das runas).
vec2 ruin(vec2 c, float fx, float hy, float seed, float density) {
	if (hy < 0.0) {
		return vec2(1.0, 0.0);
	}
	if (hash(c + seed) > density) {
		return vec2(0.0);
	}
	float kind = hash(c + seed + 8.8);
	float solid = 0.0;
	float glow = 0.0;
	if (kind < 0.45) {
		// Colunata: colunas de alturas quebradas, capitéis, base e um trecho de arquitrave.
		float n = floor(3.0 + 2.0 * hash(c + seed + 5.5));
		float ci = floor(fx * n);
		float col = fract(fx * n);
		float broken = hash(c + seed + ci * 1.7);
		float top = broken > 0.35 ? 1.15 : 0.35 + broken * 1.6;
		float pillar = step(0.3, col) * step(col, 0.7) * step(hy, top);
		float capital = step(0.16, col) * step(col, 0.84) * step(abs(hy - top), 0.035);
		float beam = step(fx, hash(c + seed + 3.1)) * step(1.15, hy) * step(hy, 1.25);
		float base = step(hy, 0.06);
		solid = clamp(pillar + capital + beam + base, 0.0, 1.0);
		glow = capital * step(0.75, broken);
	} else if (kind < 0.75) {
		// Pirâmide em degraus com porta acesa.
		float level = floor(hy / 0.16);
		float half_w = 0.46 - level * 0.07;
		solid = step(abs(fx - 0.5), half_w) * step(hy, 0.96);
		float door = step(abs(fx - 0.5), 0.05) * step(hy, 0.14);
		glow = door;
		solid *= 1.0 - door;
	} else {
		// Torre com cúpula, agulha e janelas em fita.
		float body = step(abs(fx - 0.5), 0.15) * step(hy, 1.05);
		float dome = step(length(vec2(fx - 0.5, (hy - 1.05) * 0.9)), 0.15);
		float spire = step(abs(fx - 0.5), 0.015) * step(hy, 1.42);
		solid = clamp(body + dome + spire, 0.0, 1.0);
		float row = fract(hy * 6.0);
		glow = body * step(abs(fx - 0.5), 0.08) * step(0.4, row) * step(row, 0.62) * step(0.15, hy);
		solid *= 1.0 - glow;
	}
	return vec2(solid, glow);
}

float snow(vec2 px, float cell, float speed, float seed, float t) {
	vec2 p = px / cell;
	p.y -= t * speed;
	p.x += sin(p.y * 0.7 + seed) * 0.15;
	vec2 c = floor(p);
	vec2 f = fract(p);
	float h = hash(c + seed);
	vec2 at = vec2(hash(c + seed + 4.1), hash(c + seed + 7.3)) * 0.8 + 0.1;
	float d = length((f - at) * cell);
	float twinkle = 0.55 + 0.45 * sin(t * 1.7 + h * 40.0);
	return smoothstep(1.4, 0.2, d) * step(0.62, h) * twinkle;
}

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * view_size;
	float t = clock;
	// Água: claro em cima, abismo embaixo, com curva para a luz cair rápido.
	float depth = pow(uv.y, 0.8);
	vec3 col = mix(water_top.rgb, water_deep.rgb, depth);
	// Raios de luz inclinados, que se mexem devagar.
	float rx = uv.x * 1.3 + uv.y * 0.42 + parallax.x * 0.03;
	float r = (sin(rx * 11.0 + t * 0.35) * 0.5 + 0.5) * (sin(rx * 23.0 - t * 0.22 + 1.7) * 0.5 + 0.5);
	r = pow(r, 2.5) * smoothstep(0.95, 0.0, uv.y) * rays_strength;
	col += accent.rgb * r * 0.22 + vec3(0.6, 0.9, 1.0) * r * 0.08;
	// Cáusticas perto da superfície.
	vec2 cp = (px + parallax * 6.0) * 0.045;
	float cv = sin(cp.x * 1.7 + t * 0.8 + sin(cp.y * 1.3 + t * 0.5)) + sin(cp.y * 2.1 - t * 0.6 + sin(cp.x * 1.1));
	float caustic = pow(clamp(abs(cv) * 0.5, 0.0, 1.0), 7.0) * smoothstep(0.45, 0.0, uv.y);
	col += vec3(0.55, 1.0, 0.95) * caustic * 0.12;
	// Ruínas em três terraços do leito (2,5D): o de longe é pequeno, alto na tela e some na neblina; o
	// de perto é grande, escuro e anda mais rápido com o dedo e com a rolagem do mapa.
	if (ruins_strength > 0.0) {
		for (int i = 0; i < 3; i++) {
			float k = float(i);
			float factor = 0.25 + k * 0.4;
			float cell_w = 46.0 + k * 38.0;
			float period = view_size.y * (1.25 + 0.35 * k);
			float ground = view_size.y * (0.5 + 0.17 * k);
			float x = px.x + parallax.x * factor * 22.0 + k * 53.0;
			float y = px.y + scroll * factor + parallax.y * factor * 6.0;
			// Distância até o chão do terraço mais próximo abaixo (o terraço se repete a cada período).
			float above = mod(ground - y, period);
			float row = floor((ground - y) / period);
			// Borda do leito irregular (rochas e areia).
			above -= (sin(x * 0.05 + k * 3.0) * 3.0 + sin(x * 0.13 + k) * 1.5);
			float hy = above < period * 0.6 ? above / cell_w : -1.0;
			vec2 c = vec2(floor(x / cell_w), row);
			vec2 rw = ruin(c, fract(x / cell_w), hy, 11.0 + k * 17.0, 0.55 + k * 0.1);
			float fog = 0.82 - k * 0.27 + clamp(hy * 0.06, 0.0, 0.1);
			vec3 stone = mix(water_deep.rgb * (0.5 + 0.18 * k), col, fog);
			col = mix(col, stone, rw.x * ruins_strength);
			float glow = rw.y * (0.6 + 0.4 * sin(t * 1.3 + k * 2.0 + c.x));
			col += accent.rgb * glow * (0.35 - k * 0.08) * ruins_strength;
		}
	}
	// Neve marinha: duas camadas (longe pequena e lenta, perto maior e rápida).
	vec2 sp = px + parallax * 10.0;
	float s = snow(sp + vec2(0.0, scroll * 0.6), 9.0, 0.35, 3.0, t) * 0.35;
	s += snow(sp * 0.7 + vec2(parallax.x * 8.0, scroll * 1.2), 15.0, 0.7, 9.0, t) * 0.6;
	col += vec3(0.75, 0.95, 1.0) * s * 0.55;
	// Vinheta para o conteúdo saltar no centro.
	vec2 v = uv - vec2(0.5, 0.45);
	col *= 1.0 - smoothstep(0.35, 0.95, length(v * vec2(1.1, 0.8))) * 0.55;
	COLOR = vec4(col, 1.0);
}
