class_name SpriteBank
extends RefCounted
## Texturas das naves por id de sprite (data/enemies.json, data/bosses.json) e por id de aeronave
## (data/ships.json): base e motor animado em tira horizontal de quadros quadrados.
##
## Preferência: a arte HD (tools/gen_hd_ships.py, res://assets/art/hd/<grupo>/<nome>_<camada>.png), pré-renderizada
## a 2 texels por unidade lógica; sem ela, a série Void (pixel art, 1 texel por unidade). Toda nave aponta para
## CIMA na textura; a vista gira os inimigos e o chefe em PI (não espelha: a luz de borda da HD já vem de baixo à
## direita na textura deles para cair de cima à esquerda na tela).
##
## Cada entrada separa o tamanho da textura do tamanho de desenho:
##   tex_size  lado do quadro em texels (retângulo de origem e frame_rect);
##   size      lado do quadro em unidades lógicas (retângulo de destino), tex_size / 2 na HD;
##   used      retângulo opaco da base em unidades lógicas, relativo ao centro (evolução, avarias, bocais);
##   destruction  tira de explosão da Void (null na HD: as mortes de CombatFx/WorldView a substituem).
## As texturas HD têm mipmaps no .import; quem as desenha usa filtro linear com mipmaps (HD_FILTER).

## Id de sprite = "<frota>_<tipo>" (klaed, nairan, nautolan × scout, fighter, bomber, support, frigate,
## torpedo, battlecruiser, dreadnought).
const HD_PATH := "res://assets/art/hd/%s/%s_%s.png"
const VOID_PATH := "res://assets/art/void/%s/%s_%s.png"
const VOID_PLAYER := "res://assets/art/void/main_ship/%s.png"
## Texels por unidade lógica da arte HD.
const HD_TEXELS := 2.0
const HD_FILTER := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
## Sprites próprios (glifos atlantes e alvos dos objetivos de fase): só base, explosão do asteroide Void.
const SPECIAL := {&"glyph": "enemies/glyph", &"prison_barge": "enemies/prison_barge",
		&"prison_pod": "enemies/prison_pod", &"protocol_beacon": "enemies/protocol_beacon"}
const GENERATED := "res://assets/art/generated/%s.png"

static var _cache: Dictionary = {}
static var _textures: Dictionary = {}


## Nave inimiga ou do chefe: {base, engine, engine_frames, tex_size, size, used, hd, destruction,
## destruction_frames, destruction_size}.
static func ship(id: StringName) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var entry: Dictionary
	if SPECIAL.has(id):
		entry = _entry(generated(String(SPECIAL[id])), null, null, null, 1.0)
		_set_destruction(entry, texture("res://assets/art/void/environment/asteroid_explode.png"))
	else:
		var fleet := String(id).get_slice("_", 0)
		var kind := String(id).get_slice("_", 1)
		if fleet.is_empty() or kind.is_empty():
			fleet = "klaed"
			kind = "scout"
		var base := texture(HD_PATH % [fleet, kind, "base"])
		if base != null:
			entry = _entry(base, texture(HD_PATH % [fleet, kind, "engine"]), null, null, 1.0 / HD_TEXELS)
		else:
			entry = _entry(texture(VOID_PATH % [fleet, kind, "base"]), texture(VOID_PATH % [fleet, kind, "engine"]),
					null, null, 1.0)
			_set_destruction(entry, texture(VOID_PATH % [fleet, kind, "destruction"]))
	_cache[id] = entry
	return entry


## Aeronave do jogador pelo id de data/ships.json: a mesma entrada, mais `engine_boost` (motor em potência, nave
## subindo), `glow` (silhueta borrada da evolução do hangar, null na Void) e `sheen` (tira do brilho que varre o
## casco, só nas naves premium; null nas outras).
static func player(ship_id: StringName) -> Dictionary:
	var key := StringName("player/" + String(ship_id))
	if _cache.has(key):
		return _cache[key]
	var entry: Dictionary
	var base := texture(HD_PATH % ["player", ship_id, "base"])
	if base != null:
		entry = _entry(base, texture(HD_PATH % ["player", ship_id, "engine"]),
				texture(HD_PATH % ["player", ship_id, "engine_boost"]), texture(HD_PATH % ["player", ship_id, "glow"]),
				1.0 / HD_TEXELS)
		entry["sheen"] = texture(HD_PATH % ["player", ship_id, "sheen"])
	else:
		entry = _entry(texture(VOID_PLAYER % "base_full"), texture(VOID_PLAYER % "engine_base_idle"),
				texture(VOID_PLAYER % "engine_base_powering"), null, 1.0)
	entry["id"] = ship_id
	_cache[key] = entry
	return entry


static func _entry(base: Texture2D, engine: Texture2D, boost: Texture2D, glow: Texture2D, texel: float) -> Dictionary:
	var tex_size := base.get_height() if base != null else 64
	var size := float(tex_size) * texel
	var entry := {
		"base": base, "engine": engine, "engine_boost": boost, "glow": glow, "hd": texel < 1.0,
		"tex_size": tex_size, "size": size,
		"engine_frames": maxi(1, engine.get_width() / tex_size) if engine != null else 1,
		"used": _used(base, texel), "destruction": null, "destruction_frames": 1, "destruction_size": tex_size,
	}
	return entry


static func _set_destruction(entry: Dictionary, tex: Texture2D) -> void:
	entry["destruction"] = tex
	if tex != null:
		entry["destruction_frames"] = maxi(1, tex.get_width() / tex.get_height())
		entry["destruction_size"] = tex.get_height()


## Retângulo opaco da base em unidades lógicas, com o centro do quadro na origem (lido uma vez por nave).
static func _used(base: Texture2D, texel: float) -> Rect2:
	if base == null:
		return Rect2(-12, -12, 24, 24)
	var side := Vector2(base.get_size())
	var img := base.get_image()
	var r := Rect2(Vector2.ZERO, side)
	if img != null:
		if img.is_compressed():
			img.decompress()
		r = Rect2(img.get_used_rect())
	return Rect2((r.position - side * 0.5) * texel, r.size * texel)


## Arte gerada pelo projeto (tools/gen_sprites.py): "bullets/orb_cyan_8", "pickups/medal"...
static func generated(name: String) -> Texture2D:
	return texture(GENERATED % name)


static func texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_textures[path] = tex
	return tex


## Retângulo do quadro `index` numa tira horizontal de quadros `tex_size` x `tex_size` (em texels).
static func frame_rect(index: int, tex_size: int) -> Rect2:
	return Rect2(index * tex_size, 0, tex_size, tex_size)


## Esquece as texturas (saída do jogo e testes: nada de recurso preso no encerramento).
static func clear() -> void:
	_cache.clear()
	_textures.clear()
	ShipLivery.clear()
	ShipArt.clear()
	ShipIcon.clear()
