class_name HubScreen
extends Screen
## Hub interativo (plano mestre 7.2, no espírito do menu de Star Wars: Galaxy of Heroes, sem copiar
## nada dele): cena viva do hangar em parallax, saldo no topo, banner de destaque, botão JOGAR na zona
## do polegar e abas embaixo. No Vertical Slice só Hangar e Campanha estão abertas.

const TAB_HEIGHT := 48.0
const PLAY_HEIGHT := 52.0
const TABS: Array[StringName] = [&"hangar", &"campaign", &"ships", &"events", &"shop"]
const OPEN_TABS: Array[StringName] = [&"hangar", &"campaign"]

var _stage: HangarStage
var _wallet: Label
var _credits_button: Button
var _banner: Button
var _play: Button
var _tabs: HBoxContainer
var _tab_buttons: Dictionary = {}
var _banner_index: int = 0
var _banner_timer: float = 0.0


func _build() -> void:
	_stage = HangarStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.ship_tapped.connect(func() -> void: AudioManager.play_ui("kenney_ui_confirm"))
	add_child(_stage)
	_wallet = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.GOLD)
	_wallet.add_theme_color_override("font_outline_color", UiTheme.VOLCANIC)
	_wallet.add_theme_constant_override("outline_size", 4)
	add_child(_wallet)
	_credits_button = Button.new()
	_credits_button.name = "Credits"
	_credits_button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN)
	_credits_button.text = "i"
	_credits_button.pressed.connect(func() -> void: navigate.emit(&"credits"))
	add_child(_credits_button)
	_banner = Button.new()
	_banner.name = "Banner"
	_banner.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_banner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_banner.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 8.0)
	_banner.pressed.connect(func() -> void: navigate.emit(&"map"))
	add_child(_banner)
	_play = Button.new()
	_play.name = "Play"
	_play.custom_minimum_size = Vector2(0, PLAY_HEIGHT)
	_play.add_theme_font_size_override("font_size", UiTheme.HEADING_SIZE)
	_play.add_theme_stylebox_override("normal", _gold_box(false))
	_play.add_theme_stylebox_override("hover", _gold_box(true))
	_play.add_theme_stylebox_override("pressed", _gold_box(true))
	_play.add_theme_stylebox_override("focus", _gold_box(true))
	_play.pressed.connect(func() -> void: navigate.emit(&"map"))
	add_child(_play)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 2)
	add_child(_tabs)
	for tab: StringName in TABS:
		var b := Button.new()
		b.name = "Tab_" + String(tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, TAB_HEIGHT)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.disabled = not tab in OPEN_TABS
		# Abas estreitas: margem interna mínima para o nome caber inteiro.
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var box := UiTheme.button_box(state)
			box.content_margin_left = 2
			box.content_margin_right = 2
			if tab == &"hangar":
				box.border_color = UiTheme.GOLD
			b.add_theme_stylebox_override(state, box)
		b.pressed.connect(_on_tab.bind(tab))
		_tabs.add_child(b)
		_tab_buttons[tab] = b


func _gold_box(hot: bool) -> StyleBoxFlat:
	var box := UiTheme.button_box("normal")
	box.bg_color = Color("6b4a12") if not hot else Color("8a6418")
	box.border_color = UiTheme.GOLD
	box.set_border_width_all(2)
	return box


func on_show(_app: Node) -> void:
	_stage.reduce_motion = bool(Settings.get_value("reduce_motion"))
	refresh_texts()


func _process(delta: float) -> void:
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
	_wallet.text = "%s %s   %s %s   %s %s" % [tr("currency.credits"), Locale.format_number(int(wallet["credits"])),
			tr("currency.orichalcum"), Locale.format_number(int(wallet["orichalcum"])),
			tr("currency.pearls"), Locale.format_number(int(wallet["pearls"]))]
	_play.text = tr("hub.play") % "1-1"
	for tab: StringName in TABS:
		var b: Button = _tab_buttons[tab]
		b.text = tr("hub.tab_" + String(tab))
		b.tooltip_text = "" if tab in OPEN_TABS else tr("hub.soon")
	_update_banner()
	relayout()


func _update_banner() -> void:
	_banner.text = tr("hub.banner_c1") if _banner_index == 0 else tr("hub.banner_daily")
	_banner.disabled = _banner_index != 0


func _layout() -> void:
	if _tabs == null:
		return
	var left := safe.position.x + 8.0
	var width := safe.size.x - 16.0
	_tabs.position = Vector2(left, safe.end.y - TAB_HEIGHT - 6.0)
	_tabs.size = Vector2(width, TAB_HEIGHT)
	var play_width := minf(width, 300.0)
	_play.size = Vector2(play_width, PLAY_HEIGHT)
	_play.position = Vector2(floorf(safe.position.x + (safe.size.x - play_width) * 0.5),
			_tabs.position.y - PLAY_HEIGHT - 12.0)
	_credits_button.position = Vector2(safe.end.x - UiTheme.TOUCH_MIN - 6.0, safe.position.y + 6.0)
	_wallet.position = Vector2(left, safe.position.y + 14.0)
	_wallet.size = Vector2(_credits_button.position.x - left - 8.0, 0)
	_wallet.clip_text = true
	_banner.position = Vector2(left, safe.position.y + UiTheme.TOUCH_MIN + 16.0)
	_banner.size = Vector2(width, UiTheme.TOUCH_MIN + 8.0)


func _on_tab(tab: StringName) -> void:
	AudioManager.play_ui("kenney_ui_tab")
	if tab == &"campaign":
		navigate.emit(&"map")


func layout_controls() -> Array[Control]:
	return [_wallet, _credits_button, _banner, _play, _tabs]


## Volta para o título.
func back() -> bool:
	navigate.emit(&"boot")
	return true
