class_name PowerChip
extends PanelContainer
## Selo dos Poderes I e II (.ai/08-poderes-das-naves.md): pílula pequena e translúcida no alto do campo, logo
## abaixo da barra do chefe ou da faixa do placar, com o ícone do poder, o nome e o nível na cor da nave. Fica
## SECONDS na tela, entra e sai rápido e nunca desce para a metade do jogador (o Poder III usa a HudBanner).

const SECONDS := 0.9
const FADE_IN := 0.1
const FADE_OUT := 0.22
const ICON := 16.0

var _icon: TextureRect
var _text: Label
var _left: float = 0.0
var _reduced := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(ICON, ICON)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_text = UiTheme.heading("", UiTheme.SMALL_SIZE + 1, UiTheme.WHITE)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_color_override("font_outline_color", UiTheme.ABYSS)
	_text.add_theme_constant_override("outline_size", 3)
	row.add_child(_text)


## Mostra o selo centrado em `center_x`, com o topo em `top`, sem passar de `max_w` de largura.
func pop(icon: Texture2D, text: String, tint: Color, center_x: float, top: float, max_w: float, reduced: bool) -> void:
	_reduced = reduced
	_icon.texture = icon
	_text.text = text
	_text.add_theme_color_override("font_color", tint.lerp(UiTheme.WHITE, 0.3))
	_text.clip_text = false
	var box := UiTheme.pill_box(tint)
	box.bg_color = Color(tint.darkened(0.85), 0.62)
	box.border_color = Color(tint, 0.75)
	box.shadow_color = Color(tint, 0.3)
	box.shadow_size = 4
	box.content_margin_left = 6
	box.content_margin_right = 9
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	add_theme_stylebox_override("panel", box)
	size = Vector2.ZERO
	reset_size()
	if size.x > max_w:
		_text.clip_text = true
		_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_text.custom_minimum_size.x = max_w - ICON - 25.0
		reset_size()
		size.x = max_w
	position = Vector2(roundf(center_x - size.x * 0.5), top)
	_left = SECONDS
	visible = true
	modulate.a = 1.0 if reduced else 0.0


func tick(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		visible = false
		return
	var since := SECONDS - _left
	modulate.a = 1.0 if _reduced else minf(clampf(since / FADE_IN, 0.0, 1.0), clampf(_left / FADE_OUT, 0.0, 1.0))
