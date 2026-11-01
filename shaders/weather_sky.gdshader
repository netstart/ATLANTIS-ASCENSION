shader_type canvas_item;
// Clima abaixo das naves (scripts/view/weather_view.gd), um único desenho de tela cheia sobre o chão:
//   céu (medium 0): bancos de nuvem baixos com sombra no chão (2,5D: a nave voa por cima), relâmpago
//     dentro da nuvem com o raio ramificado, chuva, neve e cinzas ao longe, rastros da corrente de jato;
//     no "olho" da tempestade as nuvens abrem um poço claro no meio do campo;
//   água (medium 1): neve marinha derivando com a corrente, filetes que mostram para onde a corrente
//     corre, plâncton que brilha, faixa da termoclina e o clarão difuso de raio vindo da superfície;
//   vácuo (medium 2): cortinas de aurora e o vento solar.
// Pixel art: coordenadas presas ao pixel lógico (como shaders/seabed_floor.gdshader). Todo tom fica
// abaixo de `luma_cap` (o teto de brilho do cenário): as balas inimigas, desenhadas por cima, mantêm o
// contraste de 4,5:1. Só o clarão do relâmpago passa do teto, por um instante (e some com "reduzir
// flashes").

uniform int medium = 0;
uniform float detail : hint_range(0.0, 2.0) = 2.0;
uniform vec2 view_size = vec2(305.0, 678.0);
uniform vec4 field = vec4(17.0, 114.0, 270.0, 450.0);
uniform float scroll = 0.0;
uniform float cam_x = 0.0;
uniform vec2 drift = vec2(0.0);
uniform vec2 wind_dir = vec2(0.0, 1.0);
uniform float wind_speed = 0.0;
uniform float luma_cap = 0.07;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float clouds = 0.0;
uniform float cloud_tone = 0.6;
uniform float eye = 0.0;
uniform float rain = 0.0;
uniform float snow = 0.0;
uniform float ash = 0.0;
uniform float streaks = 0.0;
uniform float flow = 0.0;
uniform float glow = 0.0;
uniform float layer = 0.0;
uniform float aurora = 0.0;
uniform float haze = 0.0;
uniform vec4 haze_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 cloud_dark : source_color = vec4(0.05, 0.06, 0.08, 1.0);
uniform vec4 cloud_lit : source_color = vec4(0.2, 0.24, 0.3, 1.0);
uniform vec4 foam : source_color = vec4(0.7, 0.95, 1.0, 1.0);
uniform float flash = 0.0;
uniform vec2 flash_pos = vec2(150.0, 200.0);
uniform float bolt = 0.0;
uniform float bolt_seed = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Nuvem fofa: três oitavas do ruído com o domínio torcido por ele mesmo (bordas em couve-flor).
float billow(vec2 p) {
	vec2 q = vec2(texture(noise_tex, p * 0.7 + vec2(0.1, 0.0)).r, texture(noise_tex, p * 0.7 + vec2(0.53, 0.27)).r);
	return texture(noise_tex, p + q * 0.35).r * 0.55 + texture(noise_tex, p * 2.2 + q * 0.2 + 0.31).r * 0.3
			+ texture(noise_tex, p * 5.1 + 0.77).r * 0.15;
}

