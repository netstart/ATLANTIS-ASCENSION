class_name HubScreen
extends Screen
## Hub (plano mestre 7.2, redesenho 1.6 "neon abissal"): a aeronave num pedestal holográfico sobre o
## fundo abissal compartilhado. Topo só com moedas e dois ícones (opções e créditos); um cartão do
## capítulo atual; uma única ação dourada (JOGAR) na zona do polegar; atalhos secundários de vidro
## (Diário e Cidade) logo acima; e a barra de 5 abas com ícone e rótulo embaixo: Hangar, Campanha,
## Naves, Eventos e Loja. Ao abrir no dia, o login de 7 dias entrega a recompensa num aviso que some.

const TAB_HEIGHT := 50.0
const PLAY_HEIGHT := 56.0
const TABS: Array[StringName] = [&"hangar", &"campaign", &"ships", &"events", &"shop"]
const OPEN_TABS: Array[StringName] = [&"hangar", &"campaign", &"ships", &"events", &"shop"]
const TAB_ICONS := {
	&"hangar": "wrench", &"campaign": "target", &"ships": "joystick", &"events": "trophy", &"shop": "shoppingCart",
}
## Moedas no topo: chave, cor do losango.
const CURRENCIES := [["credits", Color("2ff3e0")], ["orichalcum", Color("ffc94a")], ["pearls", Color("b57bff")]]
const TOAST_SECONDS := 4.0

var _stage: HangarStage
var _wallet: HBoxContainer
var _wallet_labels: Dictionary = {}
var _credits_button: Button
var _options: Button
var _banner: Button
var _banner_kicker: Label
var _banner_title: Label
var _play: Button
var _logbook: Button
var _city: Button
var _toast: PanelContainer
var _toast_label: Label
var _toast_left: float = 0.0
var _tabs: HBoxContainer
var _tab_buttons: Dictionary = {}
var _banner_index: int = 0
var _banner_timer: float = 0.0


func _build() -> void:
	_stage = HangarStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.ship_tapped.connect(func() -> void: AudioManager.play_ui("kenney_ui_confirm"))
	add_child(_stage)
	_build_top()
	_build_banner()
	_play = Button.new()
	_play.name = "Play"
	UiTheme.style_primary(_play, 18)
	_play.clip_text = true
	_play.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_play.pressed.connect(_on_play)
	add_child(_play)
	_logbook = _side_button("Logbook", "menuList", func() -> void: navigate.emit(&"logbook"))
	_city = _side_button("City", "home", func() -> void: navigate.emit(&"city"))
	_build_toast()
	_build_tabs()


func _build_top() -> void:
	_wallet = HBoxContainer.new()
	_wallet.add_theme_constant_override("separation", 4)
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wallet)
	for entry: Array in CURRENCIES:
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UiTheme.pill_box(entry[1]))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		pill.add_child(row)
		# Losango da moeda (um quadrado girado): cor = qual moeda, sem depender de glifo da fonte.
		var gem := Control.new()
		gem.custom_minimum_size = Vector2(8, 8)
		gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var dot := ColorRect.new()
		dot.color = entry[1]
		dot.size = Vector2(6, 6)
		dot.position = Vector2(4, 0)
		dot.rotation = PI * 0.25
		gem.add_child(dot)
		row.add_child(gem)
		var value := UiTheme.label("0", UiTheme.FONT_SIZE, UiTheme.TEXT)
		var bold := UiTheme.bold_font()
		if bold != null:
			value.add_theme_font_override("font", bold)
		row.add_child(value)
		_wallet.add_child(pill)
		_wallet_labels[entry[0]] = value
	_options = UiTheme.icon_button("gear", "Options")
	_options.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_click")
		navigate.emit(&"options"))
	add_child(_options)
	_credits_button = UiTheme.icon_button("information", "Credits")
	_credits_button.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_click")
		navigate.emit(&"credits"))
	add_child(_credits_button)


## Cartão do capítulo: "Capítulo 1" em ciano pequeno e o título em negrito, num vidro com borda dourada.
func _build_banner() -> void:
	_banner = Button.new()
	_banner.name = "Banner"
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := UiTheme.panel_box(UiTheme.GOLD if state != "disabled" else UiTheme.CYAN, 0.78)
		if state in ["hover", "focus"]:
			box.border_color = UiTheme.GOLD
			box.shadow_color = Color(UiTheme.GOLD, 0.25)
			box.shadow_offset = Vector2.ZERO
		_banner.add_theme_stylebox_override(state, box)
	_banner.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_click")
		navigate.emit(&"map"))
	add_child(_banner)
	_banner_kicker = UiTheme.label("", UiTheme.SMALL_SIZE, UiTheme.CYAN)
	_banner_kicker.clip_text = true
	_banner_kicker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_banner_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_kicker)
	_banner_title = UiTheme.heading("", UiTheme.FONT_SIZE + 1, UiTheme.WHITE)
	_banner_title.clip_text = true
	_banner_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_banner_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_title)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.GOLD, 0.92))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_label = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.GOLD, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	add_child(_toast)


