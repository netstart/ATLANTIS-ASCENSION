shader_type canvas_item;
// Clima por cima das naves e por baixo das balas inimigas (scripts/view/weather_view.gd, dentro do
// recorte do campo): fiapos de nuvem alta passando pela nave a 1,4x da rolagem, chuva e neve de
// perto, cinzas com brasas, rastros da corrente de jato, véu de nevasca ou de sedimento que fecha a
// visão nas bordas, partículas grandes sob a água, a luz de raio vinda da superfície e o arco-íris
// quando a tempestade passa.
// Leitura acima de tudo (docs/policies/qualidade.md): opacidade total ≤ 0,35 sobre o campo, tons
// abaixo de `luma_cap` (as balas mantêm o contraste) e tudo some com `clear_for_bullets` (padrões
// densos). Coordenadas presas ao pixel lógico do campo.

uniform int medium = 0;
uniform float detail : hint_range(0.0, 2.0) = 2.0;
uniform vec2 size = vec2(270.0, 450.0);
uniform float scroll = 0.0;
uniform vec2 drift = vec2(0.0);
uniform vec2 wind_dir = vec2(0.0, 1.0);
uniform float wind_speed = 0.0;
uniform float luma_cap = 0.07;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float clouds = 0.0;
uniform float rain = 0.0;
uniform float snow = 0.0;
uniform float ash = 0.0;
uniform float streaks = 0.0;
uniform float haze = 0.0;
uniform vec4 haze_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 cloud_tint : source_color = vec4(0.2, 0.24, 0.3, 1.0);
uniform vec4 foam : source_color = vec4(0.7, 0.95, 1.0, 1.0);
uniform float flash = 0.0;
uniform float rainbow = 0.0;
uniform float clear_for_bullets : hint_range(0.0, 1.0) = 1.0;
// Teto de opacidade da camada inteira sobre o campo.
const float MAX_ALPHA = 0.35;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 cap_luma(vec3 col) {
	vec3 lin = pow((max(col, vec3(0.0)) + 0.055) / 1.055, vec3(2.4));
	float l = dot(lin, vec3(0.2126, 0.7152, 0.0722));
	if (l > luma_cap) {
		lin *= luma_cap / l;
		col = 1.055 * pow(lin, vec3(1.0 / 2.4)) - 0.055;
	}
	return col;
}

float streak(vec2 p, vec2 dir, float cell, float len, float dens, float seed) {
	vec2 n = vec2(-dir.y, dir.x);
	vec2 q = floor(vec2(dot(p, n), dot(p, dir)));
	vec2 sz = vec2(cell, cell * 4.0);
	vec2 c = floor(q / sz);
	vec2 f = q - c * sz;
	if (hash12(c + seed) > dens) {
		return 0.0;
	}
	float x0 = floor(hash12(c + seed + 7.3) * (cell - 1.0));
	float y0 = floor(hash12(c + seed + 3.1) * (sz.y - len));
	return (f.x == x0 && f.y >= y0 && f.y < y0 + len) ? 1.0 - (f.y - y0) / len * 0.5 : 0.0;
}

float flakes(vec2 p, float cell, float dens, float seed, float r) {
	vec2 c = floor(p / cell);
	float h = hash12(c + seed);
	if (h > dens) {
		return 0.0;
	}
	vec2 at = (vec2(hash12(c + seed + 1.7), hash12(c + seed + 9.2)) * 0.7 + 0.15) * cell;
	at += vec2(sin(TIME * (1.1 + h) + h * 40.0), cos(TIME * (0.9 + h) + h * 17.0)) * cell * 0.15;
	vec2 d = abs(p - c * cell - at);
	return (d.x < r && d.y < r) ? 1.0 : 0.0;
}

