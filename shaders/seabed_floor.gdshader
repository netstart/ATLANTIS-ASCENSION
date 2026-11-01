shader_type canvas_item;
render_mode blend_disabled;
// Fundo 2,5D das missões (docs/policies/qualidade.md, .ai/05 seção 3): um único desenho de tela cheia
// com três camadas de profundidade, cada uma com velocidade própria:
//   abismo (0,1x)  →  ruínas ao longe na fenda (0,3x, sob neblina)  →  chão em perspectiva (0,6–1,0x).
// Chão "mode 7": a linha `y_ref` (fundo do campo, onde está a nave) anda a 1,0x; acima dela a
// profundidade cresce, z = 1 / (1 − (y_ref − y)·persp), e o chão anda a 1/z² da rolagem (≈ 0,5x no
// topo do campo). Coordenadas do mundo presas ao texel (1 unidade) e cor quantizada com pontilhado
// ordenado 2x2: a pixel art não cintila. `scroll` vem da simulação (só leitura); `cam_x` é a câmera
// que acompanha a nave na horizontal (só visual). O brilho final é limitado a `luma_cap` (luminância
// WCAG da cor `lit` da paleta): as balas inimigas mantêm contraste ≥ 4,5:1 (tests/flow_tests.gd).
// Padrões procedurais por cenário (`pattern`): 0 areia com ondulações e pedras, 1 ruínas com
// ladrilhos, 3 basalto com fendas de lava, 4 gelo rachado, 5 circuito, 6 mar de nuvens, 7 espaço.

