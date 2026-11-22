class_name ShipLivery
extends RefCounted
## Evolução visual da aeronave pelo nível do hangar (1.25, naves HD): luz por cima da arte, nunca peças coladas
## no casco, então serve para qualquer nave do hangar. Um marco por nível do 2 ao 10 (data/livery.json "levels",
## nome em livery.<id>), todos cumulativos:
##   2 tuned_engine  a chama cresce e clareia com o nível (1,0 a 1,3x no nível 10; "flame");
##   3 accent_glow   brilho da silhueta (player/<id>_glow.png) na cor de acento, mais forte a cada nível ("glow");
##   4 afterburner   subindo, a nave troca a chama pela pluma de pós-combustão (engine_boost);
##   5 stripes       divisas do esquadrão nas âncoras "stripe" (espelhadas);
##   6 nav_lights    luzes de navegação nas pontas das asas ("wing") e estroboscópio na popa;
##   7 aura          anel de maré respirando sob a nave;
##   8 sensor        cristal aceso no nariz ("nose");
##   9 runes         centelha que sobe pela espinha ("spine") e runas pulsando nela;
##  10 trim          Ascendida: pulso de borda em ouro (o mesmo brilho da silhueta) e aura dourada; o WorldView
##                  ainda deixa o rastro de centelhas de ouro.
## Âncoras em fração da caixa opaca da base (SpriteBank.player "used"), por nave. Só desenho: a Sim nunca lê isto.
## A mesma função pinta a nave na partida (ShipArt, WorldView) e nos menus (ListScreen.ShipView). Com "reduzir
## flashes" (`calm`) o que pisca fica aceso, sem piscar.

const DATA := "res://data/livery.json"
const PATH := "res://assets/art/generated/livery/%s.png"
const PORT := Color(1.0, 0.25, 0.3)
const STARBOARD := Color(0.3, 1.0, 0.55)
const CRYSTAL := Color(0.35, 0.95, 1.0)
const GOLD := Color(1.0, 0.84, 0.4)
## Acento sem dados (nave fora da tabela): ciano do jogo.
const DEFAULT_ACCENT := Color(0.44, 0.91, 1.0)
## Lado da divisa em unidades lógicas.
const STRIPE := 6.0

static var _data: Dictionary = {}
static var _tex: Dictionary = {}
static var _glow: Texture2D
static var _ring: Texture2D


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"levels": [], "ships": {}}
	return _data


## Marcos em ordem de nível: [{id, level}].
static func parts() -> Array:
	return data().get("levels", [])


