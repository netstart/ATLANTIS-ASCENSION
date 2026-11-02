class_name GameHud
extends Control
## HUD da missão (plano mestre 7.4; guia "Neon abissal" em docs/design/ui-style.md). Posições vêm do
## Playfield: em telas altas o HUD fica acima do campo e os botões na zona do polegar; em telas curtas
## o HUD fica sobre o campo (≤ 6%, mais transparente); no desktop vai para o painel lateral.
##
## Lê a Sim a cada quadro, mas só troca texto, StyleBox e desenho vetorial quando o valor muda (regra
## de desempenho de docs/policies/qualidade.md). O que anda a cada quadro é só tamanho de ColorRect,
## modulate, escala e tweens; os anéis e glifos (draw_arc/polígonos) são refeitos só na troca de estado.
## "Reduzir movimento" desliga contagem, pulsos, varreduras e a máquina de escrever.

signal pause_pressed
signal special_pressed
## Botão PODER (terceiro da zona do polegar): lança o poder do nível da Corrente.
signal power_pressed
signal bomb_pressed
signal tide_pressed
## Reviver depois da derrota (true) ou desistir (false).
signal revive_chosen(accept: bool)
## Bênção escolhida no painel de oferta (0 a 2).
signal blessing_chosen(index: int)
signal resume_pressed
signal restart_pressed
signal quit_pressed

const RADIO_SECONDS := 4.0
const BANNER_SECONDS := 2.4
## Lado do botão compacto (telas curtas: sobre o campo) e mínimo de toque do HUD.
const BUTTON := 44.0
## Bomba e especial quando a zona do polegar tem espaço (e no painel lateral do desktop).
const BIG_BUTTON := 54.0
const PAUSE_BUTTON := 38.0
const OBJECTIVE_SECONDS := 5.0
const PORTRAIT := 32.0
## Letras por segundo da máquina de escrever do rádio.
const TYPE_RATE := 70.0
const LIFE_ICON := 12.0
const LIFE_MAX_ICONS := 6
## Salto de pontos que faz o placar pulsar (abates grandes, medalhas, bônus).
const SCORE_PULSE := 500
## Degraus do anel do especial (redesenho só quando muda de degrau: ~a cada 30 quadros).
const CHARGE_STEPS := 48
## Título do Poder III: segundos na tela (os níveis I e II usam o PowerChip).
const SUPREME_BANNER_SECONDS := 1.1
const BOSS_FILL_SECONDS := 1.2
const BOSS_BAR_H := 6.0
## Nave do jogador (Void) recortada para os ícones de casco.
const SHIP_ICON := "res://assets/art/void/main_ship/base_full.png"
## Dicas da primeira missão (tutorial em jogo, plano mestre 7.5): passo da Sim e chave do texto.
const HINTS: Array[Array] = [[60, "hint.move"], [420, "hint.graze"], [900, "hint.orbs"], [1500, "hint.special"],
		[2100, "hint.tide"], [2700, "hint.marked"], [3300, "hint.capture"]]

var layout := {}
var safe := Rect2()

