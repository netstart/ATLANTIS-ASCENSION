class_name ListScreen
extends Screen
## Base das telas em lista (hangar, naves, opções, loja, eventos, diário...): cabeçalho com Voltar,
## título e moedas, um traço ciano e uma coluna rolável de cartões de vidro. As filhas montam o
## conteúdo em `_fill()`, chamado ao mostrar a tela, ao trocar de idioma e depois de cada ação
## (`refill()`).
##
## Redesenho 1.6 ("neon abissal", docs/design/ui-style.md): a tela não pinta fundo opaco (o
## AbyssBackdrop do App aparece por trás); só um véu escuro em cima e embaixo para o texto do
## cabeçalho ler bem sobre a água. Os ícones (moedas, cadeado, visto...) são desenhados aqui em
## código, por distância com suavização, numa textura de 64 px: ficam nítidos na resolução física em
## qualquer escala e não dependem de a fonte ter o glifo (Exo 2 não tem ✓ nem cadeado).

const MAX_WIDTH := 360.0
## Margem lateral mínima da coluna (pontos lógicos).
const GUTTER := 10.0
## Largura a partir da qual as grades de cartões usam duas colunas.
const TWO_COLUMNS := 300.0
const ICON_RES := 64
const CURRENCIES: Array[String] = ["credits", "orichalcum", "pearls"]

static var _icons: Dictionary = {}

var _shade_top: TextureRect
var _shade_bottom: TextureRect
var _back: Button
var _title: Label
var _wallet: HBoxContainer
var _wallet_values: Dictionary = {}
var _divider: TextureRect
var _scroll: ScrollContainer
var _list: VBoxContainer
var _grids: Array[GridContainer] = []
var _width: float = MAX_WIDTH


func _build() -> void:
	_shade_top = _shade(true)
	_shade_bottom = _shade(false)
	_back = Button.new()
	_back.name = "Back"
	_back.icon = icon(&"back")
	_back.add_theme_constant_override("icon_max_width", UiTheme.scaled(10))
	_back.add_theme_color_override("icon_normal_color", UiTheme.CYAN)
	_back.add_theme_color_override("icon_hover_color", UiTheme.WHITE)
	_back.add_theme_color_override("icon_focus_color", UiTheme.WHITE)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := UiTheme.button_box(state)
		box.content_margin_left = 8
		box.content_margin_right = 12
		_back.add_theme_stylebox_override(state, box)
	_back.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_back")
		navigate.emit(&"back"))
	add_child(_back)
	_title = UiTheme.heading("", 18)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)
	_wallet = HBoxContainer.new()
	_wallet.name = "Wallet"
	_wallet.add_theme_constant_override("separation", 4)
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for kind: String in CURRENCIES:
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UiTheme.pill_box(_currency_color(kind)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(glyph(StringName(kind), Color.WHITE, 11))
		var value := UiTheme.label("0", UiTheme.FONT_SIZE, UiTheme.TEXT)
		_bold(value)
		row.add_child(value)
		pill.add_child(row)
		_wallet.add_child(pill)
		_wallet_values[kind] = value
	add_child(_wallet)
	_divider = TextureRect.new()
	_divider.texture = _divider_texture()
	_divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_divider.stretch_mode = TextureRect.STRETCH_SCALE
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_divider)
	_scroll = ScrollContainer.new()
	_scroll.name = "List"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	# Folga em volta da coluna: a sombra dos cartões não é cortada pela borda da rolagem e o último
	# cartão não encosta no fim da tela.
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 3)
	pad.add_theme_constant_override("margin_right", 6)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 20)
	_scroll.add_child(pad)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	pad.add_child(_list)


func on_show(_app: Node) -> void:
	refresh_texts()


func refresh_texts() -> void:
	if _back == null:
		return
	_back.text = tr("credits.back")
	_title.text = tr(title_key())
	refill()


