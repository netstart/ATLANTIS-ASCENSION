class_name OptionsScreen
extends ListScreen
## Opções (plano mestre 2.4 e 7.5): idioma, áudio, controle, acessibilidade e qualidade gráfica.
## Cada controle grava na hora (Settings.set_value); nada exige reiniciar.
##
## Cada grupo é um cartão de vidro com título. Interruptores e controles deslizantes são desenhados
## por cima do controle nativo (chanfro do tema, vetor nítido na resolução física): o nó continua
## CheckButton/HSlider, com o mesmo nome e sinais, só a pele muda.

const SLIDERS: Array[Array] = [["music_volume", 0.0, 1.0], ["sfx_volume", 0.0, 1.0], ["ui_volume", 0.0, 1.0],
		["screen_shake", 0.0, 1.0], ["drag_sensitivity", 0.8, 2.0]]
const TOGGLES: Array[String] = ["auto_fire", "vibration", "reduce_flashes", "reduce_motion", "tilt_parallax",
		"show_fps", "ghost"]
const SWITCH := Vector2(34, 18)
const KNOB := 14.0

static var _blank_switch: ImageTexture
static var _blank_knob: ImageTexture


func title_key() -> String:
	return "options.title"


func _fill() -> void:
	add_heading(tr("options.general"))
	var general := card()
	var lang := Button.new()
	lang.name = "Language"
	lang.text = String(Languages.NATIVE_NAMES.get(Locale.current, Locale.current))
	lang.pressed.connect(func() -> void:
		var i := Languages.SUPPORTED.find(Locale.current)
		Locale.set_language(Languages.SUPPORTED[(i + 1) % Languages.SUPPORTED.size()]))
	add_row(tr("options.language"), lang, general)
	var gfx := Button.new()
	gfx.name = "Graphics"
	gfx.text = GfxQuality.mode_label(GfxQuality.mode())
	gfx.pressed.connect(func() -> void:
		Settings.set_value("graphics_quality", GfxQuality.next_mode(GfxQuality.mode()))
		refill())
	add_row(tr("options.graphics"), gfx, general)
	var hand := Button.new()
	hand.name = "Handedness"
	hand.text = tr("options.hand_" + String(Settings.get_value("handedness")))
	hand.pressed.connect(func() -> void:
		Settings.set_value("handedness", "left" if Settings.get_value("handedness") == "right" else "right")
		refill())
	add_row(tr("options.handedness"), hand, general)
	var cb := Button.new()
	cb.name = "Colorblind"
	cb.text = tr("options.cb_" + String(Settings.get_value("colorblind")))
	cb.pressed.connect(func() -> void:
		var modes := ["off", "protanopia", "deuteranopia", "tritanopia"]
		var i := modes.find(String(Settings.get_value("colorblind")))
		Settings.set_value("colorblind", modes[(i + 1) % modes.size()])
		refill())
	add_row(tr("options.colorblind"), cb, general)
	var ts := Button.new()
	ts.name = "TextScale"
	ts.text = "%d%%" % roundi(float(Settings.get_value("text_scale")) * 100.0)
	ts.pressed.connect(func() -> void:
		var steps := [1.0, 1.15, 1.3]
		var i := steps.find(snappedf(float(Settings.get_value("text_scale")), 0.01))
		Settings.set_value("text_scale", steps[(i + 1) % steps.size()]))
	add_row(tr("options.text_scale"), ts, general)
	if not OS.has_feature("mobile"):
		# PC e Steam: janela em pé (tate), deitada ou tela cheia.
		var win := Button.new()
		win.name = "WindowMode"
		win.text = tr("options.window_" + String(Settings.get_value("window_mode")))
		win.pressed.connect(func() -> void:
			var modes: Array[String] = ["portrait", "landscape", "fullscreen"]
			var i := modes.find(String(Settings.get_value("window_mode")))
			Settings.set_value("window_mode", modes[(i + 1) % modes.size()])
			refill())
		add_row(tr("options.window"), win, general)
	for b: Node in general.find_children("*", "Button", true, false):
		(b as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_heading(tr("options.audio_controls"))
	var audio := card()
	for entry: Array in SLIDERS:
		var key: String = entry[0]
		var slider := HSlider.new()
		slider.name = key
		slider.min_value = float(entry[1])
		slider.max_value = float(entry[2])
		slider.step = 0.05
		slider.value = float(Settings.get_value(key))
		slider.drag_ended.connect(func(_changed: bool) -> void: Settings.set_value(key, slider.value))
		add_row(tr("options." + key), _slider_with_value(slider), audio)
	add_heading(tr("options.accessibility"))
	var access := card()
	for key: String in TOGGLES:
		var check := CheckButton.new()
		check.name = key
		check.button_pressed = bool(Settings.get_value(key))
		check.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
		_skin_switch(check)
		add_row(tr("options." + key), check, access)
	add_heading(tr("options.data"))
	var data := card()
	button(data, tr("options.logbook"), func() -> void: navigate.emit(&"logbook"))
	button(data, tr("options.credits"), func() -> void: navigate.emit(&"credits"))


## Controle deslizante com o valor em % à direita (atualiza enquanto arrasta).
func _slider_with_value(slider: HSlider) -> Control:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.custom_minimum_size = Vector2(150, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 24)
	_skin_slider(slider)
	wrap.add_child(slider)
	var value := UiTheme.label("", UiTheme.SMALL_SIZE, UiTheme.CYAN)
	value.custom_minimum_size = Vector2(UiTheme.scaled(28), 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var show := func(v: float) -> void:
		value.text = "%d%%" % roundi(v * 100.0)
	show.call(slider.value)
	slider.value_changed.connect(show)
	wrap.add_child(value)
	return wrap


## Interruptor: esconde os ícones nativos (textura vazia do mesmo tamanho, para reservar o lugar) e
## desenha trilho e botão chanfrados por cima; menta ligado, apagado desligado.
static func _skin_switch(check: CheckButton) -> void:
	if _blank_switch == null:
		_blank_switch = ImageTexture.create_from_image(Image.create(int(SWITCH.x), int(SWITCH.y), false,
				Image.FORMAT_RGBA8))
	for key: String in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored",
			"unchecked_mirrored", "checked_disabled_mirrored", "unchecked_disabled_mirrored"]:
		check.add_theme_icon_override(key, _blank_switch)
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
		check.add_theme_stylebox_override(state, empty)
	var focus := UiTheme.chamfer(Color(UiTheme.CYAN, 0.06), UiTheme.CYAN, 1, UiTheme.CUT_SMALL)
	check.add_theme_stylebox_override("focus", focus)
	check.draw.connect(func() -> void:
		var on := check.button_pressed
		var at := Vector2(check.size.x - SWITCH.x - 4.0, floorf((check.size.y - SWITCH.y) * 0.5))
		var track := UiTheme.chamfer(Color(UiTheme.MINT, 0.22) if on else Color(UiTheme.ABYSS, 0.85),
				UiTheme.MINT if on else Color(UiTheme.TEXT_DIM, 0.45), 1, 5)
		check.draw_style_box(track, Rect2(at, SWITCH))
		var knob_x := at.x + (SWITCH.x - KNOB - 3.0 if on else 3.0)
		var knob := UiTheme.chamfer(UiTheme.MINT if on else UiTheme.TEXT_DIM, Color(0, 0, 0, 0), 0, 4)
		if on:
			knob.shadow_color = Color(UiTheme.MINT, 0.45)
			knob.shadow_size = 4
		check.draw_style_box(knob, Rect2(Vector2(knob_x, at.y + 3.0), Vector2(KNOB, SWITCH.y - 6.0))))


## Controle deslizante: trilho do tema e um botão chanfrado ciano desenhado por cima do nativo.
static func _skin_slider(slider: HSlider) -> void:
	if _blank_knob == null:
		_blank_knob = ImageTexture.create_from_image(Image.create(int(KNOB), int(KNOB), false, Image.FORMAT_RGBA8))
	for key: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(key, _blank_knob)
	slider.draw.connect(func() -> void:
		var span := maxf(0.001, slider.max_value - slider.min_value)
		var t := (slider.value - slider.min_value) / span
		var x := floorf(t * (slider.size.x - KNOB))
		var knob := UiTheme.chamfer(UiTheme.CYAN, Color(UiTheme.WHITE, 0.9), 1, 4)
		knob.shadow_color = Color(UiTheme.CYAN, 0.4)
		knob.shadow_size = 4 if slider.has_focus() else 2
		slider.draw_style_box(knob, Rect2(Vector2(x, floorf((slider.size.y - KNOB - 2.0) * 0.5)),
				Vector2(KNOB, KNOB + 2.0))))
