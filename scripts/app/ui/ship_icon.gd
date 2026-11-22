class_name ShipIcon
extends RefCounted
## Miniatura de uma aeronave do hangar (ladrilhos da Loja, da coleção de Naves e da Oficina, ícone da pintura no
## resultado): a base HD (SpriteBank.player) recortada na caixa opaca, com mipmaps, feita uma vez por nave e
## pintura e guardada. Os ladrilhos a desenham com filtro linear com mipmaps (pixel_art falso).
##
## A pintura é um verniz chapado por cima do casco (Image.blend_rect_mask, operação nativa: nada de laço por pixel
## em GDScript), na mesma força do modo pintura do shader da partida, para a miniatura bater com a nave em jogo.

## Força do verniz da pintura na miniatura (o shader da partida usa 0,72 preservando o sombreado).
const PAINT_ALPHA := 0.45

static var _cache: Dictionary = {}


static func texture(ship: String, paint: Color = Color(0, 0, 0, 0)) -> Texture2D:
	var key := "%s:%s" % [ship, paint.to_html(true) if paint.a > 0.0 else "-"]
	if _cache.has(key):
		return _cache[key]
	var art := SpriteBank.player(StringName(ship))
	var base: Texture2D = art.get("base")
	if base == null:
		return null
	var img := base.get_image()
	if img == null:
		return base
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	img = img.get_region(used)
	if paint.a > 0.0:
		var coat := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		coat.fill(Color(paint, PAINT_ALPHA))
		var mask := img.duplicate() as Image
		img.blend_rect_mask(coat, mask, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func clear() -> void:
	_cache.clear()
