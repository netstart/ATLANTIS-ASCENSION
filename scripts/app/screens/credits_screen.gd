class_name CreditsScreen
extends Screen
## Créditos (docs/policies/licencas.md, "Tela de créditos"): lista TODO autor, asset e software de
## licenses/index.json, em toda versão. Nada é filtrado; o que não é arte, áudio ou fonte vai para
## Tecnologia (mesma regra de tools/build_license_index.py).
##
## Redesenho 1.6: sem fundo opaco (a água do App aparece por trás). Um cartão de abertura com o autor,
## depois um cartão de vidro por seção: título ciano em negrito, cada obra em texto claro e a linha
## de autor e licença apagada, menor. O cabeçalho segue o das listas (Voltar compacto, traço ciano).

const INDEX_PATH := "res://licenses/index.json"
const AUTHOR := "Clayton K. N. Passos"
const SECTIONS: Array[String] = ["art", "music", "sfx", "fonts", "tech"]
const MAX_WIDTH := 380.0

var _shade: TextureRect
var _back: Button
var _title: Label
var _divider: ColorRect
var _scroll: ScrollContainer
var _list: VBoxContainer
var _entries: Array = []


func _build() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(UiTheme.ABYSS, 0.82))
	g.set_color(1, Color(UiTheme.ABYSS, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 64
	_shade = TextureRect.new()
	_shade.texture = tex
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_back = Button.new()
	_back.name = "Back"
	_back.icon = ListScreen.icon(&"back")
	_back.add_theme_constant_override("icon_max_width", UiTheme.scaled(10))
	_back.add_theme_color_override("icon_normal_color", UiTheme.CYAN)
	_back.add_theme_color_override("icon_hover_color", UiTheme.WHITE)
	_back.add_theme_color_override("icon_focus_color", UiTheme.WHITE)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := UiTheme.button_box(state)
		box.content_margin_left = 8
		box.content_margin_right = 12
		_back.add_theme_stylebox_override(state, box)
	_back.pressed.connect(func() -> void: navigate.emit(&"back"))
	add_child(_back)
	_title = UiTheme.heading("", 18)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)
	_divider = ColorRect.new()
	_divider.color = Color(UiTheme.CYAN, 0.45)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_divider)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 3)
	pad.add_theme_constant_override("margin_right", 6)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 24)
	_scroll.add_child(pad)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	pad.add_child(_list)
	_entries = load_index()


## Entradas de licenses/index.json (vazia se o arquivo faltar).
static func load_index() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


## Seção de uma entrada: arte, música, efeitos, fontes ou tecnologia (padrão).
static func section_of(entry: Dictionary) -> String:
	var category := String(entry.get("category", ""))
	if category == "art":
		return "art"
	if category == "font":
		return "fonts"
	if category == "audio":
		return "music" if "music" in String(entry.get("id", "")).to_lower() else "sfx"
	return "tech"


func refresh_texts() -> void:
	_back.text = tr("credits.back")
	_title.text = tr("credits.title")
	for child: Node in _list.get_children():
		child.free()
	var opening := _card(UiTheme.GOLD)
	var by := UiTheme.heading(tr("credits.game_by") % AUTHOR, 14, UiTheme.GOLD)
	by.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	by.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening.add_child(by)
	for key: String in SECTIONS:
		var rows := _entries.filter(func(e: Variant) -> bool: return section_of(e as Dictionary) == key)
		if rows.is_empty():
			continue
		var box := _card(UiTheme.CYAN)
		var heading := UiTheme.heading(tr("credits.section_" + key), 14, UiTheme.CYAN)
		heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.name = "Section_" + key
		box.add_child(heading)
		var rule := ColorRect.new()
		rule.color = Color(UiTheme.CYAN, 0.2)
		rule.custom_minimum_size = Vector2(0, 1)
		box.add_child(rule)
		for row: Variant in rows:
			var entry := row as Dictionary
			var item := VBoxContainer.new()
			item.add_theme_constant_override("separation", 1)
			item.add_child(UiTheme.label(String(entry.get("name", "")), UiTheme.FONT_SIZE, UiTheme.TEXT, true))
			var line := tr("credits.license") % [String(entry.get("author", "")), String(entry.get("license_id", ""))]
			item.add_child(UiTheme.label(line, UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM, true))
			box.add_child(item)
	relayout()


func _card(accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(accent, 0.82))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_list.add_child(panel)
	return box


func _layout() -> void:
	if _scroll == null:
		return
	var width := floorf(minf(safe.size.x - 20.0, MAX_WIDTH))
	var left := floorf(safe.position.x + (safe.size.x - width) * 0.5)
	var top := safe.position.y + 6.0
	_back.size = Vector2.ZERO
	_back.size = Vector2(_back.get_combined_minimum_size().x, UiTheme.TOUCH_MIN)
	_back.position = Vector2(left, top)
	_title.position = Vector2(_back.position.x + _back.size.x + 10.0, top)
	_title.size = Vector2(maxf(0.0, left + width - _title.position.x), UiTheme.TOUCH_MIN)
	var y := top + UiTheme.TOUCH_MIN + 8.0
	_divider.position = Vector2(left, y)
	_divider.size = Vector2(width, 1.0)
	y += 5.0
	_shade.position = Vector2.ZERO
	_shade.size = Vector2(size.x, y + 28.0)
	_scroll.position = Vector2(left - 3.0, y)
	_scroll.size = Vector2(width + 9.0, maxf(0.0, safe.end.y - y))


## Textos visíveis da lista (teste da tela de créditos), inclusive os de dentro dos cartões.
func shown_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for child: Node in _list.find_children("*", "Label", true, false):
		texts.append((child as Label).text)
	return texts


func layout_controls() -> Array[Control]:
	return [_back, _title, _scroll]


func scroll() -> ScrollContainer:
	return _scroll
