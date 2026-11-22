class_name ShipArt
extends RefCounted
## Desenho de uma aeronave do jogador (SpriteBank.player): chama animada, evolução do hangar (ShipLivery), casco
## com a pintura da loja e as avarias. Um só caminho para a nave na partida, a ala do co-op, o Fantasma do Abismo
## (WorldView) e as vistas dos menus (ListScreen.ShipView), para todas mudarem juntas.
##
## Quem chama põe o transform no centro da nave (posição, inclinação, zoom) e a camada com filtro linear com
## mipmaps (SpriteBank.HD_FILTER) e o material de shaders/sprite_flash.gdshader, que lê a pintura do modulate
## (paint_color). Sem pintura, a arte HD sai como é: a cor de data/ships.json não tinge a nave HD.
##
## Avarias (dano no casco): a 2/3 e a 1/3 o casco escurece um pouco e ganha rachaduras com brilho de faísca em
## pontos fixos dentro da parte opaca (damage_spots); o WorldView solta a fumaça desses mesmos pontos.

## Quadros por segundo da chama (o mesmo ANIM_FPS dos inimigos).
const ANIM_FPS := 12.0
## Escurecimento do casco por estágio de avaria (0: inteiro, 1: <= 2/3, 2: <= 1/3).
const DAMAGE_DARK: Array[float] = [1.0, 0.88, 0.76]
## Rachaduras por estágio de avaria.
const DAMAGE_CRACKS: Array[int] = [0, 2, 4]
const CRACK := 8.0
## Candidatos a ponto de avaria, em fração da caixa opaca: os que caem em pixel opaco valem (até 4).
const SPOT_FRACTIONS: Array[Vector2] = [Vector2(0.32, 0.42), Vector2(0.66, 0.58), Vector2(0.45, 0.72),
		Vector2(0.58, 0.3), Vector2(0.38, 0.6), Vector2(0.62, 0.45), Vector2(0.5, 0.5), Vector2(0.5, 0.35)]

static var _spots: Dictionary = {}
static var _material: ShaderMaterial


## Estágio de avaria pelo casco que resta (0, 1 ou 2).
static func damage_stage(hull: int, max_hull: int) -> int:
	var frac := float(hull) / maxf(1.0, float(max_hull))
	if frac <= 1.0 / 3.0 + 0.001:
		return 2
	if frac <= 2.0 / 3.0 + 0.001:
		return 1
	return 0


## Modulate que o shader de dano lê como pintura (alfa 6..7). Sem pintura (alfa 0), o branco com a opacidade.
static func paint_color(paint: Color, alpha: float, dark: float = 1.0) -> Color:
	if paint.a <= 0.0:
		return Color(dark, dark, dark, alpha)
	return Color(paint.r * dark, paint.g * dark, paint.b * dark, 6.0 + clampf(alpha, 0.0, 1.0))


## Material compartilhado das vistas de menu que desenham a nave pintada.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/sprite_flash.gdshader") as Shader
	return _material


## Uma nave inteira no transform atual. `thrust`: subindo (pós-combustão a partir do marco afterburner);
## `boost`: alongamento extra da chama (arrancada da saída); `damage`: estágio de avaria.
static func draw(ci: CanvasItem, art: Dictionary, time: float, level: int, alpha: float = 1.0,
		thrust: bool = false, paint: Color = Color(0, 0, 0, 0), calm: bool = false, damage: int = 0,
		boost: float = 1.0) -> void:
	var base: Texture2D = art.get("base")
	if base == null:
		return
	var tex_size: int = art["tex_size"]
	var size: float = art["size"]
	var half := Vector2(size, size) * 0.5
	var accent := ShipLivery.accent(StringName(String(art.get("id", ""))), paint)
	ShipLivery.draw_under(ci, art, level, accent, time, alpha, calm)
	_engine(ci, art, time, level, alpha, thrust, boost)
	var dark := DAMAGE_DARK[clampi(damage, 0, 2)]
	ci.draw_texture_rect_region(base, Rect2(-half, half * 2.0), Rect2(0, 0, tex_size, tex_size),
			paint_color(paint, alpha, dark))
	ShipLivery.draw_over(ci, art, level, accent, time, alpha, calm)
	if damage > 0:
		_cracks(ci, art, time, damage, alpha, calm)


