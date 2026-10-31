shader_type canvas_item;
// Acabamento do campo de jogo (scripts/view/screen_fx.gd), sem ler a tela: vinheta que puxa o olho
// para o centro, borda vermelha pulsando com o casco no fim (perigo) e clarão de bomba ou chefe.
// Só escurece as bordas (até `vignette`): as balas continuam mais claras que o fundo em volta.

uniform float vignette : hint_range(0.0, 1.0) = 0.24;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform vec4 danger_color : source_color = vec4(1.0, 0.16, 0.22, 1.0);

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.8);
	float edge = smoothstep(0.22, 0.62, length(d));
	float hurt = danger * smoothstep(0.3, 0.68, length(d));
	vec3 col = mix(vec3(0.0), danger_color.rgb, hurt / max(0.001, edge * vignette + hurt));
	float a = clamp(edge * vignette + hurt * 0.55, 0.0, 1.0);
	// O clarão soma por cima de tudo (alfa pré-multiplicado à mão: cor * alfa + clarão).
	col = mix(col, flash_color.rgb, flash / max(0.001, a + flash));
	COLOR = vec4(col, clamp(a + flash, 0.0, 1.0));
}