var _sim: Sim
var _reduced := false
var _portrait_mode := true
var _btn := BUTTON
## Placar: fonte com algarismos tabulares, valor mostrado (contagem) e alvo.
var _score: Label
var _score_shown: float = 0.0
var _score_target: int = 0
var _score_tween: Tween
## Multiplicador da corrente: pílula colorida por faixa, barra do tempo da corrente embaixo.
var _mult_pill: PanelContainer
var _mult: Label
var _chain_bar: ColorRect
var _mult_value: int = 0
var _mult_tier: int = -1
var _mult_on := false
var _last_chain: int = 0
var _mult_tween: Tween
var _mult_boxes: Array[StyleBoxFlat] = []
## Casco: ícones da nave (ou um ícone e "×N" quando passa de LIFE_MAX_ICONS).
var _lives_box: HBoxContainer
var _life_icons: Array[TextureRect] = []
var _life_count: Label
var _life_texture: Texture2D
var _hull_shown: int = -1
var _hull_max: int = -1
var _side_panel: Panel
var _weapon: Label
var _weapon_pips: Control
var _weapon_key := ""
var _pip_level: int = 0
var _pip_max: int = 0
var _weapon_right_edge: float = -1.0
var _pause: Button
var _special: Button
var _special_gauge: Control
var _special_caption: Label
var _special_glow: Panel
var _special_ready := false
var _special_q: int = -1
var _glow_tween: Tween
var _bomb: Button
var _bomb_gauge: Control
var _bomb_caption: Label
var _bombs_shown: int = -1
## PODER (PowerButton) e o rótulo com o nome do poder que sairia agora.
var _power: PowerButton
var _power_name: Label
var _power_hinted := false
var _tutorial := false
var _tide: Button
var _pressure_track: ColorRect
var _pressure: ColorRect
var _pressure_q: int = -1
var _pressure_full := false
var _objective_panel: PanelContainer
var _objective: Label
var _offer_panel: PanelContainer
var _offer_title: Label
var _offer_buttons: Array[Button] = []
var _revive_panel: PanelContainer
var _revive_text: Label
var _revive_yes: Button
var _revive_no: Button
var _dim: ColorRect
## Rádio: painel de vidro com moldura chanfrada do retrato, nome de quem fala e texto digitado.
var _radio_panel: PanelContainer
var _radio_frame: PanelContainer
var _radio_name: Label
var _radio: Label
## Retrato de quem fala no rádio (Portraits), à esquerda do texto.
var _portrait: TextureRect
var _radio_type: float = 0.0
var _radio_tween: Tween
var _banner: HudBanner
var _chip: PowerChip
var _prompt: Label
## Barra do chefe: placa com o nome, trilho, rastro do dano, preenchimento e marcas das etapas.
var _boss_root: Control
var _boss_name: Label
var _boss_track: Panel
var _boss_ghost: ColorRect
var _boss_fill: ColorRect
var _boss_shine: ColorRect
var _boss_ticks: Array[ColorRect] = []
var _boss_ref: SimBoss
var _boss_w: float = 200.0
var _boss_fill_t: float = 0.0
var _boss_shown: float = -1.0
var _boss_ghost_v: float = 0.0
var _boss_hold: float = 0.0
var _pause_panel: PanelContainer
var _pause_box: VBoxContainer
var _side_shade: Array[ColorRect] = []
var _frame_lines: Array[ColorRect] = []
var _radio_left: float = 0.0
var _dialogue: Dictionary = {}
var _objective_left: float = 0.0
var _hints: Array = []
var _refit_frames: int = 0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_reduced = UiFx.reduced()
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
	for i: int in range(2):
		var line := ColorRect.new()
		line.color = Color(UiTheme.CYAN, 0.2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		_frame_lines.append(line)
	_side_panel = Panel.new()
	_side_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.CYAN, 0.72))
	add_child(_side_panel)
	_build_top()
	_build_boss_bar()
	_build_objective()
	_build_radio()
	_build_banner()
	_prompt = _label(UiTheme.HEADING_SIZE, UiTheme.GOLD, true)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.visible = false
	_build_buttons()
	_dim = ColorRect.new()
	_dim.color = Color(UiTheme.ABYSS, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_build_offer_panel()
	_build_revive_panel()
	_build_pause_panel()
	refresh_texts()


# --- Construção ------------------------------------------------------------------------------

func _label(size: int, color: Color, bold: bool = false) -> Label:
	var l := UiTheme.heading("", size, color) if bold else UiTheme.label("", size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", UiTheme.ABYSS)
	l.add_theme_constant_override("outline_size", 3)
	add_child(l)
	return l


func _build_top() -> void:
	_score = _label(UiTheme.HEADING_SIZE, UiTheme.WHITE, true)
	_score.text = "0"
	var tab := HudKit.tabular_font()
	if tab != null:
		_score.add_theme_font_override("font", tab)
	_mult_pill = HudKit.ignore(PanelContainer.new()) as PanelContainer
	_mult_pill.custom_minimum_size = Vector2(44, 18)
	_mult_pill.visible = false
	_mult_pill.resized.connect(func() -> void: _mult_pill.pivot_offset = _mult_pill.size * 0.5)
	add_child(_mult_pill)
	_mult_boxes = HudKit.mult_boxes()
	_mult = UiTheme.heading("", UiTheme.FONT_SIZE, UiTheme.CYAN)
	_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mult.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if tab != null:
		_mult.add_theme_font_override("font", tab)
	_mult_pill.add_child(HudKit.ignore(_mult))
	_mult_pill.add_theme_stylebox_override("panel", _mult_boxes[0])
	_chain_bar = HudKit.ignore(ColorRect.new()) as ColorRect
	_chain_bar.visible = false
	add_child(_chain_bar)
	_lives_box = HudKit.ignore(HBoxContainer.new()) as HBoxContainer
	_lives_box.add_theme_constant_override("separation", 3)
	add_child(_lives_box)
	_life_count = UiTheme.heading("", UiTheme.SMALL_SIZE, UiTheme.TEXT)
	_life_count.visible = false
	_lives_box.add_child(_life_count)
	_life_texture = HudKit.trimmed_texture(SHIP_ICON)
	_pressure_track = HudKit.ignore(ColorRect.new()) as ColorRect
	_pressure_track.color = Color(UiTheme.ABYSS, 0.75)
	add_child(_pressure_track)
	_pressure = HudKit.ignore(ColorRect.new()) as ColorRect
	_pressure.color = UiTheme.CYAN
	add_child(_pressure)


func _build_buttons() -> void:
	_pause = _button(func() -> void: pause_pressed.emit())
	_pause.name = "Pause"
	var pause_glyph := _glyph(_pause, func(c: Control) -> void: HudKit.draw_pause(c))
	pause_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	HudKit.style_round(_pause, UiTheme.CYAN, 0.5, false, 4)
	_tide = _button(func() -> void: tide_pressed.emit())
	_tide.name = "Tide"
	_tide.custom_minimum_size = Vector2(BUTTON, 38)
	HudKit.style_round(_tide, UiTheme.CYAN, 0.9, true, 6, 26)
	var wave := _glyph(_tide, func(c: Control) -> void: HudKit.draw_waves(c))
	wave.position = Vector2(6, 0)
	wave.size = Vector2(18, 38)
	_tide.resized.connect(func() -> void: wave.size.y = _tide.size.y)
	_tide.visible = false
	_special = _button(func() -> void: special_pressed.emit())
	_special.name = "Special"
	_special_glow = HudKit.ignore(Panel.new()) as Panel
	_special_glow.show_behind_parent = true
	_special_glow.add_theme_stylebox_override("panel", HudKit.glow_box(UiTheme.GOLD))
	_special_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_special_glow.visible = false
	_special.add_child(_special_glow)
	_special_gauge = _glyph(_special, func(c: Control) -> void: HudKit.draw_special(c, _btn >= BIG_BUTTON,
			1.0 if _special_ready else _special_q / float(CHARGE_STEPS), _special_ready))
	_special_gauge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_special_caption = HudKit.caption(_special)
	_bomb = _button(func() -> void: bomb_pressed.emit())
	_bomb.name = "Bomb"
	_bomb_gauge = _glyph(_bomb, func(c: Control) -> void: HudKit.draw_bomb(c, _btn >= BIG_BUTTON, _bombs_shown))
	_bomb_gauge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bomb_caption = HudKit.caption(_bomb)
	_power = PowerButton.new()
	_power.name = "Power"
	_power.focus_mode = Control.FOCUS_NONE
	_power.custom_minimum_size = Vector2(BUTTON, BUTTON)
	_power.pressed.connect(func() -> void: power_pressed.emit())
	add_child(_power)
	_power_name = _label(UiTheme.SMALL_SIZE, UiTheme.WHITE, true)
	_power.setup(_power_name, _reduced)
	_weapon = _label(UiTheme.FONT_SIZE, UiTheme.TEXT, true)
	_weapon_pips = HudKit.ignore(Control.new())
	_weapon_pips.draw.connect(func() -> void: HudKit.draw_pips(_weapon_pips, _pip_level, _pip_max))
	add_child(_weapon_pips)
	_style_special()
	_style_bomb()


func _button(on_press: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(BUTTON, BUTTON)
	b.pressed.connect(on_press)
	add_child(b)
	return b


## Camada de desenho vetorial dentro de um botão (refeita só com queue_redraw na troca de estado).
func _glyph(parent: Control, painter: Callable) -> Control:
	var c := HudKit.ignore(Control.new())
	c.draw.connect(painter.bind(c))
	parent.add_child(c)
	return c


func _build_boss_bar() -> void:
	_boss_root = HudKit.ignore(Control.new())
	_boss_root.visible = false
	add_child(_boss_root)
	_boss_name = UiTheme.heading("", UiTheme.SMALL_SIZE, UiTheme.CORAL)
	_boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name.add_theme_color_override("font_outline_color", UiTheme.ABYSS)
	_boss_name.add_theme_constant_override("outline_size", 3)
	_boss_name.clip_text = true
	_boss_root.add_child(_boss_name)
	_boss_track = HudKit.ignore(Panel.new()) as Panel
	var track := UiTheme.chamfer(Color(UiTheme.ABYSS, 0.82), Color(UiTheme.CORAL, 0.55), 1, 4)
	track.shadow_color = Color(UiTheme.CORAL, 0.2)
	track.shadow_size = 4
	_boss_track.add_theme_stylebox_override("panel", track)
	_boss_root.add_child(_boss_track)
	_boss_ghost = HudKit.ignore(ColorRect.new()) as ColorRect
	_boss_ghost.color = Color(UiTheme.WHITE, 0.7)
	_boss_root.add_child(_boss_ghost)
	_boss_fill = HudKit.ignore(ColorRect.new()) as ColorRect
	_boss_fill.color = UiTheme.CORAL
	_boss_root.add_child(_boss_fill)
	_boss_shine = HudKit.ignore(ColorRect.new()) as ColorRect
	_boss_shine.color = Color(1.0, 0.85, 0.88, 0.45)
	_boss_root.add_child(_boss_shine)


func _build_objective() -> void:
	_objective_panel = HudKit.ignore(PanelContainer.new()) as PanelContainer
	var box := UiTheme.panel_box(UiTheme.GOLD, 0.7)
	box.set_content_margin_all(8)
	_objective_panel.add_theme_stylebox_override("panel", box)
	_objective_panel.visible = false
	add_child(_objective_panel)
	_objective = UiTheme.heading("", UiTheme.FONT_SIZE, UiTheme.GOLD)
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_panel.add_child(_objective)


func _build_radio() -> void:
	_radio_panel = HudKit.ignore(PanelContainer.new()) as PanelContainer
	_radio_panel.visible = false
	add_child(_radio_panel)
	var row := HudKit.ignore(HBoxContainer.new()) as HBoxContainer
	row.add_theme_constant_override("separation", 8)
	_radio_panel.add_child(row)
	_radio_frame = HudKit.ignore(PanelContainer.new()) as PanelContainer
	_radio_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_radio_frame)
	_portrait = Portraits.make_rect(PORTRAIT)
	_radio_frame.add_child(_portrait)
	var col := HudKit.ignore(VBoxContainer.new()) as VBoxContainer
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	_radio_name = UiTheme.heading("", UiTheme.SMALL_SIZE, UiTheme.CYAN)
	_radio_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_radio_name)
	_radio = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT)
	_radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	col.add_child(_radio)


