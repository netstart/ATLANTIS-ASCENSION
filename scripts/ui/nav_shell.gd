class_name NavShell
extends Control
## Casca de navegação dos menus de comando (1.15): a barra de cima e a barra de abas de baixo, as duas
## fixas, por cima das cinco telas-aba (Loja, Oficina, Campanha, Naves e Eventos). O App cria uma só,
## acima das telas, e a mostra só quando a tela atual é uma aba (is_tab). Trocar de aba não empilha
## histórico e as telas-aba não têm "Voltar": voltar numa aba leva à Campanha, e da Campanha ao título.
##
## Barra de cima: o bloco da piloto (retrato da Maré com moldura, nível no canto e barrinha de
## experiência, Economy.pilot), o Poder em ouro com o raio (Economy.power) e as três moedas em pílulas
## com "+" (tocar leva à Loja); a engrenagem abre as Opções. Em telas estreitas (até 420 pontos de
## coluna) as moedas descem para uma segunda linha. As moedas e o Poder contam até o valor novo.
##
## Barra de abas: cinco botões iguais, ícone grande sobre o rótulo; a aba ativa sobe um pouco acima da
## barra, ganha fundo ciano claro e ícone maior. A Campanha fica no meio, com o ícone dourado (é a casa
## e leva ao Jogar). A bolinha "!" (Notices) aparece nas abas com algo a fazer. LB/RB do controle e
## Q/E do teclado trocam de aba. Som kenney_ui_tab; movimento curto, parado em "reduzir movimento".
##
## As telas-aba recebem a área útil já sem a casca: Screen.relayout desconta insets_for() de `safe`.

signal tab_selected(tab: StringName)
signal options_requested

## Ordem das abas, da esquerda para a direita.
const TABS: Array[StringName] = [&"shop", &"hangar", &"hub", &"ships", &"events"]
const HOME := &"hub"
const TAB_LABELS := {&"shop": "hub.tab_shop", &"hangar": "hangar.title", &"hub": "hub.tab_campaign",
		&"ships": "hub.tab_ships", &"events": "hub.tab_events"}
const CURRENCIES: Array[String] = ["credits", "orichalcum", "pearls"]
const CURRENCY_COLORS := {"credits": Color("ffc94a"), "orichalcum": Color("2ff3e0"), "pearls": Color("b57bff")}
## Medidas (pontos lógicos).
const PAD := 5.0
const ROW := 36.0
const GAP := 3.0
const POWER_WIDTH := 104.0
const PILL_MAX := 112.0
const TAB_BAR := 50.0
const TAB_RAISE := 7.0
const MAX_WIDTH := 560.0
## Coluna a partir da qual moedas e Poder dividem uma linha só.
const WIDE := 420.0
const ANIM := 0.16

var current: StringName = &""

var _pilot: PilotBadge
var _power: PowerReadout
var _pills: Dictionary = {}
var _options: Button
var _tabs: Dictionary = {}
var _top_band := Rect2()
var _bottom_band := Rect2()


static func is_tab(screen: StringName) -> bool:
	return screen in TABS


## Coluna das barras dentro da área segura (no desktop não atravessa a tela inteira).
static func column(safe: Rect2) -> Rect2:
	var w := floorf(minf(safe.size.x - 8.0, MAX_WIDTH))
	return Rect2(floorf(safe.position.x + (safe.size.x - w) * 0.5), safe.position.y, w, safe.size.y)


static func wide(safe: Rect2) -> bool:
	return column(safe).size.x >= WIDE


## Pontos que a casca ocupa em cima e embaixo da área segura (Vector2(cima, baixo)).
static func insets_for(_view: Vector2, safe: Rect2) -> Vector2:
	var top := PAD + ROW + (0.0 if wide(safe) else GAP + ROW) + PAD
	return Vector2(top, TAB_BAR + TAB_RAISE + 4.0)


