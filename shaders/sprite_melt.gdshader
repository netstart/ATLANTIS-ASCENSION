shader_type canvas_item;
// Derretimento dos inimigos abatidos (CombatFx.MELT, desenhado em scripts/view/world_view.gd _draw_wrecks).
// Um só material na camada das mortes: o progresso vem no alfa do modulate (2..3 = derretendo, 0..1 do
// fim), como em sprite_flash.gdshader, e os desenhos continuam num lote. Qualquer outro modulate desenha
// normalmente (as quedas). O sprite é desenhado girado 180° (as naves inimigas olham para baixo), então o
// alto da tela é UV.y = 1.
// Efeito: cada coluna de 2 px escorre para baixo numa velocidade própria (pingos), a frente de dissolução
// desce do alto com ruído por pixel e a borda que resta acende em brasa, do branco ao laranja; o corpo
// escurece em vermelho conforme derrete. Só aritmética e um texture() por pixel: cabe no GLES3 do Android.

varying float melt;
varying vec3 tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	melt = -1.0;
	tint = COLOR.rgb;
	if (COLOR.a > 1.75) {
		melt = clamp(COLOR.a - 2.0, 0.0, 1.0);
		COLOR.a = 1.0;
	}
}

void fragment() {
	if (melt >= 0.0) {
		vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
		float drip = hash(vec2(floor(px.x / 2.0), 7.0));
		// Escorre: a coluna amostra mais acima (UV.y maior = mais alto na tela) quanto mais derreteu.
		float sag = melt * melt * (0.25 + 0.35 * drip);
		vec2 uv = vec2(UV.x, UV.y + sag);
		vec4 tex = uv.y <= 1.0 ? texture(TEXTURE, uv) : vec4(0.0);
		// Altura na tela de cima (0) para baixo (1) do ponto amostrado, e a frente que desce.
		float s = 1.0 - uv.y;
		float front = melt * 1.3 - 0.15;
		float edge = s + hash(px) * 0.25 + drip * 0.1 - front;
		float alive = step(0.0, edge);
		float glow = (1.0 - smoothstep(0.0, 0.14, edge)) * alive;
		vec3 body = mix(tex.rgb * tint, tex.rgb * vec3(0.9, 0.3, 0.12), melt * 0.8);
		vec3 hot = mix(vec3(1.0, 0.95, 0.8), vec3(1.0, 0.45, 0.1), smoothstep(0.0, 0.14, edge));
		COLOR = vec4(mix(body, hot, glow * 0.9), tex.a * alive);
	}
}