func _build_banner() -> void:
	_banner = HudBanner.new()
	add_child(_banner)
	_chip = PowerChip.new()
	add_child(_chip)


## Painel das bênçãos (plano mestre 4.11): a fase congela até o jogador escolher 1 de 3.
func _build_offer_panel() -> void:
	_offer_panel = HudKit.glass(UiTheme.GOLD)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_offer_panel.add_child(list)
	_offer_title = UiTheme.heading("", UiTheme.HEADING_SIZE, UiTheme.GOLD)
	_offer_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	add_child(_offer_panel)


func _build_revive_panel() -> void:
	_revive_panel = HudKit.glass(UiTheme.CORAL)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	_revive_panel.add_child(list)
	_revive_text = UiTheme.heading("", UiTheme.HEADING_SIZE, UiTheme.CORAL)
	_revive_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_revive_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(_revive_text)
	_revive_yes = Button.new()
	_revive_yes.name = "Revive"
	_revive_yes.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 10.0)
	UiTheme.style_primary(_revive_yes)
	_revive_yes.pressed.connect(func() -> void: revive_chosen.emit(true))
	list.add_child(_revive_yes)
	_revive_no = Button.new()
	_revive_no.name = "GiveUp"
	_revive_no.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	_revive_no.pressed.connect(func() -> void: revive_chosen.emit(false))
	list.add_child(_revive_no)
	add_child(_revive_panel)


func _build_pause_panel() -> void:
	_pause_panel = HudKit.glass(UiTheme.CYAN)
	_pause_box = HudKit.menu_box(_pause_panel, [["Resume", resume_pressed], ["Restart", restart_pressed],
			["Quit", quit_pressed]])
	add_child(_pause_panel)


# --- Painéis ---------------------------------------------------------------------------------

func show_revive() -> void:
	_revive_text.text = tr("hud.revive_title")
	_revive_yes.text = tr("hud.revive_ad") if Store.ads_allowed(SaveManager.data) else tr("hud.revive_free")
	_revive_no.text = tr("hud.give_up")
	var field: Rect2 = layout.get("field", Rect2(Vector2.ZERO, size))
	var width := field.size.x - 32.0
	_revive_text.custom_minimum_size.x = width - 28.0
	_revive_panel.size.x = width
	_open_panel(_revive_panel)
	_refit_panels()
	FocusNav.arm(_revive_yes)


## Painéis com texto quebrado medem a altura só depois que o contêiner dá a largura ao rótulo:
## encolhe-os de novo nos quadros seguintes (PanelContainer nunca encolhe sozinho) e recentraliza.
func _refit_panels() -> void:
	_refit_frames = 3
	_refit_now()


func _process(_delta: float) -> void:
	if _refit_frames > 0:
		_refit_frames -= 1
		_refit_now()


func _refit_now() -> void:
	var field: Rect2 = layout.get("field", Rect2(Vector2.ZERO, size))
	for panel: Control in [_revive_panel, _offer_panel, _pause_panel, _objective_panel, _radio_panel]:
		if not panel.visible:
			continue
		var width := panel.size.x
		panel.reset_size()
		panel.size.x = maxf(width, panel.size.x)
		if panel != _objective_panel and panel != _radio_panel:
			panel.position = (field.get_center() - panel.size * 0.5).floor()


func hide_revive() -> void:
	_revive_panel.visible = false
	_sync_dim()


func revive_visible() -> bool:
	return _revive_panel.visible


func _open_panel(panel: Control) -> void:
	var was := panel.visible
	panel.visible = true
	_sync_dim()
	if not was:
		UiFx.enter(panel)


## Véu escuro atrás de pausa, reviver e bênçãos: o painel de vidro lê bem sobre a ação congelada.
func _sync_dim() -> void:
	_dim.visible = _pause_panel.visible or _revive_panel.visible or _offer_panel.visible


func refresh_texts() -> void:
	_special_caption.text = tr("hud.special")
	_bomb_caption.text = tr("hud.bomb")
	_power.retext()
	_tide.text = tr("hud.tide_button")
	_offer_title.text = tr("hud.blessing_title")
	(_pause_box.get_node("Title") as Label).text = tr("hud.paused")
	(_pause_box.get_node("Resume") as Button).text = tr("hud.resume")
	(_pause_box.get_node("Restart") as Button).text = tr("hud.restart")
	(_pause_box.get_node("Quit") as Button).text = tr("hud.quit")