func _init() -> void:
	name = "NavShell"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_pilot = PilotBadge.new()
	add_child(_pilot)
	_power = PowerReadout.new()
	add_child(_power)
	for kind: String in CURRENCIES:
		var pill := CurrencyPill.new()
		pill.kind = kind
		pill.name = "Pill_" + kind
		pill.pressed.connect(func() -> void: _pick(&"shop"))
		add_child(pill)
		_pills[kind] = pill
	_options = UiTheme.icon_button("gear", "Options")
	_options.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_click")
		options_requested.emit())
	add_child(_options)
	for tab: StringName in TABS:
		var b := TabButton.new()
		b.name = "Tab_" + String(tab)
		b.tab = tab
		b.home = tab == HOME
		b.icon_tex = _tab_icon(tab)
		b.pressed.connect(_pick.bind(tab))
		add_child(b)
		_tabs[tab] = b
	resized.connect(_layout)
	MenuKit.on_insets_change(self, _layout)
	Locale.language_changed.connect(func(_code: String) -> void: refresh_texts())
	refresh_texts()
	_layout()


static func _tab_icon(tab: StringName) -> Texture2D:
	match tab:
		&"shop":
			return UiTheme.icon("shoppingCart")
		&"hangar":
			return UiTheme.icon("wrench")
		&"hub":
			return UiTheme.icon("target")
		&"ships":
			return ListScreen.icon(&"ship")
	return UiTheme.icon("trophy")


## Marca a aba ativa (a que acabou de abrir); a troca anima a subida.
func select(tab: StringName) -> void:
	current = tab
	for key: StringName in _tabs:
		(_tabs[key] as TabButton).set_active(key == tab, is_visible_in_tree())
	refresh_notices()


## Relê o perfil: moedas, Poder, piloto e avisos (anima o que mudou se a casca está à vista).
func refresh() -> void:
	if _pilot == null:
		return
	var profile := SaveManager.data
	var animate := is_visible_in_tree()
	for kind: String in CURRENCIES:
		(_pills[kind] as CurrencyPill).set_value(int((profile["wallet"] as Dictionary).get(kind, 0)), animate)
	_power.set_value(Economy.power(profile, DB.rows("ships"), DB.rows("wings")), animate)
	_pilot.set_pilot(Economy.pilot(profile))
	_pilot.tooltip_text = tr("command.pilot") % int(Economy.pilot(profile)["level"])
	refresh_notices()


func refresh_notices() -> void:
	var profile := SaveManager.data
	for tab: StringName in _tabs:
		(_tabs[tab] as TabButton).set_notice(tab != current and Notices.for_tab(profile, tab, App.today()))


func refresh_texts() -> void:
	if _pilot == null:
		return
	for tab: StringName in _tabs:
		(_tabs[tab] as TabButton).label_text = tr(String(TAB_LABELS[tab]))
	for kind: String in CURRENCIES:
		(_pills[kind] as Button).tooltip_text = tr("command.get_more") % tr("currency." + kind)
	_power.title = tr("command.power").to_upper()
	_power.tooltip_text = tr("command.power")
	_options.tooltip_text = tr("options.title")
	refresh()


func tab_button(tab: StringName) -> Button:
	return _tabs.get(tab) as Button


## Controles da casca para os testes de layout (todos na área segura, nenhum encostando).
func layout_controls() -> Array[Control]:
	var out: Array[Control] = [_pilot, _power, _options]
	for kind: String in CURRENCIES:
		out.append(_pills[kind])
	for tab: StringName in TABS:
		out.append(_tabs[tab])
	return out


func _pick(tab: StringName) -> void:
	AudioManager.play_ui("kenney_ui_tab")
	if tab != current:
		tab_selected.emit(tab)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or current == &"":
		return
	var step := 0
	if event.is_action_pressed(&"tab_prev"):
		step = -1
	elif event.is_action_pressed(&"tab_next"):
		step = 1
	if step == 0:
		return
	get_viewport().set_input_as_handled()
	var next := TABS[wrapi(TABS.find(current) + step, 0, TABS.size())]
	_pick(next)


