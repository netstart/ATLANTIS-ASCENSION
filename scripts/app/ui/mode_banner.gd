class_name ModeBanner
extends PanelContainer
## Cartão de modo dos Eventos (1.15, menus de comando): banner ilustrado na cor do modo (fundo em
## degradê com o emblema grande à direita, StoreBanner.Backdrop), título em faixa chevron, descrição
## curta e a linha de estado ("Disponível hoje", recorde, onde abre). O cartão inteiro é o botão
## (`button`, nome "Mode_<id>"): toque, foco do controle e o afundar ao apertar. Fechado: apagado, com
## cadeado no lugar do emblema e sem botão. A bolinha "!" (Notices) fica no canto de cima.

## Cor e emblema (ListScreen.icon) de cada modo.
const STYLE := {
	&"arcade": [Color("2ff3e0"), &"play"],
	&"daily": [Color("ffc94a"), &"star"],
	&"survival": [Color("5cf29b"), &"ring"],
	&"boss_rush": [Color("ff4d6d"), &"bolt"],
	&"practice": [Color("14b8a6"), &"check"],
	&"currents": [Color("4d8dff"), &"diamond"],
	&"second_tide": [Color("b57bff"), &"ship"],
	&"abyss": [Color("6a7dff"), &"orichalcum"],
	&"coop": [Color("ff9a5c"), &"plus"],
}

var mode: StringName
var accent := UiTheme.CYAN
var button: Button
var body: VBoxContainer
var _status: HBoxContainer
var _back: Control


func _init(p_mode: StringName, title: String, desc: String, open: bool) -> void:
	mode = p_mode
	name = "ModeCard_" + String(mode)
	var style: Array = STYLE.get(mode, [UiTheme.CYAN, &"play"])
	accent = style[0]
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 84)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var back := StoreBanner.Backdrop.new()
	_back = back
	back.accent = accent
	back.dim = not open
	back.emblem = ListScreen.icon(style[1] if open else &"lock")
	add_child(back)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_top", 9)
	pad.add_theme_constant_override("margin_bottom", 10)
	# Espaço do emblema à direita.
	pad.add_theme_constant_override("margin_right", 64)
	add_child(pad)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(body)
	var strip := StoreBanner.Strip.new()
	strip.accent = accent if open else Color(accent.darkened(0.45), 1.0)
	strip.set_text(title)
	body.add_child(strip)
	var line := UiTheme.label(desc, UiTheme.FONT_SIZE, UiTheme.TEXT if open else UiTheme.TEXT_DIM, true)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(line)
	_status = HBoxContainer.new()
	_status.add_theme_constant_override("separation", 5)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_status)
	if open:
		button = Button.new()
		button.name = "Mode_" + String(mode)
		button.tooltip_text = title
		ListScreen._flat_overlay(button)
		button.button_down.connect(func() -> void: _squash(0.97))
		button.button_up.connect(func() -> void: _squash(1.0))
		add_child(button)


## Linha de estado: ícone e texto em negrito na cor pedida.
func set_status(value: String, color: Color, icon_kind: StringName = &"") -> Label:
	for child: Node in _status.get_children():
		_status.remove_child(child)
		child.queue_free()
	if icon_kind != &"":
		var g := CommandKit.glyph(icon_kind, color, 11)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_status.add_child(g)
	var l := UiTheme.label(value, UiTheme.FONT_SIZE, color, true)
	l.name = "Status"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bold := UiTheme.bold_font()
	if bold != null:
		l.add_theme_font_override("font", bold)
	_status.add_child(l)
	return l


## Bolinha "!" no canto (Desafio Diário ainda não jogado hoje).
func set_notice(on: bool) -> void:
	# No fundo (Control comum): filho direto do PanelContainer seria esticado ao cartão inteiro.
	var dot := _back.get_node_or_null(^"Notice")
	if on and dot == null:
		_back.clip_contents = false
		CommandKit.notice_dot(_back)
	elif dot != null:
		(dot as Control).visible = on


func _squash(value: float) -> void:
	if UiFx.reduced() or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * value, 0.08 if value < 1.0 else 0.18) \
			.set_trans(Tween.TRANS_BACK if value >= 1.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