## Remonta as linhas (depois de comprar, equipar ou trocar uma opção).
func refill() -> void:
	# Foco do controle na lista: volta para a mesma posição depois de remontar (comprar, equipar).
	var keep := -1
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and _list.is_ancestor_of(focused):
		keep = FocusNav.all(_list).find(focused)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_grids.clear()
	_wallet.visible = show_wallet()
	var wallet := SaveManager.data["wallet"] as Dictionary
	for kind: String in CURRENCIES:
		var value := _wallet_values[kind] as Label
		value.text = Locale.format_number(int(wallet[kind]))
		(value.get_parent().get_parent() as Control).tooltip_text = tr("currency." + kind)
	_fill()
	relayout()
	if keep >= 0:
		var controls := FocusNav.all(_list)
		FocusNav.focus(controls[mini(keep, controls.size() - 1)] if not controls.is_empty() else _back)


## Primeiro item da lista (o Voltar só quando a lista não tem nada para apertar).
func default_focus() -> Control:
	var control := FocusNav.first(_list)
	return control if control != null else _back


func title_key() -> String:
	return ""


func show_wallet() -> bool:
	return false


## Largura máxima da coluna (a loja abre um pouco mais para a grade de pinturas).
func max_width() -> float:
	return MAX_WIDTH


func _fill() -> void:
	pass


static func wallet_text() -> String:
	var wallet := SaveManager.data["wallet"] as Dictionary
	return "%s %s   %s %s   %s %s" % [TranslationServer.translate("currency.credits"),
			Locale.format_number(int(wallet["credits"])), TranslationServer.translate("currency.orichalcum"),
			Locale.format_number(int(wallet["orichalcum"])), TranslationServer.translate("currency.pearls"),
			Locale.format_number(int(wallet["pearls"]))]


func _layout() -> void:
	if _scroll == null:
		return
	_width = floorf(minf(safe.size.x - GUTTER * 2.0, max_width()))
	var left := floorf(safe.position.x + (safe.size.x - _width) * 0.5)
	var right := left + _width
	var top := safe.position.y + 6.0
	_back.size = Vector2.ZERO
	_back.size = Vector2(_back.get_combined_minimum_size().x, UiTheme.TOUCH_MIN)
	_back.position = Vector2(left, top)
	# Moedas na mesma linha do título quando o título inteiro cabe; senão descem para uma segunda
	# linha, alinhadas à direita (alemão e russo em 270 de largura).
	var title_x := _back.position.x + _back.size.x + 10.0
	var wallet_size := _wallet.get_combined_minimum_size() if show_wallet() else Vector2.ZERO
	var inline := show_wallet() and title_x + _text_width(_title) + 10.0 + wallet_size.x <= right
	var title_right := right - (wallet_size.x + 10.0 if inline else 0.0)
	_title.position = Vector2(title_x, top)
	_title.size = Vector2(maxf(0.0, title_right - title_x), UiTheme.TOUCH_MIN)
	var y := top + UiTheme.TOUCH_MIN
	if show_wallet():
		_wallet.size = wallet_size
		if inline:
			_wallet.position = Vector2(right - wallet_size.x, top + floorf((UiTheme.TOUCH_MIN - wallet_size.y) * 0.5))
		else:
			_wallet.position = Vector2(right - wallet_size.x, y + 6.0)
			y += 6.0 + wallet_size.y
	y += 8.0
	_divider.position = Vector2(left, y)
	_divider.size = Vector2(_width, 1.0)
	y += 5.0
	_shade_top.position = Vector2.ZERO
	_shade_top.size = Vector2(size.x, y + 28.0)
	_shade_bottom.size = Vector2(size.x, 48.0)
	_shade_bottom.position = Vector2(0.0, size.y - _shade_bottom.size.y)
	_scroll.position = Vector2(left - 3.0, y)
	_scroll.size = Vector2(_width + 9.0, maxf(0.0, safe.end.y - y))
	for grid: GridContainer in _grids:
		grid.columns = 2 if _width >= TWO_COLUMNS else 1


func back() -> bool:
	navigate.emit(&"back")
	return true


func layout_controls() -> Array[Control]:
	var out: Array[Control] = [_back, _title, _scroll]
	if show_wallet():
		out.append(_wallet)
	return out