func set_paused(paused: bool) -> void:
	if paused:
		_open_panel(_pause_panel)
		_pause_panel.reset_size()
		var field: Rect2 = layout.get("field", Rect2(Vector2.ZERO, size))
		_pause_panel.position = (field.get_center() - _pause_panel.size * 0.5).floor()
		(_pause_box.get_node("Resume") as Button).grab_focus()
	else:
		_pause_panel.visible = false
		_sync_dim()


## Objetivo e dicas da missão (mostrados no começo).
func setup_mission(sim: Sim) -> void:
	var obj: Dictionary = sim.mission.get("objective", {})
	_objective.text = "%s · %s" % [tr(String(sim.mission.get("name_key", ""))), tr(String(obj.get("text_key", "")))]
	_objective_left = OBJECTIVE_SECONDS
	_objective_panel.visible = true
	_refit_panels()
	_tutorial = bool(sim.mission.get("tutorial", false))
	_hints = HINTS.duplicate() if _tutorial else []


func show_offer(sim: Sim) -> void:
	var table: Dictionary = sim.tables.get("blessings", {})
	var module := not sim.offer.is_empty() and bool((table.get(sim.offer[0], {}) as Dictionary).get("abyss", false))
	_offer_title.text = tr("hud.module_title" if module else "hud.blessing_title")
	for i: int in range(_offer_buttons.size()):
		var b := _offer_buttons[i]
		b.visible = i < sim.offer.size()
		if b.visible:
			var def: Dictionary = table.get(sim.offer[i], {})
			b.text = "%s · %s\n%s" % [tr("deity." + String(def.get("deity", ""))), tr(String(def.get("name_key", ""))),
					tr(String(def.get("desc_key", "")))]
	_open_panel(_offer_panel)
	_place_offer()
	_refit_panels()
	FocusNav.arm(_offer_buttons[0])


func hide_offer() -> void:
	_offer_panel.visible = false
	_sync_dim()


## Painel das bênçãos (testes de layout).
func offer_panel() -> Control:
	return _offer_panel


func offer_visible() -> bool:
	return _offer_panel.visible


func _place_offer() -> void:
	var field: Rect2 = layout.get("field", Rect2(Vector2.ZERO, size))
	var width := field.size.x - 16.0
	for b: Button in _offer_buttons:
		b.custom_minimum_size.x = width - 28.0
	_offer_title.custom_minimum_size.x = width - 28.0
	_offer_panel.size = Vector2(width, 0)
	_offer_panel.reset_size()
	_offer_panel.size.x = width
	_offer_panel.position = (field.get_center() - _offer_panel.size * 0.5).floor()


# --- Layout ----------------------------------------------------------------------------------

## Posiciona tudo a partir do Playfield (chamado quando a tela ou a área segura mudam).
func apply_layout(p_layout: Dictionary, p_safe: Rect2) -> void:
	layout = p_layout
	safe = p_safe
	var field: Rect2 = layout["field"]
	_portrait_mode = size.y >= size.x
	_side_shade[0].position = Vector2.ZERO
	_side_shade[0].size = Vector2(field.position.x, size.y)
	_side_shade[1].position = Vector2(field.end.x, 0)
	_side_shade[1].size = Vector2(maxf(0.0, size.x - field.end.x), size.y)
	_side_shade[2].position = Vector2(field.position.x, 0)
	_side_shade[2].size = Vector2(field.size.x, field.position.y)
	_side_shade[3].position = Vector2(field.position.x, field.end.y)
	_side_shade[3].size = Vector2(field.size.x, maxf(0.0, size.y - field.end.y))
	# Fio ciano nas bordas do campo que encostam no HUD (cima e baixo em retrato, lados no desktop).
	if _portrait_mode:
		_frame_lines[0].position = Vector2(field.position.x, field.position.y)
		_frame_lines[0].size = Vector2(field.size.x, 1)
		_frame_lines[1].position = Vector2(field.position.x, field.end.y - 1.0)
		_frame_lines[1].size = Vector2(field.size.x, 1)
	else:
		_frame_lines[0].position = Vector2(field.position.x, field.position.y)
		_frame_lines[0].size = Vector2(1, field.size.y)
		_frame_lines[1].position = Vector2(field.end.x - 1.0, field.position.y)
		_frame_lines[1].size = Vector2(1, field.size.y)
	_pause.custom_minimum_size = Vector2(PAUSE_BUTTON, PAUSE_BUTTON)
	_pause.size = _pause.custom_minimum_size
	if _portrait_mode:
		_pause.position = Vector2(safe.end.x - PAUSE_BUTTON - 4.0, safe.position.y + 2.0)
		if not bool(layout["hud_overlay"]) and _pause.position.y + PAUSE_BUTTON > field.position.y:
			_pause.position.y = safe.position.y
	else:
		_pause.position = Vector2(safe.end.x - PAUSE_BUTTON - 8.0, safe.position.y + 8.0)
	_place_top()
	_place_buttons(field)
	_objective.custom_minimum_size.x = field.size.x - 32.0
	_objective_panel.size = Vector2(field.size.x - 16.0, 0)
	_objective_panel.reset_size()
	_objective_panel.position = Vector2(field.position.x + 8.0, field.position.y + field.size.y * 0.18)
	_banner.place(field)
	_prompt.position = Vector2(field.position.x + 8.0, field.position.y + field.size.y * 0.62)
	_prompt.size = Vector2(field.size.x - 16.0, 0)
	_place_boss(field)
	_place_radio()
	if _pause_panel.visible:
		set_paused(true)
	if _offer_panel.visible:
		_place_offer()
	_refit_panels()


