shader_type canvas_item;
// Onda de choque da bomba, da especial e da morte do chefe (scripts/view/screen_fx.gd): um anel que
// desloca a imagem já desenhada para fora do centro e separa um pouco as cores na borda. Lê a tela
// (cópia de fundo), por isso só fica visível enquanto a onda corre e só em qualidade Média ou Alta.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform vec2 center = vec2(0.5);
uniform float radius = 0.0;
uniform float width = 0.08;
uniform float strength = 0.02;
uniform float aspect = 0.6;

void fragment() {
	vec2 rel = UV - center;
	rel.x /= aspect;
	float d = length(rel);
	float band = 1.0 - smoothstep(0.0, width, abs(d - radius));
	vec2 dir = d > 0.0001 ? rel / d : vec2(0.0);
	dir.x *= aspect;
	vec2 offs = dir * band * strength;
	vec2 uv = SCREEN_UV - offs;
	vec3 col;
	col.r = texture(screen, uv - offs * 0.35).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv + offs * 0.35).b;
	COLOR = vec4(col + band * strength * 6.0, band > 0.002 ? 1.0 : 0.0);
}