uniform float scroll = 0.0;
uniform float emerge : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 2.0) = 2.0;
uniform vec2 view_size = vec2(305.0, 678.0);
uniform vec4 field = vec4(17.0, 114.0, 270.0, 450.0);
uniform float cam_x = 0.0;
uniform float persp = 0.00065;
uniform int pattern = 0;
uniform float tile = 16.0;
uniform float rocks = 0.22;
uniform float caustics = 1.0;
uniform float rays = 1.0;
uniform float dots = 0.0;
uniform float trench = 1.0;
uniform float luma_cap = 0.07;
uniform vec4 abyss : source_color = vec4(0.008, 0.027, 0.047, 1.0);
uniform vec4 fog : source_color = vec4(0.04, 0.165, 0.227, 1.0);
uniform vec4 floor_dark : source_color = vec4(0.05, 0.2, 0.27, 1.0);
uniform vec4 floor_lit : source_color = vec4(0.13, 0.31, 0.4, 1.0);
uniform vec4 foam : source_color = vec4(0.7, 0.95, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(0.38, 0.29, 0.09, 1.0);
// Clima (scripts/sim/weather.gd, só visual): cor da água ou do céu (rgb, quantidade em a) que troca o
// matiz e mantém o claro e escuro, escurecimento (negativo clareia), cáusticas e raios de luz
// multiplicados, e o clarão do relâmpago em volta de um ponto. Tudo antes do teto de brilho.
uniform vec4 weather_grade : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float weather_dim = 0.0;
uniform float weather_caustics = 1.0;
uniform float weather_rays = 1.0;
uniform float weather_flash = 0.0;
uniform vec2 weather_flash_pos = vec2(150.0, 200.0);

// Fendas: frequência do ruído (alongadas no sentido da rolagem) e limiar da borda.
const vec2 TRENCH_FREQ = vec2(0.016, 0.0052);
const float TRENCH_EDGE = 0.77;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Distância à borda da célula de Voronoi (F2 − F1): fendas de lava e rachaduras do gelo.
float cracks(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + hash22(i + g) - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

// Pedra arredondada (sombreada como esfera, luz do alto à esquerda) com sombra projetada.
float rock(vec2 t, float tone, float density) {
	vec2 rc = floor(t / 22.0);
	float rh = hash12(rc + 17.0);
	if (rh < 1.0 - density) {
		return tone;
	}
	vec2 rf = t - rc * 22.0 - 11.0 - (hash22(rc) - 0.5) * 8.0;
	float r = 3.0 + fract(rh * 13.7) * 5.0;
	float dd = length(rf);
	if (dd < r) {
		float lit = dot(rf / r, vec2(-0.55, -0.75));
		return 0.42 + 0.34 * clamp(lit + 0.35, 0.0, 1.0) - 0.1 * (dd / r);
	}
	if (length(rf - vec2(2.0, 3.0)) < r) {
		return tone * 0.5;
	}
	return tone;
}

// Areia com ondulações (cristas claras, cavas escuras), manchas de lodo e pedras.
float sand(vec2 t) {
	float n = vnoise(t * 0.018);
	float rip = sin(t.y * 0.42 + n * 9.0 + sin(t.x * 0.05) * 1.5);
	float tone = 0.4 + 0.2 * n;
	tone += rip > 0.45 ? 0.26 : (rip < -0.55 ? -0.2 : 0.0);
	// Manchas grandes de luz e de lodo: variação de baixa frequência, calma sob as balas.
	tone *= 0.55 + 0.75 * vnoise(t * 0.0045 + 11.0);
	return rock(t, tone, rocks);
}

// Ruínas: praças de ladrilhos com chanfro, ladrilhos faltando (areia), inscrições douradas e
// plataformas elevadas com sombra.
float ruins(vec2 t, out float glow) {
	glow = 0.0;
	float base = sand(t) * 0.85;
	if (vnoise(t * 0.0085 + 5.0) < 0.4) {
		return base;
	}
	vec2 tc = floor(t / tile);
	vec2 tf = t - tc * tile;
	float th = hash12(tc);
	if (th > 0.93) {
		return base * 0.8;
	}
	float tone = 0.46 + 0.16 * th;
	if (tf.x < 1.0 || tf.y < 1.0) {
		tone = 0.16;
	} else if (tf.x < 2.0 || tf.y < 2.0) {
		tone += 0.14;
	} else if (tf.x > tile - 2.0 || tf.y > tile - 2.0) {
		tone -= 0.1;
	}
	vec2 g = mod(tc, 4.0);
	if (g.x == 0.0 && g.y == 0.0) {
		vec2 c = abs(tf - tile * 0.5);
		if ((c.x < 1.0 && c.y < tile * 0.3) || (c.y < 1.0 && c.x < tile * 0.3)) {
			glow = 0.55 + 0.45 * emerge;
		}
	}
	// Plataforma elevada (bloco 64): topo claro, sombra para baixo e para a direita.
	vec2 bc = floor(t / 64.0);
	vec2 bf = t - bc * 64.0;
	if (hash12(bc + 3.1) > 0.72) {
		if (bf.x > 10.0 && bf.x < 50.0 && bf.y > 14.0 && bf.y < 38.0) {
			tone = 0.62 + 0.08 * th;
			if (bf.x < 12.0 || bf.y < 16.0) {
				tone = 0.8;
			}
		} else if (bf.x > 13.0 && bf.x < 54.0 && bf.y > 17.0 && bf.y < 43.0) {
			tone *= 0.45;
		}
	}
	return tone;
}

float basalt(vec2 t, out float glow) {
	float e = cracks(t * 0.028);
	float n = vnoise(t * 0.06);
	float tone = 0.32 + 0.3 * n;
	tone += e > 0.18 && e < 0.26 ? 0.12 : 0.0;
	float pulse = 0.75 + 0.25 * sin(TIME * 2.2 + vnoise(t * 0.02) * 9.0);
	glow = e < 0.06 ? pulse : smoothstep(0.2, 0.05, e) * 0.22 * pulse;
	if (e < 0.06) {
		tone = 0.05;
	}
	return rock(t, tone, rocks);
}

float ice(vec2 t) {
	float e = cracks(t * 0.03);
	float tone = 0.42 + 0.25 * vnoise(t * 0.02);
	if (e < 0.04) {
		tone = 0.95;
	} else if (e < 0.09) {
		tone -= 0.15;
	}
	if (vnoise(t * 0.022 + 31.0) > 0.6) {
		tone = 0.88 - 0.1 * vnoise(t * 0.2);
	}
	return tone;
}

float circuit(vec2 t, out float glow) {
	glow = 0.0;
	vec2 cc = floor(t / 18.0);
	vec2 cf = t - cc * 18.0;
	float h = hash12(cc);
	float tone = 0.26 + 0.08 * h;
	bool trace = h < 0.45 ? (cf.y >= 8.0 && cf.y < 10.0) : (h < 0.8 ? (cf.x >= 8.0 && cf.x < 10.0) : false);
	if (trace) {
		tone = 0.55;
		glow = step(0.88, fract((t.x + t.y) * 0.008 - TIME * 0.35)) * 0.9;
	}
	if (length(cf - 9.0) < 3.0 && h > 0.7) {
		tone = 0.7;
		glow = 0.5 + 0.5 * sin(TIME * 3.0 + h * 40.0);
	}
	vec2 bc = floor(t / 60.0);
	vec2 bf = t - bc * 60.0;
	if (hash12(bc + 9.0) > 0.7 && bf.x > 8.0 && bf.x < 44.0 && bf.y > 10.0 && bf.y < 40.0) {
		tone = (bf.x < 10.0 || bf.y < 12.0) ? 0.72 : 0.14;
		glow = 0.0;
	}
	return tone;
}

float clouds(vec2 t) {
	float c = vnoise(t * 0.011) * 0.6 + vnoise(t * 0.03 + 4.0) * 0.4;
	float lit = c - (vnoise((t + vec2(-5.0, -7.0)) * 0.011) * 0.6 + vnoise((t + vec2(-5.0, -7.0)) * 0.03 + 4.0) * 0.4);
	float tone = smoothstep(0.38, 0.72, c);
	tone += clamp(lit * 4.0, -0.25, 0.25);
	return floor(clamp(tone, 0.0, 1.0) * 4.0) / 4.0;
}

vec3 cap_luma(vec3 col) {
	vec3 lin = pow((col + 0.055) / 1.055, vec3(2.4));
	float l = dot(lin, vec3(0.2126, 0.7152, 0.0722));
	if (l > luma_cap) {
		lin *= luma_cap / l;
		col = 1.055 * pow(lin, vec3(1.0 / 2.4)) - 0.055;
	}
	return col;
}

void fragment() {
	vec2 px = floor(UV * view_size) + 0.5;
	float y_ref = field.y + field.w;
	float cx = field.x + field.z * 0.5;
	float w = max(0.1, 1.0 - (y_ref - px.y) * persp);
	float z = 1.0 / w;
	// Mundo do chão (y cresce para baixo na tela); preso ao texel.
	vec2 t = floor(vec2(cx + (px.x - cx) * z + cam_x, -(scroll + (z - 1.0) / persp)));
	float glow = 0.0;
	float tone;
	if (pattern == 1) {
		tone = ruins(t, glow);
	} else if (pattern == 3) {
		tone = basalt(t, glow);
	} else if (pattern == 4) {
		tone = ice(t);
	} else if (pattern == 5) {
		tone = circuit(t, glow);
	} else if (pattern == 6) {
		tone = clouds(t);
	} else if (pattern == 7) {
		tone = 0.0;
	} else {
		tone = sand(t);
	}
	vec3 col = mix(floor_dark.rgb, floor_lit.rgb, clamp(tone, 0.0, 1.0));
	col += accent.rgb * glow;
	float depth = clamp((z - 1.0) * 1.7, 0.0, 1.0);
	// Fenda: o chão se abre e mostra as ruínas ao longe (0,3x) e o abismo (0,1x).
	if (detail > 0.5 && trench > 0.0) {
		vec2 tm = t * TRENCH_FREQ + 3.7;
		float here = vnoise(tm);
		if (here > TRENCH_EDGE) {
			float far_side = vnoise((t + vec2(0.0, -12.0)) * TRENCH_FREQ + 3.7);
			float near_side = vnoise((t + vec2(0.0, 8.0)) * TRENCH_FREQ + 3.7);
			vec2 q = floor(vec2(cx + (px.x - cx) * z * 1.3 + cam_x * 0.35, -(scroll * 0.3 + (y_ref - px.y) * z * 1.3)));
			vec2 qc = floor(q / vec2(30.0, 54.0));
			vec2 qf = q - qc * vec2(30.0, 54.0);
			float qh = hash12(qc + 41.0);
			float x0 = 8.0 + qh * 10.0;
			bool pillar = qh > 0.55 && qf.x > x0 && qf.x < x0 + 7.0 && qf.y > 6.0;
			bool lintel = qh > 0.75 && qf.y > 4.0 && qf.y < 8.0 && qf.x > x0 - 3.0 && qf.x < x0 + 10.0;
			vec3 deep_col = mix(abyss.rgb, fog.rgb, 0.35 + 0.25 * vnoise(px * 0.02 + vec2(0.0, scroll * 0.002)));
			if (pillar || lintel) {
				deep_col = mix(fog.rgb, floor_dark.rgb, qf.x < x0 + 2.0 ? 0.75 : 0.45);
			}
			// Neve marinha do abismo, a 0,1x.
			if (hash12(floor((px + vec2(cam_x * 0.1, -scroll * 0.1)) / 2.0)) > 0.985) {
				deep_col = mix(deep_col, foam.rgb, 0.18);
			}
			if (pattern == 3) {
				// Rio de lava: corrente que escorre a 0,3x, com crosta escura boiando.
				float flow = vnoise(vec2(q.x * 0.05, q.y * 0.02 - TIME * 0.4));
				deep_col = mix(accent.rgb * 0.75, accent.rgb, step(0.5, flow));
				if (vnoise(q * 0.09 + vec2(0.0, -TIME * 0.3)) > 0.72) {
					deep_col = floor_dark.rgb * 0.6;
				}
			}
			if (far_side < TRENCH_EDGE) {
				deep_col = mix(floor_dark.rgb * 0.7, fog.rgb, 0.4);
			} else if (near_side < TRENCH_EDGE) {
				deep_col *= 0.6;
			}
			col = deep_col;
		} else if (vnoise((t + vec2(0.0, 2.0)) * TRENCH_FREQ + 3.7) > TRENCH_EDGE) {
			col = mix(col, floor_lit.rgb, 0.5);
		}
	}
	// Cáusticas projetadas no chão (seguem a perspectiva).
	if (detail > 0.5 && caustics > 0.0) {
		vec2 cp = t * 0.05;
		float a = vnoise(cp + vec2(TIME * 0.16, TIME * 0.1));
		float b = vnoise(cp * 1.6 - vec2(TIME * 0.09, TIME * 0.17) + 7.0);
		float c = pow(1.0 - abs(a - b), 14.0);
		// Só em manchas de sol que passam devagar: a rede fina não cobre o campo inteiro.
		float patch = smoothstep(0.5, 0.75, vnoise(t * 0.006 + vec2(TIME * 0.03, 0.0)));
		col += foam.rgb * floor(c * 3.0) / 3.0 * 0.11 * caustics * weather_caustics * patch * (1.0 + emerge)
				* (1.0 - depth);
	}
	// Pontos bioluminescentes (fossa hadal) e estrelas.
	if (dots > 0.0 && hash12(t + 7.0) > 1.0 - 0.006 * dots) {
		col = mix(col, accent.rgb, 0.6 + 0.4 * sin(TIME * 2.0 + t.x));
	}
	if (pattern == 7) {
		col = mix(abyss.rgb, fog.rgb, vnoise(px * 0.012 + vec2(0.0, -scroll * 0.004)) * 0.8);
		col = mix(col, accent.rgb, smoothstep(0.62, 0.9, vnoise(px * 0.007 + vec2(9.0, -scroll * 0.002))) * 0.5);
		for (int k = 0; k < 3; k++) {
			float sp = 0.1 + 0.25 * float(k);
			vec2 sc = floor((px + vec2(cam_x * sp, -scroll * sp)) / (2.0 + float(k)));
			if (hash12(sc + float(k) * 13.0) > 0.992) {
				col = mix(col, foam.rgb, 0.35 + 0.25 * float(k));
			}
		}
		depth = 0.0;
	}
	// Neblina por profundidade: azul-petróleo no meio, abismo ao longe.
	float fog_amount = depth * (0.82 - 0.35 * emerge);
	vec3 fog_col = mix(fog.rgb, abyss.rgb, clamp(depth * 1.3 - 0.2, 0.0, 1.0));
	col = mix(col, fog_col, fog_amount);
	// Raios de luz da superfície: faixas diagonais lentas, mais visíveis na água funda.
	if (detail > 1.5 && rays > 0.0) {
		float r = vnoise(vec2((px.x + px.y * 0.42) * 0.028 + TIME * 0.05, TIME * 0.03));
		col += foam.rgb * smoothstep(0.58, 0.86, r) * 0.05 * rays * weather_rays * (0.4 + 0.6 * depth);
	}
	if (weather_grade.a > 0.0) {
		float v = dot(col, vec3(0.3, 0.59, 0.11));
		vec3 tinted = weather_grade.rgb * v / max(dot(weather_grade.rgb, vec3(0.3, 0.59, 0.11)), 0.02);
		col = mix(col, tinted, weather_grade.a);
	}
	col *= 1.0 - weather_dim;
	if (weather_flash > 0.0) {
		col += foam.rgb * weather_flash * (0.25 + 0.75 * exp(-distance(px, weather_flash_pos) / 120.0)) * 0.35;
	}
	// Fora do campo (faixa do HUD, zona do polegar, laterais): um pouco mais escuro.
	vec2 outside = max(field.xy - px, px - field.xy - field.zw);
	if (max(outside.x, outside.y) > 0.0) {
		col *= 0.8;
	}
	vec2 b = mod(floor(px), 2.0);
	float dither = (b.x * 2.0 + b.y * 3.0 - 4.0 * b.x * b.y) / 4.0 + 0.125;
	col = floor(col * 40.0 + dither) / 40.0;
	COLOR = vec4(cap_luma(max(col, vec3(0.0))), 1.0);
}
