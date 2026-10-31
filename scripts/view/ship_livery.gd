class_name ShipLivery
extends RefCounted
## Evolução visual da aeronave pelo nível do hangar: cada nível acima do 1 acrescenta uma peça, e as
## peças se acumulam até a nave Ascendida do nível 10. Só desenho: a Sim nunca lê isto, e a mesma
## função pinta a nave na partida (WorldView) e nos menus (ListScreen.ShipView).
##
## A arte é de tools/gen_livery.py: camadas de 48x48 alinhadas pixel a pixel à nave Void, desenhadas
## em (-24, -24) com o transform da nave já aplicado (inclinação e zoom valem para as peças também).
## Cada peça tem uma família de cor, para funcionar com qualquer tinta ou pintura da loja:
##   HULL   estrutura, tingida com a cor da nave (parece ter vindo de fábrica);
##   ACCENT faixas, runas e lâminas, tingidas com o acento (cor oposta à da nave, sempre legível);
##   METAL  oricalco, cristal e ouro com cor própria.
## O que pisca ou brilha (luzes de navegação, cristal, chamas, halo) é desenhado aqui com a textura
## de brilho; com "reduzir flashes" (`calm`) as luzes ficam acesas sem piscar.

enum Layer { UNDER, OVER }
enum Paint { HULL, ACCENT, METAL }

const PATH := "res://assets/art/generated/livery/%s.png"
const SIZE := 48.0
## Uma peça por nível, do 2 ao 10 (Economy.SHIP_MAX_LEVEL).
const PARTS: Array[Dictionary] = [
	{"id": &"stripes", "level": 2, "layer": Layer.OVER, "paint": Paint.ACCENT},
	{"id": &"nav_lights", "level": 3, "layer": Layer.OVER, "paint": Paint.METAL},
	{"id": &"canards", "level": 4, "layer": Layer.UNDER, "paint": Paint.HULL},
	{"id": &"sensor", "level": 5, "layer": Layer.OVER, "paint": Paint.METAL},
	{"id": &"armor", "level": 6, "layer": Layer.OVER, "paint": Paint.METAL},
	{"id": &"thrusters", "level": 7, "layer": Layer.UNDER, "paint": Paint.HULL},
	{"id": &"runes", "level": 8, "layer": Layer.OVER, "paint": Paint.ACCENT},
	{"id": &"blades", "level": 9, "layer": Layer.UNDER, "paint": Paint.ACCENT},
	{"id": &"trim", "level": 10, "layer": Layer.OVER, "paint": Paint.METAL},
]
## Pontos das peças animadas, em coordenadas da nave (centro em 0,0; nariz para cima).
const NAV_LEFT := Vector2(-13.5, 6.5)
const NAV_RIGHT := Vector2(13.5, 6.5)
const STROBE := Vector2(0.0, 12.0)
const SENSOR := Vector2(0.0, -16.5)
const NOZZLES: Array[Vector2] = [Vector2(-12.0, 14.5), Vector2(12.0, 14.5)]
const PORT := Color(1.0, 0.25, 0.3)
const STARBOARD := Color(0.3, 1.0, 0.55)
const CRYSTAL := Color(0.35, 0.95, 1.0)
const FLAME := Color(1.0, 0.55, 0.2)
const GOLD := Color(1.0, 0.84, 0.4)
## Acento das naves brancas/pérola (sem matiz para opor): coral.
const NEUTRAL_ACCENT := Color(1.0, 0.48, 0.43)

static var _tex: Dictionary = {}
static var _glow: Texture2D
static var _ring: Texture2D


