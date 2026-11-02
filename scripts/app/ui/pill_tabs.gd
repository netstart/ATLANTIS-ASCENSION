class_name PillTabs
extends HBoxContainer
## Sub-abas em pílula no topo de uma tela de comando (Loja: Baú | Pinturas | Apoio): pílulas iguais que
## dividem a largura; a ativa é ouro cheio com texto escuro, as outras vidro com borda ciano. O texto
## encolhe até caber (alemão e russo em 270 de largura) em vez de alargar a barra. A bolinha "!" do
## CommandKit marca a sub-aba com algo a fazer. Cada pílula é um botão (toque, foco do controle, A).

signal changed(id: StringName)

const SIZE := 12

var active: StringName = &""
var _buttons: Dictionary = {}
var _dots: Dictionary = {}


func _init() -> void:
	name = "SubTabs"
	add_theme_constant_override("separation", 6)
	resized.connect(_fit)


## Monta as pílulas: `items` = [{id, text, notice}], `current` = a ativa.
func set_tabs(items: Array[Dictionary], current: StringName) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_dots.clear()
	active = current
	for item: Dictionary in items:
		var id: StringName = item["id"]
		var b := Button.new()
		b.name = "Tab_" + String(id)
		b.text = String(item["text"])
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = b.text
		b.pressed.connect(_pick.bind(id))
		add_child(b)
		_buttons[id] = b
		_dots[id] = CommandKit.notice_dot(b)
		(_dots[id] as Control).visible = bool(item.get("notice", false))
		_paint(b, id == active)
	_fit.call_deferred()


## Liga ou desliga a bolinha "!" de uma sub-aba.
func set_notice(id: StringName, on: bool) -> void:
	if _dots.has(id):
		(_dots[id] as Control).visible = on


func has(id: StringName) -> bool:
	return _buttons.has(id)


func button(id: StringName) -> Button:
	return _buttons.get(id) as Button


func buttons() -> Array[Control]:
	var out: Array[Control] = []
	for b: Variant in _buttons.values():
		out.append(b as Control)
	return out


func _pick(id: StringName) -> void:
	if id == active:
		return
	AudioManager.play_ui("kenney_ui_tab")
	active = id
	for key: Variant in _buttons:
		_paint(_buttons[key] as Button, key == active)
	changed.emit(id)


## Fonte de cada pílula: a maior que cabe na largura dela.
func _fit() -> void:
	for b: Variant in _buttons.values():
		var button := b as Button
		var font := CommandKit.bold(button)
		if font == null or button.size.x <= 0.0:
			continue
		button.add_theme_font_size_override("font_size",
				CommandKit.fit_size(font, button.text, button.size.x - 16.0, UiTheme.scaled(SIZE), 8))


static func _paint(b: Button, on: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat
		if on:
			box = UiTheme.primary_box("focus" if state == "focus" else "normal")
			box.shadow_size = 6 if state != "focus" else 10
		else:
			box = UiTheme.chamfer(Color(UiTheme.ABYSS, 0.72), Color(UiTheme.CYAN, 0.35), 1, 6)
			if state in ["hover", "focus"]:
				box.bg_color = Color(UiTheme.RAISED, 0.92)
				box.border_color = UiTheme.CYAN
			elif state == "pressed":
				box.bg_color = Color(UiTheme.CYAN, 0.2)
		box.content_margin_left = 8
		box.content_margin_right = 8
		b.add_theme_stylebox_override(state, box)
	var text := UiTheme.GOLD_DARK if on else UiTheme.TEXT
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(key, text if on or key == "font_color" else UiTheme.WHITE)
	var bold := UiTheme.bold_font()
	if bold != null:
		b.add_theme_font_override("font", bold)
