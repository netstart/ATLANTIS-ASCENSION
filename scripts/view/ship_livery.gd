class_name ShipLivery
extends RefCounted
## Evolução da aeronave pelo nível do hangar (1.26): cada nível do 2 ao 10 monta uma PEÇA FÍSICA nova no casco,
## cumulativa, no mesmo acabamento metálico HD da nave (data/livery.json "levels", nome em livery.<id>):
##   2 armor         placas de blindagem nos flancos;
##   3 wing_guns     canhões de asa (a boca acende; pisca a cada tiro quando a vista passa `firing`);
##   4 boosters      segundo par de motores, com chama própria (jatos daqui, a pós-combustão subindo);
##   5 fins          extensões de asa com friso aceso;
##   6 canards       estabilizadores perto do nariz;
##   7 missile_pods  casulos de mísseis;
##   8 sensor        domo sensor com antenas (cristal aceso);
##   9 coils         bobinas de energia (pulsam) e as runas que sobem pela espinha;
##  10 crown         Ascendida: coroa de ouro na popa e acabamento de ouro em placas, canhões, motores e aletas.
## A arte montada vem pronta de tools/gen_livery.py: <nave>_evo.png (um quadro por nível 2..10, do tamanho da base,
## então a nave desenha no mesmo retângulo), <nave>_evo_glow.png (a silhueta de cada quadro) e <nave>_jet.png.
## A luz por cima reforça as peças ("lights": brilho de acento, pós-combustão, luzes de navegação nas pontas das
## aletas, aura, cristal, runas e o pulso de ouro da Ascendida). Âncoras e "points" valem para o gerador e para cá.
## Só desenho: a Sim nunca lê isto. Com "reduzir flashes" (`calm`) o que pisca fica aceso, sem piscar.

const DATA := "res://data/livery.json"
const PATH := "res://assets/art/generated/livery/%s.png"
const PORT := Color(1.0, 0.25, 0.3)
const STARBOARD := Color(0.3, 1.0, 0.55)
const CRYSTAL := Color(0.35, 0.95, 1.0)
const GOLD := Color(1.0, 0.84, 0.4)
## Acento sem dados (nave fora da tabela): ciano do jogo.
const DEFAULT_ACCENT := Color(0.44, 0.91, 1.0)
## Peças em par (espelhadas); as outras ficam no eixo.
const CENTER: Array[StringName] = [&"sensor", &"crown"]
## Quadros do jato (tools/gen_livery.py JET): 6 de cruzeiro e 6 de potência, boca no alto (y = 1 unidade).
const JET_FRAMES := 6
const JET_UNITS := 24.0

static var _data: Dictionary = {}
static var _tex: Dictionary = {}
static var _evo: Dictionary = {}
static var _glow: Texture2D
static var _ring: Texture2D


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"levels": [], "ships": {}}
	return _data


## Peças em ordem de nível: [{id, level}].
static func parts() -> Array:
	return data().get("levels", [])


