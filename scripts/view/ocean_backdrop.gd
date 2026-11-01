class_name OceanBackdrop
extends Node2D
## Cenário 2,5D das missões (plano mestre 8.3; .ai/05-pesquisa-redesign-ui-gameplay.md seção 3).
## `kind` escolhe a paleta e o padrão do capítulo: ocean (1, Atlântico), atlantis (2, cidade submersa),
## storm (3, chuva), volcanic (4, lava), city (5, torres emersas), ice (6, gelo), stratosphere (7, mar de
## nuvens), orbit (8, espaço), hadal (10, fossa) e core (9, circuito). Camadas, do fundo para a frente:
##   0 abismo 0,1x · ruínas ao longe 0,3x · chão em perspectiva 0,5–1,0x: um só desenho de tela cheia
##     (shaders/seabed_floor.gdshader), com neblina por profundidade, cáusticas e raios de luz
##   1 estruturas altas no chão (colunas, basalto, agulhas de gelo, torres) projetadas na mesma
##     perspectiva e inclinadas para fora do centro da câmera (parallax de altura); crescem no Ocean Shift
##   2 partículas do capítulo (chuva, brasas, neve, vento, estrelas, faíscas)
##   3 primeiro plano 1,5x sobre o campo: algas e bolhas só nas bordas, opacidade ≤ 0,35
## Tudo é função da rolagem da Sim (só leitura) e da posição da nave (câmera), nada volta à partida.
## O brilho de todo o cenário fica abaixo da luminância da cor `lit` de cada paleta: as balas inimigas
## mantêm contraste ≥ 4,5:1 (tests/flow_tests.gd). Só retângulos por quadro, nenhum polígono.

