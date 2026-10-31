shader_type canvas_item;
// Brilho branco de dano das camadas de entidades e da nave (scripts/view/world_view.gd): um
// modulate com vermelho > 1,5 (Color(1.8, 1.8, 1.8)) pinta o sprite inteiro de branco, mantendo o
// recorte (alfa) da textura. Qualquer outro modulate desenha normalmente. Um só material por camada:
// os desenhos continuam no mesmo lote.

varying float flash;

void vertex() {
	flash = step(1.5, COLOR.r);
}

void fragment() {
	if (flash > 0.5) {
		COLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a);
	}
}