## Placar, multiplicador, casco e pressão: faixa de cima em retrato; painel de vidro no desktop.
func _place_top() -> void:
	var field: Rect2 = layout.get("field", Rect2(Vector2.ZERO, size))
	var hud: Rect2 = layout.get("hud", Rect2())
	var overlay := bool(layout.get("hud_overlay", false))
	_lives_box.reset_size()
	var lives_w := _lives_box.get_combined_minimum_size().x
	if _portrait_mode:
		_side_panel.visible = false
		_score.add_theme_font_size_override("font_size", UiTheme.scaled(UiTheme.HEADING_SIZE))
		_score.position = hud.position + Vector2(4, 1)
		var right := minf(_pause.position.x - 8.0, field.end.x - 4.0)
		_lives_box.position = Vector2(right - lives_w, hud.position.y + floorf((hud.size.y - LIFE_ICON) * 0.5))
		_mult_pill.reset_size()
		_mult_pill.position = Vector2(_lives_box.position.x - 10.0 - _mult_pill.size.x, hud.position.y + 3.0)
		_pressure_track.position = Vector2(hud.position.x + 4.0, hud.end.y - 3.0)
		_pressure_track.size = Vector2(minf(90.0, hud.size.x * 0.3), 2.0)
	else:
		var top := Vector2(field.end.x + 12.0, safe.position.y + 8.0)
		var width := clampf(_pause.position.x - top.x - 12.0, 120.0, 280.0)
		_side_panel.visible = true
		_side_panel.position = top
		_side_panel.size = Vector2(width, 78)
		_score.add_theme_font_size_override("font_size", UiTheme.scaled(UiTheme.TITLE_SIZE))
		_score.position = top + Vector2(12, 6)
		# Pílula à direita do placar; casco na segunda linha; pressão no rodapé do painel.
		_mult_pill.reset_size()
		_mult_pill.position = top + Vector2(width - 12.0 - _mult_pill.size.x, 13)
		_lives_box.position = top + Vector2(13, 46)
		_pressure_track.position = top + Vector2(12, 66)
		_pressure_track.size = Vector2(width - 24.0, 3.0)
	_pressure.position = _pressure_track.position
	_pressure.size.y = _pressure_track.size.y
	_pressure_q = -1
	_chain_bar.position = _mult_pill.position + Vector2(3.0, _mult_pill.size.y + 1.0)
	_chain_bar.size.y = 2.0
	# Sobre o campo (telas curtas) o HUD de cima fica mais transparente para não esconder balas.
	var alpha := 0.82 if overlay else 1.0
	for node: CanvasItem in [_score, _lives_box, _pressure_track, _pressure]:
		node.modulate.a = alpha


func _place_buttons(field: Rect2) -> void:
	var thumb: Rect2 = layout["thumb"]
	var sep := bool(layout.get("thumb_separate", false))
	_btn = BIG_BUTTON if not _portrait_mode or (sep and thumb.size.y >= BIG_BUTTON + 8.0) else BUTTON
	var buttons_y := field.end.y - _btn - 6.0
	if sep and _portrait_mode:
		buttons_y = thumb.position.y + minf(14.0, thumb.size.y - _btn - 4.0)
	if not _portrait_mode:
		buttons_y = safe.end.y - _btn - 16.0
	var right_x := field.end.x - _btn - 6.0 if _portrait_mode else safe.end.x - _btn - 16.0
	var left_x := field.position.x + 6.0 if _portrait_mode else field.end.x + 16.0
	var left_handed := String(Settings.get_value("handedness")) == "left" and _portrait_mode
	for b: Button in [_special, _bomb]:
		b.custom_minimum_size = Vector2(_btn, _btn)
		b.size = b.custom_minimum_size
	_power.set_side(_btn, _btn >= BIG_BUTTON)
	# Da borda para dentro: especial, bomba e PODER (o polegar alcança os três sem cruzar a nave).
	if left_handed:
		_special.position = Vector2(left_x, buttons_y)
		_bomb.position = Vector2(left_x + _btn + 10.0, buttons_y)
		_power.position = Vector2(left_x + (_btn + 10.0) * 2.0, buttons_y)
		_weapon_right_edge = field.end.x - 6.0
	else:
		_special.position = Vector2(right_x, buttons_y)
		_bomb.position = Vector2(right_x - _btn - 10.0, buttons_y)
		_power.position = Vector2(right_x - (_btn + 10.0) * 2.0, buttons_y)
		_weapon_right_edge = -1.0
	_weapon.position = Vector2(left_x, buttons_y + maxf(4.0, _btn * 0.5 - 13.0))
	_place_weapon()
	# Legenda embaixo do anel só no botão grande; no compacto o glifo ocupa o botão todo.
	var big := _btn >= BIG_BUTTON
	for cap: Label in [_special_caption, _bomb_caption]:
		cap.visible = big
		cap.position = Vector2(2, _btn - 15.0)
		cap.size = Vector2(_btn - 4.0, 13)
	# Botões dentro do campo (sem zona do polegar): translúcidos para as balas aparecerem.
	var inside := _portrait_mode and not sep
	for node: CanvasItem in [_special, _bomb, _power, _weapon, _weapon_pips, _power_name]:
		node.modulate.a = 0.62 if inside else 1.0
	_special_gauge.queue_redraw()
	_bomb_gauge.queue_redraw()
	# Nome do poder: embaixo dos botões quando a zona do polegar tem altura, senão em cima; corre do PODER
	# para dentro (a arma fica na altura do meio dos botões, sem encostar).
	var name_y := buttons_y - 16.0
	if sep and _portrait_mode and thumb.end.y - (buttons_y + _btn + 3.0) >= 15.0:
		name_y = buttons_y + _btn + 3.0
	_power.place_name(name_y, field.end.x - 6.0 if left_handed else left_x, left_handed)
	_tide.reset_size()
	var tide_y := buttons_y - _tide.size.y - (10.0 if not _portrait_mode else 8.0)
	var below := buttons_y + _btn + 8.0
	if sep and _portrait_mode and thumb.end.y - below >= _tide.size.y + 2.0:
		tide_y = below
	var tide_x := _special.position.x if left_handed else _special.position.x + _special.size.x - _tide.size.x
	_tide.position = Vector2(tide_x, tide_y)


## Nome da arma e degraus; na mão esquerda o bloco encosta na borda direita do campo.
func _place_weapon() -> void:
	_weapon.reset_size()
	if _weapon_right_edge > 0.0:
		_weapon.position.x = _weapon_right_edge - maxf(_weapon.size.x, _weapon_pips.size.x)
	_weapon_pips.position = Vector2(_weapon.position.x + 1.0, _weapon.position.y + _weapon.size.y + 2.0)


func _place_boss(field: Rect2) -> void:
	var top := field.position.y + (28.0 if bool(layout.get("hud_overlay", false)) else 6.0)
	var right := field.end.x - 8.0
	if _pause.get_rect().grow(4.0).intersects(Rect2(field.position.x, top, field.size.x, 24.0)):
		right = minf(right, _pause.position.x - 6.0)
	_boss_root.position = Vector2(field.position.x + 8.0, top)
	_boss_w = maxf(80.0, right - _boss_root.position.x)
	_boss_root.size = Vector2(_boss_w, 14.0 + BOSS_BAR_H + 2.0)
	_boss_name.position = Vector2(1, 0)
	_boss_name.size = Vector2(_boss_w - 2.0, 13)
	_boss_track.position = Vector2(0, 14)
	_boss_track.size = Vector2(_boss_w, BOSS_BAR_H + 2.0)
	_boss_ghost.position = Vector2(1, 15)
	_boss_fill.position = Vector2(1, 15)
	_boss_shine.position = Vector2(1, 15)
	_boss_ghost.size.y = BOSS_BAR_H
	_boss_fill.size.y = BOSS_BAR_H
	_boss_shine.size.y = 1.0
	_layout_boss_ticks()
	_boss_shown = -1.0


