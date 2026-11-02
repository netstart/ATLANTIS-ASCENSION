class_name LoadoutArt
extends RefCounted
## Figuras e raridades da Oficina (1.15, aba de comando): o que aparece nos encaixes do palco e nos
## ladrilhos das sub-abas. Tudo montado em código a partir da arte que o projeto já tem, sem arte nova
## de terceiros, e guardado em cache (uma imagem por figura):
##
## - nave(tinta, nível): a aeronave Void tingida com a pintura e vestida com as peças do nível
##   (ShipLivery); serve de miniatura da pintura e do núcleo.
## - peça(id, tinta): a nave apagada como silhueta e só a peça daquele nível acesa, na família de cor
##   dela (casco, acento ou metal), para o jogador ver ONDE a peça entra.
## - secundária: o míssil (proj_rocket da série Void) ou três drones (fx/drone) em formação.
## - asa(efeito): emblema desenhado por distância (par de asas apagado e o símbolo do efeito em cor).
## - dificuldade: divisas empilhadas (uma a quatro) na cor da ameaça.
##
## A pixel art é ampliada por vizinho mais próximo até >= 96 px antes de virar textura (com mipmaps):
## ladrilhos e encaixes desenham com filtro linear em qualquer tamanho sem serrilhar nem borrar.
##
## Raridade (moldura do CommandKit) — derivada dos dados reais, nunca sorteada nem vendida:
## - peça da evolução e núcleo, pelo nível da nave: 1-4 comum, 5-7 rara, 8-9 épica, 10 lendária
##   (o friso Ascendido);
## - secundária, pelo nível dela: 0-1 comum, 2-3 rara, 4 épica, 5 lendária (sobe junto com a arma);
## - asa, pelas estrelas que a abrem: até 9 comum, até 18 rara, até 36 épica, acima lendária;
## - pintura, pelo preço em Pérolas: até 40 comum, até 90 rara, 120 épica; apoiador e temporada,
##   que não se compram com Pérolas, lendárias;
## - dificuldade, pela ameaça: Brisa comum, Normal rara, Veterano épica, Abissal lendária.

const SHIP_PATH := "res://assets/art/void/main_ship/base_full.png"
const ROCKET_PATH := "res://assets/art/void/main_ship/proj_rocket.png"
const DRONE_PATH := "res://assets/art/generated/fx/drone.png"
## Lado mínimo das figuras em pixels (a pixel art sobe em múltiplo inteiro até passar disto).
const MIN_SIDE := 96
## Resolução dos emblemas desenhados por distância.
const EMBLEM := 96
const WING_COLORS := {
	&"magnet": Color("ff8a8a"), &"shield_timer": Color("7fe9ff"), &"rear_cover": Color("5cf29b"),
	&"graze_bonus": Color("ffd76e"), &"log_finder": Color("f0dcae"), &"orb_luck": Color("8cf5a8"),
	&"damage": Color("ff6f8a"), &"invuln": Color("ffe08a"), &"chain_window": Color("c79bff"),
	&"medal_net": Color("ffc94a"), &"hitbox": Color("6ff6ea"), &"tide_bonus": Color("47d6c8"),
}
const DIFFICULTY_COLORS: Array[Color] = [Color("5cf29b"), Color("2ff3e0"), Color("ffc94a"), Color("ff4d6d")]

static var _cache: Dictionary = {}


# --- Raridade --------------------------------------------------------------------------------------

## Raridade pelo nível da nave (peça que entra nesse nível, ou o núcleo da nave nesse nível).
static func level_rarity(level: int) -> int:
	if level >= Economy.SHIP_MAX_LEVEL:
		return CommandKit.LEGENDARY
	if level >= 8:
		return CommandKit.EPIC
	if level >= 5:
		return CommandKit.RARE
	return CommandKit.COMMON


static func secondary_rarity(level: int) -> int:
	if level >= Economy.SECONDARY_MAX_LEVEL:
		return CommandKit.LEGENDARY
	if level >= 4:
		return CommandKit.EPIC
	if level >= 2:
		return CommandKit.RARE
	return CommandKit.COMMON


static func wing_rarity(stars: int) -> int:
	if stars > 36:
		return CommandKit.LEGENDARY
	if stars > 18:
		return CommandKit.EPIC
	if stars > 9:
		return CommandKit.RARE
	return CommandKit.COMMON


