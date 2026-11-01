class_name StyleCallouts
extends Control
## Camada das frases dos Ecos de Estilo (StyleTracker) sobre o campo: cada frase entra grande com
## salto, sobe um pouco e some em ~1,2 s. No máximo MAX_LIVE ao mesmo tempo (a mais velha sai); quatro
## degraus de destaque (tier): ciano, menta, ouro e violeta, cada um maior que o anterior.
## "Reduzir movimento" troca o salto e a subida por um fade simples.

const MAX_LIVE := 3
const LIFE := 1.2
const RISE := 18.0
const SIZES: Array[int] = [15, 17, 20, 24]
const COLORS: Array[Color] = [UiTheme.CYAN, UiTheme.MINT, UiTheme.GOLD, UiTheme.VIOLET]
## Altura da faixa das frases no campo (fração a partir do topo).
const ANCHOR_Y := 0.2

var reduced: bool = false
var _live: Array[Label] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Mostra uma frase; devolve o rótulo (testes).
func pop(text: String, tier: int) -> Label:
	tier = clampi(tier, 0, SIZES.size() - 1)
	if _live.size() >= MAX_LIVE:
		var old: Label = _live.pop_front()
		old.queue_free()
	var label := UiTheme.heading(text, SIZES[tier], COLORS[tier])
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", UiTheme.ABYSS)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color(COLORS[tier], 0.55))
	add_child(label)
	label.size = Vector2(size.x, 0)
	label.reset_size()
	label.size.x = size.x
	# Frases ao mesmo tempo empilham para baixo, uma linha por frase viva.
	label.position = Vector2(0, floorf(size.y * ANCHOR_Y + _live.size() * (SIZES[1] + 8.0)))
	label.pivot_offset = Vector2(size.x * 0.5, label.size.y * 0.5)
	_live.append(label)
	var t := label.create_tween().set_parallel()
	if reduced:
		label.modulate.a = 0.0
		t.tween_property(label, "modulate:a", 1.0, 0.12)
	else:
		label.scale = Vector2.ONE * 1.7
		t.tween_property(label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(label, "position:y", label.position.y - RISE, LIFE).set_trans(Tween.TRANS_SINE) \
				.set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, LIFE * 0.35).set_delay(LIFE * 0.65)
	t.chain().tween_callback(_expire.bind(label))
	return label


func live_count() -> int:
	return _live.size()


func _expire(label: Label) -> void:
	_live.erase(label)
	if is_instance_valid(label):
		label.queue_free()