func _layout_boss_ticks() -> void:
	var inner := _boss_w - 2.0
	for tick: ColorRect in _boss_ticks:
		var at := float(tick.get_meta(&"at", 0.5))
		tick.position = Vector2(1.0 + floorf(inner * at), 12)
		tick.size = Vector2(1, BOSS_BAR_H + 6.0)


## Rádio em cima do campo (abaixo da barra do chefe), longe da nave; no desktop, no painel esquerdo.
func _place_radio() -> void:
	var field: Rect2 = layout.get("field", Rect2(Vector2.ZERO, size))
	var width := field.size.x - 16.0
	var top := 30.0 if bool(layout.get("hud_overlay", false)) else 8.0
	var pos := Vector2(field.position.x + 8.0, field.position.y + top)
	if _boss_root.visible:
		pos.y = _boss_root.position.y + _boss_root.size.y + 6.0
	var left_room := field.position.x - safe.position.x - 32.0
	if not _portrait_mode and left_room >= 150.0:
		width = minf(300.0, left_room)
		pos = Vector2(field.position.x - 16.0 - width, field.position.y + field.size.y * 0.55)
	var has_portrait := _portrait.texture != null
	_radio_frame.visible = has_portrait
	_radio_name.visible = has_portrait
	_radio.custom_minimum_size.x = width - 24.0 - (PORTRAIT + 2.0 + 8.0 if has_portrait else 0.0)
	_radio_panel.size = Vector2(width, 0)
	_radio_panel.reset_size()
	_radio_panel.size.x = width
	_radio_panel.position = pos


# --- Rádio e faixas --------------------------------------------------------------------------

func show_radio(dialogue_id: String) -> void:
	var row: Dictionary = _dialogue.get(dialogue_id, {})
	if row.is_empty():
		return
	var speaker := String(row.get("speaker", ""))
	var color := Color(String(row.get("color", "#dff6ff")))
	_portrait.texture = Portraits.texture(speaker, String(row.get("mood", "calm")))
	Portraits.transmit(_portrait, speaker)
	_radio_name.text = tr("speaker." + speaker)
	var text := tr(String(row.get("text_key", "")))
	# Sem retrato (narrador), o nome volta para dentro do texto.
	_open_radio(text if _portrait.texture != null else "%s: %s" % [_radio_name.text, text], color)


func show_radio_text(text: String, color: Color) -> void:
	_portrait.texture = null
	_open_radio(text, color)


func _open_radio(text: String, color: Color) -> void:
	_radio.text = text
	_radio_name.add_theme_color_override("font_color", color)
	_radio.add_theme_color_override("font_color", UiTheme.TEXT if _portrait.texture != null else color)
	var box := UiTheme.panel_box(color, 0.74)
	box.set_content_margin_all(8)
	box.content_margin_left = 8
	_radio_panel.add_theme_stylebox_override("panel", box)
	var frame := UiTheme.chamfer(Color(UiTheme.ABYSS, 0.9), Color(color, 0.85), 1, 6)
	frame.set_content_margin_all(1)
	_radio_frame.add_theme_stylebox_override("panel", frame)
	_place_radio()
	_refit_panels()
	_radio_type = 0.0
	var chars := text.length()
	_radio.visible_characters = 0 if not _reduced else -1
	_radio_left = RADIO_SECONDS + (0.0 if _reduced else minf(2.5, chars / TYPE_RATE))
	var was := _radio_panel.visible
	_radio_panel.visible = true
	_radio_panel.modulate.a = 1.0
	if not was and not _reduced:
		if _radio_tween != null and _radio_tween.is_valid():
			_radio_tween.kill()
		var y := _radio_panel.position.y
		_radio_panel.position.y = y - 6.0
		_radio_panel.modulate.a = 0.0
		_radio_tween = create_tween().set_parallel()
		_radio_tween.tween_property(_radio_panel, "position:y", y, 0.2).set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_OUT)
		_radio_tween.tween_property(_radio_panel, "modulate:a", 1.0, 0.16)


## Poder lançado: os níveis I e II viram o selo pequeno no alto do campo (abaixo da barra do chefe ou da faixa
## do placar); o III é o título grande e curto da HudBanner no terço de cima. O objetivo da missão sai da frente.
func show_power(title: String, tier: int, tint: Color, icon: Texture2D) -> void:
	_objective_left = minf(_objective_left, 0.0)
	var numeral := PowerButton.ROMAN[clampi(tier, 1, 3)]
	if tier >= 3:
		_chip.visible = false
		# Espaço sem quebra: o número do nível nunca desce sozinho para a linha de baixo.
		_banner.show_text("%s\u00a0\u00a0%s" % [title, numeral], false, tint, true, SUPREME_BANNER_SECONDS, _reduced)
		return
	var field: Rect2 = layout.get("field", Rect2(Vector2.ZERO, size))
	var top := field.position.y + (30.0 if bool(layout.get("hud_overlay", false)) else 8.0)
	if _boss_root.visible:
		top = _boss_root.position.y + _boss_root.size.y + 4.0
	_chip.pop(icon, "%s · %s" % [title, numeral], tint, field.get_center().x, top, field.size.x - 24.0, _reduced)


## Faixa grande no centro do campo. O nome do chefe que entra vira aviso em coral com listras de
## perigo (o jogo já mostra ≥ 0,5 s antes do perigo: o chefe entra invulnerável por 3 s).
func show_banner(text: String) -> void:
	var boss := _sim.boss if _sim != null else null
	var warning := boss != null and boss.state == SimBoss.State.ENTER and text == tr(String(boss.def.get("name_key", "")))
	_banner.show_text(text, warning, Color(0, 0, 0, 0), false, BANNER_SECONDS, _reduced)


# --- Quadro a quadro -------------------------------------------------------------------------

func refresh(sim: Sim, delta: float) -> void:
	_sim = sim
	_refresh_score(sim, delta)
	_refresh_mult(sim)
	_refresh_hull(sim)
	_refresh_weapon(sim)
	_refresh_buttons(sim)
	_power.refresh(sim, delta)
	if _tutorial and not _power_hinted and _power.segments() >= 1:
		_power_hinted = true
		show_radio_text(tr("hint.power"), UiTheme.CYAN)
	_objective_left -= delta
	_objective_panel.visible = _objective_left > 0.0
	_objective_panel.modulate.a = clampf(_objective_left, 0.0, 1.0)
	if not _hints.is_empty() and sim.frame >= int(_hints[0][0]):
		show_radio_text(tr(String(_hints[0][1])), UiTheme.CYAN)
		_hints.pop_front()
	if _offer_panel.visible and sim.offer.is_empty():
		hide_offer()
	_refresh_boss(sim, delta)
	var boss := sim.boss
	var duel := boss != null and boss.state == SimBoss.State.DUEL
	_prompt.visible = duel
	if duel:
		_prompt.text = tr("hud.duel")
		_prompt.modulate.a = 1.0 if _reduced else 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
	_refresh_radio(delta)
	_banner.tick(delta)
	_chip.tick(delta)