func _layout() -> void:
	if _pilot == null:
		return
	var safe := MenuKit.safe_rect(size, MenuKit.safe_margins(self))
	var col := column(safe)
	var insets := insets_for(size, safe)
	var y := safe.position.y + PAD
	_pilot.position = Vector2(col.position.x, y)
	_pilot.size = Vector2(ROW, ROW)
	_options.position = Vector2(col.end.x - ROW, y)
	_options.size = Vector2(ROW, ROW)
	var power_x := col.position.x + ROW + 6.0
	var pills_y := y
	var pills_left := 0.0
	var pills_right := _options.position.x - 6.0
	if wide(safe):
		_power.position = Vector2(power_x, y)
		_power.size = Vector2(POWER_WIDTH, ROW)
		pills_left = power_x + POWER_WIDTH + 8.0
	else:
		_power.position = Vector2(power_x, y)
		_power.size = Vector2(_options.position.x - 6.0 - power_x, ROW)
		pills_y = y + ROW + GAP
		pills_left = col.position.x
		pills_right = col.end.x
	var pill_w := floorf(minf(PILL_MAX, (pills_right - pills_left - 8.0) / 3.0))
	var x := pills_right - pill_w * 3.0 - 8.0
	for kind: String in CURRENCIES:
		var pill := _pills[kind] as Control
		pill.position = Vector2(x, pills_y)
		pill.size = Vector2(pill_w, ROW)
		x += pill_w + 4.0
	_top_band = Rect2(0.0, 0.0, size.x, safe.position.y + insets.x - 1.0)
	# Abas: a coluna inteira, cinco partes iguais; a ativa sobe TAB_RAISE acima da barra.
	var bar_top := safe.end.y - TAB_BAR
	var tab_w := floorf(col.size.x / float(TABS.size()))
	var tabs_left := floorf(col.position.x + (col.size.x - tab_w * TABS.size()) * 0.5)
	for i: int in range(TABS.size()):
		var b := _tabs[TABS[i]] as Control
		b.position = Vector2(tabs_left + tab_w * i, bar_top - TAB_RAISE)
		b.size = Vector2(tab_w, TAB_BAR + TAB_RAISE)
	_bottom_band = Rect2(0.0, bar_top, size.x, size.y - bar_top)
	queue_redraw()


func _draw() -> void:
	# Faixa de cima: abismo quase opaco que se abre embaixo, com filete ciano.
	var t := _top_band
	if t.size.y > 0.0:
		var dark := Color(UiTheme.ABYSS, 0.94)
		var soft := Color(UiTheme.ABYSS, 0.78)
		draw_polygon(PackedVector2Array([t.position, Vector2(t.end.x, t.position.y), t.end, Vector2(t.position.x, t.end.y)]),
				PackedColorArray([dark, dark, soft, soft]))
		draw_polyline_colors(PackedVector2Array([Vector2(0, t.end.y), Vector2(t.size.x * 0.5, t.end.y),
				Vector2(t.end.x, t.end.y)]), PackedColorArray([Color(UiTheme.CYAN, 0.0), Color(UiTheme.CYAN, 0.45),
				Color(UiTheme.CYAN, 0.0)]), 1.0, true)
	var b := _bottom_band
	if b.size.y > 0.0:
		draw_rect(b, Color(UiTheme.ABYSS, 0.95))
		draw_rect(Rect2(b.position, Vector2(b.size.x, 1.0)), Color(UiTheme.CYAN, 0.3))