const TILE := 96.0
const FOREGROUND_FACTOR := 1.5
const CAM_EASE := 0.08
## Paletas por cenário. deep = abismo, mid = neblina, shoal = chão escuro, lit = chão claro (teto de
## brilho), foam = luz (cáusticas, raios, bolhas), accent = brilho próprio (ouro, lava, circuito).
## pattern: 0 areia, 1 ruínas, 3 basalto, 4 gelo, 5 circuito, 6 nuvens, 7 espaço.
const PALETTES := {
	&"ocean": {"deep": Color(0.008, 0.027, 0.047), "mid": Color(0.04, 0.165, 0.227), "shoal": Color(0.05, 0.2, 0.27),
			"lit": Color(0.111, 0.272, 0.347), "foam": Color(0.7, 0.95, 1.0), "accent": Color(0.38, 0.29, 0.09),
			"pattern": 0, "rocks": 0.22, "base_emerge": 0.0, "ruins": &"columns", "kelp": true},
	&"atlantis": {"deep": Color(0.0, 0.03, 0.04), "mid": Color(0.03, 0.16, 0.18), "shoal": Color(0.06, 0.2, 0.2),
			"lit": Color(0.141, 0.278, 0.269), "foam": Color(0.75, 1.0, 0.9), "accent": Color(0.42, 0.32, 0.08),
			"pattern": 1, "tile": 16.0, "rocks": 0.12, "base_emerge": 0.35, "ruins": &"columns", "kelp": true},
	&"storm": {"deep": Color(0.02, 0.025, 0.04), "mid": Color(0.07, 0.09, 0.12), "shoal": Color(0.1, 0.13, 0.16),
			"lit": Color(0.221, 0.259, 0.296), "foam": Color(0.8, 0.85, 0.95), "accent": Color(0.3, 0.32, 0.36),
			"pattern": 0, "rocks": 0.45, "base_emerge": 0.0, "caustics": 0.4, "rays": 0.3, "ruins": &"columns",
			"kelp": true, "particles": &"rain"},
	&"volcanic": {"deep": Color(0.04, 0.01, 0.01), "mid": Color(0.14, 0.05, 0.04), "shoal": Color(0.17, 0.07, 0.05),
			"lit": Color(0.36, 0.2, 0.14), "foam": Color(1.0, 0.55, 0.2), "accent": Color(0.95, 0.38, 0.06),
			"pattern": 3, "rocks": 0.15, "base_emerge": 0.25, "caustics": 0.0, "rays": 0.0, "ruins": &"basalt",
			"particles": &"embers"},
	&"city": {"deep": Color(0.02, 0.03, 0.07), "mid": Color(0.06, 0.08, 0.16), "shoal": Color(0.09, 0.12, 0.22),
			"lit": Color(0.194, 0.252, 0.387), "foam": Color(0.6, 0.8, 1.0), "accent": Color(0.3, 0.75, 1.0),
			"pattern": 1, "tile": 24.0, "rocks": 0.05, "base_emerge": 0.6, "caustics": 0.4, "rays": 0.5,
			"ruins": &"towers"},
	&"ice": {"deep": Color(0.04, 0.07, 0.11), "mid": Color(0.1, 0.17, 0.24), "shoal": Color(0.15, 0.24, 0.32),
			"lit": Color(0.173, 0.263, 0.346), "foam": Color(0.95, 1.0, 1.0), "accent": Color(0.6, 0.9, 1.0),
			"pattern": 4, "base_emerge": 0.3, "caustics": 0.6, "ruins": &"spires", "particles": &"snow"},
	&"stratosphere": {"deep": Color(0.05, 0.08, 0.18), "mid": Color(0.09, 0.14, 0.27), "shoal": Color(0.13, 0.2, 0.35),
			"lit": Color(0.191, 0.254, 0.382), "foam": Color(0.9, 0.95, 1.0), "accent": Color(1.0, 0.85, 0.6),
			"pattern": 6, "base_emerge": 0.0, "caustics": 0.0, "rays": 0.6, "trench": 0.0, "bubbles": false,
			"particles": &"wind"},
	&"orbit": {"deep": Color(0.01, 0.01, 0.04), "mid": Color(0.03, 0.03, 0.08), "shoal": Color(0.06, 0.05, 0.12),
			"lit": Color(0.25, 0.18, 0.4), "foam": Color(0.8, 0.8, 1.0), "accent": Color(0.35, 0.15, 0.45),
			"pattern": 7, "base_emerge": 0.0, "caustics": 0.0, "rays": 0.0, "trench": 0.0, "bubbles": false,
			"shadows": false, "particles": &"stars"},
	&"hadal": {"deep": Color(0.0, 0.03, 0.04), "mid": Color(0.01, 0.07, 0.08), "shoal": Color(0.02, 0.11, 0.11),
			"lit": Color(0.08, 0.26, 0.26), "foam": Color(0.45, 1.0, 0.85), "accent": Color(0.3, 1.0, 0.85),
			"pattern": 1, "tile": 16.0, "rocks": 0.3, "base_emerge": 0.15, "caustics": 0.25, "rays": 0.2,
			"dots": 1.0, "ruins": &"columns", "kelp": true, "particles": &"glow"},
	&"core": {"deep": Color(0.06, 0.0, 0.06), "mid": Color(0.12, 0.02, 0.1), "shoal": Color(0.19, 0.04, 0.14),
			"lit": Color(0.38, 0.12, 0.3), "foam": Color(1.0, 0.5, 0.6), "accent": Color(1.0, 0.35, 0.6),
			"pattern": 5, "base_emerge": 0.0, "caustics": 0.0, "rays": 0.0, "trench": 0.0, "bubbles": false,
			"particles": &"sparks"},
}
## Partículas de primeiro plano: cor, comprimento do risco, velocidade (x rolagem), inclinação, passo.
const PARTICLES := {
	&"rain": {"color": Color(0.75, 0.85, 1.0, 0.22), "length": 4, "speed": 3.0, "slant": 0.35, "step": 17.0},
	&"embers": {"color": Color(1.0, 0.6, 0.2, 0.45), "length": 1, "speed": -1.2, "slant": 0.1, "step": 29.0},
	&"snow": {"color": Color(1.0, 1.0, 1.0, 0.4), "length": 1, "speed": 0.7, "slant": 0.25, "step": 21.0},
	&"wind": {"color": Color(1.0, 1.0, 1.0, 0.1), "length": 8, "speed": 4.0, "slant": 0.0, "step": 31.0},
	&"stars": {"color": Color(1.0, 1.0, 1.0, 0.5), "length": 1, "speed": 0.25, "slant": 0.0, "step": 19.0},
	&"glow": {"color": Color(0.45, 1.0, 0.85, 0.4), "length": 1, "speed": -0.5, "slant": 0.05, "step": 27.0},
	&"sparks": {"color": Color(1.0, 0.6, 0.7, 0.35), "length": 2, "speed": 1.5, "slant": -0.2, "step": 23.0},
}

