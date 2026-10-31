class_name OceanBackdrop
extends Node2D
## Cenário das missões em camadas de parallax (plano mestre 8.3). `kind` escolhe a paleta do capítulo:
## ocean (1, Atlântico), atlantis (2, cidade submersa), storm (3, chuva), volcanic (4, brasas), city (5, torres
## emersas), ice (6, neve), stratosphere (7, vento), orbit (8, estrelas) e core (9, faíscas). Camadas:
##   0 água (shader ocean_surface, fator 1,0 na própria textura procedural)
##   1 ruínas submersas que emergem no Ocean Shift (fator 0,6; mais lentas = mais fundas)
##   2 espuma e respingos de primeiro plano (fator 1,4; ≤ 35% de opacidade sobre o campo)
## Tudo procedural: só retângulos por quadro, nenhum polígono (docs/policies/qualidade.md).
## `emerge` (0..1) é o Ocean Shift: ruínas sobem do fundo escuro e ganham pedra e ouro.

const RUIN_FACTOR := 0.6
const SPRAY_FACTOR := 1.4
const TILE := 96.0
## Paletas por cenário: fundo, meio, raso, espuma e ruínas emersas de base.
const PALETTES := {
	&"ocean": {"deep": Color(0.024, 0.071, 0.165), "mid": Color(0.043, 0.157, 0.302), "shoal": Color(0.051, 0.235, 0.29),
			"foam": Color(0.7, 0.95, 1.0), "base_emerge": 0.0},
	&"atlantis": {"deep": Color(0.016, 0.086, 0.11), "mid": Color(0.035, 0.18, 0.2), "shoal": Color(0.09, 0.27, 0.25),
			"foam": Color(0.75, 1.0, 0.9), "base_emerge": 0.35},
	&"storm": {"deep": Color(0.035, 0.05, 0.08), "mid": Color(0.08, 0.1, 0.14), "shoal": Color(0.12, 0.16, 0.2),
			"foam": Color(0.8, 0.85, 0.95), "base_emerge": 0.0, "particles": &"rain"},
	&"volcanic": {"deep": Color(0.08, 0.02, 0.02), "mid": Color(0.17, 0.05, 0.03), "shoal": Color(0.26, 0.08, 0.03),
			"foam": Color(1.0, 0.55, 0.2), "base_emerge": 0.25, "particles": &"embers"},
	&"city": {"deep": Color(0.03, 0.04, 0.09), "mid": Color(0.06, 0.08, 0.16), "shoal": Color(0.1, 0.12, 0.22),
			"foam": Color(0.6, 0.8, 1.0), "base_emerge": 0.6},
	&"ice": {"deep": Color(0.06, 0.1, 0.15), "mid": Color(0.11, 0.18, 0.25), "shoal": Color(0.17, 0.27, 0.34),
			"foam": Color(0.95, 1.0, 1.0), "base_emerge": 0.3, "particles": &"snow"},
	&"stratosphere": {"deep": Color(0.05, 0.08, 0.18), "mid": Color(0.09, 0.14, 0.27), "shoal": Color(0.13, 0.2, 0.35),
			"foam": Color(0.9, 0.95, 1.0), "base_emerge": 0.0, "ruins": false, "particles": &"wind"},
	&"orbit": {"deep": Color(0.01, 0.01, 0.04), "mid": Color(0.03, 0.03, 0.08), "shoal": Color(0.06, 0.05, 0.12),
			"foam": Color(0.8, 0.8, 1.0), "base_emerge": 0.0, "ruins": false, "particles": &"stars"},
	&"core": {"deep": Color(0.06, 0.0, 0.06), "mid": Color(0.12, 0.02, 0.1), "shoal": Color(0.19, 0.04, 0.14),
			"foam": Color(1.0, 0.5, 0.6), "base_emerge": 0.0, "ruins": false, "particles": &"sparks"},
}
## Partículas de primeiro plano: cor, comprimento do risco, velocidade (x rolagem), inclinação, passo.
const PARTICLES := {
	&"rain": {"color": Color(0.75, 0.85, 1.0, 0.22), "length": 4, "speed": 3.0, "slant": 0.35, "step": 17.0},
	&"embers": {"color": Color(1.0, 0.6, 0.2, 0.45), "length": 1, "speed": -1.2, "slant": 0.1, "step": 29.0},
	&"snow": {"color": Color(1.0, 1.0, 1.0, 0.4), "length": 1, "speed": 0.7, "slant": 0.25, "step": 21.0},
	&"wind": {"color": Color(1.0, 1.0, 1.0, 0.1), "length": 8, "speed": 4.0, "slant": 0.0, "step": 31.0},
	&"stars": {"color": Color(1.0, 1.0, 1.0, 0.5), "length": 1, "speed": 0.25, "slant": 0.0, "step": 19.0},
	&"sparks": {"color": Color(1.0, 0.6, 0.7, 0.35), "length": 2, "speed": 1.5, "slant": -0.2, "step": 23.0},
}