// Arco-íris: anel com centro abaixo do campo, do vermelho (fora) ao violeta (dentro).
vec3 spectrum(float u) {
	return clamp(abs(mod(u * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

vec4 over(vec4 base, vec3 col, float a) {
	float out_a = a + base.a * (1.0 - a);
	vec3 out_col = (col * a + base.rgb * base.a * (1.0 - a)) / max(out_a, 0.001);
	return vec4(out_col, out_a);
}

void fragment() {
	vec2 px = floor(UV * size) + 0.5;
	// Base (nuvem alta, véu): sob o teto de brilho. Partículas (chuva, neve, cinza, rastros): fora dele,
	// pequenas e esparsas. A camada inteira fica sob MAX_ALPHA e some nos padrões densos.
	vec4 base = vec4(0.0);
	vec4 bits = vec4(0.0);
	vec2 fall = normalize(vec2(wind_dir.x * min(1.0, wind_speed / 20.0) * 0.6, 1.0));
	vec2 dir = normalize(wind_dir + vec2(0.0001));
	if (clouds > 0.0 && detail > 1.5) {
		// Fiapos altos: passam rápido por cima da nave (1,4x), esticados no sentido do voo.
		vec2 w = vec2(px.x, px.y - scroll * 1.4) - drift * 1.2;
		float n = texture(noise_tex, w * vec2(0.0035, 0.0018)).r * 0.65
				+ texture(noise_tex, w * vec2(0.011, 0.006) + vec2(0.5, 0.2)).r * 0.35;
		float edge = 0.68 - clouds * 0.3;
		float body = smoothstep(edge, edge + 0.25, n);
		base = over(base, cloud_tint.rgb + foam.rgb * flash * 0.5, body * 0.75);
	}
	if (haze > 0.0) {
		// Véu que fecha a visão nas bordas: o centro (onde a nave e as balas estão) fica legível.
		vec2 d = (px / size - 0.5) * vec2(1.4, 1.0);
		float edge = smoothstep(0.18, 0.62, length(d));
		base = over(base, haze_color.rgb, haze * (0.18 + 0.82 * edge));
	}
	base.rgb = mix(cap_luma(base.rgb), base.rgb, clamp(flash, 0.0, 1.0));
	if (rain > 0.0) {
		float r = streak(px - fall * TIME * 420.0, fall, 7.0, 6.0 + rain * 6.0, rain * 0.5, 21.0);
		bits = over(bits, vec3(0.75, 0.82, 0.92), r * 0.85);
	}
	if (snow > 0.0) {
		vec2 q = px - vec2(drift.x * 1.2 + TIME * wind_dir.x * wind_speed * 0.8, -scroll * 1.3 - TIME * 22.0);
		float f = flakes(q, 16.0, snow * 0.35, 13.0, 1.1);
		bits = over(bits, vec3(0.95, 0.97, 1.0), f);
	}
	if (ash > 0.0) {
		vec2 q = px - vec2(drift.x * 1.2, -scroll * 1.2 - TIME * 10.0);
		float f = flakes(q, 18.0, ash * 0.3, 17.0, 0.9);
		bool ember = hash12(floor(q / 18.0) + 5.0) > 0.88;
		bits = over(bits, ember ? vec3(1.0, 0.5, 0.15) : vec3(0.1, 0.08, 0.07), f);
	}
	if (streaks > 0.0) {
		float f = streak(px - dir * TIME * 620.0, dir, 13.0, 26.0, streaks * 0.16, 23.0);
		bits = over(bits, vec3(0.88, 0.92, 1.0), f * 0.8);
	}
	if (medium == 1) {
		// Partículas grandes de perto (1,5x), arrastadas pela corrente.
		vec2 q = px - vec2(0.0, -scroll * 1.5) - drift * 1.5;
		float f = flakes(q, 23.0, 0.16 + snow * 0.12, 29.0, 0.9);
		bits = over(bits, foam.rgb, f * 0.75);
		if (flash > 0.0) {
			float top = 1.0 - smoothstep(0.0, size.y * 0.7, px.y);
			bits = over(bits, foam.rgb, flash * top * 0.8);
		}
	}
	if (rainbow > 0.0) {
		vec2 c = vec2(size.x * 0.62, size.y * 1.35);
		float u = (distance(px, c) - size.y * 0.95) / 26.0;
		if (u > 0.0 && u < 1.0) {
			bits = over(bits, spectrum(u * 0.8), rainbow * sin(u * 3.14159) * 0.9);
		}
	}
	vec4 outc = over(base, bits.rgb, bits.a);
	COLOR = vec4(outc.rgb, clamp(outc.a, 0.0, 1.0) * MAX_ALPHA * clear_for_bullets);
}