var view_size := Vector2(305, 678)
## Campo de jogo na tela (Playfield.layout); sem ele, um campo centrado na vista.
var field := Rect2()
var scroll: float = 0.0
var emerge: float = 0.0
var tilt := Vector2.ZERO
var detail: int = 2
var kind: StringName = &"ocean"
## Corrente ou vento atual (unidades/s): as partículas derivam junto.
var drift := Vector2.ZERO
## Desenhar algas e bolhas por cima do campo (z_index 1); a partida liga, a história não.
var foreground_on_top: bool = false
## Partículas próprias do cenário (chuva, neve...). A partida desliga quando o clima já cai do céu
## (WeatherView): duas chuvas ao mesmo tempo nunca.
var particles_on: bool = true

var _floor: ColorRect
var _material: ShaderMaterial
var _pillars: PillarLayer
var _front: ForegroundLayer
var _rain: ParticleLayer
var _drift_offset := Vector2.ZERO
var _cam_x: float = 0.0


func _ready() -> void:
	var palette := palette_of(kind)
	_floor = ColorRect.new()
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/seabed_floor.gdshader") as Shader
	_floor.material = _material
	add_child(_floor)
	_pillars = PillarLayer.new()
	_pillars.setup(palette)
	add_child(_pillars)
	_rain = ParticleLayer.new()
	add_child(_rain)
	_front = ForegroundLayer.new()
	_front.kelp = bool(palette.get("kelp", false))
	_front.z_index = 1 if foreground_on_top else 0
	add_child(_front)
	var m := _material
	m.set_shader_parameter("abyss", palette["deep"])
	m.set_shader_parameter("fog", palette["mid"])
	m.set_shader_parameter("floor_dark", palette["shoal"])
	m.set_shader_parameter("floor_lit", palette["lit"])
	m.set_shader_parameter("foam", palette["foam"])
	m.set_shader_parameter("accent", palette["accent"])
	m.set_shader_parameter("pattern", int(palette["pattern"]))
	m.set_shader_parameter("tile", float(palette.get("tile", 16.0)))
	m.set_shader_parameter("rocks", float(palette.get("rocks", 0.2)))
	m.set_shader_parameter("caustics", float(palette.get("caustics", 1.0)))
	m.set_shader_parameter("rays", float(palette.get("rays", 1.0)))
	m.set_shader_parameter("dots", float(palette.get("dots", 0.0)))
	m.set_shader_parameter("trench", float(palette.get("trench", 1.0)))
	m.set_shader_parameter("persp", ParallaxRig.FLOOR_PERSP)
	# Teto de brilho com 4% de folga para a quantização de cor do shader.
	m.set_shader_parameter("luma_cap", luminance(palette["lit"]) * 0.96)
	set_view(view_size)


static func palette_of(p_kind: StringName) -> Dictionary:
	return PALETTES.get(p_kind, PALETTES[&"ocean"])


## Luminância relativa WCAG 2 (a mesma de tests/flow_tests.gd).
static func luminance(c: Color) -> float:
	var lin := Vector3.ZERO
	for i: int in range(3):
		var v: float = [c.r, c.g, c.b][i]
		lin[i] = v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.x + 0.7152 * lin.y + 0.0722 * lin.z


## A cor `c` escurecida até a luminância `cap` (mantém o matiz). Alfa preservado.
static func capped(c: Color, cap: float) -> Color:
	var l := luminance(c)
	if l <= cap or l <= 0.0:
		return c
	var k := pow(cap / l, 1.0 / 2.4)
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func set_drift(value: Vector2) -> void:
	drift = value


## Clima sobre o chão (WeatherView): `grade` muda o matiz (quantidade no alfa), `dim` escurece
## (negativo clareia), cáusticas e raios multiplicados e o clarão do relâmpago em `flash_pos` (tela).
## Tudo passa pelo teto de brilho do shader: a leitura das balas não muda.
func set_weather(grade: Color, dim: float, caustics: float, rays: float, flash: float, flash_pos: Vector2) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("weather_grade", grade)
	_material.set_shader_parameter("weather_dim", dim)
	_material.set_shader_parameter("weather_caustics", caustics)
	_material.set_shader_parameter("weather_rays", rays)
	_material.set_shader_parameter("weather_flash", flash)
	_material.set_shader_parameter("weather_flash_pos", flash_pos)