# --- Linhas soltas --------------------------------------------------------------------------------

## Título de seção: ciano em negrito, com um respiro maior acima (agrupa os cartões abaixo dele).
func add_heading(text: String) -> Label:
	if _list.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(gap)
	var l := UiTheme.heading(text, 14, UiTheme.CYAN)
	# Sem o halo do título: em 14 pt ele borra as letras; o ciano já separa a seção.
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(l)
	return l


func add_text(text: String, color: Color = UiTheme.TEXT) -> Label:
	var l := UiTheme.label(text, UiTheme.FONT_SIZE, color, true)
	_list.add_child(l)
	return l


## Botão de largura inteira na coluna (vidro; `primary` pinta de ouro a ação principal).
func add_button(text: String, on_press: Callable, enabled: bool = true, button_name: String = "",
		primary: bool = false) -> Button:
	return button(_list, text, on_press, enabled, button_name, primary)


## Linha "nome ............ controle" (opções), dentro de `parent` (um cartão) ou solta na coluna.
func add_row(text: String, control: Control, parent: Container = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UiTheme.label(text, UiTheme.FONT_SIZE, UiTheme.TEXT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, 112.0), UiTheme.TOUCH_MIN)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	(parent if parent != null else _list).add_child(row)
	return row


# --- Cartões --------------------------------------------------------------------------------------

## Cartão de vidro (PanelContainer + panel_box) com uma coluna interna; devolve a coluna. O painel é
## `get_parent()` da coluna.
func card(accent: Color = UiTheme.CYAN, parent: Container = null, alpha: float = 0.84) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(accent, alpha))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	(parent if parent != null else _list).add_child(panel)
	return box


## Grade de cartões: duas colunas quando a coluna tem largura (o número é revisto a cada layout).
func grid(parent: Container = null) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2 if _width >= TWO_COLUMNS else 1
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else _list).add_child(g)
	_grids.append(g)
	return g


## Linha de título de cartão: ícone opcional, nome em negrito (quebra) e espaço à direita para um
## selo, preço ou número (o chamador acrescenta com `add_child`).
func title_row(parent: Container, text: String, color: Color = UiTheme.WHITE, size: int = 13,
		icon_kind: StringName = &"", icon_color: Color = UiTheme.CYAN) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if icon_kind != &"":
		var g := glyph(icon_kind, icon_color, size)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(g)
	var l := UiTheme.label(text, size, color, true)
	_bold(l)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	parent.add_child(row)
	return row


## Texto de cartão (quebra de linha; apagado por padrão: descrição).
func text(parent: Container, value: String, color: Color = UiTheme.TEXT_DIM, size: int = UiTheme.FONT_SIZE) -> Label:
	var l := UiTheme.label(value, size, color, true)
	parent.add_child(l)
	return l


## Botão dentro de um cartão (ou da coluna). Toca o clique, roda a ação e remonta a tela.
func button(parent: Container, value: String, on_press: Callable, enabled: bool = true, button_name: String = "",
		primary: bool = false) -> Button:
	var b := Button.new()
	if not button_name.is_empty():
		b.name = button_name
	b.text = value
	b.disabled = not enabled
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary:
		UiTheme.style_primary(b, 13)
		b.custom_minimum_size.y = 40.0
	b.pressed.connect(_press.bind(on_press))
	parent.add_child(b)
	return b


## Botão de preço (ouro): ícone da moeda e o valor. É a ação de compra do cartão.
func price_button(parent: Container, amount: int, currency: String, on_press: Callable, enabled: bool,
		button_name: String, hint: String = "") -> Button:
	# Ícone e número centrados juntos (o ícone nativo do Button fica preso à borda esquerda).
	var b := button(parent, "", on_press, enabled, button_name, true)
	b.tooltip_text = hint
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mark := glyph(StringName(currency), Color(1, 1, 1, 1.0 if enabled else 0.5), 13)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var value := UiTheme.label(Locale.format_number(amount), 14, Color(UiTheme.GOLD_DARK, 1.0 if enabled else 0.5))
	_bold(value)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	b.add_child(row)
	b.custom_minimum_size.x = row.get_combined_minimum_size().x + 24.0
	return b


