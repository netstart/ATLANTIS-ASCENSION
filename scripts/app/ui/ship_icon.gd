class_name ShipIcon
extends RefCounted
## Miniatura da aeronave numa cor (ladrilhos da Loja e da coleção de Naves, CommandKit.ItemTile): a arte
## base de 48x48 tingida como na partida (multiplicação pela tinta), feita uma vez por cor e guardada.
## O ladrilho a desenha sem filtro e em escala inteira.

const BASE := "res://assets/art/void/main_ship/base_full.png"

static var _cache: Dictionary = {}


static func texture(tint: Color) -> Texture2D:
	var key := tint.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var base := SpriteBank.texture(BASE)
	if base == null:
		return null
	var img := base.get_image()
	if img == null:
		return base
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var paint := Color(tint, 1.0)
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			img.set_pixel(x, y, img.get_pixel(x, y) * paint)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
