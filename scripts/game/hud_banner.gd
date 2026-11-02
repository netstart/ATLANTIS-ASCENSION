class_name HudBanner
extends Control
## Faixa grande do HUD da partida (GameHud): tira de vidro com duas barras chanfradas e o texto no meio. Ciano
## nos anúncios, coral com listras de perigo no aviso de chefe e na cor da nave nos poderes
## (.ai/08-poderes-das-naves.md): só o Poder III, em letra de título no terço de cima, curto e mais
## transparente (os níveis I e II usam o PowerChip). A entrada é HudKit.banner_in; "reduzir movimento" mostra
## parada.

## Altura da faixa no campo (fração da altura): anúncio e Poder III.
const AT_NORMAL := 0.3
const AT_SUPREME := 0.17
## Segundos do apagar no fim: anúncio e poder (o poder sai rápido).
const FADE_NORMAL := 0.35
const FADE_POWER := 0.18

var warning := false
var accent := UiTheme.CYAN

var _band: ColorRect
var _bars: Array[Control] = []
var _text: Label
var _tween: Tween
var _left: float = 0.0
var _fade: float = FADE_NORMAL
var _field := Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_band = HudKit.ignore(ColorRect.new()) as ColorRect
	add_child(_band)
	for i: int in range(2):
		var bar := HudKit.ignore(Control.new())
		bar.draw.connect(func() -> void: HudKit.draw_banner_bar(bar, i, warning, accent))
		add_child(bar)
		_bars.append(bar)
	_text = UiTheme.heading("", UiTheme.TITLE_SIZE, UiTheme.WHITE)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_outline_color", UiTheme.ABYSS)
	_text.add_theme_constant_override("outline_size", 4)
	add_child(_text)


func place(field: Rect2) -> void:
	_field = field
	position = Vector2(field.position.x, field.position.y + field.size.y * AT_NORMAL)
	size = Vector2(field.size.x, 60)
	_text.position = Vector2(10, 10)
	_text.size = Vector2(field.size.x - 20.0, 0)


## Mostra `text` por `seconds`. `tint` com alfa (poderes) troca o ciano pela cor da nave; `big` é o título do
## supremo. `blink` pisca o aviso de chefe (desligado por "reduzir flashes").
func show_text(text: String, p_warning: bool, tint: Color, big: bool, seconds: float, reduced: bool) -> void:
	_text.text = text
	_left = seconds
	warning = p_warning
	var power := tint.a > 0.0
	accent = UiTheme.CORAL if warning else (tint if power else UiTheme.CYAN)
	var font_color := UiTheme.WHITE
	if warning:
		font_color = UiTheme.CORAL
	elif power and big:
		font_color = tint.lerp(UiTheme.WHITE, 0.25)
	_text.add_theme_color_override("font_color", font_color)
	_text.add_theme_color_override("font_shadow_color", Color(accent, 0.6 if power else 0.45))
	_text.add_theme_font_size_override("font_size", UiTheme.HEADING_SIZE if power and not big else UiTheme.TITLE_SIZE)
	# Faixa de poder mais transparente: o golpe acontece atrás dela.
	_band.color = Color(0.22, 0.02, 0.07, 0.62) if warning else \
			(Color(accent.darkened(0.85), 0.36) if power else Color(UiTheme.ABYSS, 0.55))
	_fade = FADE_POWER if power else FADE_NORMAL
	var at := AT_SUPREME if power else AT_NORMAL
	position.y = _field.position.y + _field.size.y * at
	var w := size.x
	_text.size = Vector2(w - 20.0, 0)
	var text_h := _text.get_minimum_size().y
	_text.size.y = text_h
	var bar_h := 7.0 if warning else 3.0
	var h := text_h + 20.0
	size.y = h
	_band.position = Vector2(0, 0)
	_band.size = Vector2(w, h)
	_bars[0].position = Vector2(0, -bar_h)
	_bars[1].position = Vector2(0, h)
	for i: int in range(2):
		var bar := _bars[i]
		bar.size = Vector2(w, bar_h)
		bar.pivot_offset = Vector2(0.0 if i == 0 else w, bar_h * 0.5)
		bar.queue_redraw()
	_text.pivot_offset = _text.size * 0.5
	_band.pivot_offset = Vector2(w * 0.5, h * 0.5)
	visible = true
	modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if reduced:
		_text.scale = Vector2.ONE
		_text.modulate.a = 1.0
		_band.scale = Vector2.ONE
		for bar: Control in _bars:
			bar.scale = Vector2.ONE
		return
	_tween = HudKit.banner_in(self, _band, _bars, _text, warning and not bool(Settings.get_value("reduce_flashes")))


## Conta o tempo na tela e apaga no fim (FADE_NORMAL ou FADE_POWER).
func tick(delta: float) -> void:
	_left -= delta
	if visible:
		visible = _left > 0.0
		modulate.a = clampf(_left / _fade, 0.0, 1.0)