## Placar com contagem rápida (alcança o alvo em ~0,3 s) e pulso dourado nos saltos grandes.
func _refresh_score(sim: Sim, delta: float) -> void:
	var score := sim.scoring.score
	if score != _score_target:
		var jump := score - _score_target
		_score_target = score
		if score < _score_shown or _reduced:
			_score_shown = score
		if jump >= SCORE_PULSE and not _reduced:
			_score.pivot_offset = Vector2(0.0, _score.size.y * 0.5)
			_score_tween = HudKit.pop(_score, _score_tween, 1.14, Color(1.0, 0.88, 0.55, _score.modulate.a),
					Color(1, 1, 1, _score.modulate.a), 0.32)
	if _score_shown < _score_target:
		var gap := _score_target - _score_shown
		_score_shown = minf(_score_target, _score_shown + maxf(gap * 12.0 * delta, 40.0 * delta))
	var text := Locale.format_number(int(_score_shown))
	if text != _score.text:
		_score.text = text


## Pílula do multiplicador: cor por faixa (ciano, menta, ouro, violeta no máximo), cresce quando sobe
## e pisca coral quando a corrente quebra.
func _refresh_mult(sim: Sim) -> void:
	var chain := sim.scoring.chain
	var mult := sim.scoring.multiplier()
	var broke := chain < _last_chain
	_last_chain = chain
	if chain > 0:
		if mult != _mult_value or not _mult_on:
			var rose := _mult_on and mult > _mult_value
			_mult_value = mult
			_mult.text = "×%d" % mult
			var tier := 3 if mult >= Scoring.MAX_MULT else (2 if mult >= 8 else (1 if mult >= 4 else 0))
			if tier != _mult_tier:
				_mult_tier = tier
				_mult_pill.add_theme_stylebox_override("panel", _mult_boxes[tier])
				_mult_pill.reset_size()
				_mult.add_theme_color_override("font_color", _mult_boxes[tier].border_color)
				_chain_bar.color = Color(_mult_boxes[tier].border_color, 0.8)
			if not _mult_on:
				_mult_on = true
				_mult_pill.visible = true
				_chain_bar.visible = true
				_mult_anim(Color.WHITE, 1.15)
			elif rose:
				_mult_anim(Color.WHITE, 1.3)
		if broke:
			_mult_anim(Color(UiTheme.CORAL, 1.0), 1.0)
		_chain_bar.size.x = (_mult_pill.size.x - 6.0) * clampf(float(sim.scoring.chain_timer) / sim.scoring.window,
				0.0, 1.0)
	elif _mult_on:
		_mult_on = false
		_mult_value = 0
		_chain_bar.visible = false
		_mult_break()


func _mult_anim(flash: Color, grow: float) -> void:
	if _reduced:
		_mult_pill.modulate = Color.WHITE
		return
	var lit := flash.lightened(0.2) if flash != Color.WHITE else Color(1.5, 1.5, 1.5)
	_mult_tween = HudKit.pop(_mult_pill, _mult_tween, grow, lit, Color.WHITE, 0.3)


func _mult_break() -> void:
	if _mult_tween != null and _mult_tween.is_valid():
		_mult_tween.kill()
	if _reduced:
		_mult_pill.visible = false
		return
	_mult_pill.modulate = Color(UiTheme.CORAL.r * 1.4, UiTheme.CORAL.g * 1.4, UiTheme.CORAL.b * 1.4, 1.0)
	_mult_tween = create_tween()
	_mult_tween.tween_property(_mult_pill, "modulate", Color(UiTheme.CORAL, 0.0), 0.45).set_delay(0.12)
	_mult_tween.tween_callback(func() -> void:
		_mult_pill.visible = _mult_on
		_mult_pill.modulate = Color.WHITE)


func _refresh_hull(sim: Sim) -> void:
	var hull := maxi(0, sim.player.hull)
	var max_hull := maxi(1, sim.player.max_hull)
	if max_hull != _hull_max:
		_hull_max = max_hull
		_rebuild_lives()
		_hull_shown = -1
	if hull == _hull_shown:
		return
	var lost := _hull_shown > hull
	var gained := _hull_shown >= 0 and hull > _hull_shown
	var before := _hull_shown
	_hull_shown = hull
	if _life_count.visible:
		_life_count.text = "×%d" % hull
		_life_count.add_theme_color_override("font_color", UiTheme.CORAL if hull <= 1 else UiTheme.TEXT)
		return
	for i: int in range(_life_icons.size()):
		var icon := _life_icons[i]
		var alive := i < hull
		icon.modulate = Color.WHITE if alive else Color(0.35, 0.45, 0.6, 0.35)
		if _reduced:
			continue
		if lost and i >= hull and i < before:
			HudKit.flash_icon(icon, Color(2.0, 0.5, 0.6, 1.0), Color(0.35, 0.45, 0.6, 0.35))
		elif gained and alive and i >= before:
			HudKit.flash_icon(icon, Color(0.8, 2.0, 1.2, 1.0), Color.WHITE)
	# Último casco: o ícone que sobra fica coral (perigo).
	if hull == 1 and not _life_icons.is_empty():
		_life_icons[0].modulate = Color(1.0, 0.55, 0.62)


func _rebuild_lives() -> void:
	for icon: TextureRect in _life_icons:
		_lives_box.remove_child(icon)
		icon.queue_free()
	_life_icons.clear()
	var n := _hull_max if _hull_max <= LIFE_MAX_ICONS else 1
	for i: int in range(n):
		var icon := HudKit.life_icon(_life_texture, LIFE_ICON)
		_lives_box.add_child(icon)
		_life_icons.append(icon)
	_life_count.visible = _hull_max > LIFE_MAX_ICONS
	_lives_box.move_child(_life_count, -1)
	_place_top()


func _refresh_weapon(sim: Sim) -> void:
	var p := sim.player
	var max_level := p.max_level()
	if p.level != _pip_level or max_level != _pip_max:
		_pip_level = p.level
		_pip_max = max_level
		_weapon_pips.custom_minimum_size = HudKit.pips_size(max_level)
		_weapon_pips.size = _weapon_pips.custom_minimum_size
		_weapon_pips.queue_redraw()
		_place_weapon()
	var key := String(p.weapon)
	if key != _weapon_key:
		_weapon_key = key
		_weapon.text = tr("weapon." + key)
		_place_weapon()