## Peças montadas num nível (cumulativas).
static func parts_at(level: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in parts():
		if int(p["level"]) <= level:
			out.append(StringName(String(p["id"])))
	return out


## Peça que o próximo nível acrescenta ({} no máximo).
static func next_part(level: int) -> Dictionary:
	for p: Dictionary in parts():
		if int(p["level"]) > level:
			return {"id": StringName(String(p["id"])), "level": int(p["level"])}
	return {}


## Peça que chega exatamente neste nível (&"" no nível 1).
static func part_at(level: int) -> StringName:
	for p: Dictionary in parts():
		if int(p["level"]) == level:
			return StringName(String(p["id"]))
	return &""


## Nível em que uma peça ou uma luz ("lights") acende (99 se não existe).
static func level_of(id: StringName) -> int:
	for p: Dictionary in parts():
		if StringName(String(p["id"])) == id:
			return int(p["level"])
	return int((data().get("lights", {}) as Dictionary).get(String(id), 99))


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


## Opacidade do brilho de acento (0 antes da luz accent_glow).
static func glow_alpha(level: int) -> float:
	var at := level_of(&"accent_glow")
	if level < at:
		return 0.0
	var a: Array = (data().get("glow", {}) as Dictionary).get("alpha", [0.16, 0.4])
	return lerpf(float(a[0]), float(a[1]), clampf(float(level - at) / float(Economy.SHIP_MAX_LEVEL - at), 0.0, 1.0))


## Ponto de uma âncora (fração da caixa opaca) em unidades lógicas, com o centro da nave na origem.
static func point(art: Dictionary, frac: Variant, mirror: bool = false) -> Vector2:
	var used: Rect2 = art.get("used", Rect2(-12, -12, 24, 24))
	var f := Vector2(float((frac as Array)[0]), float((frac as Array)[1]))
	if mirror:
		f.x = 1.0 - f.x
	return used.position + used.size * f


## Escala das peças desta nave: a caixa opaca menor sobre "scale.ref", entre min e max (ou o "k" da nave).
## A mesma conta do tools/gen_livery.py (ship_scale).
static func scale_of(art: Dictionary) -> float:
	var a := anchors(StringName(String(art.get("id", ""))))
	if a.has("k"):
		return float(a["k"])
	var sc: Dictionary = data().get("scale", {})
	var used: Rect2 = art.get("used", Rect2(-12, -12, 24, 24))
	return clampf(minf(used.size.x, used.size.y) / float(sc.get("ref", 40.0)), float(sc.get("min", 0.8)),
			float(sc.get("max", 1.15)))


## Pontos de uma peça montada (unidades, centro da nave na origem): a âncora mais o "points"[key] na escala da
## nave, nos dois lados nas peças em par. Vazio se a nave não tem a peça.
static func part_points(art: Dictionary, part: StringName, key: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a := anchors(StringName(String(art.get("id", ""))))
	if not a.has(String(part)):
		return out
	var off_raw: Array = (data().get("points", {}) as Dictionary).get(key, [0.0, 0.0])
	var off := Vector2(float(off_raw[0]), float(off_raw[1])) * scale_of(art)
	for mirror: bool in ([false] if part in CENTER else [false, true]):
		out.append(point(art, a[String(part)], mirror) + Vector2(-off.x if mirror else off.x, off.y))
	return out


static func texture(id: String) -> Texture2D:
	if not _tex.has(id):
		_tex[id] = SpriteBank.texture(PATH % id)
	return _tex[id]


## Emblema de uma peça (ladrilhos da Oficina): a peça montada numa nave genérica apagada.
static func icon(id: StringName) -> Texture2D:
	return texture("icon_" + String(id))


## Arte montada da nave ({evo, glow, jet}, texturas nulas na Void ou sem arte gerada).
static func evo(art: Dictionary) -> Dictionary:
	var id := String(art.get("id", ""))
	if not _evo.has(id):
		var hd := bool(art.get("hd", false))
		_evo[id] = {
			"evo": SpriteBank.texture(SpriteBank.HD_PATH % ["player", id, "evo"]) if hd else null,
			"glow": SpriteBank.texture(SpriteBank.HD_PATH % ["player", id, "evo_glow"]) if hd else null,
			"jet": SpriteBank.texture(SpriteBank.HD_PATH % ["player", id, "jet"]) if hd else null,
		}
	return _evo[id]


## Casco do nível: [textura, região]. Do nível 2 em diante o quadro montado; antes (ou sem arte), a base.
static func hull(art: Dictionary, level: int) -> Array:
	var tex_size: int = art["tex_size"]
	var tex: Texture2D = evo(art)["evo"] if level >= 2 else null
	if tex == null:
		return [art.get("base"), Rect2(0, 0, tex_size, tex_size)]
	var frame := clampi(level - 2, 0, tex.get_width() / tex_size - 1)
	return [tex, SpriteBank.frame_rect(frame, tex_size)]


## Silhueta borrada do nível (o brilho de acento e o pulso de ouro contornam as peças também).
static func _silhouette(art: Dictionary, level: int) -> Array:
	var tex: Texture2D = evo(art)["glow"] if level >= 2 else null
	if tex == null:
		var g: Texture2D = art.get("glow")
		return [g, Rect2(Vector2.ZERO, g.get_size()) if g != null else Rect2()]
	var side := tex.get_height()
	return [tex, SpriteBank.frame_rect(clampi(level - 2, 0, tex.get_width() / side - 1), side)]


## Por baixo do casco: aura, brilho de acento, o pulso de borda da Ascendida e os jatos dos propulsores.
static func draw_under(ci: CanvasItem, art: Dictionary, level: int, accent_color: Color, time: float,
		alpha: float = 1.0, calm: bool = false, thrust: bool = false, boost: float = 1.0) -> void:
	if level < 2:
		return
	_load()
	var used: Rect2 = art.get("used", Rect2(-12, -12, 24, 24))
	var breathe := 0.5 + 0.5 * sin(time * 2.2) if not calm else 0.6
	var ascended := has(level, &"ascended")
	if has(level, &"aura"):
		var col := GOLD if ascended else accent_color
		var reach := maxf(used.size.x, used.size.y)
		_ring_at(ci, used.get_center(), reach * (1.15 + 0.05 * breathe), Color(col, (0.16 + 0.08 * breathe) * alpha))
		_glow_at(ci, used.get_center(), reach * 1.2 / 32.0, Color(col, (0.06 + 0.04 * breathe) * alpha))
	_jets(ci, art, level, time, alpha, thrust, boost)
	var sil := _silhouette(art, level)
	var glow: Texture2D = sil[0]
	if glow == null:
		return
	var size := float(art.get("size", 48.0))
	var rect := Rect2(-size * 0.5, -size * 0.5, size, size)
	var a := glow_alpha(level)
	if a > 0.0:
		ci.draw_texture_rect_region(glow, rect, sil[1], Color(accent_color, a * alpha))
	if ascended:
		# Pulso de borda: a silhueta montada um pouco maior, em ouro, batendo devagar.
		var pulse := 0.5 + 0.5 * sin(time * 3.0) if not calm else 0.6
		var grow := size * (1.05 + 0.03 * pulse)
		ci.draw_texture_rect_region(glow, Rect2(-grow * 0.5, -grow * 0.5, grow, grow), sil[1],
				Color(GOLD, (0.14 + 0.16 * pulse) * alpha))


## Chama dos propulsores extras: cresce com o nível como a principal e vira pluma de potência subindo.
static func _jets(ci: CanvasItem, art: Dictionary, level: int, time: float, alpha: float, thrust: bool,
		boost: float) -> void:
	if not has(level, &"boosters"):
		return
	var tex: Texture2D = evo(art)["jet"]
	if tex == null:
		return
	var fb := flame(level)
	var k := scale_of(art)
	var s := fb.x * boost
	var side := tex.get_height()
	var frame := int(time * ShipArt.ANIM_FPS) % JET_FRAMES + (JET_FRAMES if thrust and has(level, &"afterburner") else 0)
	var w := JET_UNITS * k * (1.0 + (s - 1.0) * 0.35)
	var h := JET_UNITS * k * s
	for at: Vector2 in part_points(art, &"boosters", "jet"):
		var rect := Rect2(at.x - w * 0.5, at.y - h / JET_UNITS, w, h)
		ci.draw_texture_rect_region(tex, rect, SpriteBank.frame_rect(frame, side), Color(fb.y, fb.y, fb.y, alpha))


## Por cima do casco: boca dos canhões, luzes de navegação nas aletas, cristal do sensor, bobinas e runas.
static func draw_over(ci: CanvasItem, art: Dictionary, level: int, accent_color: Color, time: float,
		alpha: float = 1.0, calm: bool = false, firing: bool = false) -> void:
	if level < 2:
		return
	_load()
	var a := anchors(StringName(String(art.get("id", ""))))
	if a.is_empty():
		return
	var k := scale_of(art)
	if has(level, &"wing_guns"):
		# Boca acesa; atirando, lampeja no ritmo da rajada (12 Hz), salvo em "reduzir flashes".
		var flash := 0.35
		if firing:
			flash = 0.9 if calm or fposmod(time * 12.0, 1.0) < 0.5 else 0.45
		for at: Vector2 in part_points(art, &"wing_guns", "muzzle"):
			_glow_at(ci, at, 0.22 * k * (0.8 + 0.6 * flash), Color(accent_color.lightened(0.3), flash * alpha))
	if has(level, &"nav_lights"):
		_nav_lights(ci, art, time, alpha, calm)
	if has(level, &"sensor"):
		var pulse := 0.75 + 0.25 * sin(time * 4.0) if not calm else 0.85
		for at: Vector2 in part_points(art, &"sensor", "sensor"):
			_glow_at(ci, at, 0.3 * k * pulse, Color(CRYSTAL, 0.7 * alpha))
	if has(level, &"runes"):
		# Bobinas pulsando, uma meia fase atrás da outra, e a centelha subindo pela espinha.
		var coils := part_points(art, &"coils", "coil")
		for i: int in range(coils.size()):
			var beat := 0.5 + 0.5 * sin(time * 3.0 + float(i) * PI) if not calm else 0.7
			_glow_at(ci, coils[i], 0.26 * k * (0.7 + 0.3 * beat), Color(accent_color, 0.4 * beat * alpha))
		if a.has("spine"):
			var spine: Array = a["spine"]
			var top := point(art, spine[0])
			var tail := point(art, spine[1])
			var spark := tail.lerp(top, fposmod(time * 0.8, 1.0))
			_glow_at(ci, spark, 0.2, Color(accent_color.lightened(0.4), 0.8 * alpha))


static func _nav_lights(ci: CanvasItem, art: Dictionary, time: float, alpha: float, calm: bool) -> void:
	var beat := 0.8 + 0.2 * sin(time * 6.0) if not calm else 0.9
	var tips := part_points(art, &"fins", "fin_tip")
	for i: int in range(tips.size()):
		var c: Color = PORT if i == 0 else STARBOARD
		_glow_at(ci, tips[i], 0.28 * beat, Color(c, 0.8 * alpha))
		ci.draw_rect(Rect2(tips[i] - Vector2(0.6, 0.6), Vector2(1.2, 1.2)), Color(c.lightened(0.5), alpha))
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
	_evo.clear()
	_glow = null
	_ring = null
