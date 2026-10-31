class_name GameHud
extends Control
## HUD da missão (plano mestre 7.4). Posições vêm do Playfield: em telas altas o HUD fica acima do
## campo e os botões na zona do polegar; em telas curtas o HUD fica sobre o campo (≤ 6%); no desktop
## vai para o painel lateral. Lê a Sim a cada quadro; só troca textos quando o valor muda.

signal pause_pressed
signal special_pressed
signal bomb_pressed
signal tide_pressed
## Bênção escolhida no painel de oferta (0 a 2).
signal blessing_chosen(index: int)
signal resume_pressed
signal restart_pressed
signal quit_pressed

const RADIO_SECONDS := 4.0
const BANNER_SECONDS := 2.4
const BUTTON := 44.0
const OBJECTIVE_SECONDS := 5.0
## Dicas da primeira missão (tutorial em jogo, plano mestre 7.5): passo da Sim e chave do texto.
const HINTS: Array[Array] = [[60, "hint.move"], [420, "hint.graze"], [900, "hint.orbs"], [1500, "hint.special"],
		[2100, "hint.tide"], [2700, "hint.marked"]]

var layout := {}
var safe := Rect2()

var _score: Label
var _mult: Label
var _hull: Label
var _bombs: Label
var _weapon: Label
var _pause: Button
var _special: Button
var _bomb: Button
var _tide: Button
var _pressure: ProgressBar
var _objective: Label
var _offer_panel: PanelContainer
var _offer_title: Label
var _offer_buttons: Array[Button] = []
var _radio: Label
var _banner: Label
var _prompt: Label
var _boss_bar: ProgressBar
var _pause_panel: PanelContainer
var _pause_box: VBoxContainer
var _side_shade: Array[ColorRect] = []
var _radio_left: float = 0.0
var _banner_left: float = 0.0
var _last_score: int = -1
var _dialogue: Dictionary = {}
var _objective_left: float = 0.0
var _hints: Array = []


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue.json"))
	if typeof(parsed) == TYPE_ARRAY:
		for row: Variant in parsed:
			_dialogue[String((row as Dictionary).get("id", ""))] = row
	# Esquerda, direita, cima e baixo do campo: a borda da área de jogo fica sempre clara.
	for i: int in range(4):
		var shade := ColorRect.new()
		shade.color = Color(UiTheme.ABYSS, 0.55)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		_side_shade.append(shade)
	_score = _label(UiTheme.HEADING_SIZE, UiTheme.WHITE)
	_mult = _label(UiTheme.FONT_SIZE, UiTheme.CYAN)
	_hull = _label(UiTheme.FONT_SIZE, UiTheme.CORAL)
	_bombs = _label(UiTheme.FONT_SIZE, UiTheme.GOLD)
	_weapon = _label(UiTheme.FONT_SIZE, UiTheme.TEXT)
	_radio = _label(UiTheme.FONT_SIZE, UiTheme.TEXT)
	_radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner = _label(UiTheme.TITLE_SIZE, UiTheme.CORAL)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt = _label(UiTheme.HEADING_SIZE, UiTheme.GOLD)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 1.0
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.CORAL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UiTheme.ABYSS, 0.8)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_bar.add_theme_stylebox_override("background", bg)
	add_child(_boss_bar)
	_pause = _button("II", func() -> void: pause_pressed.emit())
	_special = _button("", func() -> void: special_pressed.emit())
	_bomb = _button("", func() -> void: bomb_pressed.emit())
	_tide = _button("", func() -> void: tide_pressed.emit())
	_pressure = _bar(UiTheme.CYAN)
	_objective = _label(UiTheme.FONT_SIZE, UiTheme.GOLD)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_offer_panel()
	_build_pause_panel()
	refresh_texts()


func _label(size: int, color: Color) -> Label:
	var l := UiTheme.label("", size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", UiTheme.VOLCANIC)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(BUTTON, BUTTON)
	b.pressed.connect(on_press)
	add_child(b)
	return b


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UiTheme.ABYSS, 0.8)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	add_child(bar)
	return bar


