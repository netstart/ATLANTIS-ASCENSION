// Reflexo do oricalco nos botões principais (UiGlint, 1.9): uma faixa de luz diagonal atravessa a TELA
// de baixo à esquerda para cima à direita a cada `period` s. Como a faixa é em coordenadas de tela, um
// material só serve a todos os botões e cada um acende quando a luz passa por ele, em sequência.
// Só as partes claras acendem (o ouro e o filete); o texto escuro e o vidro desativado quase não mudam,
// então a leitura nunca piora. Sem ler a tela: custa uma conta por pixel do botão.
shader_type canvas_item;

uniform float period = 4.5;
// Fração do período em que a faixa atravessa a tela; no resto ela descansa fora da vista.
uniform float sweep = 0.38;
uniform float strength : hint_range(0.0, 1.0) = 0.42;
uniform float width = 0.075;
uniform vec4 tint : source_color = vec4(1.0, 0.98, 0.88, 1.0);

void fragment() {
	vec4 c = COLOR;
	float t = fract(TIME / period) / sweep;
	// Coordenada diagonal: 0 no canto de baixo à esquerda, 1,6 no de cima à direita.
	float d = SCREEN_UV.x * 0.6 + (1.0 - SCREEN_UV.y);
	float head = t * 2.0 - 0.2;
	float band = smoothstep(width, 0.0, abs(d - head)) + 0.35 * smoothstep(width * 3.0, 0.0, abs(d - head));
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float mask = smoothstep(0.42, 0.78, luma);
	COLOR = vec4(c.rgb + tint.rgb * band * mask * strength, c.a);
}
