class_name Portraits
extends RefCounted
## Retratos dos personagens (plano mestre 3.2), gerados por tools/gen_portraits.py: 64x64, 3 expressões.
## O narrador não tem retrato. A expressão vem do campo "mood" da fala (calm quando falta).

const DIR := "res://assets/art/generated/portraits/%s_%s.png"
const MOODS: Array[String] = ["calm", "alert", "smile"]


static func path(speaker: String, mood: String) -> String:
	return DIR % [speaker, mood if mood in MOODS else "calm"]


## Textura do retrato ou null (narrador, personagem sem retrato).
static func texture(speaker: String, mood: String = "calm") -> Texture2D:
	var p := path(speaker, mood)
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## Retrato pronto para a interface: sem filtro (pixel art) e no tamanho pedido.
static func make_rect(size: float) -> TextureRect:
	var r := TextureRect.new()
	r.name = "Portrait"
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(size, size)
	r.size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