## Deslocamento atual da câmera que segue a nave (o clima anda junto, em parallax).
func cam() -> float:
	return _cam_x


## Teto de brilho do cenário (luminância WCAG): o clima desenhado por cima respeita o mesmo.
func luma_cap() -> float:
	return luminance(palette_of(kind)["lit"]) * 0.96


func set_view(size: Vector2) -> void:
	view_size = size
	if field.size == Vector2.ZERO or not Rect2(Vector2.ZERO, size).encloses(field):
		var fs := Playfield.FIELD
		field = Rect2(((size - fs) * 0.5).floor(), fs)
	if _floor != null:
		_floor.size = size
		_apply_field()


## Campo de jogo na tela (o chão anda a 1,0x na linha de baixo do campo, onde a nave voa).
func set_field(rect: Rect2) -> void:
	field = rect
	if _floor != null:
		_apply_field()


func _apply_field() -> void:
	_material.set_shader_parameter("view_size", view_size)
	_material.set_shader_parameter("field", Vector4(field.position.x, field.position.y, field.size.x, field.size.y))


## Um quadro do cenário. `p_tilt.x` (-1..1) é a posição da nave no campo: a câmera a acompanha.
func apply(p_scroll: float, p_emerge: float, p_tilt: Vector2 = Vector2.ZERO, reduce_motion: bool = false) -> void:
	scroll = p_scroll
	var palette := palette_of(kind)
	var base := float(palette["base_emerge"])
	emerge = clampf(base + p_emerge * (1.0 - base), 0.0, 1.0)
	if not reduce_motion:
		_drift_offset += drift * 0.02
	tilt = Vector2.ZERO if reduce_motion else p_tilt.limit_length(1.0)
	_cam_x = lerpf(_cam_x, tilt.x * ParallaxRig.CAM_SHIFT * Playfield.FIELD.x, CAM_EASE)
	# A precisão dos padrões do shader cai com números grandes: a rolagem volta a cada 32768 unidades.
	_material.set_shader_parameter("scroll", fposmod(scroll, 32768.0))
	_material.set_shader_parameter("emerge", emerge)
	_material.set_shader_parameter("detail", float(detail))
	_material.set_shader_parameter("cam_x", _cam_x)
	_pillars.visible = palette.has("ruins")
	if _pillars.visible:
		_pillars.scroll = scroll
		_pillars.emerge = emerge
		_pillars.cam_x = _cam_x
		_pillars.field = field
		_pillars.view_size = view_size
		_pillars.queue_redraw()
	_front.visible = detail >= 1
	if _front.visible:
		_front.offset = scroll * FOREGROUND_FACTOR
		_front.cam = -_cam_x * FOREGROUND_FACTOR
		_front.field = field
		_front.view_size = view_size
		_front.bubbles = detail >= 2 and bool(palette.get("bubbles", true))
		_front.reduce_motion = reduce_motion
		_front.queue_redraw()
	var kind_p := StringName(String(palette.get("particles", "")))
	_rain.visible = PARTICLES.has(kind_p) and detail >= 1 and particles_on
	if _rain.visible:
		var cfg: Dictionary = PARTICLES[kind_p]
		_rain.position = ParallaxRig.layer_offset(0.0, 1.0, 0.0, tilt, 1.2, reduce_motion)
		_rain.position.x += fposmod(_drift_offset.x, 24.0) - 12.0
		_rain.color = cfg["color"]
		_rain.length = int(cfg["length"])
		_rain.step = float(cfg["step"])
		_rain.offset = scroll * float(cfg["speed"])
		_rain.slant = float(cfg["slant"]) + drift.x * 0.01
		_rain.view_size = view_size
		_rain.queue_redraw()


