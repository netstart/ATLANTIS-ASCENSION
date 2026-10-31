class_name SpriteBank
extends RefCounted
## Texturas das naves por id de sprite (data/enemies.json, data/bosses.json): base, motor animado e
## destruição animada, todas em tiras horizontais de quadros quadrados (padrão da série Void).
## As naves Void apontam para cima; inimigos são desenhados espelhados na vertical.

const SPRITES := {
	&"klaed_scout": "res://assets/art/void/klaed/scout_%s.png",
	&"klaed_fighter": "res://assets/art/void/klaed/fighter_%s.png",
	&"klaed_support": "res://assets/art/void/klaed/support_%s.png",
	&"klaed_frigate": "res://assets/art/void/klaed/frigate_%s.png",
	&"klaed_dreadnought": "res://assets/art/void/klaed/dreadnought_%s.png",
}
const GENERATED := "res://assets/art/generated/%s.png"

static var _cache: Dictionary = {}
static var _textures: Dictionary = {}


## {base, engine, engine_frames, destruction, destruction_frames, size} de um sprite.
static func ship(id: StringName) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var pattern: String = SPRITES.get(id, SPRITES[&"klaed_scout"])
	var base := texture(pattern % "base")
	var size := base.get_height() if base != null else 64
	var engine := texture(pattern % "engine")
	var destruction := texture(pattern % "destruction")
	var entry := {
		"base": base, "size": size,
		"engine": engine, "engine_frames": maxi(1, engine.get_width() / size) if engine != null else 1,
		"destruction": destruction,
		"destruction_frames": maxi(1, destruction.get_width() / size) if destruction != null else 1,
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