## Painel das bênçãos (plano mestre 4.11): a fase congela até o jogador escolher 1 de 3.
func _build_offer_panel() -> void:
	_offer_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTheme.ABYSS, 0.93)
	box.border_color = UiTheme.GOLD
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(10)
	_offer_panel.add_theme_stylebox_override("panel", box)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_offer_panel.add_child(list)
	_offer_title = UiTheme.label("", UiTheme.HEADING_SIZE, UiTheme.GOLD, true)
	_offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(_offer_title)
	for i: int in range(3):
		var b := Button.new()
		b.name = "Blessing%d" % i
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(func() -> void: blessing_chosen.emit(i))
		list.add_child(b)
		_offer_buttons.append(b)
	_offer_panel.visible = false
	add_child(_offer_panel)


func _build_pause_panel() -> void:
	_pause_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTheme.ABYSS, 0.94)
	box.border_color = UiTheme.TURQUOISE
	box.set_border_width_all(1)
	box.set_content_margin_all(16)
	_pause_panel.add_theme_stylebox_override("panel", box)
	_pause_box = VBoxContainer.new()
	_pause_box.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(_pause_box)
	var title := UiTheme.label("", UiTheme.HEADING_SIZE, UiTheme.GOLD)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_box.add_child(title)
	for entry: Array in [["Resume", resume_pressed], ["Restart", restart_pressed], ["Quit", quit_pressed]]:
		var b := Button.new()
		b.name = entry[0]
		b.custom_minimum_size = Vector2(180, UiTheme.TOUCH_MIN)
		var sig: Signal = entry[1]
		b.pressed.connect(func() -> void: sig.emit())
		_pause_box.add_child(b)
	_pause_panel.visible = false
	add_child(_pause_panel)


func refresh_texts() -> void:
	_special.text = tr("hud.special")
	_bomb.text = tr("hud.bomb")
	_tide.text = tr("hud.tide_button")
	_offer_title.text = tr("hud.blessing_title")
	(_pause_box.get_node("Title") as Label).text = tr("hud.paused")
	(_pause_box.get_node("Resume") as Button).text = tr("hud.resume")
	(_pause_box.get_node("Restart") as Button).text = tr("hud.restart")
	(_pause_box.get_node("Quit") as Button).text = tr("hud.quit")


func set_paused(paused: bool) -> void:
	_pause_panel.visible = paused
	if paused:
		_pause_panel.reset_size()
		var field: Rect2 = layout.get("field", Rect2(Vector2.ZERO, size))
		_pause_panel.position = (field.get_center() - _pause_panel.size * 0.5).floor()
		(_pause_box.get_node("Resume") as Button).grab_focus()


## Objetivo e dicas da missão (mostrados no começo).
func setup_mission(sim: Sim) -> void:
	var obj: Dictionary = sim.mission.get("objective", {})
	_objective.text = "%s · %s" % [tr(String(sim.mission.get("name_key", ""))), tr(String(obj.get("text_key", "")))]
	_objective_left = OBJECTIVE_SECONDS
	_hints = HINTS.duplicate() if bool(sim.mission.get("tutorial", false)) else []


func show_offer(sim: Sim) -> void:
	var table: Dictionary = sim.tables.get("blessings", {})
	for i: int in range(_offer_buttons.size()):
		var b := _offer_buttons[i]
		b.visible = i < sim.offer.size()
		if b.visible:
			var def: Dictionary = table.get(sim.offer[i], {})
			b.text = "%s · %s\n%s" % [tr("deity." + String(def.get("deity", ""))), tr(String(def.get("name_key", ""))),
					tr(String(def.get("desc_key", "")))]
	_offer_panel.visible = true
	_place_offer()
	_offer_buttons[0].grab_focus()


func hide_offer() -> void:
	_offer_panel.visible = false


## Painel das bênçãos (testes de layout).
func offer_panel() -> Control:
	return _offer_panel


func offer_visible() -> bool:
	return _offer_panel.visible


func _place_offer() -> void:
	var field: Rect2 = layout.get("field", Rect2(Vector2.ZERO, size))
	var width := field.size.x - 16.0
	for b: Button in _offer_buttons:
		b.custom_minimum_size.x = width - 20.0
	_offer_title.custom_minimum_size.x = width - 20.0
	_offer_panel.size = Vector2(width, 0)
	_offer_panel.reset_size()
	_offer_panel.size.x = width
	_offer_panel.position = (field.get_center() - _offer_panel.size * 0.5).floor()