## Estruturas altas no chão em perspectiva: cada uma é a base projetada no chão (mesma conta do
## shader) e um topo que se afasta do centro da câmera conforme a altura, desenhados como fatias
## empilhadas (lado sombreado de baixo para cima), tampa clara e sombra no chão. Sorteadas por hash
## do bloco de TILE unidades: o mesmo bloco é sempre igual, em qualquer aparelho.
class PillarLayer:
	extends Node2D

	## Inclinação por unidade de altura (fração da distância ao centro da câmera).
	const LEAN := 0.0012
	const SHADOW := Color(0.0, 0.01, 0.03, 0.35)
	## Estilos: pegada (largura, profundidade), altura mínima e variação, chance de uma segunda peça,
	## largura do topo (afunilar), capitel e base largos (colunas) e peças por grupo (órgão de basalto).
	const STYLES := {
		&"columns": {"size": Vector2(12, 10), "height": 26.0, "vary": 30.0, "pair": 0.45, "taper": 1.0,
				"capital": true, "cluster": 1},
		&"basalt": {"size": Vector2(11, 10), "height": 10.0, "vary": 22.0, "pair": 0.5, "taper": 1.0,
				"capital": false, "cluster": 3},
		&"spires": {"size": Vector2(14, 12), "height": 24.0, "vary": 34.0, "pair": 0.35, "taper": 0.25,
				"capital": false, "cluster": 2},
		&"towers": {"size": Vector2(26, 22), "height": 30.0, "vary": 40.0, "pair": 0.3, "taper": 1.0,
				"capital": false, "cluster": 1},
	}

	var scroll: float = 0.0
	var emerge: float = 0.0
	var cam_x: float = 0.0
	var field := Rect2(17, 114, 270, 450)
	var view_size := Vector2(305, 678)
	var _style: Dictionary = STYLES[&"columns"]
	var _side := Color()
	var _side_dark := Color()
	var _cap := Color()
	var _trim := Color()
	var _fog := Color()
	var _windows: bool = false

	func setup(palette: Dictionary) -> void:
		_style = STYLES.get(StringName(String(palette.get("ruins", "columns"))), STYLES[&"columns"])
		var cap := OceanBackdrop.luminance(palette["lit"]) * 0.96
		var lit: Color = palette["lit"]
		var shoal: Color = palette["shoal"]
		_side = OceanBackdrop.capped(shoal.lerp(lit, 0.55), cap)
		_side_dark = OceanBackdrop.capped(shoal.lerp(palette["deep"], 0.35), cap)
		_cap = OceanBackdrop.capped(lit.lightened(0.15), cap)
		_trim = OceanBackdrop.capped(palette["accent"], cap)
		_fog = palette["mid"]
		_windows = StringName(String(palette.get("ruins", ""))) == &"towers"

	func _draw() -> void:
		var y_ref := field.end.y
		var cx := field.get_center().x
		var center := field.get_center()
		var persp := ParallaxRig.FLOOR_PERSP
		var z_top := ParallaxRig.floor_depth(-40.0, y_ref)
		var far := (z_top - 1.0) / persp
		var near := (ParallaxRig.floor_depth(view_size.y + 60.0, y_ref) - 1.0) / persp
		var first := floori((scroll + near) / OceanBackdrop.TILE) - 1
		var last := floori((scroll + far) / OceanBackdrop.TILE) + 1
		var rise := 0.4 + 0.6 * emerge
		var size: Vector2 = _style["size"]
		var spread := view_size.x * z_top + 60.0
		var items: Array[Vector4] = []
		# Do mais longe para o mais perto: o de perto cobre o de longe.
		for tile: int in range(last, first - 1, -1):
			var h := absi(hash(tile * 7919 + 13))
			var count := 1 + (1 if float(h % 100) / 100.0 < float(_style["pair"]) else 0)
			for k: int in range(count):
				var hk := absi(hash(h + k * 104729))
				var wx := cx + (float(hk % 1000) / 1000.0 - 0.5) * spread
				var ahead := tile * OceanBackdrop.TILE + float((hk >> 10) % int(OceanBackdrop.TILE)) - scroll
				for c: int in range(int(_style["cluster"])):
					# Grupo: peças vizinhas, mais baixas para os lados (órgão de basalto, agulhas de gelo).
					var hc := absi(hash(hk + c * 7907))
					var off := Vector2.ZERO if c == 0 else Vector2(float(hc % 15) - 7.0, float((hc >> 5) % 11) - 5.0) * 1.4
					var height := (float(_style["height"]) + float((hc >> 17) % int(_style["vary"]))) * rise
					height *= 1.0 if c == 0 else 0.6
					items.append(Vector4(wx + off.x, ahead - off.y, height, float(hk % 7)))
		for it: Vector4 in items:
			_shadow(it, cx, y_ref, center, size)
		for it: Vector4 in items:
			_pillar(it, cx, y_ref, center, size)

	func _shadow(it: Vector4, cx: float, y_ref: float, _center: Vector2, size: Vector2) -> void:
		var p := ParallaxRig.floor_to_screen(it.x, it.y, cx, y_ref, cam_x)
		if p.z <= 0.0:
			return
		var s := p.z
		var reach := it.z * 0.35 * s
		var foot := size * s
		draw_rect(Rect2(Vector2(p.x, p.y) - foot * 0.5 + Vector2(2.0, 1.0) * s,
				foot + Vector2(reach, reach * 0.4)), SHADOW)

	func _pillar(it: Vector4, cx: float, y_ref: float, center: Vector2, size: Vector2) -> void:
		var p := ParallaxRig.floor_to_screen(it.x, it.y, cx, y_ref, cam_x)
		if p.z <= 0.0:
			return
		var s := p.z
		var base := Vector2(p.x, p.y)
		if base.y < -80.0 or base.y > view_size.y + 120.0:
			return
		var lean := LEAN * it.z
		var top := base + (base - center) * lean - Vector2(0.0, it.z * 0.75 * s)
		var fog := clampf((1.0 / s - 1.0) * 1.7, 0.0, 1.0) * (0.82 - 0.35 * emerge)
		var foot := (size * s).round()
		var taper := float(_style["taper"])
		var capital := bool(_style["capital"])
		if capital:
			# Base (plinto) mais larga.
			var plinth := (foot + Vector2(4.0, 2.0) * s).round()
			draw_rect(Rect2((base - plinth * 0.5 + Vector2(0.0, 1.0)).round(), plinth), _side_dark.lerp(_fog, fog))
		var slices := clampi(int(base.distance_to(top) / 2.0) + 2, 2, 16)
		for i: int in range(slices):
			var u := float(i) / float(slices - 1)
			var at := base.lerp(top, u)
			var col := _side_dark.lerp(_side, u).lerp(_fog, fog)
			var fu := (foot * lerpf(1.0, taper, u)).round().max(Vector2(1.0, 1.0))
			var r := Rect2((at - fu * 0.5).round(), fu)
			draw_rect(r, col)
			draw_rect(Rect2(r.position + Vector2(r.size.x * 0.66, 0.0), Vector2(ceilf(r.size.x * 0.34), r.size.y)),
					col.darkened(0.3))
			if _windows and i % 3 == 1 and int(it.w + i) % 2 == 0:
				draw_rect(Rect2(r.position + Vector2(2.0, r.size.y * 0.4), Vector2(maxf(1.0, foot.x * 0.25), 1.0)),
						_trim.lerp(_fog, fog))
		var top_foot := (foot * taper).round().max(Vector2(1.0, 1.0))
		if capital:
			top_foot = (foot + Vector2(5.0, 3.0) * s).round()
		var cap_rect := Rect2((top - top_foot * 0.5).round(), top_foot)
		draw_rect(cap_rect, _cap.lerp(_fog, fog))
		draw_rect(Rect2(cap_rect.position, Vector2(cap_rect.size.x, 1.0)), _trim.lerp(_fog, fog))
		draw_rect(Rect2(cap_rect.position + Vector2(0.0, cap_rect.size.y - 1.0), Vector2(cap_rect.size.x, 1.0)),
				_side_dark.lerp(_fog, fog))