## Pintura pelo cosmético (`{}` = a pintura original da nave, comum).
static func paint_rarity(def: Dictionary) -> int:
	if bool(def.get("supporter", false)) or bool(def.get("season", false)):
		return CommandKit.LEGENDARY
	var pearls := int(def.get("pearls", 0))
	if pearls >= 120:
		return CommandKit.EPIC
	if pearls >= 60:
		return CommandKit.RARE
	return CommandKit.COMMON


static func difficulty_rarity(diff: StringName) -> int:
	return maxi(0, Economy.DIFFICULTIES.find(diff))


# --- Figuras ---------------------------------------------------------------------------------------

## A aeronave na `tint`, com as peças estáticas do `level` (sem chamas nem brilhos: é miniatura).
static func ship(tint: Color, level: int) -> Texture2D:
	var key := "ship:%s:%d" % [tint.to_html(), level]
	if _cache.has(key):
		return _cache[key]
	var base := _image(SHIP_PATH)
	if base == null:
		return null
	var out := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
	var accent := ShipLivery.accent_of(tint)
	for layer: int in [ShipLivery.Layer.UNDER, -1, ShipLivery.Layer.OVER]:
		if layer == -1:
			_stamp(out, base, tint)
			continue
		for p: Dictionary in ShipLivery.PARTS:
			if int(p["level"]) <= level and int(p["layer"]) == layer:
				_stamp(out, _image(ShipLivery.PATH % p["id"]), _paint(p, tint, accent))
	return _store(key, out)


## A nave como silhueta escura e só a peça `id` acesa (ladrilho da evolução).
static func part(id: StringName, tint: Color) -> Texture2D:
	var key := "part:%s:%s" % [id, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var base := _image(SHIP_PATH)
	if base == null:
		return null
	var out := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
	_stamp(out, base, Color(0.32, 0.46, 0.6, 0.6))
	for p: Dictionary in ShipLivery.PARTS:
		if p["id"] == id:
			_stamp(out, _image(ShipLivery.PATH % id), _paint(p, tint, ShipLivery.accent_of(tint)))
	return _store(key, out)


static func secondary(kind: StringName) -> Texture2D:
	var key := "secondary:%s" % kind
	if _cache.has(key):
		return _cache[key]
	var out: Image = null
	if kind == &"missiles":
		var strip := _image(ROCKET_PATH)
		if strip != null:
			var side := strip.get_height()
			out = strip.get_region(Rect2i(0, 0, side, side))
	else:
		var drone := _image(DRONE_PATH)
		if drone != null:
			# Três drones em cunha, como voam ao lado da nave.
			var d := drone.get_width()
			out = Image.create(d * 3, d * 3, false, Image.FORMAT_RGBA8)
			for at: Vector2i in [Vector2i(d, 0), Vector2i(0, d * 2 - d / 2), Vector2i(d * 2, d * 2 - d / 2)]:
				out.blend_rect(drone, Rect2i(Vector2i.ZERO, drone.get_size()), at)
	return _store(key, out) if out != null else null


## Emblema da asa: par de asas apagado atrás e o símbolo do efeito (data/wings.json "effect").
static func wing(effect: StringName) -> Texture2D:
	var key := "wing:%s" % effect
	if _cache.has(key):
		return _cache[key]
	var color: Color = WING_COLORS.get(effect, UiTheme.CYAN)
	var img := Image.create(EMBLEM, EMBLEM, false, Image.FORMAT_RGBA8)
	var left := PackedVector2Array([Vector2(0.47, 0.6), Vector2(0.04, 0.5), Vector2(0.02, 0.6), Vector2(0.3, 0.8),
			Vector2(0.47, 0.74)])
	var right := PackedVector2Array()
	for p: Vector2 in left:
		right.append(Vector2(1.0 - p.x, p.y))
	for y: int in range(EMBLEM):
		for x: int in range(EMBLEM):
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(EMBLEM)
			var out := Color(1, 1, 1, 0)
			var wings := minf(_poly_sd(p, left), _poly_sd(p, right))
			out = _over(out, Color("4f7590"), _cov(wings))
			out = _over(out, Color("9fc3da"), _cov(absf(wings) - 0.008) * 0.8)
			# Símbolo no círculo de cima (centro 0,5; 0,42; raio 0,3 em unidades do emblema).
			var q := (p - Vector2(0.5, 0.42)) / 0.3
			out = _over(out, Color(UiTheme.ABYSS, 0.85), _cov((q.length() - 1.0) * 0.3))
			out = _over(out, Color(color, 0.9), _cov((absf(q.length() - 1.0) - 0.06) * 0.3))
			out = _over(out, color, _cov(_symbol(effect, q) * 0.3))
			img.set_pixel(x, y, out)
	return _store(key, img, false)


## Divisas da dificuldade: uma por degrau de ameaça, na cor dele.
static func difficulty(diff: StringName) -> Texture2D:
	var key := "difficulty:%s" % diff
	if _cache.has(key):
		return _cache[key]
	var index := difficulty_rarity(diff)
	var color := DIFFICULTY_COLORS[index]
	var count := index + 1
	var img := Image.create(EMBLEM, EMBLEM, false, Image.FORMAT_RGBA8)
	var step := 0.16
	var top := 0.5 - step * float(count - 1) * 0.5 - 0.08
	for y: int in range(EMBLEM):
		for x: int in range(EMBLEM):
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(EMBLEM)
			var out := Color(1, 1, 1, 0)
			for i: int in range(count):
				var cy := top + step * float(i)
				var d := minf(_seg_d(p, Vector2(0.2, cy), Vector2(0.5, cy + 0.16)),
						_seg_d(p, Vector2(0.5, cy + 0.16), Vector2(0.8, cy)))
				out = _over(out, Color(UiTheme.ABYSS, 0.9), _cov(d - 0.075))
				out = _over(out, color.lightened(0.15 * float(i)), _cov(d - 0.05))
			img.set_pixel(x, y, out)
	return _store(key, img, false)


## Esquece as figuras (troca de pintura em teste, saída do jogo).
static func clear() -> void:
	_cache.clear()


# --- Montagem --------------------------------------------------------------------------------------

static func _image(path: String) -> Image:
	var tex := SpriteBank.texture(path)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Pinta `src` multiplicado por `tint` por cima de `dst` (mesmo tamanho).
static func _stamp(dst: Image, src: Image, tint: Color) -> void:
	if src == null:
		return
	var w := mini(dst.get_width(), src.get_width())
	var h := mini(dst.get_height(), src.get_height())
	for y: int in range(h):
		for x: int in range(w):
			var c := src.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var top := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a * tint.a)
			dst.set_pixel(x, y, _over(dst.get_pixel(x, y), Color(top, 1.0), top.a))