## Posiciona tudo a partir do Playfield (chamado quando a tela ou a área segura mudam).
func apply_layout(p_layout: Dictionary, p_safe: Rect2) -> void:
	layout = p_layout
	safe = p_safe
	var field: Rect2 = layout["field"]
	var hud: Rect2 = layout["hud"]
	var portrait := size.y >= size.x
	_side_shade[0].position = Vector2.ZERO
	_side_shade[0].size = Vector2(field.position.x, size.y)
	_side_shade[1].position = Vector2(field.end.x, 0)
	_side_shade[1].size = Vector2(maxf(0.0, size.x - field.end.x), size.y)
	_side_shade[2].position = Vector2(field.position.x, 0)
	_side_shade[2].size = Vector2(field.size.x, field.position.y)
	_side_shade[3].position = Vector2(field.position.x, field.end.y)
	_side_shade[3].size = Vector2(field.size.x, maxf(0.0, size.y - field.end.y))
	var top := hud.position if portrait else Vector2(field.end.x + 12.0, safe.position.y + 12.0)
	var width := field.size.x if portrait else maxf(80.0, safe.end.x - field.end.x - 24.0)
	_score.position = top + Vector2(4, 2)
	_mult.position = top + Vector2(4, 22) if not portrait else top + Vector2(width * 0.42, 6)
	_hull.position = top + (Vector2(width - 120, 6) if portrait else Vector2(4, 44))
	_bombs.position = top + (Vector2(width - 76, 6) if portrait else Vector2(4, 62))
	_pause.position = Vector2(safe.end.x - BUTTON - 4.0, safe.position.y + 2.0) if portrait \
			else Vector2(safe.end.x - BUTTON - 8.0, safe.position.y + 8.0)
	if portrait:
		_hull.position.x = minf(_hull.position.x, _pause.position.x - 96.0)
		_bombs.position.x = minf(_bombs.position.x, _pause.position.x - 50.0)
		if not bool(layout["hud_overlay"]) and _pause.position.y + BUTTON > field.position.y:
			_pause.position.y = safe.position.y
	var thumb: Rect2 = layout["thumb"]
	var buttons_y := field.end.y - BUTTON - 6.0
	if bool(layout.get("thumb_separate", false)):
		buttons_y = thumb.position.y + minf(16.0, thumb.size.y - BUTTON - 4.0)
	if not portrait:
		buttons_y = safe.end.y - BUTTON - 16.0
	var right_x := field.end.x - BUTTON - 6.0 if portrait else safe.end.x - BUTTON - 16.0
	var left_x := field.position.x + 6.0 if portrait else field.end.x + 16.0
	if String(Settings.get_value("handedness")) == "left" and portrait:
		var tmp := right_x
		right_x = left_x
		left_x = tmp
	_special.reset_size()
	_bomb.reset_size()
	if right_x > left_x:
		_special.position = Vector2(right_x + BUTTON - _special.size.x, buttons_y)
		_bomb.position = Vector2(_special.position.x - _bomb.size.x - 8.0, buttons_y)
	else:
		_special.position = Vector2(right_x, buttons_y)
		_bomb.position = Vector2(_special.position.x + _special.size.x + 8.0, buttons_y)
	_weapon.position = Vector2(left_x, buttons_y + 14.0)
	_tide.reset_size()
	_tide.position = Vector2(_special.position.x + _special.size.x - _tide.size.x, buttons_y - BUTTON - 8.0)
	_pressure.position = _score.position + Vector2(0, 24 if portrait else 82)
	_pressure.size = Vector2(minf(90.0, width * 0.3), 3.0)
	_objective.position = Vector2(field.position.x + 8.0, field.position.y + field.size.y * 0.18)
	_objective.size = Vector2(field.size.x - 16.0, 0)
	_radio.position = Vector2(field.position.x + 8.0, field.end.y - BUTTON - 64.0)
	_radio.size = Vector2(field.size.x - 16.0, 0)
	_banner.position = Vector2(field.position.x + 8.0, field.position.y + field.size.y * 0.3)
	_banner.size = Vector2(field.size.x - 16.0, 0)
	_prompt.position = Vector2(field.position.x + 8.0, field.position.y + field.size.y * 0.62)
	_prompt.size = Vector2(field.size.x - 16.0, 0)
	_boss_bar.position = Vector2(field.position.x + 8.0, field.position.y + (28.0 if bool(layout["hud_overlay"]) else 4.0))
	_boss_bar.size = Vector2(field.size.x - 16.0, 4.0)
	if _pause_panel.visible:
		set_paused(true)
	if _offer_panel.visible:
		_place_offer()


