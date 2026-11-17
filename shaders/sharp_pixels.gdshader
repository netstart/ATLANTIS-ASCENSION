shader_type canvas_item;
// Ampliação nítida de pixel art por fator não inteiro (campo no PC deitado, Game): cada texel vira um bloco
// cheio e só a borda entre dois texels mistura, numa faixa de 1 pixel da tela. Exige filtro linear no nó.

uniform vec2 tex_size = vec2(1.0);

void fragment() {
	vec2 px = UV * tex_size;
	vec2 seam = floor(px + 0.5);
	vec2 per_pixel = max(fwidth(px), vec2(1e-5));
	px = seam + clamp((px - seam) / per_pixel, -0.5, 0.5);
	COLOR = texture(TEXTURE, px / tex_size);
}
