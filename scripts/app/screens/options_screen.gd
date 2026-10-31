class_name OptionsScreen
extends ListScreen
## Opções (plano mestre 2.4 e 7.5): idioma, áudio, controle, acessibilidade e qualidade gráfica.
## Cada controle grava na hora (Settings.set_value); nada exige reiniciar.

const SLIDERS: Array[Array] = [["music_volume", 0.0, 1.0], ["sfx_volume", 0.0, 1.0], ["ui_volume", 0.0, 1.0],
		["screen_shake", 0.0, 1.0], ["drag_sensitivity", 0.8, 2.0]]
const TOGGLES: Array[String] = ["auto_fire", "vibration", "reduce_flashes", "reduce_motion", "tilt_parallax",
		"show_fps"]


func title_key() -> String:
	return "options.title"


func _fill() -> void:
	add_heading(tr("options.general"))
	var lang := Button.new()
	lang.name = "Language"
	lang.text = String(Languages.NATIVE_NAMES.get(Locale.current, Locale.current))
	lang.pressed.connect(func() -> void:
		var i := Languages.SUPPORTED.find(Locale.current)
		Locale.set_language(Languages.SUPPORTED[(i + 1) % Languages.SUPPORTED.size()]))
	add_row(tr("options.language"), lang)
	var gfx := Button.new()
	gfx.name = "Graphics"
	gfx.text = GfxQuality.mode_label(GfxQuality.mode())
	gfx.pressed.connect(func() -> void:
		Settings.set_value("graphics_quality", GfxQuality.next_mode(GfxQuality.mode()))
		refill())
	add_row(tr("options.graphics"), gfx)
	var hand := Button.new()
	hand.name = "Handedness"
	hand.text = tr("options.hand_" + String(Settings.get_value("handedness")))
	hand.pressed.connect(func() -> void:
		Settings.set_value("handedness", "left" if Settings.get_value("handedness") == "right" else "right")
		refill())
	add_row(tr("options.handedness"), hand)
	add_heading(tr("options.audio_controls"))
	for entry: Array in SLIDERS:
		var key: String = entry[0]
		var slider := HSlider.new()
		slider.name = key
		slider.min_value = float(entry[1])
		slider.max_value = float(entry[2])
		slider.step = 0.05
		slider.value = float(Settings.get_value(key))
		slider.drag_ended.connect(func(_changed: bool) -> void: Settings.set_value(key, slider.value))
		add_row(tr("options." + key), slider)
	add_heading(tr("options.accessibility"))
	for key: String in TOGGLES:
		var check := CheckButton.new()
		check.name = key
		check.button_pressed = bool(Settings.get_value(key))
		check.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
		add_row(tr("options." + key), check)
	add_heading(tr("options.data"))
	add_button(tr("options.logbook"), func() -> void: navigate.emit(&"logbook"))
	add_button(tr("options.credits"), func() -> void: navigate.emit(&"credits"))