var view_size := Vector2(305, 678)
var scroll: float = 0.0
var emerge: float = 0.0
var tilt := Vector2.ZERO
var detail: int = 2
var kind: StringName = &"ocean"
## Corrente ou vento atual (unidades/s): a espuma e a chuva derivam junto.
var drift := Vector2.ZERO

var _water: ColorRect
var _material: ShaderMaterial
var _ruins: RuinsLayer
var _spray: SprayLayer
var _rain: ParticleLayer
var _drift_offset := Vector2.ZERO


func _ready() -> void:
	_water = ColorRect.new()
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/ocean_surface.gdshader") as Shader
	_water.material = _material
	add_child(_water)
	_ruins = RuinsLayer.new()
	add_child(_ruins)
	_spray = SprayLayer.new()
	add_child(_spray)
	_rain = ParticleLayer.new()
	add_child(_rain)
	var palette: Dictionary = PALETTES.get(kind, PALETTES[&"ocean"])
	for key: String in ["deep", "mid", "shoal", "foam"]:
		_material.set_shader_parameter(key, palette[key])
	set_view(view_size)


func set_drift(value: Vector2) -> void:
	drift = value


func set_view(size: Vector2) -> void:
	view_size = size
	if _water != null:
		_water.size = size
		_material.set_shader_parameter("view_size", size)


func apply(p_scroll: float, p_emerge: float, p_tilt: Vector2 = Vector2.ZERO, reduce_motion: bool = false) -> void:
	scroll = p_scroll
	var palette: Dictionary = PALETTES.get(kind, PALETTES[&"ocean"])
	var base := float(palette["base_emerge"])
	emerge = clampf(base + p_emerge * (1.0 - base), 0.0, 1.0)
	if not reduce_motion:
		_drift_offset += drift * 0.02
	tilt = Vector2.ZERO if reduce_motion else p_tilt
	_material.set_shader_parameter("scroll", scroll)
	_material.set_shader_parameter("shallow", emerge)
	_material.set_shader_parameter("detail", float(detail))
	_ruins.position = ParallaxRig.layer_offset(0.0, RUIN_FACTOR, 0.0, tilt, 0.4, reduce_motion)
	_ruins.offset = scroll * RUIN_FACTOR
	_ruins.emerge = emerge
	_ruins.view_size = view_size
	_ruins.queue_redraw()
	_spray.visible = detail >= 1
	_spray.offset = scroll * SPRAY_FACTOR
	_spray.position = ParallaxRig.layer_offset(0.0, SPRAY_FACTOR, 0.0, tilt, 1.2, reduce_motion)
	_spray.position.x += fposmod(_drift_offset.x, 24.0) - 12.0
	_spray.view_size = view_size
	_spray.amount = 0.5 + 0.5 * emerge
	_spray.queue_redraw()
	_ruins.visible = bool(palette.get("ruins", true))
	var kind_p := StringName(String(palette.get("particles", "")))
	_rain.visible = PARTICLES.has(kind_p) and detail >= 1
	if _rain.visible:
		var cfg: Dictionary = PARTICLES[kind_p]
		_rain.color = cfg["color"]
		_rain.length = int(cfg["length"])
		_rain.step = float(cfg["step"])
		_rain.offset = scroll * float(cfg["speed"])
		_rain.slant = float(cfg["slant"]) + drift.x * 0.01
		_rain.view_size = view_size
		_rain.queue_redraw()