## Primeiro plano a 1,5x, por cima do campo: fitas de alga ondulando e bolhas subindo, só nas bordas do
## campo e nas laterais da tela (nunca no miolo, onde as balas precisam de leitura). Opacidade ≤ 0,35.
class ForegroundLayer:
	extends Node2D

	const KELP := Color(0.01, 0.07, 0.06, 0.34)
	const KELP_LIGHT := Color(0.2, 0.5, 0.4, 0.22)
	const BUBBLE := Color(0.75, 0.95, 1.0, 0.3)
	## Faixa do campo (de cada borda para dentro) onde o primeiro plano pode entrar.
	const EDGE := 14.0

	var offset: float = 0.0
	var cam: float = 0.0
	var field := Rect2(17, 114, 270, 450)
	var view_size := Vector2(305, 678)
	var kelp: bool = true
	var bubbles: bool = true
	var reduce_motion: bool = false
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta * (0.4 if reduce_motion else 1.0)

	func _draw() -> void:
		var anchors: Array[float] = []
		var left := field.position.x + cam
		var right := field.end.x + cam
		anchors.append_array([left - 7.0, left + 6.0, right - 6.0, right + 7.0])
		# Laterais largas (paisagem): mais algas espaçadas.
		var margin := field.position.x
		var n := mini(5, int(margin / 26.0))
		for i: int in range(n):
			anchors.append(left - 22.0 - i * 26.0)
			anchors.append(right + 22.0 + i * 26.0)
		if kelp:
			for i: int in range(anchors.size()):
				_strand(anchors[i], i)
		if bubbles:
			_bubbles(anchors)

	func _strand(x0: float, idx: int) -> void:
		var period := view_size.y + 260.0
		var length := 150.0 + float(absi(hash(idx * 31)) % 110)
		var phase := float(absi(hash(idx * 17)) % 628) / 100.0
		var y0 := fposmod(offset + idx * 211.0, period) - length - 40.0
		var seg := 4.0
		var count := int(length / seg)
		for k: int in range(count):
			var y := y0 + k * seg
			if y < -seg or y > view_size.y:
				continue
			var u := float(k) / float(count)
			var sway := sin(y * 0.045 + _time * 1.3 + phase) * (2.0 + 5.0 * u)
			var w := roundf(lerpf(6.0, 2.0, u))
			var x := roundf(x0 + sway - w * 0.5)
			draw_rect(Rect2(x, y, w, seg), KELP)
			if k % 5 == 2:
				var side := -1.0 if (k / 5) % 2 == 0 else 1.0
				draw_rect(Rect2(x + (w if side > 0.0 else -4.0), y + 1.0, 4.0, 2.0), KELP)
				draw_rect(Rect2(x + 1.0, y, 1.0, seg), KELP_LIGHT)

	func _bubbles(anchors: Array[float]) -> void:
		var step := 37.0
		var first := floori(-offset / step) - 1
		var last := first + ceili(view_size.y / step) + 2
		for i: int in range(first, last + 1):
			var h := absi(hash(i * 7907 + 3))
			if h % 3 != 0:
				continue
			var x := anchors[h % anchors.size()] + float((h >> 4) % 13) - 6.0
			x += sin(_time * 2.0 + i) * 2.0
			var y := i * step + offset - fposmod(_time * 14.0 + float(h % 50), 60.0)
			var big := (h >> 8) % 3 == 0
			var r := 3.0 if big else 2.0
			var p := Vector2(roundf(x), roundf(y))
			draw_rect(Rect2(p + Vector2(-r + 1.0, -r), Vector2(r * 2.0 - 2.0, 1.0)), BUBBLE)
			draw_rect(Rect2(p + Vector2(-r + 1.0, r - 1.0), Vector2(r * 2.0 - 2.0, 1.0)), BUBBLE)
			draw_rect(Rect2(p + Vector2(-r, -r + 1.0), Vector2(1.0, r * 2.0 - 2.0)), BUBBLE)
			draw_rect(Rect2(p + Vector2(r - 1.0, -r + 1.0), Vector2(1.0, r * 2.0 - 2.0)), BUBBLE)
			draw_rect(Rect2(p + Vector2(-r + 1.0, -r + 1.0), Vector2(1.0, 1.0)), Color(1, 1, 1, 0.35))


## Partículas de primeiro plano (chuva, brasas, neve, vento, estrelas, faíscas): riscos de 1 px em
## colunas sorteadas por hash da linha, como as outras camadas (iguais em qualquer aparelho).
class ParticleLayer:
	extends Node2D

	var color := Color(0.75, 0.85, 1.0, 0.22)
	var length: int = 4
	var step: float = 17.0
	var offset: float = 0.0
	var slant: float = 0.35
	var view_size := Vector2(305, 678)

	func _draw() -> void:
		var first := floori(-offset / step) - 1
		var last := first + ceili(view_size.y / step) + 2
		for i: int in range(first, last):
			var h := absi(hash(i * 7907))
			for k: int in range(3):
				var x := float((h >> (k * 6)) % maxi(1, int(view_size.x) + 40)) - 20.0
				var y := i * step + offset + float((h >> (k * 4 + 3)) % int(step))
				for s: int in range(length):
					draw_rect(Rect2(x + slant * s * 3.0, y + s * 3.0, 1.0, 3.0 if length > 1 else 1.0), color)