## Cartão inteiro tocável (escolha de asa, dificuldade, pintura): vidro com nome, descrição e um
## visto menta quando escolhido. Um botão sem caixa cobre o cartão (foco do controle e toque), e o
## cartão afunda junto ao apertar.
func choice(title: String, desc: String, on: bool, on_press: Callable, enabled: bool = true,
		button_name: String = "", parent: Container = null) -> Button:
	var panel := PanelContainer.new()
	var box := UiTheme.panel_box(UiTheme.MINT if on else UiTheme.CYAN, 0.9 if on else 0.72)
	if on:
		box.bg_color = Color(UiTheme.DEEP_BLUE.lerp(UiTheme.MINT, 0.14), 0.9)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", box)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 6.0)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	for side: String in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var mark := glyph(&"check" if on else &"ring", UiTheme.MINT if on else Color(UiTheme.TEXT_DIM, 0.7), 14)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := UiTheme.label(title, 13, UiTheme.WHITE if on else UiTheme.TEXT, true)
	_bold(name_label)
	col.add_child(name_label)
	if not desc.is_empty():
		col.add_child(UiTheme.label(desc, UiTheme.FONT_SIZE, UiTheme.TEXT_DIM, true))
	row.add_child(col)
	pad.add_child(row)
	panel.add_child(pad)
	var b := Button.new()
	if not button_name.is_empty():
		b.name = button_name
	b.disabled = not enabled
	b.tooltip_text = title
	_flat_overlay(b)
	b.pressed.connect(_press.bind(on_press))
	b.button_down.connect(func() -> void: _squash(panel, 0.97))
	b.button_up.connect(func() -> void: _squash(panel, 1.0))
	panel.add_child(b)
	if not enabled:
		panel.modulate = Color(1, 1, 1, 0.55)
	(parent if parent != null else _list).add_child(panel)
	return b


## Selo pequeno (equipada, nível, resgatada): pílula escura com ícone e texto em negrito na cor.
func badge(value: String, color: Color, icon_kind: StringName = &"") -> PanelContainer:
	var pill := PanelContainer.new()
	var box := UiTheme.pill_box(color)
	box.bg_color = Color(color, 0.12)
	box.border_color = Color(color, 0.6)
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	if icon_kind != &"":
		row.add_child(glyph(icon_kind, color, 10))
	var l := UiTheme.label(value, UiTheme.SMALL_SIZE, color)
	_bold(l)
	row.add_child(l)
	pill.add_child(row)
	return pill


## Barras de nível: `total` segmentos inclinados (o chanfro da casa), `value` acesos na cor.
func pips(parent: Container, value: int, total: int, color: Color = UiTheme.GOLD) -> Control:
	# Mais de 12 segmentos viram tracinhos ilegíveis em 270 de largura: aí vale a barra contínua.
	if total > 12:
		return bar(parent, float(value), float(total), color)
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 6)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var gap := 3.0
		var w := (c.size.x - gap * float(total - 1)) / float(maxi(1, total))
		var h := c.size.y
		for i: int in range(total):
			var x := float(i) * (w + gap)
			var col := color if i < value else Color(UiTheme.TEXT_DIM, 0.18)
			c.draw_colored_polygon(PackedVector2Array([Vector2(x + 2.0, 0), Vector2(x + w, 0),
					Vector2(x + w - 2.0, h), Vector2(x, h)]), col))
	parent.add_child(c)
	return c