static func _paint(p: Dictionary, tint: Color, accent: Color) -> Color:
	match int(p["paint"]):
		ShipLivery.Paint.HULL:
			return tint
		ShipLivery.Paint.ACCENT:
			return accent
	return Color.WHITE


## Guarda a imagem como textura com mipmaps; pixel art (`pixel`) sobe antes em múltiplo inteiro.
static func _store(key: String, img: Image, pixel: bool = true) -> Texture2D:
	if pixel:
		img = _trim(img)
		var k := ceili(float(MIN_SIDE) / float(maxi(1, maxi(img.get_width(), img.get_height()))))
		if k > 1:
			img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Recorta a figura ao que tem pixel (mais 1 de folga) num quadrado centrado: o míssil de 32x32 com
## 6 px de largura enche o ladrilho em vez de virar um risco.
static func _trim(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	var side := maxi(used.size.x, used.size.y) + 2
	if side >= img.get_width() and side >= img.get_height():
		return img
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
	return out


# --- Símbolos das asas (distância com sinal em unidades do círculo: raio 1) -------------------------

static func _symbol(effect: StringName, q: Vector2) -> float:
	match effect:
		&"magnet":
			# Ímã em U: meio anel embaixo e duas pernas.
			var ring := absf(q.length() - 0.42) - 0.16 if q.y > -0.05 else 9.0
			var legs := minf(_rect_sd(q, Vector2(-0.42, -0.3), Vector2(0.16, 0.26)),
					_rect_sd(q, Vector2(0.42, -0.3), Vector2(0.16, 0.26)))
			return minf(ring, legs)
		&"shield_timer":
			return minf(absf(q.length() - 0.55) - 0.1, _seg_d(q, Vector2(0, 0), Vector2(0, -0.32)) - 0.08)
		&"rear_cover":
			var a := minf(_seg_d(q, Vector2(-0.45, -0.35), Vector2(0, 0.0)), _seg_d(q, Vector2(0, 0.0),
					Vector2(0.45, -0.35)))
			var b := minf(_seg_d(q, Vector2(-0.45, 0.05), Vector2(0, 0.4)), _seg_d(q, Vector2(0, 0.4),
					Vector2(0.45, 0.05)))
			return minf(a, b) - 0.11
		&"graze_bonus":
			return _poly_sd(q, _star(4, 0.7, 0.2))
		&"log_finder":
			var page := _rect_sd(q, Vector2.ZERO, Vector2(0.42, 0.55))
			var lines := 9.0
			for i: int in range(3):
				lines = minf(lines, _seg_d(q, Vector2(-0.24, -0.25 + 0.25 * float(i)),
						Vector2(0.24, -0.25 + 0.25 * float(i))) - 0.05)
			return maxf(page, -lines)
		&"orb_luck":
			var d := 9.0
			for v: Vector2 in [Vector2(0, -0.3), Vector2(0, 0.3), Vector2(-0.3, 0), Vector2(0.3, 0)]:
				d = minf(d, (q - v).length() - 0.26)
			return d
		&"damage":
			return _poly_sd(q, PackedVector2Array([Vector2(0, -0.8), Vector2(0.2, 0.25), Vector2(0, 0.6),
					Vector2(-0.2, 0.25)]))
		&"invuln":
			var halo := absf(((q - Vector2(0, -0.45)) * Vector2(1.0, 2.6)).length() - 0.5) - 0.18
			return minf(halo / 2.0, (q - Vector2(0, 0.25)).length() - 0.3)
		&"chain_window":
			return minf(absf((q - Vector2(-0.25, 0)).length() - 0.32) - 0.09,
					absf((q - Vector2(0.25, 0)).length() - 0.32) - 0.09)
		&"medal_net":
			# Rede: aro e fios em losango dentro dele.
			var disc := q.length() - 0.6
			var mesh := minf(absf(fposmod(q.x + q.y, 0.4) - 0.2), absf(fposmod(q.x - q.y, 0.4) - 0.2)) - 0.05
			return minf(absf(disc) - 0.08, maxf(disc, mesh))
		&"hitbox":
			return minf(absf(q.length() - 0.55) - 0.08, q.length() - 0.18)
		&"tide_bonus":
			var d := 9.0
			for row: float in [-0.22, 0.22]:
				var prev := Vector2(-0.6, row + sin(-0.6 * 6.0) * 0.12)
				for i: int in range(1, 13):
					var x := -0.6 + 1.2 * float(i) / 12.0
					var at := Vector2(x, row + sin(x * 6.0) * 0.12)
					d = minf(d, _seg_d(q, prev, at))
					prev = at
			return d - 0.08
	return _poly_sd(q, _star(5, 0.7, 0.3))


static func _star(points: int, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(points * 2):
		var r := outer if i % 2 == 0 else inner
		var a := -PI * 0.5 + PI * float(i) / float(points)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


# --- Distâncias (mesmo método dos ícones de ListScreen) --------------------------------------------

static func _cov(d: float) -> float:
	return clampf(0.5 - d * float(EMBLEM), 0.0, 1.0)


static func _over(dst: Color, src: Color, a: float) -> Color:
	var sa := src.a * a
	var oa := sa + dst.a * (1.0 - sa)
	if oa <= 0.0:
		return Color(src, 0.0)
	var rgb := (Color(src.r, src.g, src.b) * sa + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - sa)) / oa
	return Color(rgb.r, rgb.g, rgb.b, oa)


static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _rect_sd(p: Vector2, center: Vector2, half: Vector2) -> float:
	var q := (p - center).abs() - half
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


static func _poly_sd(p: Vector2, pts: PackedVector2Array) -> float:
	var d := INF
	var inside := false
	var j := pts.size() - 1
	for i: int in range(pts.size()):
		var a := pts[j]
		var b := pts[i]
		d = minf(d, _seg_d(p, a, b))
		if (b.y > p.y) != (a.y > p.y) and p.x < (a.x - b.x) * (p.y - b.y) / (a.y - b.y) + b.x:
			inside = not inside
		j = i
	return -d if inside else d
