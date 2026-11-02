class_name CommandSheet
extends Control
## Painel de detalhe e confirmação das telas de comando (Loja: a pintura escolhida): véu escuro por cima
## da tela, cartão de vidro centrado com a faixa do título (StoreBanner.Strip) e o conteúdo que a tela
## monta em `open()`. Tocar fora, "Fechar", B do controle ou Esc fecham (a tela chama `close()` no seu
## back()). Entra com um sopro de escala, parado em "reduzir movimento".

signal closed

const MAX_WIDTH := 300.0

var _veil: ColorRect
var _panel: PanelContainer
var _strip: StoreBanner.Strip
var _content: VBoxContainer
var _area := Rect2()


func _init() -> void:
	name = "Sheet"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_veil = ColorRect.new()
	_veil.color = Color(UiTheme.ABYSS, 0.72)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			close())
	add_child(_veil)
	_panel = PanelContainer.new()
	_panel.name = "SheetPanel"
	var box := UiTheme.panel_box(UiTheme.CYAN, 0.97)
	box.shadow_size = 18
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", box)
	_panel.resized.connect(_center)
	# Texto com quebra calcula a altura mínima com a largura antiga; quando ela baixa, o cartão encolhe.
	_panel.minimum_size_changed.connect(func() -> void: _shrink.call_deferred())
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_strip = StoreBanner.Strip.new()
	col.add_child(_strip)
	_content = VBoxContainer.new()
	_content.name = "SheetContent"
	_content.add_theme_constant_override("separation", 8)
	col.add_child(_content)


func is_open() -> bool:
	return visible


## Limpa e abre o painel com `title` na cor `accent`; devolve a coluna onde a tela monta o conteúdo.
func open(title: String, accent: Color) -> VBoxContainer:
	var was_open := visible
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_strip.accent = accent
	_strip.set_text(title)
	(_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(accent, 0.7)
	visible = true
	_place.call_deferred()
	if not was_open and not UiFx.reduced():
		_panel.modulate.a = 0.0
		_panel.scale = Vector2.ONE * 0.94
		var t := create_tween().set_parallel()
		t.tween_property(_panel, "modulate:a", 1.0, 0.14)
		t.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _content


func close() -> void:
	if not visible:
		return
	visible = false
	AudioManager.play_ui("kenney_ui_back")
	closed.emit()


## Área onde o cartão se centra (a área útil da tela, em coordenadas da tela).
func place(area: Rect2) -> void:
	_area = area
	_place()


## Controles do painel (testes de layout).
func controls() -> Array[Control]:
	var out: Array[Control] = []
	if visible:
		out.append(_panel)
	return out


## Largura fixa; a altura vem do conteúdo (texto com quebra só sabe a altura depois de ter largura),
## então o cartão se recentra a cada `resized`.
func _place() -> void:
	_veil.position = Vector2.ZERO
	_veil.size = size
	var w := floorf(minf(_area.size.x - 20.0, MAX_WIDTH))
	_panel.custom_minimum_size = Vector2(w, 0.0)
	_panel.size = Vector2(w, 0.0)
	_center()
	_shrink.call_deferred()


func _shrink() -> void:
	if not visible:
		return
	_panel.size = Vector2(_panel.size.x, 0.0)
	_center()


func _center() -> void:
	_panel.position = (_area.position + (_area.size - _panel.size) * 0.5).floor()
	_panel.position.y = maxf(_area.position.y, _panel.position.y)
	_panel.pivot_offset = _panel.size * 0.5
