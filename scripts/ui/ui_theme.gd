class_name UiTheme
extends RefCounted
## Tema das telas (plano mestre 8.1, redesenho 1.6 "neon abissal"): paleta, fontes do idioma e as
## caixas de botão e painel. Montado em código para não depender do editor e para trocar de fonte
## junto com o idioma.
##
## Linguagem visual única: vidro de batiscafo com cantos chanfrados a 45° (StyleBoxFlat com
## corner_detail = 1 desenha o chanfro sem textura). O chanfro grande fica em cima à esquerda e embaixo
## à direita, o pequeno nos outros dois. Cor é significado: ciano = interativo e foco, dourado = ação
## principal e recompensa, coral = perigo, violeta = raro, menta = sucesso.

const ABYSS := Color("050b1a")
const DEEP_BLUE := Color("0b1e33")
const RAISED := Color("12304d")
const TURQUOISE := Color("14b8a6")
const CYAN := Color("2ff3e0")
const GOLD := Color("ffc94a")
const GOLD_DARK := Color("1a1200")
const CORAL := Color("ff4d6d")
const VIOLET := Color("b57bff")
const MINT := Color("5cf29b")
const WHITE := Color("f4fbff")
const VOLCANIC := Color("151216")
const TEXT := Color("e6f7ff")
const TEXT_DIM := Color("8fb3c9")

const FONT_SIZE := 12
const TITLE_SIZE := 24
const HEADING_SIZE := 16
const SMALL_SIZE := 10
## Altura mínima dos alvos de toque, em pontos lógicos (≈ 7 mm no aparelho de referência).
const TOUCH_MIN := 36.0
## Chanfros (pontos lógicos): grande e pequeno.
const CUT := 7
const CUT_SMALL := 2

## Escala do texto (opção de acessibilidade: 1,0 / 1,15 / 1,3). Vale para o tema e para os rótulos.
static var text_scale: float = 1.0


static func build(font: Font) -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = scaled(FONT_SIZE)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", ABYSS)
	theme.set_constant("outline_size", "Label", 0)
	theme.set_constant("line_spacing", "Label", 1)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "Button", button_box(state))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", WHITE)
	theme.set_color("font_pressed_color", "Button", CYAN)
	theme.set_color("font_focus_color", "Button", WHITE)
	theme.set_color("font_hover_pressed_color", "Button", CYAN)
	theme.set_color("font_disabled_color", "Button", Color(TEXT_DIM, 0.6))
	theme.set_constant("h_separation", "Button", 6)
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(DEEP_BLUE, 0.0)
	theme.set_stylebox("panel", "ScrollContainer", scroll_bg)
	theme.set_stylebox("panel", "PanelContainer", panel_box())
	theme.set_stylebox("panel", "Panel", panel_box())
	_scrollbar(theme)
	_slider(theme)
	_progress(theme)
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_color", "CheckBox", TEXT)
	return theme


static func scaled(size: int) -> int:
	return roundi(size * text_scale)


## Caixa chanfrada base: chanfro grande em cima à esquerda e embaixo à direita.
static func chamfer(bg: Color, border: Color, width: int = 1, cut: int = CUT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.corner_detail = 1
	box.corner_radius_top_left = cut
	box.corner_radius_bottom_right = cut
	box.corner_radius_top_right = CUT_SMALL
	box.corner_radius_bottom_left = CUT_SMALL
	box.anti_aliasing = true
	box.anti_aliasing_size = 0.6
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## Botão secundário (vidro): borda ciano discreta; foco e hover acendem a borda e um halo.
static func button_box(state: String) -> StyleBoxFlat:
	var box := chamfer(Color(DEEP_BLUE, 0.86), Color(CYAN, 0.38))
	box.border_width_top = 1
	box.border_width_bottom = 2
	match state:
		"hover", "focus":
			box.bg_color = Color(RAISED, 0.92)
			box.border_color = CYAN
			box.shadow_color = Color(CYAN, 0.28)
			box.shadow_size = 5
		"pressed":
			box.bg_color = Color(CYAN, 0.18)
			box.border_color = CYAN
			box.border_width_bottom = 1
			box.content_margin_top = 7
			box.content_margin_bottom = 5
		"disabled":
			box.bg_color = Color(ABYSS, 0.7)
			box.border_color = Color(TEXT_DIM, 0.22)
	return box


## Botão principal (a ação da tela): ouro de oricalco com halo; texto escuro e em negrito.
static func primary_box(state: String) -> StyleBoxFlat:
	var box := chamfer(GOLD, Color("fff0b8"), 1, CUT + 2)
	box.border_width_bottom = 3
	box.border_color = Color("fff0b8")
	box.shadow_color = Color(GOLD, 0.32)
	box.shadow_size = 8
	match state:
		"hover", "focus":
			box.bg_color = Color("ffd76e")
			box.shadow_color = Color(GOLD, 0.55)
			box.shadow_size = 12
		"pressed":
			box.bg_color = Color("e9ae2c")
			box.border_width_bottom = 1
			box.shadow_size = 4
		"disabled":
			# Sem dinheiro ou bloqueado: vira vidro com filete dourado (a ação existe, mas ainda não dá).
			box.bg_color = Color(DEEP_BLUE, 0.8)
			box.border_width_bottom = 1
			box.shadow_size = 0
	box.border_color = Color("fff3c4") if state != "disabled" else Color(GOLD, 0.4)
	return box


## Aba da barra inferior: sem caixa quando inativa; a ativa ganha vidro e um traço ciano em cima.
static func tab_box(state: String, active: bool) -> StyleBoxFlat:
	var box := chamfer(Color(DEEP_BLUE, 0.0), Color(CYAN, 0.0), 0, CUT_SMALL)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	if active:
		box.bg_color = Color(CYAN, 0.12)
		box.border_color = CYAN
		box.border_width_top = 2
	if state in ["hover", "focus"]:
		box.bg_color = Color(CYAN, 0.18 if active else 0.08)
		box.border_color = CYAN
		box.border_width_top = 2
	elif state == "pressed":
		box.bg_color = Color(CYAN, 0.24)
	return box


## Painel de vidro (cartões, folhas, diálogos).
static func panel_box(accent: Color = CYAN, alpha: float = 0.84) -> StyleBoxFlat:
	var box := chamfer(Color(DEEP_BLUE, alpha), Color(accent, 0.42), 1, CUT + 3)
	box.border_width_top = 2
	box.border_color = Color(accent, 0.55)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


## Pílula de moeda do topo (fundo escuro, sem borda forte).
static func pill_box(accent: Color = GOLD) -> StyleBoxFlat:
	var box := chamfer(Color(ABYSS, 0.72), Color(accent, 0.35), 1, 5)
	box.content_margin_left = 6
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


## Pinta um botão como ação principal (caixas, texto escuro, fonte em negrito e o reflexo que corre,
## UiGlint).
static func style_primary(button: Button, size: int = HEADING_SIZE) -> void:
	button.material = UiGlint.material()
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, primary_box(state))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		button.add_theme_color_override(key, GOLD_DARK)
	button.add_theme_color_override("font_disabled_color", Color(GOLD, 0.55))
	button.add_theme_font_size_override("font_size", scaled(size))
	var bold := bold_font()
	if bold != null:
		button.add_theme_font_override("font", bold)