func _build_tabs() -> void:
	var bar := PanelContainer.new()
	bar.name = "TabBar"
	var bar_box := UiTheme.chamfer(Color(UiTheme.ABYSS, 0.82), Color(UiTheme.CYAN, 0.25), 0, UiTheme.CUT)
	bar_box.border_width_top = 1
	bar_box.set_content_margin_all(2)
	bar.add_theme_stylebox_override("panel", bar_box)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 0)
	bar.add_child(_tabs)
	for tab: StringName in TABS:
		var b := Button.new()
		b.name = "Tab_" + String(tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, TAB_HEIGHT - 4.0)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.disabled = not tab in OPEN_TABS
		b.icon = UiTheme.icon(TAB_ICONS[tab])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_constant_override("h_separation", 1)
		b.add_theme_font_size_override("font_size", UiTheme.scaled(UiTheme.SMALL_SIZE))
		UiTheme.style_tab(b, tab == &"campaign")
		b.add_theme_color_override("icon_normal_color", UiTheme.CYAN if tab == &"campaign" else UiTheme.TEXT_DIM)
		b.add_theme_color_override("icon_hover_color", UiTheme.WHITE)
		b.add_theme_color_override("icon_focus_color", UiTheme.WHITE)
		b.add_theme_color_override("icon_pressed_color", UiTheme.CYAN)
		b.pressed.connect(_on_tab.bind(tab))
		_tabs.add_child(b)
		_tab_buttons[tab] = b


## Atalho secundário (vidro, ícone + texto) acima do botão Jogar.
func _side_button(button_name: String, icon_name: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.name = button_name
	b.icon = UiTheme.icon(icon_name)
	b.expand_icon = true
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.add_theme_constant_override("icon_max_width", 14)
	b.add_theme_color_override("icon_normal_color", UiTheme.CYAN)
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_click")
		on_press.call())
	add_child(b)
	return b


## Jogar: a cena de história pendente (prólogo, fim de ato) vem antes do mapa.
func _on_play() -> void:
	AudioManager.play_ui("kenney_ui_confirm")
	navigate.emit(&"story" if not StoryScreen.pending(SaveManager.data).is_empty() else &"map")


func on_show(_app: Node) -> void:
	_stage.reduce_motion = bool(Settings.get_value("reduce_motion"))
	var reward := LiveOps.login(SaveManager.data, App.today())
	if not reward.is_empty():
		SaveManager.save_profile()
		AudioManager.play_ui("kenney_ui_confirm")
		show_toast(tr("hub.login_reward") % [int(SaveManager.data["login"]["streak"]), reward_text(reward)])
	refresh_texts()


## "+400 Créditos, +10 Pérolas".
static func reward_text(reward: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: String in reward:
		if k != "core":
			parts.append("+%d %s" % [int(reward[k]), TranslationServer.translate("currency." + k)])
	return ", ".join(parts)


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast_left = TOAST_SECONDS
	relayout()


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left, 0.0, 1.0)
		_toast.visible = _toast_left > 0.0
	_banner_timer += delta
	if _banner_timer > 6.0:
		_banner_timer = 0.0
		_banner_index = (_banner_index + 1) % 2
		_update_banner()
	if bool(Settings.get_value("tilt_parallax")) and OS.has_feature("mobile"):
		var acc := Input.get_accelerometer()
		_stage.tilt = Vector2(clampf(acc.x / 4.0, -1.0, 1.0), clampf((acc.y + 6.0) / 6.0, -1.0, 1.0))


func refresh_texts() -> void:
	var wallet := SaveManager.data["wallet"] as Dictionary
	for key: String in _wallet_labels:
		var value := _wallet_labels[key] as Label
		value.text = Locale.format_number(int(wallet[key]))
		(value.get_parent().get_parent() as Control).tooltip_text = tr("currency." + key)
	var next := Economy.next_mission(SaveManager.data)
	_play.text = tr("hub.play") % MapScreen.node_label(Economy.node(next))
	_options.tooltip_text = tr("options.title")
	_credits_button.tooltip_text = tr("boot.credits")
	_logbook.text = tr("logbook.title")
	_city.text = tr("city.title")
	for tab: StringName in TABS:
		var b: Button = _tab_buttons[tab]
		b.text = tr("hub.tab_" + String(tab))
		b.tooltip_text = "" if tab in OPEN_TABS else tr("hub.soon")
	_update_banner()
	relayout()