func _refresh_buttons(sim: Sim) -> void:
	var p := sim.player
	var ready := p.special_charge >= 1.0
	var q := int(clampf(p.special_charge, 0.0, 1.0) * CHARGE_STEPS)
	if ready != _special_ready:
		_special_ready = ready
		_style_special()
		if ready and not _reduced:
			_special.pivot_offset = _special.size * 0.5
			_special.scale = Vector2(1.18, 1.18)
			_special.create_tween().tween_property(_special, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK) \
					.set_ease(Tween.EASE_OUT)
	if q != _special_q:
		_special_q = q
		_special_gauge.queue_redraw()
	if p.bombs != _bombs_shown:
		_bombs_shown = p.bombs
		_bomb.disabled = p.bombs <= 0
		_style_bomb()
		_bomb_gauge.queue_redraw()
	var pressure := sim.scoring.pressure / Scoring.PRESSURE_MAX
	var value := pressure if sim.tide_frames == 0 else float(sim.tide_frames) / Sim.TIDE_FRAMES
	var pq := int(value * 200.0)
	if pq != _pressure_q:
		_pressure_q = pq
		_pressure.size.x = _pressure_track.size.x * clampf(value, 0.0, 1.0)
	var full := pressure >= 1.0 or sim.tide_frames > 0
	if full != _pressure_full:
		_pressure_full = full
		_pressure.color = UiTheme.WHITE if full else UiTheme.CYAN
	_tide.visible = full
	_tide.disabled = sim.tide_frames > 0
	if _tide.visible and not _tide.disabled and not _reduced:
		_tide.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)


## Especial: vidro com borda ouro fraca enquanto carrega; pronto, borda ouro cheia e halo pulsando.
func _style_special() -> void:
	var inside := _special.modulate.a < 1.0
	if _special_ready:
		HudKit.style_round(_special, UiTheme.GOLD, 1.0, true, 14)
	else:
		HudKit.style_round(_special, UiTheme.GOLD, 0.6 if inside else 0.9, false, 14)
	_special_caption.add_theme_color_override("font_color", UiTheme.GOLD if _special_ready else UiTheme.TEXT_DIM)
	_special_glow.visible = _special_ready
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	if _special_ready and not _reduced:
		_special_glow.modulate.a = 1.0
		_glow_tween = _special_glow.create_tween().set_loops()
		_glow_tween.tween_property(_special_glow, "modulate:a", 0.3, 0.55).set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_property(_special_glow, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	else:
		_special_glow.modulate.a = 1.0


func _style_bomb() -> void:
	HudKit.style_round(_bomb, UiTheme.CYAN, 0.9, false, 14)
	_bomb_caption.add_theme_color_override("font_color", UiTheme.TEXT if _bombs_shown > 0 else UiTheme.TEXT_DIM)


func _refresh_radio(delta: float) -> void:
	_radio_left -= delta
	if not _radio_panel.visible:
		return
	if _radio.visible_characters >= 0:
		_radio_type += delta
		var shown := int(_radio_type * TYPE_RATE)
		_radio.visible_characters = -1 if shown >= _radio.get_total_character_count() else shown
	_radio_panel.visible = _radio_left > 0.0
	if _radio_left < 0.35:
		_radio_panel.modulate.a = clampf(_radio_left / 0.35, 0.0, 1.0)


func _refresh_boss(sim: Sim, delta: float) -> void:
	var boss := sim.boss
	var active := boss != null and boss.state != SimBoss.State.DEAD
	if active and boss != _boss_ref:
		_boss_appear(boss)
	elif not active and _boss_root.visible:
		_boss_root.visible = false
		_boss_ref = null
		_place_radio()
	if not active:
		return
	var target := clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0)
	_boss_fill_t = minf(1.0, _boss_fill_t + delta / BOSS_FILL_SECONDS)
	var shown := minf(target, ease(_boss_fill_t, 0.4)) if _boss_fill_t < 1.0 else target
	if shown < _boss_shown - 0.0001 and _boss_fill_t >= 1.0:
		_boss_hold = 0.35
	if _boss_hold > 0.0:
		_boss_hold -= delta
	else:
		_boss_ghost_v = move_toward(_boss_ghost_v, shown, delta * 0.6)
	_boss_ghost_v = maxf(_boss_ghost_v, shown)
	var inner := _boss_w - 2.0
	if not is_equal_approx(shown, _boss_shown):
		_boss_shown = shown
		_boss_fill.size.x = floorf(inner * shown)
		_boss_shine.size.x = _boss_fill.size.x
	_boss_ghost.size.x = floorf(inner * _boss_ghost_v)
	if boss.state == SimBoss.State.DYING:
		_boss_root.modulate.a = maxf(0.0, _boss_root.modulate.a - delta * 1.5)


func _boss_appear(boss: SimBoss) -> void:
	_boss_ref = boss
	_boss_name.text = tr(String(boss.def.get("name_key", ""))).to_upper()
	for tick: ColorRect in _boss_ticks:
		tick.queue_free()
	_boss_ticks.clear()
	# Uma marca em cada limiar de etapa (until_hp entre 0 e 1): o jogador vê quando o chefe muda.
	for raw: Variant in boss.def.get("phases", []):
		var at := float((raw as Dictionary).get("until_hp", 0.0))
		if at <= 0.0 or at >= 1.0:
			continue
		var tick := HudKit.ignore(ColorRect.new()) as ColorRect
		tick.color = Color(UiTheme.WHITE, 0.85)
		tick.set_meta(&"at", at)
		_boss_root.add_child(tick)
		_boss_ticks.append(tick)
	_layout_boss_ticks()
	_boss_fill_t = 1.0 if _reduced else 0.0
	_boss_ghost_v = 0.0
	_boss_shown = -1.0
	_boss_fill.size.x = 0.0
	_boss_root.visible = true
	_boss_root.modulate.a = 1.0
	_place_radio()
	if not _reduced:
		var y := _boss_root.position.y
		_boss_root.position.y = y - 8.0
		_boss_root.modulate.a = 0.0
		var t := create_tween().set_parallel()
		t.tween_property(_boss_root, "position:y", y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_boss_root, "modulate:a", 1.0, 0.25)


## Controles que precisam caber na área segura (testes de layout).
func layout_controls() -> Array[Control]:
	return [_score, _pause, _special, _bomb, _power, _weapon, _tide, _power_name]


## Botão PODER (o Game chama charged/empty; testes leem o nome em name_label).
func power_button() -> PowerButton:
	return _power
