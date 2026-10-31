class_name ListScreen
extends Screen
## Base das telas em lista (hangar, naves, opções, diário): cabeçalho com Voltar e título, saldo
## opcional e uma coluna rolável de linhas. As filhas montam as linhas em `_fill()`, chamado ao
## mostrar a tela, ao trocar de idioma e depois de cada ação (`refill()`).

const MAX_WIDTH := 360.0
const HEADER := 56.0

var _background: ColorRect
var _back: Button
var _title: Label
var _wallet: Label
var _scroll: ScrollContainer
var _list: VBoxContainer


func _build() -> void:
	_background = ColorRect.new()
	_background.color = Color(UiTheme.ABYSS, 0.97)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	_back = Button.new()
	_back.name = "Back"
	_back.custom_minimum_size = Vector2(72, UiTheme.TOUCH_MIN)
	_back.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_back")
		navigate.emit(&"back"))
	add_child(_back)
	_title = UiTheme.label("", UiTheme.HEADING_SIZE, UiTheme.GOLD)
	_title.clip_text = true
	add_child(_title)
	_wallet = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.GOLD)
	_wallet.clip_text = true
	add_child(_wallet)
	_scroll = ScrollContainer.new()
	_scroll.name = "List"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)


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
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_wallet.text = wallet_text() if show_wallet() else ""
	_fill()
	relayout()


func title_key() -> String:
	return ""


func show_wallet() -> bool:
	return false


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
	var width := minf(safe.size.x - 16.0, MAX_WIDTH)
	var left := floorf(safe.position.x + (safe.size.x - width) * 0.5)
	_back.position = Vector2(safe.position.x + 8.0, safe.position.y + 6.0)
	_title.position = Vector2(_back.position.x + 84.0, safe.position.y + 12.0)
	_title.size = Vector2(maxf(0.0, safe.end.x - 8.0 - _title.position.x), 0)
	var top := safe.position.y + HEADER
	if show_wallet():
		_wallet.position = Vector2(left, top)
		_wallet.size = Vector2(width, 0)
		top += 22.0
	_scroll.position = Vector2(left, top)
	_scroll.size = Vector2(width, safe.end.y - top - 8.0)
	_list.custom_minimum_size = Vector2(width - 10.0, 0)
	for child: Node in _list.get_children():
		if child is Label and (child as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			(child as Label).custom_minimum_size.x = width - 10.0


func back() -> bool:
	navigate.emit(&"back")
	return true


func layout_controls() -> Array[Control]:
	return [_back, _title, _scroll]


# --- Linhas ---------------------------------------------------------------------------------------

func add_heading(text: String) -> Label:
	var l := UiTheme.label(text, UiTheme.HEADING_SIZE, UiTheme.CYAN, true)
	_list.add_child(l)
	return l


func add_text(text: String, color: Color = UiTheme.TEXT) -> Label:
	var l := UiTheme.label(text, UiTheme.FONT_SIZE, color, true)
	_list.add_child(l)
	return l


func add_button(text: String, on_press: Callable, enabled: bool = true, button_name: String = "") -> Button:
	var b := Button.new()
	if not button_name.is_empty():
		b.name = button_name
	b.text = text
	b.disabled = not enabled
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	b.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_click")
		on_press.call()
		refill())
	_list.add_child(b)
	return b


## Linha "nome ............ valor" com um controle à direita (opções).
func add_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UiTheme.label(text, UiTheme.FONT_SIZE, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, 120.0), UiTheme.TOUCH_MIN)
	row.add_child(control)
	_list.add_child(row)
	return row