## Peças acesas num nível (cumulativas).
static func parts_at(level: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in PARTS:
		if int(p["level"]) <= level:
			out.append(p["id"])
	return out


## Peça que o próximo nível acrescenta ({} no máximo).
static func next_part(level: int) -> Dictionary:
	for p: Dictionary in PARTS:
		if int(p["level"]) > level:
			return p
	return {}


## Peça que chega exatamente neste nível (&"" no nível 1).
static func part_at(level: int) -> StringName:
	for p: Dictionary in PARTS:
		if int(p["level"]) == level:
			return p["id"]
	return &""


## Acento da nave: o matiz oposto ao da tinta, claro e saturado (lê contra o casco).
static func accent_of(tint: Color) -> Color:
	if tint.s < 0.15:
		return NEUTRAL_ACCENT
	return Color.from_hsv(fposmod(tint.h + 0.5, 1.0), 0.62, 1.0)


static func texture(id: StringName) -> Texture2D:
	if not _tex.has(id):
		_tex[id] = SpriteBank.texture(PATH % id)
	return _tex[id]


## Peças por baixo do casco (canards, propulsores e chamas, lâminas, halo). `thrust`: subindo.
static func draw_under(ci: CanvasItem, level: int, tint: Color, time: float, alpha: float = 1.0,
		thrust: bool = false, calm: bool = false) -> void:
	if level < 2:
		return
	_load()
	var accent := accent_of(tint)
	if level >= 10:
		# Halo de ouro respirando atrás da nave Ascendida.
		var breathe := 0.5 + 0.5 * sin(time * 2.2)
		_glow_at(ci, Vector2(0, 2), 2.1, Color(GOLD, (0.16 + 0.08 * breathe) * alpha))
		_ring_at(ci, Vector2(0, 2), 1.45 + 0.05 * breathe, Color(GOLD, (0.22 + 0.12 * breathe) * alpha))
	for p: Dictionary in PARTS:
		if int(p["level"]) > level or p["layer"] != Layer.UNDER:
			continue
		var id: StringName = p["id"]
		if id == &"blades":
			var shimmer := 0.62 + 0.18 * sin(time * 5.0) if not calm else 0.72
			ci.draw_texture(texture(id), Vector2(-SIZE, -SIZE) * 0.5, Color(accent, shimmer * alpha))
			continue
		if id == &"thrusters":
			_flames(ci, time, alpha, thrust)
		ci.draw_texture(texture(id), Vector2(-SIZE, -SIZE) * 0.5, _paint(p, tint, accent, alpha))


## Peças por cima do casco (faixas, luzes, cristal, blindagem, runas, friso).
static func draw_over(ci: CanvasItem, level: int, tint: Color, time: float, alpha: float = 1.0,
		calm: bool = false) -> void:
	if level < 2:
		return
	_load()
	var accent := accent_of(tint)
	for p: Dictionary in PARTS:
		if int(p["level"]) > level or p["layer"] != Layer.OVER:
			continue
		var id: StringName = p["id"]
		var col := _paint(p, tint, accent, alpha)
		if id == &"runes":
			# Pulso lento e uma centelha que sobe pela espinha.
			col.a *= 0.6 + 0.4 * (0.5 + 0.5 * sin(time * 3.0)) if not calm else 0.85
		ci.draw_texture(texture(id), Vector2(-SIZE, -SIZE) * 0.5, col)
		match id:
			&"nav_lights":
				_nav_lights(ci, time, alpha, calm)
			&"sensor":
				var pulse := 0.75 + 0.25 * sin(time * 4.0) if not calm else 0.85
				_glow_at(ci, SENSOR, 0.32 * pulse, Color(CRYSTAL, 0.85 * alpha))
			&"runes":
				var y := lerpf(9.5, -3.5, fposmod(time * 0.8, 1.0))
				_glow_at(ci, Vector2(0.0, y), 0.18, Color(accent.lightened(0.4), 0.9 * alpha))
			&"trim":
				_glints(ci, time, alpha)


## Cor de uma peça pela família dela (Paint).
static func _paint(p: Dictionary, tint: Color, accent: Color, alpha: float) -> Color:
	match p["paint"]:
		Paint.HULL:
			return Color(tint, alpha)
		Paint.ACCENT:
			return Color(accent, alpha)
	return Color(1, 1, 1, alpha)


static func _nav_lights(ci: CanvasItem, time: float, alpha: float, calm: bool) -> void:
	var beat := 0.8 + 0.2 * sin(time * 6.0) if not calm else 0.9
	for side: Array in [[NAV_LEFT, PORT], [NAV_RIGHT, STARBOARD]]:
		var at: Vector2 = side[0]
		var c: Color = side[1]
		_glow_at(ci, at, 0.28 * beat, Color(c, 0.75 * alpha))
		ci.draw_rect(Rect2(at - Vector2(0.5, 0.5), Vector2(1, 1)), Color(c.lightened(0.5), alpha))
	if calm:
		return
	# Estroboscópio da cauda: dois lampejos curtos a cada 1,4 s, como nos aviões.
	var t := fposmod(time, 1.4)
	if t < 0.05 or (t > 0.16 and t < 0.21):
		_glow_at(ci, STROBE, 0.4, Color(1, 1, 1, 0.9 * alpha))


static func _flames(ci: CanvasItem, time: float, alpha: float, thrust: bool) -> void:
	for i: int in range(NOZZLES.size()):
		var at := NOZZLES[i]
		var flicker := 0.85 + 0.15 * sin(time * 40.0 + float(i) * 2.1)
		var length := (5.0 if thrust else 3.0) * flicker
		ci.draw_rect(Rect2(at.x - 1.0, at.y, 2.0, length), Color(FLAME, 0.95 * alpha))
		ci.draw_rect(Rect2(at.x - 0.5, at.y, 1.0, length * 0.6), Color(1.0, 0.95, 0.75, alpha))
		_glow_at(ci, at + Vector2(0, length * 0.5), 0.22 * flicker, Color(FLAME, 0.7 * alpha))


## Brilhos que correm pelo friso de ouro (posições fixas, um acende de cada vez).
static func _glints(ci: CanvasItem, time: float, alpha: float) -> void:
	var spots: Array[Vector2] = [Vector2(0, -13), Vector2(-14, 6), Vector2(14, 6), Vector2(-6, 9), Vector2(6, 9)]
	var k := int(time * 2.5) % spots.size()
	var f := fposmod(time * 2.5, 1.0)
	var s := sin(f * PI)
	var at := spots[k]
	_glow_at(ci, at, 0.3 * s, Color(1, 0.95, 0.75, 0.9 * alpha))
	ci.draw_rect(Rect2(at.x - 0.5, at.y - 1.5 * s, 1.0, 3.0 * s), Color(1, 1, 1, alpha * s))
	ci.draw_rect(Rect2(at.x - 1.5 * s, at.y - 0.5, 3.0 * s, 1.0), Color(1, 1, 1, alpha * s))


static func _glow_at(ci: CanvasItem, at: Vector2, scale: float, color: Color) -> void:
	if _glow == null:
		return
	var size := _glow.get_size() * scale
	ci.draw_texture_rect(_glow, Rect2(at - size * 0.5, size), false, color)


static func _ring_at(ci: CanvasItem, at: Vector2, scale: float, color: Color) -> void:
	if _ring == null:
		return
	var size := _ring.get_size() * scale
	ci.draw_texture_rect(_ring, Rect2(at - size * 0.5, size), false, color)


static func _load() -> void:
	if _glow == null:
		_glow = SpriteBank.generated("fx/glow_32")
		_ring = SpriteBank.generated("fx/ring_32")


## Esquece as texturas (junto com SpriteBank.clear()).
static func clear() -> void:
	_tex.clear()
	_glow = null
	_ring = null