## Marcos acesos num nível (cumulativos).
static func parts_at(level: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in parts():
		if int(p["level"]) <= level:
			out.append(StringName(String(p["id"])))
	return out


## Marco que o próximo nível acrescenta ({} no máximo).
static func next_part(level: int) -> Dictionary:
	for p: Dictionary in parts():
		if int(p["level"]) > level:
			return {"id": StringName(String(p["id"])), "level": int(p["level"])}
	return {}


## Marco que chega exatamente neste nível (&"" no nível 1).
static func part_at(level: int) -> StringName:
	for p: Dictionary in parts():
		if int(p["level"]) == level:
			return StringName(String(p["id"]))
	return &""


## Nível em que um marco acende (99 se não existe).
static func level_of(id: StringName) -> int:
	for p: Dictionary in parts():
		if StringName(String(p["id"])) == id:
			return int(p["level"])
	return 99


static func has(level: int, id: StringName) -> bool:
	return level >= level_of(id)


## Âncoras de uma nave ({} fora da tabela).
static func anchors(ship_id: StringName) -> Dictionary:
	return (data().get("ships", {}) as Dictionary).get(String(ship_id), {})


## Acento: a pintura equipada (clareada) ou a cor da nave na tabela.
static func accent(ship_id: StringName, paint: Color = Color(0, 0, 0, 0)) -> Color:
	if paint.a > 0.0:
		return accent_of(paint)
	return Color(String(anchors(ship_id).get("accent", DEFAULT_ACCENT.to_html())))


## Acento de uma pintura: o matiz dela claro e saturado (as naves brancas/pérola ficam no ciano do jogo).
static func accent_of(tint: Color) -> Color:
	if tint.s < 0.15:
		return DEFAULT_ACCENT
	return Color.from_hsv(tint.h, 0.55, 1.0)


## Escala e brilho da chama no nível (1,0 no nível 1 até o máximo do "flame" no 10).
static func flame(level: int) -> Vector2:
	var f: Dictionary = data().get("flame", {})
	var u := clampf(float(level - 1) / float(Economy.SHIP_MAX_LEVEL - 1), 0.0, 1.0)
	var s: Array = f.get("scale", [1.0, 1.3])
	var b: Array = f.get("bright", [1.0, 1.35])
	return Vector2(lerpf(float(s[0]), float(s[1]), u), lerpf(float(b[0]), float(b[1]), u))


## Opacidade do brilho de acento (0 antes do marco).
static func glow_alpha(level: int) -> float:
	var at := level_of(&"accent_glow")
	if level < at:
		return 0.0
	var a: Array = (data().get("glow", {}) as Dictionary).get("alpha", [0.22, 0.55])
	return lerpf(float(a[0]), float(a[1]), clampf(float(level - at) / float(Economy.SHIP_MAX_LEVEL - at), 0.0, 1.0))


## Ponto de uma âncora (fração da caixa opaca) em unidades lógicas, com o centro da nave na origem.
static func point(art: Dictionary, frac: Variant, mirror: bool = false) -> Vector2:
	var used: Rect2 = art.get("used", Rect2(-12, -12, 24, 24))
	var f := Vector2(float((frac as Array)[0]), float((frac as Array)[1]))
	if mirror:
		f.x = 1.0 - f.x
	return used.position + used.size * f


static func texture(id: String) -> Texture2D:
	if not _tex.has(id):
		_tex[id] = SpriteBank.texture(PATH % id)
	return _tex[id]


## Emblema de um marco (ladrilhos da Oficina).
static func icon(id: StringName) -> Texture2D:
	return texture("icon_" + String(id))


## Por baixo do casco: aura, brilho de acento e o pulso de borda da Ascendida.
static func draw_under(ci: CanvasItem, art: Dictionary, level: int, accent_color: Color, time: float,
		alpha: float = 1.0, calm: bool = false) -> void:
	if level < 2:
		return
	_load()
	var used: Rect2 = art.get("used", Rect2(-12, -12, 24, 24))
	var center := used.get_center()
	var reach := maxf(used.size.x, used.size.y)
	var breathe := 0.5 + 0.5 * sin(time * 2.2) if not calm else 0.6
	var ascended := level >= Economy.SHIP_MAX_LEVEL
	if has(level, &"aura"):
		var col := GOLD if ascended else accent_color
		_ring_at(ci, center, reach * (1.15 + 0.05 * breathe), Color(col, (0.28 + 0.14 * breathe) * alpha))
		_glow_at(ci, center, reach * 1.2 / 32.0, Color(col, (0.08 + 0.05 * breathe) * alpha))
	var glow: Texture2D = art.get("glow")
	if glow == null:
		return
	var size := float(art.get("size", 48.0))
	var rect := Rect2(-size * 0.5, -size * 0.5, size, size)
	var a := glow_alpha(level)
	if a > 0.0:
		ci.draw_texture_rect(glow, rect, false, Color(accent_color, a * alpha))
	if ascended:
		# Pulso de borda: a silhueta um pouco maior, em ouro, batendo devagar.
		var pulse := 0.5 + 0.5 * sin(time * 3.0) if not calm else 0.6
		var grow := size * (1.06 + 0.04 * pulse)
		ci.draw_texture_rect(glow, Rect2(-grow * 0.5, -grow * 0.5, grow, grow), false,
				Color(GOLD, (0.35 + 0.35 * pulse) * alpha))


## Por cima do casco: divisas, luzes de navegação, cristal e runas.
static func draw_over(ci: CanvasItem, art: Dictionary, level: int, accent_color: Color, time: float,
		alpha: float = 1.0, calm: bool = false) -> void:
	if level < 2:
		return
	_load()
	var a := anchors(StringName(String(art.get("id", ""))))
	if a.is_empty():
		return
	if has(level, &"stripes") and a.has("stripe"):
		var tex := texture("stripe")
		var col := Color(GOLD if level >= Economy.SHIP_MAX_LEVEL else accent_color, 0.9 * alpha)
		for mirror: bool in [false, true]:
			var at := point(art, a["stripe"], mirror)
			ci.draw_texture_rect(tex, Rect2(at - Vector2(STRIPE, STRIPE) * 0.5, Vector2(STRIPE, STRIPE)), false, col)
	if has(level, &"nav_lights") and a.has("wing"):
		_nav_lights(ci, art, a, time, alpha, calm)
	if has(level, &"sensor") and a.has("nose"):
		var pulse := 0.75 + 0.25 * sin(time * 4.0) if not calm else 0.85
		var nose := point(art, a["nose"])
		_glow_at(ci, nose, 0.32 * pulse, Color(CRYSTAL, 0.85 * alpha))
		ci.draw_rect(Rect2(nose - Vector2(0.75, 1.25), Vector2(1.5, 2.5)), Color(0.85, 1.0, 1.0, alpha))
	if has(level, &"runes") and a.has("spine"):
		var spine: Array = a["spine"]
		var top := point(art, spine[0])
		var tail := point(art, spine[1])
		var beat := 0.6 + 0.4 * (0.5 + 0.5 * sin(time * 3.0)) if not calm else 0.85
		for k: int in range(4):
			var at := tail.lerp(top, (float(k) + 0.5) / 4.0)
			ci.draw_rect(Rect2(at - Vector2(0.5, 1.0), Vector2(1.0, 2.0)), Color(accent_color.lightened(0.3), beat * alpha))
		var spark := tail.lerp(top, fposmod(time * 0.8, 1.0))
		_glow_at(ci, spark, 0.2, Color(accent_color.lightened(0.4), 0.9 * alpha))


static func _nav_lights(ci: CanvasItem, art: Dictionary, a: Dictionary, time: float, alpha: float, calm: bool) -> void:
	var beat := 0.8 + 0.2 * sin(time * 6.0) if not calm else 0.9
	for side: Array in [[false, PORT], [true, STARBOARD]]:
		var at := point(art, a["wing"], bool(side[0]))
		var c: Color = side[1]
		_glow_at(ci, at, 0.3 * beat, Color(c, 0.8 * alpha))
		ci.draw_rect(Rect2(at - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), Color(c.lightened(0.5), alpha))
	if calm:
		return
	# Estroboscópio da popa: dois lampejos curtos a cada 1,4 s, como nos aviões.
	var t := fposmod(time, 1.4)
	if t < 0.05 or (t > 0.16 and t < 0.21):
		var used: Rect2 = art.get("used", Rect2(-12, -12, 24, 24))
		_glow_at(ci, Vector2(used.get_center().x, used.end.y - 3.0), 0.4, Color(1, 1, 1, 0.9 * alpha))


static func _glow_at(ci: CanvasItem, at: Vector2, scale: float, color: Color) -> void:
	if _glow == null:
		return
	var size := _glow.get_size() * scale
	ci.draw_texture_rect(_glow, Rect2(at - size * 0.5, size), false, color)


## Anel liso (fx/ring_128) de diâmetro `diameter` em unidades lógicas.
static func _ring_at(ci: CanvasItem, at: Vector2, diameter: float, color: Color) -> void:
	if _ring == null:
		return
	var size := Vector2(diameter, diameter)
	ci.draw_texture_rect(_ring, Rect2(at - size * 0.5, size), false, color)


static func _load() -> void:
	if _glow == null:
		_glow = SpriteBank.generated("fx/glow_32")
		_ring = SpriteBank.generated("fx/ring_128")


## Esquece as texturas (junto com SpriteBank.clear()).
static func clear() -> void:
	_tex.clear()
	_glow = null
	_ring = null
