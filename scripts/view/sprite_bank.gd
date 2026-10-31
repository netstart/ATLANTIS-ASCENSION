class_name SpriteBank
extends RefCounted
## Texturas das naves por id de sprite (data/enemies.json, data/bosses.json): base, motor animado e
## destruição animada, todas em tiras horizontais de quadros quadrados (padrão da série Void).
## As naves Void apontam para cima; inimigos são desenhados espelhados na vertical.

## Id de sprite = "<frota>_<tipo>" (klaed, nairan, nautolan × scout, fighter, bomber, support, frigate,
## torpedo, battlecruiser, dreadnought) → res://assets/art/void/<frota>/<tipo>_<camada>.png.
const VOID_PATH := "res://assets/art/void/%s/%s_%s.png"
## Sprites próprios (glifos atlantes): só base, explosão do asteroide Void.
const SPECIAL := {&"glyph": "enemies/glyph"}
const GENERATED := "res://assets/art/generated/%s.png"

static var _cache: Dictionary = {}
static var _textures: Dictionary = {}


## {base, engine, engine_frames, destruction, destruction_frames, size} de um sprite.
static func ship(id: StringName) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var base: Texture2D
	var engine: Texture2D
	var destruction: Texture2D
	if SPECIAL.has(id):
		base = generated(String(SPECIAL[id]))
		destruction = texture("res://assets/art/void/environment/asteroid_explode.png")
	else:
		var fleet := String(id).get_slice("_", 0)
		var kind := String(id).get_slice("_", 1)
		if fleet.is_empty() or kind.is_empty():
			fleet = "klaed"
			kind = "scout"
		base = texture(VOID_PATH % [fleet, kind, "base"])
		engine = texture(VOID_PATH % [fleet, kind, "engine"])
		destruction = texture(VOID_PATH % [fleet, kind, "destruction"])
	var size := base.get_height() if base != null else 64
	var entry := {
		"base": base, "size": size,
		"engine": engine, "engine_frames": maxi(1, engine.get_width() / size) if engine != null else 1,
		"destruction": destruction,
		"destruction_frames": maxi(1, destruction.get_width() / destruction.get_height()) if destruction != null else 1,
		"destruction_size": destruction.get_height() if destruction != null else size,
	}
	_cache[id] = entry
	return entry


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


## Retângulo do quadro `index` numa tira horizontal de quadros `size` x `size`.
static func frame_rect(index: int, size: int) -> Rect2:
	return Rect2(index * size, 0, size, size)


## Esquece as texturas (saída do jogo e testes: nada de recurso preso no encerramento).
static func clear() -> void:
	_cache.clear()
	_textures.clear()
	ShipLivery.clear()