## Bloco da piloto: retrato 32x32 (arte de 96 px reduzida com mipmaps) com moldura ciano,
## o nível num selo dourado no canto de baixo à esquerda e a barrinha de experiência embaixo.
class PilotBadge:
	extends Control

	const PORTRAIT := 32.0

	var _texture: Texture2D
	var _level: int = 1
	var _progress: float = 0.0

	func _ready() -> void:
		name = "Pilot"
		mouse_filter = Control.MOUSE_FILTER_PASS
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_texture = Portraits.texture("mare", "smile")

	func set_pilot(pilot: Dictionary) -> void:
		_level = int(pilot.get("level", 1))
		_progress = clampf(float(pilot.get("xp", 0)) / maxf(1.0, float(pilot.get("need", 1))), 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var frame := Rect2(Vector2((size.x - PORTRAIT) * 0.5, 0.0), Vector2(PORTRAIT, PORTRAIT))
		draw_colored_polygon(CommandKit.chamfer_points(frame, 5.0), UiTheme.DEEP_BLUE)
		if _texture != null:
			draw_texture_rect(_texture, frame, false)
		var outline := CommandKit.chamfer_points(frame.grow(0.5), 5.0)
		outline.append(outline[0])
		draw_polyline(outline, UiTheme.CYAN, 1.5, true)
		# Experiência: trilho escuro e preenchimento ciano.
		var bar := Rect2(frame.position.x, frame.end.y + 1.0, PORTRAIT, 3.0)
		draw_rect(bar, Color(UiTheme.ABYSS, 0.95))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _progress, bar.size.y)), UiTheme.CYAN)
		# Nível.
		var font := CommandKit.bold(self)
		var fs := UiTheme.scaled(9)
		var text := str(_level)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var chip := Rect2(Vector2(frame.position.x - 2.0, frame.end.y - fs - 3.0), Vector2(tw + 7.0, fs + 3.0))
		draw_colored_polygon(CommandKit.chamfer_points(chip, 3.0, 1.0), UiTheme.GOLD)
		draw_string(font, Vector2(chip.position.x + 3.5, chip.end.y - 2.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UiTheme.GOLD_DARK)


## Poder: painel escuro com filete dourado, raio, "PODER" pequeno e o número grande em ouro, que conta
## até o valor novo quando muda.
class PowerReadout:
	extends Control

	var title: String = "":
		set(value):
			title = value
			queue_redraw()
	var _shown: float = -1.0
	var _target: int = 0

	func _ready() -> void:
		name = "Power"
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_value(value: int, animate: bool) -> void:
		if value == _target and _shown >= 0.0:
			return
		var from := _shown
		_target = value
		if from < 0.0 or not animate or UiFx.reduced():
			_shown = float(value)
			queue_redraw()
			return
		create_tween().tween_method(func(v: float) -> void:
			_shown = v
			queue_redraw(), from, float(value), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var rect := Rect2(Vector2(0.0, 3.0), Vector2(size.x, size.y - 6.0))
		var outline := CommandKit.chamfer_points(rect, 6.0)
		draw_colored_polygon(outline, Color(UiTheme.ABYSS, 0.7))
		outline.append(outline[0])
		draw_polyline(outline, Color(UiTheme.GOLD, 0.4), 1.0, true)
		var icon := ListScreen.icon(&"bolt")
		var side := 18.0
		draw_texture_rect(icon, Rect2(Vector2(6.0, (size.y - side) * 0.5), Vector2(side, side)), false, UiTheme.GOLD)
		var left := 6.0 + side + 5.0
		var room := size.x - left - 6.0
		var font := get_theme_font("font")
		var bold := CommandKit.bold(self)
		var small := CommandKit.fit_size(font, title, room, UiTheme.scaled(8), 6)
		draw_string(font, Vector2(left, rect.position.y + 4.0 + small), title, HORIZONTAL_ALIGNMENT_LEFT, room, small,
				UiTheme.TEXT_DIM)
		var number := Locale.format_number(roundi(maxf(_shown, 0.0)))
		var big := CommandKit.fit_size(bold, number, room, UiTheme.scaled(16), 9)
		draw_string(bold, Vector2(left, rect.end.y - 4.0), number, HORIZONTAL_ALIGNMENT_LEFT, room, big, UiTheme.GOLD)


## Pílula de moeda tocável (leva à Loja): ícone da moeda, saldo e o "+" ciano. O alvo de toque tem a
## altura inteira (36); a pílula desenhada é mais baixa. Saldo novo conta e a pílula acende na cor.
class CurrencyPill:
	extends Button

	const HEIGHT := 26.0

	var kind: String = "credits"
	var _shown: float = -1.0
	var _target: int = 0
	var _flash: float = 0.0

	func _init() -> void:
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _ready() -> void:
		for sig: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
			sig.connect(queue_redraw)

	## Saldo atual (às vezes compacto: 123K acima de cem mil, para caber em 270 de largura).
	static func compact(value: int) -> String:
		return Locale.format_number(value) if value < 100000 else Locale.format_number(value / 1000) + "K"

	func set_value(value: int, animate: bool) -> void:
		if value == _target and _shown >= 0.0:
			return
		var from := _shown
		_target = value
		if from < 0.0 or not animate or UiFx.reduced():
			_shown = float(value)
			queue_redraw()
			return
		var tween := create_tween().set_parallel()
		tween.tween_method(func(v: float) -> void:
			_shown = v
			queue_redraw(), from, float(value), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(v: float) -> void:
			_flash = v
			queue_redraw(), 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)

	func _draw() -> void:
		var color: Color = CURRENCY_COLORS.get(kind, UiTheme.GOLD)
		var rect := Rect2(Vector2(0.0, floorf((size.y - HEIGHT) * 0.5)), Vector2(size.x, HEIGHT))
		var outline := CommandKit.chamfer_points(rect, 6.0)
		draw_colored_polygon(outline, Color(UiTheme.ABYSS, 0.82).lerp(Color(color, 0.5), _flash * 0.5))
		var hot := has_focus() or is_hovered()
		outline.append(outline[0])
		draw_polyline(outline, UiTheme.WHITE if hot else Color(color, 0.55), 1.0, true)
		var icon_side := 14.0
		draw_texture_rect(ListScreen.icon(StringName(kind)), Rect2(Vector2(5.0, rect.position.y + (HEIGHT - icon_side)
				* 0.5), Vector2(icon_side, icon_side)), false)
		var plus_side := 16.0
		var plus := Rect2(Vector2(size.x - plus_side - 5.0, rect.position.y + (HEIGHT - plus_side) * 0.5),
				Vector2(plus_side, plus_side))
		var box := CommandKit.chamfer_points(plus, 3.0, 1.0)
		draw_colored_polygon(box, Color(UiTheme.CYAN, 0.22))
		box.append(box[0])
		draw_polyline(box, UiTheme.CYAN, 1.0, true)
		draw_texture_rect(ListScreen.icon(&"plus"), plus.grow(-3.0), false, UiTheme.CYAN)
		var left := 5.0 + icon_side + 4.0
		var room := plus.position.x - 4.0 - left
		var text := compact(roundi(maxf(_shown, 0.0)))
		var font := CommandKit.bold(self)
		var fs := CommandKit.fit_size(font, text, room, UiTheme.scaled(12), 7)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(left + maxf(0.0, (room - tw) * 0.5), rect.position.y + HEIGHT * 0.5 + fs * 0.36),
				text, HORIZONTAL_ALIGNMENT_LEFT, room, fs, UiTheme.WHITE)


## Aba da barra de baixo. Inativa: ícone 20 e rótulo apagados. Ativa: sobe TAB_RAISE, fundo ciano claro
## com filete, ícone 26 branco e rótulo ciano em negrito. A casa (Campanha) tem o ícone dourado.
class TabButton:
	extends Button

	var tab: StringName = &""
	var home: bool = false
	var icon_tex: Texture2D
	var label_text: String = "":
		set(value):
			label_text = value
			tooltip_text = value
			queue_redraw()
	var active: bool = false
	## 0 = repouso, 1 = aba ativa (anima a subida).
	var rise: float = 0.0:
		set(value):
			rise = value
			_place_dot()
			queue_redraw()

	var _dot: CommandKit.NoticeDot

	func _init() -> void:
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _ready() -> void:
		_dot = CommandKit.NoticeDot.new()
		var side := float(UiTheme.scaled(12))
		_dot.size = Vector2(side, side)
		_dot.visible = false
		add_child(_dot)
		resized.connect(_place_dot)
		for sig: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
			sig.connect(queue_redraw)
		_place_dot()

	func set_active(on: bool, animate: bool) -> void:
		active = on
		var goal := 1.0 if on else 0.0
		if not animate or UiFx.reduced() or not is_inside_tree():
			rise = goal
			return
		create_tween().tween_property(self, "rise", goal, ANIM).set_trans(Tween.TRANS_BACK if on else Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_OUT)

	func set_notice(on: bool) -> void:
		if _dot != null:
			_dot.visible = on

	func has_notice() -> bool:
		return _dot != null and _dot.visible

	func _icon_side() -> float:
		return lerpf(20.0, 26.0, clampf(rise, 0.0, 1.2))

	func _icon_top() -> float:
		return lerpf(TAB_RAISE + 7.0, 4.0, clampf(rise, 0.0, 1.2))

	func _place_dot() -> void:
		if _dot == null:
			return
		var side := _icon_side()
		_dot.position = Vector2(size.x * 0.5 + side * 0.5 - _dot.size.x * 0.45, _icon_top() - _dot.size.y * 0.35)

	func _draw() -> void:
		var r := clampf(rise, 0.0, 1.0)
		if r > 0.0:
			var panel := Rect2(Vector2(2.0, TAB_RAISE * (1.0 - r)), Vector2(size.x - 4.0, size.y - TAB_RAISE * (1.0 - r)))
			var pts := CommandKit.chamfer_points(panel, 7.0)
			var top := Color(UiTheme.CYAN.lerp(UiTheme.WHITE, 0.15), 0.34 * r)
			var bottom := Color(UiTheme.RAISED, 0.96 * r)
			draw_polygon(pts, PackedColorArray([top, top, top, bottom, bottom, bottom, bottom, top]))
			pts.append(pts[0])
			draw_polyline(pts, Color(UiTheme.CYAN, 0.9 * r), 1.0, true)
			draw_line(Vector2(panel.position.x + 7.0, panel.position.y + 1.0),
					Vector2(panel.end.x - 2.0, panel.position.y + 1.0), Color(UiTheme.WHITE, 0.8 * r), 2.0, true)
		var hot := has_focus() or is_hovered()
		if has_focus():
			var ring := CommandKit.chamfer_points(Rect2(Vector2(1.0, TAB_RAISE * (1.0 - r)),
					Vector2(size.x - 2.0, size.y - TAB_RAISE * (1.0 - r) - 1.0)), 7.0)
			ring.append(ring[0])
			draw_polyline(ring, UiTheme.WHITE, 1.5, true)
		var side := _icon_side()
		var icon_color := UiTheme.WHITE if active or hot else (UiTheme.GOLD if home else UiTheme.TEXT_DIM)
		if icon_tex != null:
			draw_texture_rect(icon_tex, Rect2(Vector2((size.x - side) * 0.5, _icon_top()), Vector2(side, side)), false,
					icon_color)
		var font := CommandKit.bold(self) if active else get_theme_font("font")
		var fs := CommandKit.fit_size(font, label_text, size.x - 6.0, UiTheme.scaled(10), 7)
		var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - tw) * 0.5, size.y - 7.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UiTheme.CYAN if active else (UiTheme.WHITE if hot else UiTheme.TEXT_DIM))