## Ruínas atlantes procedurais: colunas, arcos e escadarias por bloco de TILE unidades, sorteados por
## um hash do índice do bloco (o mesmo bloco sempre igual, em qualquer aparelho).
class RuinsLayer:
	extends Node2D

	const SUNK := Color(0.05, 0.17, 0.30, 0.55)
	const STONE := Color(0.44, 0.56, 0.58, 1.0)
	const STONE_DARK := Color(0.22, 0.31, 0.36, 1.0)
	const GOLD := Color(0.91, 0.72, 0.29, 1.0)

	var offset: float = 0.0
	var emerge: float = 0.0
	var view_size := Vector2(305, 678)

	func _draw() -> void:
		var first := floori((-offset) / OceanBackdrop.TILE) - 1
		var last := first + ceili(view_size.y / OceanBackdrop.TILE) + 2
		var stone := SUNK.lerp(STONE, emerge)
		var dark := SUNK.darkened(0.25).lerp(STONE_DARK, emerge)
		var trim := SUNK.lerp(GOLD, emerge * emerge)
		var shadow := Color(0.0, 0.02, 0.06, 0.25 + 0.25 * emerge)
		var lift := 4.0 * emerge
		for tile: int in range(first, last + 1):
			var h := absi(hash(tile * 7919))
			var y := tile * OceanBackdrop.TILE + offset
			for k: int in range(1 + h % 3):
				var x := float((h >> (k * 5)) % maxi(1, int(view_size.x) - 40)) + 8.0
				var kind := (h >> (k * 3 + 11)) % 3
				var yy := y + float((h >> (k * 4 + 2)) % 40)
				_structure(kind, Vector2(x, yy), stone, dark, trim, shadow, lift)

	func _structure(kind: int, at: Vector2, stone: Color, dark: Color, trim: Color, shadow: Color, lift: float) -> void:
		match kind:
			0:
				draw_rect(Rect2(at + Vector2(lift, lift), Vector2(12, 46)), shadow)
				draw_rect(Rect2(at, Vector2(12, 46)), stone)
				draw_rect(Rect2(at + Vector2(9, 0), Vector2(3, 46)), dark)
				draw_rect(Rect2(at + Vector2(-2, -3), Vector2(16, 3)), trim)
			1:
				draw_rect(Rect2(at + Vector2(lift, lift), Vector2(40, 34)), shadow)
				draw_rect(Rect2(at, Vector2(8, 34)), stone)
				draw_rect(Rect2(at + Vector2(32, 0), Vector2(8, 34)), stone)
				draw_rect(Rect2(at + Vector2(-2, -6), Vector2(44, 6)), dark)
				draw_rect(Rect2(at + Vector2(-2, -8), Vector2(44, 2)), trim)
			_:
				for s: int in range(3):
					var w := 34.0 - s * 9.0
					draw_rect(Rect2(at + Vector2(s * 4.5 + lift, s * 7.0 + lift), Vector2(w, 7)), shadow)
					draw_rect(Rect2(at + Vector2(s * 4.5, s * 7.0), Vector2(w, 7)), stone if s % 2 == 0 else dark)
				draw_rect(Rect2(at + Vector2(9, 21), Vector2(16, 2)), trim)


## Espuma e respingos de primeiro plano: traços curtos e claros, rápidos, sempre transparentes.
class SprayLayer:
	extends Node2D

	const COLOR := Color(0.82, 0.96, 1.0, 0.22)

	var offset: float = 0.0
	var amount: float = 0.5
	var view_size := Vector2(305, 678)

	func _draw() -> void:
		var step := 23.0
		var first := floori(-offset / step) - 1
		var last := first + ceili(view_size.y / step) + 2
		for i: int in range(first, last + 1):
			var h := absi(hash(i * 104729))
			if float(h % 100) / 100.0 > amount:
				continue
			var x := float(h % maxi(1, int(view_size.x)))
			var y := i * step + offset
			var w := 6.0 + float((h >> 7) % 14)
			draw_rect(Rect2(x, y, w, 1.0), COLOR)


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