func show_radio(dialogue_id: String) -> void:
	var row: Dictionary = _dialogue.get(dialogue_id, {})
	if row.is_empty():
		return
	_radio.text = "%s: %s" % [tr("speaker." + String(row.get("speaker", ""))), tr(String(row.get("text_key", "")))]
	_radio.add_theme_color_override("font_color", Color(String(row.get("color", "#dff6ff"))))
	_radio_left = RADIO_SECONDS


func show_radio_text(text: String, color: Color) -> void:
	_radio.text = text
	_radio.add_theme_color_override("font_color", color)
	_radio_left = RADIO_SECONDS


func show_banner(text: String) -> void:
	_banner.text = text
	_banner_left = BANNER_SECONDS


func refresh(sim: Sim, delta: float) -> void:
	if sim.scoring.score != _last_score:
		_last_score = sim.scoring.score
		_score.text = Locale.format_number(sim.scoring.score)
	_mult.text = "x%d" % sim.scoring.multiplier() if sim.scoring.chain > 0 else ""
	_hull.text = "♥".repeat(maxi(0, sim.player.hull)) + "·".repeat(maxi(0, sim.player.max_hull - sim.player.hull))
	_bombs.text = "◆".repeat(sim.player.bombs)
	_weapon.text = "%s %s" % [tr("weapon." + String(sim.player.weapon)), "▲".repeat(sim.player.level)]
	var ready := sim.player.special_charge >= 1.0
	_special.modulate = Color(1, 1, 1) if ready else Color(0.6, 0.7, 0.8, 0.8)
	_special.text = tr("hud.special") if ready else "%d%%" % int(sim.player.special_charge * 100.0)
	_bomb.disabled = sim.player.bombs <= 0
	var pressure := sim.scoring.pressure / Scoring.PRESSURE_MAX
	_pressure.value = pressure if sim.tide_frames == 0 else float(sim.tide_frames) / Sim.TIDE_FRAMES
	_tide.visible = pressure >= 1.0 or sim.tide_frames > 0
	_tide.disabled = sim.tide_frames > 0
	if _tide.visible and not _tide.disabled:
		_tide.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
	_objective_left -= delta
	_objective.visible = _objective_left > 0.0
	_objective.modulate.a = clampf(_objective_left, 0.0, 1.0)
	if not _hints.is_empty() and sim.frame >= int(_hints[0][0]):
		show_radio_text(tr(String(_hints[0][1])), UiTheme.CYAN)
		_hints.pop_front()
	if _offer_panel.visible and sim.offer.is_empty():
		hide_offer()
	var boss := sim.boss
	_boss_bar.visible = boss != null and boss.state != SimBoss.State.ENTER
	if _boss_bar.visible:
		_boss_bar.value = boss.hp / boss.max_hp
	var duel := boss != null and boss.state == SimBoss.State.DUEL
	_prompt.visible = duel
	if duel:
		_prompt.text = tr("hud.duel")
		_prompt.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
	_radio_left -= delta
	_radio.visible = _radio_left > 0.0
	_radio.modulate.a = clampf(_radio_left * 2.0, 0.0, 1.0)
	_banner_left -= delta
	_banner.visible = _banner_left > 0.0
	_banner.modulate.a = clampf(_banner_left * 2.0, 0.0, 1.0)


## Controles que precisam caber na área segura (testes de layout).
func layout_controls() -> Array[Control]:
	return [_score, _pause, _special, _bomb, _weapon, _tide]