## Bocais da nave para a fumaça do motor e a luz: dois pontos na popa da caixa opaca (unidades lógicas).
static func nozzles(art: Dictionary) -> Array[Vector2]:
	var used: Rect2 = art.get("used", Rect2(-12, -12, 24, 24))
	var spread := clampf(used.size.x * 0.16, 3.0, 9.0)
	var y := used.end.y + 1.0
	return [Vector2(used.get_center().x - spread, y), Vector2(used.get_center().x + spread, y)]


## Chama: a tira do motor esticada a partir da popa pelo nível (ShipLivery.flame) e mais clara; subindo, a pluma
## de pós-combustão (Void: sempre; HD: a partir do marco afterburner, antes só um pouco mais longa).
static func _engine(ci: CanvasItem, art: Dictionary, time: float, level: int, alpha: float, thrust: bool,
		boost: float) -> void:
	var tex: Texture2D = art.get("engine")
	var stretch := 1.0
	if thrust:
		if art.get("engine_boost") != null and (not bool(art.get("hd", false)) or ShipLivery.has(level, &"afterburner")):
			tex = art["engine_boost"]
		else:
			stretch = 1.12
	if tex == null:
		return
	var tex_size: int = art["tex_size"]
	var size: float = art["size"]
	var fb := ShipLivery.flame(level)
	var s := fb.x * stretch * boost
	var sx := 1.0 + (s - 1.0) * 0.35
	var used: Rect2 = art["used"]
	var tail := used.end.y - 1.0
	# Escala vertical ancorada na popa: a chama cresce para trás, a boca do bocal não sai do lugar.
	var rect := Rect2(-size * 0.5 * sx, tail + (-size * 0.5 - tail) * s, size * sx, size * s)
	var frames := maxi(1, tex.get_width() / tex_size)
	var f := int(time * ANIM_FPS) % frames
	ci.draw_texture_rect_region(tex, rect, SpriteBank.frame_rect(f, tex_size), Color(fb.y, fb.y, fb.y, alpha))


## Rachaduras com faísca nos pontos de avaria (determinísticos por nave).
static func _cracks(ci: CanvasItem, art: Dictionary, time: float, damage: int, alpha: float, calm: bool) -> void:
	var crack := ShipLivery.texture("crack")
	var glow := SpriteBank.generated("fx/glow_32")
	var spots := damage_spots(art)
	for i: int in range(mini(DAMAGE_CRACKS[clampi(damage, 0, 2)], spots.size())):
		var at := spots[i]
		if crack != null:
			ci.draw_texture_rect(crack, Rect2(at - Vector2(CRACK, CRACK) * 0.5, Vector2(CRACK, CRACK)), false,
					Color(1, 1, 1, 0.9 * alpha))
		var beat := 0.5 + 0.5 * sin(time * 9.0 + float(i) * 2.3) if not calm else 0.6
		if glow != null:
			var g := Vector2(7.0, 7.0) * (0.6 + 0.4 * beat)
			ci.draw_texture_rect(glow, Rect2(at - g * 0.5, g), false, Color(1.0, 0.55, 0.2, 0.55 * beat * alpha))


## Pontos de avaria da nave (unidades lógicas, centro na origem): candidatos de SPOT_FRACTIONS que caem em
## pixel opaco da base, lidos uma vez por nave.
static func damage_spots(art: Dictionary) -> Array[Vector2]:
	var key := String(art.get("id", "")) + ":" + str(art.get("tex_size", 0))
	if _spots.has(key):
		return _spots[key]
	var out: Array[Vector2] = []
	var base: Texture2D = art.get("base")
	var used: Rect2 = art.get("used", Rect2(-12, -12, 24, 24))
	var img := base.get_image() if base != null else null
	if img != null and img.is_compressed():
		img.decompress()
	var texel := float(art.get("tex_size", 1)) / maxf(1.0, float(art.get("size", 1.0)))
	for f: Vector2 in SPOT_FRACTIONS:
		var at := used.position + used.size * f
		if img != null:
			var px := Vector2i(((at + Vector2.ONE * float(art["size"]) * 0.5) * texel).floor())
			if px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height():
				continue
			if img.get_pixelv(px).a < 0.8:
				continue
		out.append(at)
		if out.size() >= 4:
			break
	_spots[key] = out
	return out


static func clear() -> void:
	_spots.clear()
	_material = null