## Barra de progresso fina com preenchimento chanfrado na cor pedida.
func bar(parent: Container, value: float, total: float, color: Color = UiTheme.CYAN) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.max_value = maxf(1.0, total)
	p.value = clampf(value, 0.0, p.max_value)
	p.custom_minimum_size = Vector2(0, 7)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := UiTheme.chamfer(Color(UiTheme.ABYSS, 0.8), Color(color, 0.3), 1, UiTheme.CUT_SMALL)
	var fill := UiTheme.chamfer(color, Color(UiTheme.WHITE, 0.0), 0, UiTheme.CUT_SMALL)
	for box: StyleBoxFlat in [bg, fill]:
		box.content_margin_left = 0
		box.content_margin_right = 0
		box.content_margin_top = 0
		box.content_margin_bottom = 0
	fill.shadow_color = Color(color, 0.35)
	fill.shadow_size = 3
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fill)
	parent.add_child(p)
	return p


## Ícone desenhado (moeda, cadeado, visto...) num quadrado de `size` pontos, tingido de `color`.
func glyph(kind: StringName, color: Color = UiTheme.WHITE, size: int = 12) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(kind)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var side := float(UiTheme.scaled(size))
	t.custom_minimum_size = Vector2(side, side)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.self_modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Vista da aeronave (herói do hangar, miniatura da coleção e da loja), com as peças do `level` do
## hangar (ShipLivery).
func ship_view(tint: Color, zoom: int, dim: bool = false, level: int = 1) -> ShipView:
	var view := ShipView.new()
	view.tint = tint
	view.zoom = zoom
	view.dim = dim
	view.level = level
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return view


## Cor da aeronave como aparece na partida: tinta da nave e, por cima, a pintura equipada.
static func ship_tint(ship: String, cosmetic: String = "") -> Color:
	var paint := Store.tint_of(cosmetic)
	if not paint.is_empty():
		return Color(paint)
	for row: Variant in DB.rows("ships"):
		if String((row as Dictionary)["id"]) == ship:
			return Color(String((row as Dictionary).get("tint", "#ffffff")))
	return Color.WHITE


func _press(on_press: Callable) -> void:
	AudioManager.play_ui("kenney_ui_click")
	on_press.call()
	refill()


