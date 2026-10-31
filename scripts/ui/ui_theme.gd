class_name UiTheme
extends RefCounted
## Tema das telas (plano mestre 8.1): paleta atlante, fonte do idioma atual e caixas dos botões.
## Montado em código para não depender do editor e para trocar de fonte junto com o idioma.

const DEEP_BLUE := Color("0b1e3f")
const ABYSS := Color("06122a")
const TURQUOISE := Color("1fb5a8")
const CYAN := Color("3ff3ff")
const GOLD := Color("e8b84a")
const WHITE := Color("f4fbff")
const VOLCANIC := Color("151216")
const CORAL := Color("ff5a5f")
const TEXT := Color("dff6ff")
const TEXT_DIM := Color("8fb3c8")

const FONT_SIZE := 12
const TITLE_SIZE := 24
const HEADING_SIZE := 16
## Altura mínima dos alvos de toque, em pontos lógicos (≈ 7 mm no aparelho de referência).
const TOUCH_MIN := 36.0


## Escala do texto (opção de acessibilidade: 1,0 / 1,15 / 1,3). Vale para o tema e para os rótulos.
static var text_scale: float = 1.0


static func build(font: Font) -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = scaled(FONT_SIZE)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", VOLCANIC)
	theme.set_constant("outline_size", "Label", 0)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "Button", button_box(state))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", WHITE)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(DEEP_BLUE, 0.0)
	theme.set_stylebox("panel", "ScrollContainer", scroll_bg)
	return theme


static func scaled(size: int) -> int:
	return roundi(size * text_scale)


static func button_box(state: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(DEEP_BLUE, 0.92)
	box.border_color = Color(TURQUOISE, 0.85)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	match state:
		"hover", "focus":
			box.border_color = CYAN
		"pressed":
			box.bg_color = Color(ABYSS, 0.95)
			box.border_color = GOLD
		"disabled":
			box.border_color = Color(TEXT_DIM, 0.5)
	return box


## Rótulo padrão (quebra de linha opcional).
static func label(text: String, size: int = FONT_SIZE, color: Color = TEXT, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", scaled(size))
	node.add_theme_color_override("font_color", color)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node
