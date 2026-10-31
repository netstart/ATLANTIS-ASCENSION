class_name CreditsScreen
extends Screen
## Créditos (docs/policies/licencas.md, "Tela de créditos"): lista TODO autor, asset e software de
## licenses/index.json, em toda versão. Nada é filtrado; o que não é arte, áudio ou fonte vai para
## Tecnologia (mesma regra de tools/build_license_index.py).

const INDEX_PATH := "res://licenses/index.json"
const AUTHOR := "Clayton K. N. Passos"
const SECTIONS: Array[String] = ["art", "music", "sfx", "fonts", "tech"]
const HEADER_HEIGHT := 44.0

var _background: ColorRect
var _back: Button
var _title: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _entries: Array = []


func _build() -> void:
	_background = ColorRect.new()
	_background.color = UiTheme.ABYSS
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	_back = Button.new()
	_back.name = "Back"
	_back.custom_minimum_size = Vector2(72, UiTheme.TOUCH_MIN)
	_back.pressed.connect(func() -> void: navigate.emit(&"back"))
	add_child(_back)
	_title = UiTheme.label("", UiTheme.HEADING_SIZE, UiTheme.GOLD)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
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
	_list.add_child(UiTheme.label(tr("credits.game_by") % AUTHOR, UiTheme.FONT_SIZE, UiTheme.TEXT, true))
	for key: String in SECTIONS:
		var rows := _entries.filter(func(e: Variant) -> bool: return section_of(e as Dictionary) == key)
		if rows.is_empty():
			continue
		var heading := UiTheme.label(tr("credits.section_" + key), UiTheme.HEADING_SIZE, UiTheme.TURQUOISE)
		heading.name = "Section_" + key
		_list.add_child(heading)
		for row: Variant in rows:
			var entry := row as Dictionary
			_list.add_child(UiTheme.label(String(entry.get("name", "")), UiTheme.FONT_SIZE, UiTheme.GOLD, true))
			var line := tr("credits.license") % [String(entry.get("author", "")), String(entry.get("license_id", ""))]
			_list.add_child(UiTheme.label(line, UiTheme.FONT_SIZE, UiTheme.TEXT_DIM, true))
	relayout()


func _layout() -> void:
	if _scroll == null:
		return
	var left := safe.position.x + 12.0
	var width := safe.size.x - 24.0
	_back.reset_size()
	_back.position = Vector2(left, safe.position.y + 4.0)
	_title.position = Vector2(_back.position.x + _back.size.x + 12.0, safe.position.y + 4.0)
	_title.size = Vector2(maxf(0.0, safe.end.x - 12.0 - _title.position.x), UiTheme.TOUCH_MIN)
	_scroll.position = Vector2(left, safe.position.y + HEADER_HEIGHT)
	_scroll.size = Vector2(width, safe.size.y - HEADER_HEIGHT - 8.0)
	_list.custom_minimum_size = Vector2(width - 8.0, 0.0)


## Textos visíveis da lista (teste da tela de créditos).
func shown_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for child: Node in _list.get_children():
		if child is Label:
			texts.append((child as Label).text)
	return texts


func layout_controls() -> Array[Control]:
	return [_back, _title, _scroll]


func scroll() -> ScrollContainer:
	return _scroll