func _squash(panel: Control, value: float) -> void:
	if UiFx.reduced() or not panel.is_inside_tree():
		return
	panel.pivot_offset = panel.size * 0.5
	var tween := panel.create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE * value, 0.08 if value < 1.0 else 0.18) \
			.set_trans(Tween.TRANS_BACK if value >= 1.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _flat_overlay(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("disabled", empty)
	for state: String in ["hover", "focus", "pressed"]:
		var box := UiTheme.chamfer(Color(UiTheme.CYAN, 0.16 if state == "pressed" else 0.06), UiTheme.CYAN, 1,
				UiTheme.CUT + 3)
		b.add_theme_stylebox_override(state, box)


static func _bold(l: Label) -> void:
	var bold := UiTheme.bold_font()
	if bold != null:
		l.add_theme_font_override("font", bold)


static func _text_width(l: Label) -> float:
	var font := l.get_theme_font("font")
	return font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x \
			if font != null else 0.0


static func _currency_color(kind: String) -> Color:
	match kind:
		"orichalcum":
			return UiTheme.CYAN
		"pearls":
			return UiTheme.VIOLET
	return UiTheme.GOLD


func _shade(top: bool) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(UiTheme.ABYSS, 0.82 if top else 0.0))
	g.set_color(1, Color(UiTheme.ABYSS, 0.0 if top else 0.7))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 64
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


static func _divider_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	g.colors = PackedColorArray([Color(UiTheme.CYAN, 0.0), Color(UiTheme.CYAN, 0.55), Color(UiTheme.CYAN, 0.55),
			Color(UiTheme.CYAN, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 1
	return tex


# --- Ícones desenhados ----------------------------------------------------------------------------

## Textura do ícone `kind` (gerada uma vez e guardada). Monocromáticos saem brancos para tingir com
## self_modulate; as moedas já saem nas cores delas.
static func icon(kind: StringName) -> Texture2D:
	if _icons.has(kind):
		return _icons[kind]
	var img := Image.create(ICON_RES, ICON_RES, false, Image.FORMAT_RGBA8)
	for y: int in range(ICON_RES):
		for x: int in range(ICON_RES):
			img.set_pixel(x, y, _icon_pixel(kind, Vector2(float(x) + 0.5, float(y) + 0.5) / float(ICON_RES)))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_icons[kind] = tex
	return tex


static func _icon_pixel(kind: StringName, p: Vector2) -> Color:
	var c := Vector2(0.5, 0.5)
	var out := Color(1, 1, 1, 0)
	match kind:
		&"credits":
			# Moeda: aro escuro, disco dourado e um anel gravado.
			out = _over(out, Color("b9790f"), _cov(p.distance_to(c) - 0.45))
			out = _over(out, UiTheme.GOLD, _cov(p.distance_to(c) - 0.37))
			out = _over(out, Color("fff0b8"), _cov(p.distance_to(c + Vector2(-0.1, -0.12)) - 0.1) * 0.7)
			out = _over(out, Color("b9790f"), _cov(absf(p.distance_to(c) - 0.22) - 0.035))
		&"orichalcum":
			# Cristal de oricalco: hexágono em pé com a face esquerda mais escura.
			var hexa := PackedVector2Array([Vector2(0.5, 0.04), Vector2(0.88, 0.27), Vector2(0.88, 0.73),
					Vector2(0.5, 0.96), Vector2(0.12, 0.73), Vector2(0.12, 0.27)])
			var tone := Color("1fb5a6") if p.x < 0.5 else Color("7ff9ee")
			out = _over(out, tone, _cov(_poly_sd(p, hexa)))
			out = _over(out, Color("e9fffc"), _cov(_seg_d(p, Vector2(0.5, 0.14), Vector2(0.5, 0.86)) - 0.025) * 0.8)
		&"pearls":
			out = _over(out, Color("9d86e0"), _cov(p.distance_to(c) - 0.42))
			out = _over(out, Color("efe8ff"), _cov(p.distance_to(c + Vector2(-0.03, -0.03)) - 0.35))
			out = _over(out, Color.WHITE, _cov(p.distance_to(Vector2(0.38, 0.36)) - 0.1))
		&"lock":
			var arc := absf(p.distance_to(Vector2(0.5, 0.42)) - 0.19) - 0.065
			if p.y > 0.46:
				arc = 1.0
			out = _over(out, Color.WHITE, _cov(arc))
			out = _over(out, Color.WHITE, _cov(_rect_sd(p, Vector2(0.5, 0.67), Vector2(0.3, 0.23)) - 0.04))
			out.a *= 1.0 - _cov(p.distance_to(Vector2(0.5, 0.64)) - 0.06)
		&"check":
			var d := minf(_seg_d(p, Vector2(0.16, 0.52), Vector2(0.4, 0.76)), _seg_d(p, Vector2(0.4, 0.76),
					Vector2(0.86, 0.24)))
			out = _over(out, Color.WHITE, _cov(d - 0.085))
		&"ring":
			out = _over(out, Color.WHITE, _cov(absf(p.distance_to(c) - 0.36) - 0.05))
		&"diamond":
			out = _over(out, Color.WHITE, _cov(_poly_sd(p, PackedVector2Array([Vector2(0.5, 0.06),
					Vector2(0.94, 0.5), Vector2(0.5, 0.94), Vector2(0.06, 0.5)]))))
		&"star":
			var pts := PackedVector2Array()
			for i: int in range(10):
				var r := 0.46 if i % 2 == 0 else 0.2
				var a := -PI * 0.5 + PI * float(i) / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r + Vector2(0, 0.03))
			out = _over(out, Color.WHITE, _cov(_poly_sd(p, pts)))
		&"back":
			var d := minf(_seg_d(p, Vector2(0.66, 0.14), Vector2(0.3, 0.5)), _seg_d(p, Vector2(0.3, 0.5),
					Vector2(0.66, 0.86)))
			out = _over(out, Color.WHITE, _cov(d - 0.09))
		&"play":
			out = _over(out, Color.WHITE, _cov(_poly_sd(p, PackedVector2Array([Vector2(0.26, 0.12),
					Vector2(0.86, 0.5), Vector2(0.26, 0.88)])) - 0.03))
	return out


## Cobertura de um pixel pela distância com sinal (unidades do ícone; 1 = ICON_RES pixels).
static func _cov(d: float) -> float:
	return clampf(0.5 - d * float(ICON_RES), 0.0, 1.0)


static func _over(dst: Color, src: Color, a: float) -> Color:
	var sa := src.a * a
	var oa := sa + dst.a * (1.0 - sa)
	if oa <= 0.0:
		return Color(src, 0.0)
	var rgb := (Color(src.r, src.g, src.b) * sa + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - sa)) / oa
	return Color(rgb.r, rgb.g, rgb.b, oa)


static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _rect_sd(p: Vector2, center: Vector2, half: Vector2) -> float:
	var q := (p - center).abs() - half
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


## Distância com sinal a um polígono qualquer (negativa dentro; regra par-ímpar).
static func _poly_sd(p: Vector2, pts: PackedVector2Array) -> float:
	var d := INF
	var inside := false
	var j := pts.size() - 1
	for i: int in range(pts.size()):
		var a := pts[j]
		var b := pts[i]
		d = minf(d, _seg_d(p, a, b))
		if (b.y > p.y) != (a.y > p.y) and p.x < (a.x - b.x) * (p.y - b.y) / (a.y - b.y) + b.x:
			inside = not inside
		j = i
	return -d if inside else d


## Aeronave em destaque: halo ciano em degradê (círculos vetoriais, nítidos em qualquer escala), anel
## fino, motor animado e a nave em escala inteira com filtro nearest, vestida com as peças do nível
## (ShipLivery; no nível máximo o halo vira ouro). Flutua 2 pontos devagar; parada em "reduzir
## movimento". Redesenha a 15 Hz, só enquanto visível (60 Hz durante a revelação).
## `reveal()`: a peça nova acabou de ser montada — onda de luz e centelhas que se abrem.
class ShipView:
	extends Control

	const REDRAW_HZ := 15.0
	const SIZE := 48.0
	const REVEAL_TIME := 1.4
	const ASCEND_TIME := 2.4

	var tint := Color.WHITE
	var zoom: int = 2
	var dim: bool = false
	var level: int = 1

	var _time: float = 0.0
	var _reveal: float = -1.0
	var _wait: float = 0.0
	var _base: Texture2D
	var _engine: Texture2D

	func _ready() -> void:
		_base = SpriteBank.texture("res://assets/art/void/main_ship/base_full.png")
		_engine = SpriteBank.texture("res://assets/art/void/main_ship/engine_base_powering.png")
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(SIZE * float(zoom) + 24.0, SIZE * float(zoom) + 12.0)

	## Começa a revelação da peça nova (em "reduzir movimento" a peça só aparece).
	func reveal() -> void:
		if not UiFx.reduced():
			_reveal = 0.0

	func revealing() -> bool:
		return _reveal >= 0.0

	func _process(delta: float) -> void:
		if dim or not is_visible_in_tree() or UiFx.reduced():
			return
		_time += delta
		_wait -= delta
		if _reveal >= 0.0:
			_reveal += delta
			if _reveal > _reveal_time():
				_reveal = -1.0
		if _wait <= 0.0:
			_wait = 1.0 / (60.0 if _reveal >= 0.0 else REDRAW_HZ)
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5 + Vector2(0.0, roundf(sin(_time * 1.6) * 2.0))
		var radius := SIZE * float(zoom) * 0.62
		var ascended := level >= Economy.SHIP_MAX_LEVEL and not dim
		var ring := UiTheme.GOLD if ascended else UiTheme.CYAN
		var halo := Color(tint.lerp(ring, 0.6), 0.022 if not dim else 0.01)
		for i: int in range(20):
			draw_circle(center, radius * (1.0 - float(i) * 0.045), halo, true, -1.0, true)
		var ring_alpha := (0.3 if ascended else 0.18) if not dim else 0.08
		draw_arc(center, radius, 0.0, TAU, 64, Color(ring, ring_alpha), 1.0, true)
		if _base == null:
			return
		var col := Color(0.16, 0.24, 0.34, 0.9) if dim else tint
		var z := float(zoom)
		var calm := UiFx.reduced()
		if _reveal >= 0.0 and level >= Economy.SHIP_MAX_LEVEL:
			_draw_ascend(center, radius, clampf(_reveal / ASCEND_TIME, 0.0, 1.0))
		draw_set_transform(center.round(), 0.0, Vector2(z, z))
		var half := Vector2(SIZE, SIZE) * 0.5
		if _engine != null and not dim:
			var frames := maxi(1, _engine.get_width() / int(SIZE))
			draw_texture_rect_region(_engine, Rect2(-half, half * 2.0),
					SpriteBank.frame_rect(int(_time * 10.0) % frames, int(SIZE)), col)
		if not dim:
			ShipLivery.draw_under(self, level, col, _time, 1.0, true, calm)
		draw_texture(_base, -half, col)
		if not dim:
			ShipLivery.draw_over(self, level, col, _time, 1.0, calm)
		draw_set_transform(Vector2.ZERO)
		if _reveal >= 0.0:
			_draw_reveal(center, radius)

	## A Ascendida (nível máximo) ganha a revelação longa, com raios de ouro.
	func _reveal_time() -> float:
		return ASCEND_TIME if level >= Economy.SHIP_MAX_LEVEL else REVEAL_TIME

	## Onda de luz que sai da nave, brilho que apaga e oito centelhas que se abrem (ouro e acento).
	func _draw_reveal(center: Vector2, radius: float) -> void:
		var t := clampf(_reveal / _reveal_time(), 0.0, 1.0)
		var accent := ShipLivery.accent_of(tint)
		var fade := 1.0 - t
		var wave := ease(t, 0.4)
		draw_arc(center, radius * (0.35 + 0.9 * wave), 0.0, TAU, 64, Color(UiTheme.WHITE, 0.8 * fade), 2.0, true)
		draw_arc(center, radius * (0.25 + 0.7 * wave), 0.0, TAU, 64, Color(accent, 0.6 * fade), 1.0, true)
		draw_circle(center, radius * 0.7, Color(accent, 0.16 * fade * fade), true, -1.0, true)
		for i: int in range(8):
			var a := TAU * float(i) / 8.0 + 0.4
			var dir := Vector2(cos(a), sin(a))
			var from := center + dir * radius * (0.3 + 0.8 * wave)
			draw_line(from, from + dir * radius * 0.16 * fade, Color(UiTheme.GOLD if i % 2 == 0 else accent, fade),
					1.5, true)

	## Ascensão: doze raios de ouro que crescem e giram devagar por trás da nave, uma segunda onda
	## dourada que sai atrasada e dezesseis centelhas que se espalham e apagam.
	func _draw_ascend(center: Vector2, radius: float, t: float) -> void:
		var fade := 1.0 - t
		var rise := ease(minf(1.0, t * 3.0), 0.3)
		for i: int in range(12):
			var a := TAU * float(i) / 12.0 + t * 0.6
			var dir := Vector2(cos(a), sin(a))
			var side := Vector2(-dir.y, dir.x) * radius * 0.07
			var tip := center + dir * radius * (0.6 + 0.9 * rise)
			draw_colored_polygon(PackedVector2Array([center + side, center - side, tip]),
					Color(UiTheme.GOLD, 0.16 * fade))
		var late := clampf((t - 0.25) / 0.75, 0.0, 1.0)
		if late > 0.0:
			draw_arc(center, radius * (0.4 + 1.1 * ease(late, 0.4)), 0.0, TAU, 64,
					Color(UiTheme.GOLD, 0.7 * (1.0 - late)), 2.0, true)
		for i: int in range(16):
			var a := TAU * (float(i) + 0.5) / 16.0
			var p := center + Vector2(cos(a), sin(a)) * radius * (0.2 + 1.3 * ease(t, 0.35))
			draw_circle(p, 0.5 + 1.5 * fade, Color(1.0, 0.95, 0.7, fade), true, -1.0, true)
