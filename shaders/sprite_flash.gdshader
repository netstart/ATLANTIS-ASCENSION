shader_type canvas_item;
// Retorno de dano das camadas de entidades e da nave (scripts/view/world_view.gd), lido do modulate.
// Um só material por camada: os desenhos continuam no mesmo lote.
//  - Vermelho > 1,5 (Color(1.8, 1.8, 1.8)): brilho branco dos inimigos comuns, mantendo o recorte.
//  - Alfa 2..3 (tinte quente) ou 4..5 (dourado, ponto fraco): chefe atingido. O excesso do alfa é a
//    força do tinte (0..1; a vista limita a ~0,34, HitPulse): mistura leve no sprite e mais forte na
//    borda (a borda vem do alfa dos vizinhos), para o chefe continuar legível sob tiro contínuo.
//  - Qualquer outro modulate desenha normalmente.

varying float flash;
varying float hit;
varying float gold;

void vertex() {
	flash = step(1.5, COLOR.r);
	float a = COLOR.a;
	gold = step(3.5, a);
	hit = 0.0;
	if (a > 1.75) {
		hit = clamp(a - mix(2.0, 4.0, gold), 0.0, 1.0);
		COLOR.a = 1.0;
	}
}

void fragment() {
	if (flash > 0.5) {
		COLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a);
	} else if (hit > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * 1.5;
		float inner = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
				min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		float rim = 1.0 - inner;
		vec3 hot = mix(vec3(1.0, 0.45, 0.2), vec3(1.0, 0.82, 0.3), gold);
		// Miolo: mistura leve e um pouco de calor somado (aparece até em sprite já vermelho). Borda: o
		// contorno escuro acende na cor quente, o sinal mais legível sem esconder o desenho.
		vec3 lit = mix(COLOR.rgb, hot, hit * 0.5) + hot * hit * 0.3;
		COLOR.rgb = mix(lit, hot, min(1.0, hit * 2.2) * rim);
	}
}