// Pontilhado ordenado 2x2 (o mesmo do chão): as faixas de tom não viram degraus lisos.
float ordered(vec2 px) {
	vec2 b = mod(floor(px), 2.0);
	return (b.x * 2.0 + b.y * 3.0 - 4.0 * b.x * b.y) / 4.0 + 0.125;
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

// Riscos de 1 px em células de uma grade girada para o sentido da queda: chuva, filetes, rastros.
// `dir` é o sentido do risco; `cell` a largura da célula; `len` o comprimento; `dens` a fração ocupada.
float streak(vec2 p, vec2 dir, float cell, float len, float dens, float seed) {
	vec2 n = vec2(-dir.y, dir.x);
	vec2 q = floor(vec2(dot(p, n), dot(p, dir)));
	vec2 size = vec2(cell, cell * 4.0);
	vec2 c = floor(q / size);
	vec2 f = q - c * size;
	if (hash12(c + seed) > dens) {
		return 0.0;
	}
	float x0 = floor(hash12(c + seed + 7.3) * (cell - 1.0));
	float y0 = floor(hash12(c + seed + 3.1) * (size.y - len));
	return (f.x == x0 && f.y >= y0 && f.y < y0 + len) ? 1.0 - (f.y - y0) / len * 0.6 : 0.0;
}

// Pontos que flutuam (neve, neve marinha, cinzas, plâncton) com balanço próprio.
float flakes(vec2 p, float cell, float dens, float seed, float size) {
	vec2 c = floor(p / cell);
	float h = hash12(c + seed);
	if (h > dens) {
		return 0.0;
	}
	vec2 at = (vec2(hash12(c + seed + 1.7), hash12(c + seed + 9.2)) * 0.7 + 0.15) * cell;
	at.x += sin(TIME * (0.8 + h) + h * 40.0) * cell * 0.12;
	vec2 d = abs(p - c * cell - at);
	return (d.x < size && d.y < size) ? 1.0 : 0.0;
}

// Uma camada por cima da outra (alfa "over"): `top` sobre `base`.
vec4 over(vec4 base, vec3 col, float a) {
	float out_a = a + base.a * (1.0 - a);
	vec3 out_col = (col * a + base.rgb * base.a * (1.0 - a)) / max(out_a, 0.001);
	return vec4(out_col, out_a);
}

void fragment() {
	vec2 px = floor(UV * view_size) + 0.5;
	float dither = ordered(px);
	// Base (nuvens, sombras, faixas, véus): sob o teto de brilho. Partículas pequenas e esparsas
	// (chuva, neve, filetes, brilho) ficam fora do teto, com alfa limitado, como a chuva do cenário.
	vec4 base = vec4(0.0);
	vec4 bits = vec4(0.0);
	vec2 dir = normalize(wind_dir + vec2(0.0001));
	vec2 fall = normalize(vec2(wind_dir.x * min(1.0, wind_speed / 20.0) * 0.6, 1.0));
	if (medium == 0) {
		// Nuvens baixas: andam a 0,75x da rolagem (entre o chão e a nave) e com o vento. Ruído com o
		// domínio torcido (nuvem fofa, não mancha), luz do alto à esquerda, tons em faixas com pontilhado.
		if (clouds > 0.0 && detail > 0.5) {
			vec2 w = vec2(px.x + cam_x * 0.7, px.y - scroll * 0.75) - drift * 0.6;
			float cover = clouds;
			if (eye > 0.0) {
				vec2 rel = (px - field.xy - field.zw * vec2(0.5, 0.45)) / field.z;
				// O olho: parede de nuvem em volta, céu aberto no meio do campo.
				float ring = smoothstep(0.36, 0.7, length(rel * vec2(1.0, 0.7)));
				cover = mix(cover, cover * ring * 1.25, eye);
			}
			vec2 p = w * vec2(0.0024, 0.002);
			float n = billow(p);
			float edge = 0.66 - cover * 0.34;
			float body = smoothstep(edge, edge + 0.28, n);
			float rim = clamp((n - billow(p - vec2(0.006, 0.008))) * 9.0, -1.0, 1.0);
			float tone = clamp(cloud_tone + rim * 0.45 + (body - 0.5) * 0.4, 0.0, 1.0);
			tone = floor(tone * 4.0 + dither) / 4.0;
			body = floor(body * 5.0 + dither) / 5.0;
			// Sombra da nuvem no chão, deslocada como a das naves (só a oitava grande: barata).
			float shadow = smoothstep(edge, edge + 0.3, texture(noise_tex, p - vec2(0.012, 0.02)).r) * (1.0 - body);
			base = over(base, vec3(0.0), shadow * 0.3);
			vec3 cloud = mix(cloud_dark.rgb, cloud_lit.rgb, tone);
			// O relâmpago acende a nuvem por dentro em volta do ponto do clarão.
			cloud += foam.rgb * flash * exp(-distance(px, flash_pos) / 70.0) * 0.9;
			base = over(base, cloud, body * 0.85);
		}
		if (rain > 0.0) {
			vec2 q = px - fall * TIME * 260.0 - vec2(cam_x * 0.8, 0.0);
			float r = streak(q, fall, 9.0, 4.0 + rain * 4.0, rain * 0.45, 1.0);
			bits = over(bits, vec3(0.62, 0.7, 0.82), r * 0.4);
		}
		if (snow > 0.0) {
			vec2 q = px - vec2(drift.x * 0.5, -scroll * 0.9 - TIME * 14.0);
			float f = flakes(q, 13.0, snow * 0.35, 3.0, 0.6);
			bits = over(bits, vec3(0.85, 0.9, 0.95), f * 0.55);
		}
		if (ash > 0.0) {
			vec2 q = px - vec2(drift.x * 0.5, -scroll * 0.8 - TIME * 6.0);
			float f = flakes(q, 15.0, ash * 0.4, 5.0, 0.6);
			bool ember = hash12(floor(q / 15.0) + 2.0) > 0.9;
			bits = over(bits, ember ? vec3(1.0, 0.45, 0.12) : vec3(0.09, 0.07, 0.06), f * (ember ? 0.75 : 0.6));
		}
		if (streaks > 0.0) {
			float f = streak(px - dir * TIME * 420.0, dir, 11.0, 18.0, streaks * 0.22, 9.0);
			bits = over(bits, vec3(0.8, 0.86, 0.95), f * 0.32);
		}
	} else if (medium == 1) {
		if (layer > 0.0) {
			// Termoclina: faixa de água fria que desce devagar, com borda ondulada.
			float y = mod(px.y - scroll * 0.4 + sin(px.x * 0.035 + TIME * 0.6) * 6.0, 380.0);
			float band = smoothstep(0.0, 24.0, y) * smoothstep(150.0, 110.0, y);
			band = floor(band * 4.0 + dither) / 4.0;
			base = over(base, vec3(0.0, 0.05, 0.2), band * 0.45 * layer);
			// Borda da camada: a luz se curva na troca de temperatura (fio claro que ondula).
			float lip = step(abs(y - 18.0), 0.6) * layer;
			bits = over(bits, foam.rgb * 0.8, lip * 0.35);
		}
		if (snow > 0.0) {
			// Neve marinha: duas profundidades, a de trás mais lenta.
			vec2 p1 = px - vec2(cam_x * 0.5, -scroll * 0.5) - drift * 0.5 + vec2(0.0, TIME * 3.0);
			vec2 p2 = px - vec2(cam_x * 0.8, -scroll * 0.8) - drift * 0.9 + vec2(0.0, TIME * 5.0);
			float f = max(flakes(p1, 11.0, snow * 0.3, 2.0, 0.6) * 0.55, flakes(p2, 17.0, snow * 0.25, 6.0, 0.6));
			bits = over(bits, mix(foam.rgb, vec3(0.8), 0.3), f * 0.5);
		}
		if (flow > 0.0 && detail > 0.5) {
			vec2 q = px - dir * TIME * (30.0 + wind_speed * 4.0) - vec2(cam_x * 0.8, -scroll * 0.8);
			float f = streak(q, dir, 14.0, 9.0 + wind_speed * 0.4, flow * 0.3, 4.0);
			bits = over(bits, foam.rgb, f * 0.3 * flow);
		}
		if (glow > 0.0) {
			vec2 q = px - vec2(cam_x * 0.6, -scroll * 0.6) - drift * 0.7;
			float twinkle = 0.45 + 0.55 * sin(TIME * 2.2 + hash12(floor(q / 19.0)) * 30.0);
			float f = flakes(q, 19.0, glow * 0.2, 8.0, 0.6) * twinkle;
			bits = over(bits, vec3(0.35, 1.0, 0.75), f * 0.85);
		}
		if (flash > 0.0) {
			// Raio na superfície: a luz chega difusa, de cima, e treme.
			float top = 1.0 - smoothstep(0.0, view_size.y * 0.8, px.y);
			bits = over(bits, foam.rgb, flash * top * 0.5);
		}
	} else {
		if (aurora > 0.0 && detail > 0.5) {
			// Cortinas de aurora: faixas verticais que ondulam, verde embaixo e violeta em cima.
			float x = px.x + cam_x * 0.2 + sin(px.y * 0.012 + TIME * 0.4) * 40.0;
			float curtain = pow(texture(noise_tex, vec2(x * 0.004, TIME * 0.02)).r, 3.0) * 2.2;
			float fade = smoothstep(view_size.y * 0.75, 0.0, px.y);
			vec3 hue = mix(vec3(0.15, 0.9, 0.55), vec3(0.6, 0.25, 0.9), smoothstep(0.0, view_size.y * 0.6,
					view_size.y - px.y));
			base = over(base, hue, clamp(curtain * fade, 0.0, 1.0) * 0.5 * aurora);
		}
		if (streaks > 0.0) {
			float f = streak(px - dir * TIME * 300.0, dir, 12.0, 10.0, streaks * 0.2, 11.0);
			bits = over(bits, vec3(1.0, 0.75, 0.5), f * 0.45);
		}
	}
	if (haze > 0.0) {
		// Turbidez ou véu de cinza: mais forte no alto (longe) do que perto da nave.
		float far = 0.55 + 0.45 * (1.0 - clamp(px.y / view_size.y, 0.0, 1.0));
		base = over(base, haze_color.rgb, haze * 0.42 * far);
	}
	// O clarão passa do teto de brilho por um instante (a nuvem acesa); o resto da base nunca.
	vec3 capped = cap_luma(base.rgb);
	base.rgb = flash > 0.0 ? mix(capped, base.rgb, clamp(flash, 0.0, 1.0)) : capped;
	if (bolt > 0.0) {
		// Raio ramificado ao longe: desce em zigue-zague até o ponto do clarão.
		float top = flash_pos.y - 150.0;
		if (px.y > top && px.y < flash_pos.y) {
			float u = (px.y - top) / 150.0;
			float x = flash_pos.x + (texture(noise_tex, vec2(px.y * 0.011, bolt_seed)).r - 0.5) * 38.0 * (1.0 - u)
					+ (hash12(vec2(floor(px.y / 3.0), bolt_seed)) - 0.5) * 3.0;
			float fork = flash_pos.x + (px.y - top) * 0.35 * sign(bolt_seed - 0.5)
					+ (texture(noise_tex, vec2(px.y * 0.02, bolt_seed + 0.3)).r - 0.5) * 20.0;
			if (abs(px.x - x) < 0.8 || (u < 0.55 && u > 0.25 && abs(px.x - fork) < 0.6)) {
				bits = over(bits, vec3(0.9, 0.95, 1.0), bolt);
			}
		}
	}
	vec4 outc = over(base, bits.rgb, bits.a);
	COLOR = vec4(outc.rgb, clamp(outc.a, 0.0, 1.0));
}