func _update_banner() -> void:
	var chapter := int(Economy.node(Economy.next_mission(SaveManager.data))["chapter"])
	var text := tr("hub.banner_c%d" % chapter) if _banner_index == 0 else tr("hub.banner_daily")
	# "Capítulo 1 · A Halcyon pede socorro": antes do ponto vira o chapéu, depois o título.
	var parts := text.split(" · ", false, 1)
	_banner_kicker.text = parts[0].to_upper() if parts.size() > 1 else tr("hub.tab_campaign").to_upper()
	_banner_title.text = parts[1] if parts.size() > 1 else text
	_banner.tooltip_text = text
	_banner.disabled = _banner_index != 0


func _layout() -> void:
	if _tabs == null:
		return
	var left := safe.position.x + 8.0
	var width := safe.size.x - 16.0
	var column := minf(width, 360.0)
	var col_left := floorf(safe.position.x + (safe.size.x - column) * 0.5)
	# Topo: ícones à direita, moedas à esquerda no que sobra.
	var top := safe.position.y + 6.0
	_credits_button.size = Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN)
	_credits_button.position = Vector2(safe.end.x - UiTheme.TOUCH_MIN - 8.0, top)
	_options.size = _credits_button.size
	_options.position = _credits_button.position - Vector2(UiTheme.TOUCH_MIN + 6.0, 0.0)
	_wallet.reset_size()
	_wallet.position = Vector2(left, top + floorf((UiTheme.TOUCH_MIN - _wallet.size.y) * 0.5))
	var wallet_room := _options.position.x - left - 6.0
	_wallet.scale = Vector2.ONE * minf(1.0, wallet_room / maxf(_wallet.size.x, 1.0))
	# Cartão do capítulo.
	var banner_h := UiTheme.TOUCH_MIN + 14.0
	_banner.position = Vector2(col_left, top + UiTheme.TOUCH_MIN + 10.0)
	_banner.size = Vector2(column, banner_h)
	_banner_kicker.position = Vector2(14.0, 8.0)
	_banner_kicker.size = Vector2(column - 28.0, 14.0)
	_banner_title.position = Vector2(14.0, 21.0)
	_banner_title.size = Vector2(column - 28.0, 22.0)
	# Base: abas, Jogar e atalhos.
	var bar := _tabs.get_parent() as Control
	# No desktop a barra não atravessa a tela inteira: fica na coluna central, como num celular grande.
	var bar_w := minf(safe.size.x - 8.0, 560.0)
	bar.position = Vector2(floorf(safe.position.x + (safe.size.x - bar_w) * 0.5), safe.end.y - TAB_HEIGHT - 4.0)
	bar.size = Vector2(bar_w, TAB_HEIGHT)
	var play_width := minf(column, 320.0)
	_play.size = Vector2(play_width, PLAY_HEIGHT)
	_play.position = Vector2(floorf(safe.position.x + (safe.size.x - play_width) * 0.5),
			bar.position.y - PLAY_HEIGHT - 14.0)
	var half := floorf((play_width - 8.0) * 0.5)
	var row_y := _play.position.y - UiTheme.TOUCH_MIN - 10.0
	for k: int in range(2):
		var b: Button = [_logbook, _city][k]
		b.size = Vector2(half, UiTheme.TOUCH_MIN)
		b.position = Vector2(_play.position.x + k * (half + 8.0), row_y)
	# Altura do aviso pelo texto quebrado na largura útil (rótulo com quebra não sabe a própria altura
	# antes de ter largura).
	var text_w := column - 24.0
	var font_size := _toast_label.get_theme_font_size("font_size")
	var text_h := _toast_label.get_theme_font("font").get_multiline_string_size(_toast_label.text,
			HORIZONTAL_ALIGNMENT_CENTER, text_w, font_size).y
	_toast_label.custom_minimum_size = Vector2(text_w, text_h)
	_toast.size = Vector2(column, 0.0)
	_toast.reset_size()
	_toast.position = Vector2(col_left, _banner.position.y + banner_h + 10.0)


func _on_tab(tab: StringName) -> void:
	AudioManager.play_ui("kenney_ui_tab")
	match tab:
		&"campaign":
			navigate.emit(&"map")
		&"hangar":
			navigate.emit(&"hangar")
		&"ships":
			navigate.emit(&"ships")
		&"events":
			navigate.emit(&"events")
		&"shop":
			navigate.emit(&"shop")


func layout_controls() -> Array[Control]:
	return [_wallet, _credits_button, _options, _banner, _play, _tabs, _logbook, _city]


## Volta para o título.
func back() -> bool:
	navigate.emit(&"boot")
	return true