## Pinta um botão como aba da barra inferior.
static func style_tab(button: Button, active: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, tab_box(state, active))
	button.add_theme_color_override("font_color", CYAN if active else TEXT_DIM)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_focus_color", WHITE)


## Ícone da interface (Kenney Game Icons, CC0, brancos para tingir por modulate/cor do botão).
static func icon(icon_name: String) -> Texture2D:
	var path := "res://assets/art/kenney/icons/%s.png" % icon_name
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Botão só de ícone (quadrado, vidro). Filtro linear com mipmaps: o ícone de 100 px desce sem serrilhado.
static func icon_button(icon_name: String, node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
	b.add_theme_constant_override("icon_max_width", 18)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box := button_box(state)
		box.set_content_margin_all(8)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("icon_normal_color", Color(TEXT, 0.85))
	b.add_theme_color_override("icon_hover_color", CYAN)
	b.add_theme_color_override("icon_focus_color", CYAN)
	b.add_theme_color_override("icon_pressed_color", CYAN)
	return b


## Fonte de título do idioma atual (null nos testes de regras, que rodam sem autoloads).
static func bold_font() -> Font:
	var loop := Engine.get_main_loop() as SceneTree
	var locale := loop.root.get_node_or_null(^"Locale") if loop != null else null
	return locale.get("font_bold") as Font if locale != null else null


## Rótulo padrão (quebra de linha opcional).
static func label(text: String, size: int = FONT_SIZE, color: Color = TEXT, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", scaled(size))
	node.add_theme_color_override("font_color", color)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


## Título em negrito, com tracking largo e sombra suave (cabeçalhos de tela).
static func heading(text: String, size: int = HEADING_SIZE, color: Color = WHITE) -> Label:
	var node := label(text, size, color)
	var bold := bold_font()
	if bold != null:
		node.add_theme_font_override("font", bold)
	node.add_theme_color_override("font_shadow_color", Color(color, 0.25))
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", 0)
	node.add_theme_constant_override("shadow_outline_size", 6)
	return node


static func _scrollbar(theme: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(CYAN, 0.06)
	track.content_margin_left = 2
	track.content_margin_right = 2
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(CYAN, 0.45)
	grab.set_corner_radius_all(2)
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	for kind: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", kind, track)
		theme.set_stylebox("grabber", kind, grab)
		theme.set_stylebox("grabber_highlight", kind, grab)
		theme.set_stylebox("grabber_pressed", kind, grab)


static func _slider(theme: Theme) -> void:
	var track := chamfer(Color(ABYSS, 0.9), Color(CYAN, 0.3), 1, CUT_SMALL)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := chamfer(Color(CYAN, 0.75), Color(CYAN, 0.0), 0, CUT_SMALL)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)


static func _progress(theme: Theme) -> void:
	var bg := chamfer(Color(ABYSS, 0.85), Color(CYAN, 0.28), 1, CUT_SMALL)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fill := chamfer(CYAN, Color(WHITE, 0.0), 0, CUT_SMALL)
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", TEXT)
