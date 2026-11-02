class_name HangarScreen
extends ListScreen
## Oficina do hangar (plano mestre 4.9 e 7.2; aba de comando da 1.15): nível da aeronave, arma
## secundária, asas, pintura e dificuldade. Toda regra vem da Economy e da Store; a tela só mostra e
## chama.
##
## Leiaute (estrutura dos shmups mobile, sem copiar arte nem nomes):
## - Palco: a aeronave grande no centro (ShipView: evolução do nível, pintura, flutuação e motor) entre
##   seis encaixes (CommandKit.slot): à esquerda arma secundária, asa 1 e asa 2; à direita pintura,
##   núcleo (o nível da nave e as peças montadas) e dificuldade. Encaixe vazio mostra a colmeia e o
##   "+"; cheio, a figura com a moldura da raridade e o nível. Tocar no encaixe abre a sub-aba dele.
## - Faixa de atributos (Dano, Casco, Peças) e o botão dourado "Evoluir nave" com o preço e o ganho
##   (dano, Poder e a próxima peça). O Poder total já está na barra de cima.
## - Sub-abas Nave, Armas, Asas, Pinturas e Desafio; cada uma é uma grade de ladrilhos (4 colunas em
##   270, 5 em 360, mais no desktop) com raridade por cor (LoadoutArt), nível e aviso. Tocar num
##   ladrilho abre o cartão de detalhe por cima do rodapé: nome, descrição, antes → depois e as ações
##   (Equipar, Evoluir, Comprar) com o preço sempre legível, inclusive quando falta dinheiro.
## - Telas largas (NavShell.wide): palco à esquerda, sub-abas e grade à direita.
## Controle: o foco anda pela geometria (encaixes → sub-abas → grade → cartão); B fecha o cartão.
##
## Cada nível monta uma peça nova na nave (ShipLivery): a subida revela a peça com uma onda de luz e um
## selo dourado. Som: a trava metálica na compra e o brilho de vidro na revelação; a Ascendida (nível
## máximo) tem celebração própria — raios de ouro, título "Nave Ascendida", sino e vinheta de tambor.

const TABS: Array[StringName] = [&"ship", &"weapons", &"wings", &"paints", &"mode"]
## Ciano claro da sub-aba ativa (texto escuro por cima).
const TAB_ACTIVE := Color("a5fbf2")
## Preço que ainda não dá: rosa claro, legível no vidro escuro.
const SHORT := Color("ff9db0")
const GAP := 6.0
const WIDE_MAX := 760.0
## Abaixo desta altura útil o palco encolhe (encaixes menores, sem legenda, nave em 2x).
const COMPACT_HEIGHT := 420.0
const CAPTION_SIZE := 9
## Folga da legenda sob o encaixe e o que o palco gasta fora das colunas (margens e espaços).
const CAPTION_EXTRA := 6.0
const STAGE_CHROME := 20.0

## Nível recém-comprado: a próxima montagem da tela revela a peça dele.
var _revealed: int = 0
var _tab: StringName = &"ship"
## Ladrilho aberto no cartão de detalhe: {"kind", "id"} ou vazio.
var _detail: Dictionary = {}
var _wide_built: bool = false
var _want_focus: String = ""
var _side_scroll: ScrollContainer
var _side: VBoxContainer
var _panel: PanelContainer
var _spacer: Control
var _grid: GridContainer
var _cells: Array[VBoxContainer] = []
var _tab_buttons: Array[Button] = []


func title_key() -> String:
	return "hangar.title"


func show_wallet() -> bool:
	return true


func max_width() -> float:
	return WIDE_MAX if _is_wide() else MAX_WIDTH


func _build() -> void:
	super._build()
	_side_scroll = ScrollContainer.new()
	_side_scroll.name = "StageColumn"
	_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side_scroll.visible = false
	add_child(_side_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 3)
	pad.add_theme_constant_override("margin_right", 6)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 12)
	_side_scroll.add_child(pad)
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", 8)
	pad.add_child(_side)
	_panel = PanelContainer.new()
	_panel.name = "Detail"
	_panel.visible = false
	_panel.minimum_size_changed.connect(_place_panel)
	add_child(_panel)


func _is_wide() -> bool:
	return in_shell() and NavShell.wide(safe)


func _compact() -> bool:
	return not _wide_built and safe.size.y < COMPACT_HEIGHT


## Remonta e devolve o foco ao mesmo controle (encaixe, sub-aba, ladrilho, ação do cartão).
func refill() -> void:
	var key := ""
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and is_ancestor_of(focused):
		key = String(focused.get_meta(&"focus_key", ""))
	super.refill()
	if not _want_focus.is_empty():
		key = _want_focus
		_want_focus = ""
	var target := _find_key(key)
	if target != null:
		FocusNav.focus(target)


func default_focus() -> Control:
	var first := FocusNav.first(_side) if _wide_built else null
	return first if first != null else super.default_focus()


## B/Voltar fecha o cartão de detalhe antes de sair da aba.
func back() -> bool:
	if not _detail.is_empty():
		_close_detail()
		return true
	return super.back()


func layout_controls() -> Array[Control]:
	if not in_shell():
		return super.layout_controls()
	var out: Array[Control] = [_scroll]
	if _side_scroll.visible:
		out.append(_side_scroll)
	if _panel.visible:
		out.append(_panel)
	return out


func _fill() -> void:
	for child: Node in _side.get_children():
		_side.remove_child(child)
		child.queue_free()
	_cells.clear()
	_tab_buttons.clear()
	_wide_built = _is_wide()
	_side_scroll.visible = _wide_built
	var profile := SaveManager.data
	var top: Container = _side if _wide_built else _list
	_fill_stage(top, profile)
	_fill_strip(top, profile)
	_fill_tabs(profile)
	_fill_grid(profile)
	_spacer = Control.new()
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(_spacer)
	_fill_detail(profile)


func _layout() -> void:
	super._layout()
	if _side_scroll == null:
		return
	if in_shell():
		_ribbon.visible = false
	var width := floorf(minf(safe.size.x - GUTTER * 2.0, max_width()))
	var left := floorf(safe.position.x + (safe.size.x - width) * 0.5)
	var top := safe.position.y + 6.0 if in_shell() else _scroll.position.y
	var height := maxf(0.0, safe.end.y - top)
	var grid_width := width
	if _wide_built:
		var stage_width := _stage_width()
		_side_scroll.position = Vector2(left - 3.0, top)
		_side_scroll.size = Vector2(stage_width + 9.0, height)
		var right := left + stage_width + 12.0
		grid_width = left + width - right
		_scroll.position = Vector2(right - 3.0, top)
		_scroll.size = Vector2(grid_width + 9.0, height)
	else:
		_scroll.position = Vector2(left - 3.0, top)
		_scroll.size = Vector2(width + 9.0, height)
	_size_grid(grid_width)
	_place_panel()
	if _wide_built != _is_wide() and is_inside_tree():
		refill.call_deferred()


# --- Palco ----------------------------------------------------------------------------------------

func _fill_stage(parent: Container, profile: Dictionary) -> void:
	var ship := StringName(String(profile["selected"]["ship"]))
	var level := Economy.ship_level(profile, ship)
	var tint := ship_tint(String(ship), String(profile["selected"].get("cosmetic", "")))
	var column := _stage_width()
	var captions := not _compact()
	# Encaixes do maior lado (até 54) que ainda deixa a nave em 2x inteira entre as duas colunas.
	var extra := CAPTION_EXTRA if captions else 0.0
	var room := floorf((column - STAGE_CHROME - ShipView.SIZE * 2.0 - 8.0) * 0.5) - extra
	var side := clampf(room, 38.0, 44.0 if _compact() else 54.0)
	var panel := PanelContainer.new()
	panel.name = "Stage"
	var box := UiTheme.chamfer(Color(UiTheme.ABYSS, 0.5), Color(UiTheme.CYAN, 0.3), 1, UiTheme.CUT + 3)
	box.border_width_top = 2
	box.border_color = Color(UiTheme.CYAN, 0.45)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var left := _slot_column(row)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 2)
	row.add_child(center)
	var right := _slot_column(row)
	for info: Dictionary in _left_slots(profile):
		_slot(left, info, side, captions)
	for info: Dictionary in _right_slots(profile, level, tint):
		_slot(right, info, side, captions)
	# Nome e nível em cima, a nave no meio (selos da subida por cima dela) e as barras de nível embaixo.
	var center_width := column - STAGE_CHROME - (side + extra) * 2.0
	var name_label := UiTheme.label(tr("ship." + String(ship)), 13, UiTheme.WHITE)
	_bold(name_label)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var level_badge := badge(tr("hangar.level") % level, UiTheme.GOLD)
	level_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Nome e nível lado a lado; se não cabem no meio do palco (russo em 453x544), o nível desce.
	var side_by_side := _text_width(name_label) + 5.0 + level_badge.get_combined_minimum_size().x <= center_width
	var head: BoxContainer = HBoxContainer.new() if side_by_side else VBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 5 if side_by_side else 1)
	head.add_child(name_label)
	head.add_child(level_badge)
	center.add_child(head)
	var tall := safe.size.y >= (400.0 if _wide_built else 560.0)
	var zoom := 3 if not _compact() and tall and center_width >= ShipView.SIZE * 3.0 + 8.0 else 2
	var holder := MarginContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(holder)
	var view := ship_view(tint, zoom, false, level)
	view.name = "HeroShip"
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(view)
	view.custom_minimum_size = Vector2(ShipView.SIZE * float(zoom) + 8.0, ShipView.SIZE * float(zoom) + 8.0)
	var seals := VBoxContainer.new()
	seals.alignment = BoxContainer.ALIGNMENT_END
	seals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seals.add_theme_constant_override("separation", 2)
	holder.add_child(seals)
	if _revealed == level and ShipLivery.part_at(level) != &"":
		view.reveal()
		_announce(seals, level)
	_revealed = 0
	var bars := VBoxContainer.new()
	bars.custom_minimum_size = Vector2(minf(center_width, 120.0), 0)
	bars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(bars)
	pips(bars, level, Economy.SHIP_MAX_LEVEL)


## Largura do palco (a coluna da esquerda nas telas largas, a coluna inteira nas outras).
func _stage_width() -> float:
	var width := floorf(minf(safe.size.x - GUTTER * 2.0, max_width()))
	return clampf(floorf(width * 0.5), 210.0, 340.0) if _wide_built else width


func _slot_column(row: HBoxContainer) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 5)
	row.add_child(col)
	return col


## Encaixes da esquerda: arma secundária e as duas asas.
func _left_slots(profile: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var weapon := StringName(String(profile["selected"]["secondary"]))
	var weapon_level := Economy.secondary_level(profile, weapon) if weapon != &"" else 0
	var armed := weapon_level > 0
	out.append({"key": "weapon", "tab": &"weapons", "caption": tr("workshop.slot_weapon"),
			"texture": LoadoutArt.secondary(weapon) if armed else null, "level": weapon_level,
			"rarity": LoadoutArt.secondary_rarity(weapon_level),
			"tip": tr("secondary." + String(weapon)) if armed else tr("hangar.secondary"),
			"notice": Notices.can_upgrade_secondary(profile)})
	var chosen: Array = profile["selected"]["wings"]
	var open := Notices.wing_slot_open(profile)
	for i: int in range(Economy.MAX_WINGS):
		var def := _wing_def(String(chosen[i])) if i < chosen.size() else {}
		out.append({"key": "wing%d" % (i + 1), "tab": &"wings", "caption": tr("workshop.slot_wing") % (i + 1),
				"texture": LoadoutArt.wing(StringName(String(def["effect"]))) if not def.is_empty() else null,
				"level": 0, "rarity": LoadoutArt.wing_rarity(int(def.get("stars", 0))),
				"tip": tr(String(def["name_key"])) if not def.is_empty() else tr("workshop.slot_wing") % (i + 1),
				"notice": def.is_empty() and open})
	return out


## Encaixes da direita: pintura, núcleo (nível da nave) e dificuldade.
func _right_slots(profile: Dictionary, level: int, tint: Color) -> Array[Dictionary]:
	var cosmetic := String(profile["selected"].get("cosmetic", ""))
	var difficulty := StringName(String(profile["selected"]["difficulty"]))
	return [
		{"key": "paint", "tab": &"paints", "caption": tr("workshop.slot_paint"),
				"texture": LoadoutArt.ship(tint, 1), "level": 0, "rarity": LoadoutArt.paint_rarity(_cosmetic(cosmetic)),
				"tip": tr("cosmetic." + cosmetic) if not cosmetic.is_empty() else tr("shop.default_paint"),
				"notice": false},
		{"key": "core", "tab": &"ship", "caption": tr("workshop.slot_core"), "texture": LoadoutArt.ship(tint, level),
				"level": level, "rarity": LoadoutArt.level_rarity(level), "tip": tr("hangar.level") % level,
				"notice": Notices.can_upgrade_ship(profile)},
		{"key": "mode", "tab": &"mode", "caption": tr("workshop.tab_mode"),
				"texture": LoadoutArt.difficulty(difficulty), "level": 0,
				"rarity": LoadoutArt.difficulty_rarity(difficulty), "tip": tr("difficulty." + String(difficulty)),
				"notice": false},
	]


func _slot(parent: Container, info: Dictionary, side: float, caption: bool) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 1)
	parent.add_child(cell)
	var tex: Texture2D = info["texture"]
	var s := CommandKit.slot(tex)
	s.name = "Slot_" + String(info["key"])
	s.custom_minimum_size = Vector2(side, side)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.tooltip_text = String(info["tip"])
	s.set_meta(&"focus_key", "slot:" + String(info["key"]))
	cell.add_child(s)
	if tex != null:
		var mark := SlotMark.new()
		mark.rarity = int(info["rarity"])
		mark.level = int(info["level"])
		s.add_child(mark)
	if bool(info["notice"]):
		CommandKit.notice_dot(s)
	var tab: StringName = info["tab"]
	s.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_click")
		_select_tab(tab))
	if caption:
		var l := UiTheme.label(String(info["caption"]), CAPTION_SIZE, UiTheme.TEXT_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var room := side + CAPTION_EXTRA
		l.add_theme_font_size_override("font_size", CommandKit.fit_size(l.get_theme_font("font"), l.text, room,
				UiTheme.scaled(CAPTION_SIZE), 7))
		l.custom_minimum_size.x = room
		cell.add_child(l)


## Anuncia a peça recém-montada: selo dourado e brilho de vidro; na Ascendida, antes do selo, o
## título grande, o sino e a vinheta (a trilha abaixa enquanto ela toca).
func _announce(seals: VBoxContainer, level: int) -> void:
	if level >= Economy.SHIP_MAX_LEVEL:
		var title := UiTheme.label(tr("hangar.ascended"), 16, UiTheme.GOLD)
		title.name = "Ascended"
		_bold(title)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_outline_color", Color(UiTheme.ABYSS, 0.9))
		title.add_theme_constant_override("outline_size", 4)
		seals.add_child(title)
		_pop_in(title)
		AudioManager.play_ui("kenney_ascend_bell")
		AudioManager.play_jingle("kenney_jingle_ascend")
	else:
		get_tree().create_timer(0.2).timeout.connect(func() -> void: AudioManager.play_ui("kenney_part_shine"))
	var fresh := badge(tr("hangar.livery_new") % tr("livery." + String(ShipLivery.part_at(level))), UiTheme.GOLD,
			&"star")
	fresh.name = "NewPart"
	(fresh.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(UiTheme.ABYSS, 0.88)
	fresh.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	seals.add_child(fresh)
	_pop_in(fresh)


## Selo que salta para dentro (escala 0,6 → 1 com mola), salvo em "reduzir movimento".
func _pop_in(node: Control) -> void:
	if UiFx.reduced():
		return
	node.scale = Vector2.ONE * 0.6
	node.modulate.a = 0.0
	node.resized.connect(func() -> void: node.pivot_offset = node.size * 0.5)
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.set_delay(0.25)
	tween.tween_property(node, "modulate:a", 1.0, 0.2).set_delay(0.25)


# --- Atributos e evolução -------------------------------------------------------------------------

func _fill_strip(parent: Container, profile: Dictionary) -> void:
	var ship := StringName(String(profile["selected"]["ship"]))
	var level := Economy.ship_level(profile, ship)
	var bonus := Economy.ship_bonus(level)
	var chips := HFlowContainer.new()
	chips.name = "Stats"
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	parent.add_child(chips)
	chips.add_child(CommandKit.stat_chip(&"diamond", tr("workshop.damage"),
			"+%d%%" % roundi(float(bonus["damage"]) * 100.0), UiTheme.CORAL))
	chips.add_child(CommandKit.stat_chip(&"ship", tr("workshop.hull"), "+%d" % int(bonus["hull"]), UiTheme.CYAN))
	# Peças só onde cabem na mesma linha (as barras de nível do palco já mostram o progresso).
	if _stage_width() >= 300.0:
		chips.add_child(CommandKit.stat_chip(&"star", tr("workshop.parts"),
				"%d/%d" % [ShipLivery.parts_at(level).size(), ShipLivery.PARTS.size()], UiTheme.GOLD))
	if level >= Economy.SHIP_MAX_LEVEL:
		var done := badge(tr("hangar.ascended") + " · " + tr("hangar.max"), UiTheme.GOLD, &"star")
		done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		parent.add_child(done)
		return
	var cost := Economy.ship_level_cost(level, profile)
	var next := Economy.ship_bonus(level + 1)
	var part := ShipLivery.next_part(level)
	var gain := "%s +%d%%  ·  %s +%s  ·  %s" % [tr("workshop.damage"),
			roundi((float(next["damage"]) - float(bonus["damage"])) * 100.0), tr("command.power"),
			Locale.format_number(_power_gain(profile, ship)), tr("livery." + String(part["id"]))]
	var b := _action(parent, tr("workshop.upgrade"), {"credits": cost}, Economy.can_pay(profile, {"credits": cost}),
			"UpgradeShip", true, _upgrade_ship.bind(ship), gain)
	b.set_meta(&"focus_key", "upgrade")
	b.tooltip_text = "%s · %s" % [tr("hangar.upgrade") % Locale.format_number(cost),
			tr("hangar.livery_next") % tr("livery." + String(part["id"]))]


## Poder a mais com a nave um nível acima (mesma conta da barra de cima).
func _power_gain(profile: Dictionary, ship: StringName) -> int:
	var next := {"selected": profile["selected"], "hangar": {"ship_levels": {String(ship):
			Economy.ship_level(profile, ship) + 1}, "modules": profile["hangar"]["modules"]}}
	return Economy.power(next) - Economy.power(profile)


func _upgrade_ship(ship: StringName) -> void:
	if Economy.upgrade_ship(SaveManager.data, ship):
		_revealed = Economy.ship_level(SaveManager.data, ship)
		AudioManager.play_ui("kenney_part_clamp")
		SaveManager.save_profile()


# --- Sub-abas e grade -----------------------------------------------------------------------------

func _fill_tabs(profile: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "SubTabs"
	row.add_theme_constant_override("separation", 4)
	_list.add_child(row)
	var notices := {&"ship": Notices.can_upgrade_ship(profile), &"weapons": Notices.can_upgrade_secondary(profile),
			&"wings": Notices.wing_slot_open(profile)}
	for tab: StringName in TABS:
		var b := Button.new()
		b.name = "Tab_" + String(tab)
		b.text = _tab_label(tab)
		b.tooltip_text = _tab_tip(tab, profile)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta(&"focus_key", "tab:" + String(tab))
		_style_tab(b, tab == _tab)
		row.add_child(b)
		_tab_buttons.append(b)
		if bool(notices.get(tab, false)):
			CommandKit.notice_dot(b)
		b.pressed.connect(func() -> void:
			AudioManager.play_ui("kenney_ui_tab")
			_select_tab(tab))


func _style_tab(b: Button, active: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := UiTheme.chamfer(TAB_ACTIVE if active else Color(UiTheme.DEEP_BLUE, 0.85),
				Color(UiTheme.WHITE, 0.9) if active else Color(UiTheme.CYAN, 0.32), 1, UiTheme.CUT_SMALL + 3)
		box.content_margin_left = 3
		box.content_margin_right = 3
		if state in ["hover", "focus"]:
			box.border_color = UiTheme.WHITE
			box.border_width_bottom = 2
			if not active:
				box.bg_color = Color(UiTheme.RAISED, 0.95)
		elif state == "pressed":
			box.bg_color = TAB_ACTIVE.darkened(0.15) if active else Color(UiTheme.CYAN, 0.2)
		if active:
			box.shadow_color = Color(UiTheme.CYAN, 0.35)
			box.shadow_size = 5
		b.add_theme_stylebox_override(state, box)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(key, UiTheme.ABYSS if active else (UiTheme.TEXT if key == "font_color"
				else UiTheme.WHITE))
	var bold := UiTheme.bold_font()
	if bold != null:
		b.add_theme_font_override("font", bold)


func _tab_label(tab: StringName) -> String:
	match tab:
		&"weapons":
			return tr("workshop.tab_weapons")
		&"wings":
			return tr("workshop.tab_wings")
		&"paints":
			return tr("workshop.tab_paints")
		&"mode":
			return tr("workshop.tab_mode")
	return tr("workshop.tab_ship")


## Dica da sub-aba (mouse no desktop): o nome longo e a contagem.
func _tab_tip(tab: StringName, profile: Dictionary) -> String:
	match tab:
		&"ship":
			var level := Economy.ship_level(profile, StringName(String(profile["selected"]["ship"])))
			return tr("hangar.livery") % [ShipLivery.parts_at(level).size(), ShipLivery.PARTS.size()]
		&"weapons":
			return tr("hangar.secondary")
		&"wings":
			return tr("hangar.wings") % [(profile["selected"]["wings"] as Array).size(), Economy.MAX_WINGS]
		&"mode":
			return tr("hangar.difficulty")
	return _tab_label(tab)


func _rarity_name(rarity: int) -> String:
	match rarity:
		CommandKit.RARE:
			return tr("workshop.rarity_rare")
		CommandKit.EPIC:
			return tr("workshop.rarity_epic")
		CommandKit.LEGENDARY:
			return tr("workshop.rarity_legendary")
	return tr("workshop.rarity_common")


func _select_tab(tab: StringName) -> void:
	if tab == _tab and _detail.is_empty():
		return
	_tab = tab
	_detail = {}
	refill()


func _fill_grid(profile: Dictionary) -> void:
	_grid = GridContainer.new()
	_grid.name = "Items"
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_grid)
	for entry: Dictionary in _entries(profile):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		_grid.add_child(cell)
		var tile := CommandKit.item_tile(entry["texture"], int(entry["level"]), int(entry["rarity"]),
				bool(entry["notice"]))
		tile.name = "Item_" + (String(entry["id"]) if not String(entry["id"]).is_empty() else "default")
		tile.pixel_art = false
		tile.selected = bool(entry["selected"])
		tile.locked = bool(entry["locked"])
		tile.tooltip_text = String(entry["name"])
		tile.set_meta(&"focus_key", "tile:%s:%s" % [entry["kind"], entry["id"]])
		cell.add_child(tile)
		if bool(entry["selected"]) or bool(entry.get("done", false)):
			var check := glyph(&"check", UiTheme.MINT, 12)
			check.position = Vector2(4, 4)
			tile.add_child(check)
		elif bool(entry.get("buy", false)):
			# Pintura da Loja ainda não comprada: a cor fica à vista, só um cadeado pequeno no canto.
			var lock := glyph(&"lock", UiTheme.TEXT, 11)
			lock.position = Vector2(5, 5)
			tile.add_child(lock)
		var kind: StringName = entry["kind"]
		var id := String(entry["id"])
		tile.pressed.connect(func() -> void:
			AudioManager.play_ui("kenney_ui_click")
			_open_detail(kind, id))
		var caption := UiTheme.label(String(entry["name"]), CAPTION_SIZE,
				UiTheme.TEXT if not bool(entry["locked"]) else UiTheme.TEXT_DIM, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD
		caption.max_lines_visible = 2
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(caption)
		_cells.append(cell)


## Colunas e lado dos ladrilhos pela largura da grade (4 em 270, 5 em 360, até 8 no desktop).
func _size_grid(width: float) -> void:
	if _grid == null or not is_instance_valid(_grid):
		return
	var cols := clampi(floori((width + GAP) / (CommandKit.TILE + GAP)), 4, 8)
	var side := floorf((width - GAP * float(cols - 1)) / float(cols))
	_grid.columns = cols
	var line := float(UiTheme.scaled(CAPTION_SIZE)) * 1.3
	# Um tamanho de legenda para a grade toda: o maior em que cada palavra cabe inteira na largura (nada
	# de "Propulsore-s"). Palavra que nem em 7 cabe (russo) quebra por sílaba, sem invadir o vizinho.
	var fs := UiTheme.scaled(CAPTION_SIZE)
	var fits := true
	for cell: VBoxContainer in _cells:
		var caption := cell.get_child(cell.get_child_count() - 1) as Label
		var font := caption.get_theme_font("font")
		for word: String in caption.text.split(" ", false):
			fs = mini(fs, CommandKit.fit_size(font, word, side - 2.0, UiTheme.scaled(CAPTION_SIZE), 7))
			fits = fits and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x <= side - 2.0
	for cell: VBoxContainer in _cells:
		var tile := cell.get_child(0) as Control
		tile.custom_minimum_size = Vector2(side, side)
		var caption := cell.get_child(cell.get_child_count() - 1) as Label
		caption.custom_minimum_size = Vector2(side, ceilf(line * 2.0))
		caption.add_theme_font_size_override("font_size", fs)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD if fits else TextServer.AUTOWRAP_WORD_SMART
	# Sub-abas: um tamanho só para as cinco (o do rótulo mais longo).
	var room := (width - 4.0 * float(TABS.size() - 1)) / float(TABS.size()) - 8.0
	var tab_size := UiTheme.scaled(11)
	for b: Button in _tab_buttons:
		tab_size = mini(tab_size, CommandKit.fit_size(b.get_theme_font("font"), b.text, room, UiTheme.scaled(11), 7))
	for b: Button in _tab_buttons:
		b.add_theme_font_size_override("font_size", tab_size)


## Ladrilhos da sub-aba atual: {kind, id, name, texture, level, rarity, notice, selected, locked, done}.
func _entries(profile: Dictionary) -> Array[Dictionary]:
	match _tab:
		&"weapons":
			return _weapon_entries(profile)
		&"wings":
			return _wing_entries(profile)
		&"paints":
			return _paint_entries(profile)
		&"mode":
			return _mode_entries(profile)
	return _part_entries(profile)


## Evolução: as nove peças em ordem; montadas com o visto, a próxima acesa (com aviso se dá para
## comprar) e as seguintes com cadeado.
func _part_entries(profile: Dictionary) -> Array[Dictionary]:
	var ship := StringName(String(profile["selected"]["ship"]))
	var level := Economy.ship_level(profile, ship)
	var tint := ship_tint(String(ship), String(profile["selected"].get("cosmetic", "")))
	var next := int(ShipLivery.next_part(level).get("level", 0))
	var out: Array[Dictionary] = []
	for p: Dictionary in ShipLivery.PARTS:
		var at := int(p["level"])
		out.append({"kind": &"part", "id": String(p["id"]), "name": tr("livery." + String(p["id"])),
				"texture": LoadoutArt.part(p["id"], tint), "level": at, "rarity": LoadoutArt.level_rarity(at),
				"notice": at == next and Notices.can_upgrade_ship(profile), "selected": false,
				"locked": at > level and at != next, "done": at <= level})
	return out


func _weapon_entries(profile: Dictionary) -> Array[Dictionary]:
	var equipped := StringName(String(profile["selected"]["secondary"]))
	var out: Array[Dictionary] = []
	for kind: StringName in Economy.SECONDARIES:
		var level := Economy.secondary_level(profile, kind)
		out.append({"kind": &"weapon", "id": String(kind), "name": tr("secondary." + String(kind)),
				"texture": LoadoutArt.secondary(kind), "level": level, "rarity": LoadoutArt.secondary_rarity(level),
				"notice": level < Economy.SECONDARY_MAX_LEVEL and Economy.can_pay(profile, _secondary_cost(level)),
				"selected": level > 0 and equipped == kind, "locked": level == 0})
	return out


func _wing_entries(profile: Dictionary) -> Array[Dictionary]:
	var wings := DB.rows("wings")
	var available := Economy.wings_available(profile, wings)
	var chosen: Array = profile["selected"]["wings"]
	var out: Array[Dictionary] = []
	for row: Variant in wings:
		var def := row as Dictionary
		if not Economy.released(def):
			continue
		var id := String(def["id"])
		var open := StringName(id) in available
		out.append({"kind": &"wing", "id": id, "name": tr(String(def["name_key"])),
				"texture": LoadoutArt.wing(StringName(String(def["effect"]))), "level": 0,
				"rarity": LoadoutArt.wing_rarity(int(def["stars"])),
				"notice": open and not chosen.has(id) and chosen.size() < Economy.MAX_WINGS,
				"selected": chosen.has(id), "locked": not open})
	return out


func _paint_entries(profile: Dictionary) -> Array[Dictionary]:
	var ship := String(profile["selected"]["ship"])
	var level := Economy.ship_level(profile, StringName(ship))
	var equipped := String(profile["selected"].get("cosmetic", ""))
	var out: Array[Dictionary] = [{"kind": &"paint", "id": "", "name": tr("shop.default_paint"),
			"texture": LoadoutArt.ship(ship_tint(ship), level), "level": 0, "rarity": CommandKit.COMMON,
			"notice": false, "selected": equipped.is_empty(), "locked": false}]
	for c: Variant in Store.cosmetics():
		var def := c as Dictionary
		var id := String(def["id"])
		var owned := Store.owned(profile, id)
		var rare := bool(def.get("supporter", false)) or bool(def.get("season", false))
		if not owned and rare and not Store.purchases_enabled():
			continue  # Mesma regra da Loja: pintura que não dá para obter não aparece.
		out.append({"kind": &"paint", "id": id, "name": tr("cosmetic." + id),
				"texture": LoadoutArt.ship(Color(String(def.get("color", "#ffffff"))), level), "level": 0,
				"rarity": LoadoutArt.paint_rarity(def), "notice": false, "selected": owned and equipped == id,
				"locked": false, "buy": not owned})
	return out


func _mode_entries(profile: Dictionary) -> Array[Dictionary]:
	var current := String(profile["selected"]["difficulty"])
	var out: Array[Dictionary] = []
	for diff: StringName in Economy.DIFFICULTIES:
		out.append({"kind": &"mode", "id": String(diff), "name": tr("difficulty." + String(diff)),
				"texture": LoadoutArt.difficulty(diff), "level": 0, "rarity": LoadoutArt.difficulty_rarity(diff),
				"notice": false, "selected": current == String(diff), "locked": false})
	return out


# --- Cartão de detalhe ----------------------------------------------------------------------------

func _open_detail(kind: StringName, id: String) -> void:
	if _detail.get("kind", &"") == kind and String(_detail.get("id", "")) == id:
		_close_detail()
		return
	_detail = {"kind": kind, "id": id}
	if FocusNav.pad:
		_want_focus = "detail:first"
	refill()
	_reveal_tile()


func _close_detail() -> void:
	var key := "tile:%s:%s" % [_detail.get("kind", &""), _detail.get("id", "")]
	_detail = {}
	AudioManager.play_ui("kenney_ui_back")
	_want_focus = key if FocusNav.pad else ""
	refill()


func _fill_detail(profile: Dictionary) -> void:
	for child: Node in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()
	var entry := {}
	if not _detail.is_empty():
		for e: Dictionary in _entries(profile):
			if e["kind"] == _detail["kind"] and String(e["id"]) == String(_detail["id"]):
				entry = e
	if entry.is_empty():
		_detail = {}
		_panel.visible = false
		return
	_panel.visible = true
	var color := CommandKit.rarity_color(int(entry["rarity"]))
	var style := UiTheme.panel_box(color, 0.97)
	style.shadow_size = 14
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_offset = Vector2(0, -2)
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var icon_tile := CommandKit.item_tile(entry["texture"], int(entry["level"]), int(entry["rarity"]))
	icon_tile.name = "DetailIcon"
	icon_tile.pixel_art = false
	icon_tile.locked = bool(entry["locked"])
	icon_tile.focus_mode = Control.FOCUS_NONE
	icon_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_tile.custom_minimum_size = Vector2(46, 46)
	icon_tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon_tile)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 1)
	head.add_child(names)
	var title := UiTheme.label(String(entry["name"]), 14, UiTheme.WHITE, true)
	title.name = "DetailName"
	_bold(title)
	names.add_child(title)
	var sub := _rarity_name(int(entry["rarity"]))
	if int(entry["level"]) > 0:
		sub += "  ·  " + tr("hangar.level") % int(entry["level"])
	names.add_child(UiTheme.label(sub, UiTheme.SMALL_SIZE, color.lightened(0.25), true))
	var close := UiTheme.icon_button("cross", "CloseDetail")
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = tr("workshop.close")
	close.set_meta(&"focus_key", "detail:close")
	close.pressed.connect(_close_detail)
	head.add_child(close)
	match entry["kind"]:
		&"part":
			_detail_part(box, profile, entry)
		&"weapon":
			_detail_weapon(box, profile, entry)
		&"wing":
			_detail_wing(box, profile, entry)
		&"paint":
			_detail_paint(box, profile, entry)
		&"mode":
			_detail_mode(box, profile, entry)
	# Primeiro foco do cartão: a primeira ação habilitada (ou o fechar, se não houver ação).
	var actions := box.find_child("Actions", false, false)
	var first := FocusNav.first(actions) if actions != null else null
	(first if first != null else close).set_meta(&"focus_key", "detail:first")
	# Do cartão, "para cima" no controle volta ao ladrilho aberto (não a um vizinho escondido atrás).
	var tile := _find_key("tile:%s:%s" % [entry["kind"], entry["id"]])
	if tile != null:
		for node: Node in box.find_children("*", "Button", true, false):
			var b := node as Button
			if b.focus_mode != Control.FOCUS_NONE and b != close:
				b.focus_neighbor_top = b.get_path_to(tile)
		close.focus_neighbor_left = close.get_path_to(tile)


func _detail_part(box: VBoxContainer, profile: Dictionary, entry: Dictionary) -> void:
	var ship := StringName(String(profile["selected"]["ship"]))
	var level := Economy.ship_level(profile, ship)
	var at := int(entry["level"])
	var now := Economy.ship_bonus(level)
	var then := Economy.ship_bonus(at)
	if at <= level:
		_status(box, tr("workshop.installed"), UiTheme.MINT, &"check")
		text(box, tr("hangar.bonus") % [roundi(float(then["damage"]) * 100.0), int(then["hull"])])
		return
	_status(box, tr("workshop.part_at") % at, UiTheme.MINT if at == level + 1 else UiTheme.TEXT_DIM, &"lock")
	_stat(box, tr("workshop.damage"), "+%d%%" % roundi(float(now["damage"]) * 100.0),
			"+%d%%" % roundi(float(then["damage"]) * 100.0))
	if int(then["hull"]) != int(now["hull"]):
		_stat(box, tr("workshop.hull"), "+%d" % int(now["hull"]), "+%d" % int(then["hull"]))
	if at != level + 1:
		return
	_stat(box, tr("command.power"), Locale.format_number(Economy.power(profile)),
			Locale.format_number(Economy.power(profile) + _power_gain(profile, ship)))
	var cost := Economy.ship_level_cost(level, profile)
	_short(box, profile, {"credits": cost})
	var row := _actions(box)
	_action(row, tr("workshop.evolve"), {"credits": cost}, Economy.can_pay(profile, {"credits": cost}),
			"UpgradePart", true, _upgrade_ship.bind(ship))


func _detail_weapon(box: VBoxContainer, profile: Dictionary, entry: Dictionary) -> void:
	var kind := StringName(String(entry["id"]))
	var level := int(entry["level"])
	var on := bool(entry["selected"])
	text(box, tr("secondary.%s_desc" % kind))
	var cost := _secondary_cost(level)
	if level < Economy.SECONDARY_MAX_LEVEL:
		_stat(box, tr("workshop.level"), str(level), str(level + 1))
		_stat(box, tr("command.power"), Locale.format_number(Economy.secondary_power(level)),
				Locale.format_number(Economy.secondary_power(level + 1)))
		_short(box, profile, cost)
	else:
		_status(box, tr("hangar.max"), UiTheme.GOLD, &"star")
	var row := _actions(box)
	if level == 0:
		var buy := _action(row, tr("workshop.buy"), cost, Economy.can_pay(profile, cost), "BuySecondary", true,
				func() -> void:
					if Economy.upgrade_secondary(SaveManager.data, kind):
						SaveManager.data["selected"]["secondary"] = String(kind)
						AudioManager.play_ui("kenney_part_clamp")
						SaveManager.save_profile())
		buy.tooltip_text = tr("hangar.buy") % Locale.format_number(int(cost["credits"]))
		return
	# Equipar é a ação principal enquanto a arma está guardada; equipada, a principal vira subir o nível.
	_action(row, tr("workshop.remove") if on else tr("hangar.equip"), {}, true, "EquipSecondary", not on,
			func() -> void:
				SaveManager.data["selected"]["secondary"] = "" if on else String(kind)
				SaveManager.save_profile())
	if level < Economy.SECONDARY_MAX_LEVEL:
		var up := _action(row, tr("workshop.evolve"), cost, Economy.can_pay(profile, cost), "UpgradeSecondary", on,
				func() -> void:
					if Economy.upgrade_secondary(SaveManager.data, kind):
						AudioManager.play_ui("kenney_part_clamp")
						SaveManager.save_profile())
		up.tooltip_text = tr("hangar.upgrade_both") % [Locale.format_number(int(cost["credits"])),
				int(cost["orichalcum"])]


func _detail_wing(box: VBoxContainer, profile: Dictionary, entry: Dictionary) -> void:
	var def := _wing_def(String(entry["id"]))
	var id := StringName(String(entry["id"]))
	var chosen: Array = profile["selected"]["wings"]
	text(box, tr(String(def["desc_key"])))
	var stars := int(def["stars"])
	_stat(box, tr("command.power"), "", "+" + Locale.format_number(
			Economy.POWER_WING_BASE + Economy.POWER_WING_PER_STAR * stars))
	if bool(entry["locked"]):
		_status(box, tr("hangar.wing_locked") % [Economy.total_stars(profile), stars], UiTheme.GOLD, &"star")
		return
	var on := bool(entry["selected"])
	var full := not on and chosen.size() >= Economy.MAX_WINGS
	if full:
		_status(box, tr("workshop.slots_full") % [chosen.size(), Economy.MAX_WINGS], SHORT, &"lock")
	var row := _actions(box)
	_action(row, tr("workshop.remove") if on else tr("hangar.equip"), {}, not full, "EquipWing", not on,
			func() -> void:
				Economy.toggle_wing(SaveManager.data, id, DB.rows("wings"))
				SaveManager.save_profile())


func _detail_paint(box: VBoxContainer, _profile: Dictionary, entry: Dictionary) -> void:
	var id := String(entry["id"])
	var def := _cosmetic(id)
	if bool(entry["selected"]):
		_status(box, tr("hangar.equipped"), UiTheme.MINT, &"check")
		return
	if not bool(entry.get("buy", false)):
		var row := _actions(box)
		_action(row, tr("hangar.equip"), {}, true, "EquipPaint", true, func() -> void:
			Store.equip(SaveManager.data, id)
			SaveManager.save_profile())
		return
	# A compra fica na Loja; aqui só o caminho até ela, com o preço à vista.
	if bool(def.get("supporter", false)):
		_status(box, tr("shop.supporter_only"), UiTheme.VIOLET, &"lock")
	elif bool(def.get("season", false)):
		_status(box, tr("shop.season_only"), UiTheme.VIOLET, &"lock")
	var price := {} if int(def.get("pearls", 0)) <= 0 else {"pearls": int(def["pearls"])}
	var row := _actions(box)
	_action(row, tr("workshop.in_shop"), price, true, "GoShop", false, func() -> void: navigate.emit(&"shop"))


func _detail_mode(box: VBoxContainer, profile: Dictionary, entry: Dictionary) -> void:
	var diff := String(entry["id"])
	text(box, tr("difficulty.%s_desc" % diff))
	if String(profile["selected"]["difficulty"]) == diff:
		_status(box, tr("workshop.chosen"), UiTheme.MINT, &"check")
		return
	var row := _actions(box)
	_action(row, tr("workshop.select"), {}, true, "PickDifficulty", true, func() -> void:
		SaveManager.data["selected"]["difficulty"] = diff
		SaveManager.save_profile())


## Linha "rótulo ..... antes → depois" (antes vazio: só o valor novo, em menta).
func _stat(box: VBoxContainer, label: String, before: String, after: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_label := UiTheme.label(label, 11, UiTheme.TEXT_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	if not before.is_empty():
		var a := UiTheme.label(before, 12, UiTheme.WHITE)
		_bold(a)
		row.add_child(a)
		row.add_child(UiTheme.label("→", 12, UiTheme.TEXT_DIM))
	var b := UiTheme.label(after, 12, UiTheme.MINT)
	_bold(b)
	row.add_child(b)
	box.add_child(row)


func _status(box: VBoxContainer, value: String, color: Color, icon_kind: StringName) -> void:
	var row := title_row(box, value, color, 11, icon_kind, color)
	row.name = "Status"


## Quanto falta para pagar `cost` (linha rosa clara), se faltar.
func _short(box: VBoxContainer, profile: Dictionary, cost: Dictionary) -> void:
	var missing: PackedStringArray = []
	for kind: String in cost:
		var gap := int(cost[kind]) - int((profile["wallet"] as Dictionary).get(kind, 0))
		if gap > 0:
			missing.append("%s %s" % [Locale.format_number(gap), tr("currency." + kind)])
	if not missing.is_empty():
		_status(box, tr("workshop.short") % ", ".join(missing), SHORT, &"lock")


## Fileira de ações: lado a lado; empilha quando não cabe (_place_panel).
func _actions(box: VBoxContainer) -> BoxContainer:
	var row := BoxContainer.new()
	row.name = "Actions"
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	return row


## Botão de ação com preço: título e moedas centrados. Ouro (`primary`) ou vidro; sem dinheiro, vira
## vidro com o título claro e o preço que falta em rosa — nunca texto escuro em fundo escuro.
## `gain`: segunda linha menor (o ganho da evolução).
func _action(parent: Container, title: String, cost: Dictionary, enabled: bool, button_name: String, primary: bool,
		on_press: Callable, gain: String = "") -> Button:
	var b := button(parent, "", on_press, enabled, button_name, primary)
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.custom_minimum_size.y = 46.0 if not gain.is_empty() else 40.0
	var lit := primary and enabled
	var ink := UiTheme.GOLD_DARK if lit else UiTheme.WHITE
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(col)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	var head := UiTheme.label(title.to_upper() if primary else title, 12, ink)
	head.name = "Title"
	_bold(head)
	line.add_child(head)
	# Duas moedas: o preço desce para uma segunda linha (o botão cabe ao lado de outro em 270).
	if cost.size() > 1:
		b.custom_minimum_size.y = 46.0
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line = HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 3)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(line)
	for kind: String in cost:
		var mark := glyph(StringName(kind), Color.WHITE, 12)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(mark)
		var paid := Economy.can_pay(SaveManager.data, {kind: cost[kind]})
		var amount := UiTheme.label(Locale.format_number(int(cost[kind])), 13,
				ink if paid else (Color("7a0f22") if lit else SHORT))
		amount.name = "Price_" + kind
		_bold(amount)
		line.add_child(amount)
	if not gain.is_empty():
		var sub := UiTheme.label(gain, 10, Color(UiTheme.GOLD_DARK, 0.85) if lit else UiTheme.TEXT)
		sub.name = "Gain"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.clip_text = true
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(sub)
		b.resized.connect(func() -> void:
			sub.add_theme_font_size_override("font_size", CommandKit.fit_size(sub.get_theme_font("font"), gain,
					b.size.x - 16.0, UiTheme.scaled(10), 7)))
	b.tooltip_text = title
	b.custom_minimum_size.x = col.get_combined_minimum_size().x + 20.0
	return b


## Põe o cartão no rodapé da área de conteúdo (sobre a grade) e abre espaço para rolar até o fim.
func _place_panel() -> void:
	if _panel == null or not _panel.visible or _scroll == null:
		if _spacer != null and is_instance_valid(_spacer):
			_spacer.custom_minimum_size.y = 0.0
		return
	var w := _scroll.size.x - 9.0
	var actions := _panel.find_child("Actions", true, false) as BoxContainer
	if actions != null:
		actions.vertical = false
		actions.vertical = actions.get_combined_minimum_size().x > w - 24.0
	_panel.size = Vector2(w, 0.0)
	var h := _panel.get_combined_minimum_size().y
	_panel.size = Vector2(w, h)
	_panel.position = Vector2(_scroll.position.x + 3.0, floorf(safe.end.y - h - 4.0))
	if _spacer != null and is_instance_valid(_spacer):
		_spacer.custom_minimum_size.y = h + 4.0


## O ladrilho aberto não fica escondido atrás do cartão.
func _reveal_tile() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if _detail.is_empty() or not _panel.visible:
		return
	var tile := _find_key("tile:%s:%s" % [_detail["kind"], _detail["id"]])
	if tile == null:
		return
	var cell := tile.get_parent() as Control
	var top := cell.get_global_rect().position.y
	var bottom := cell.get_global_rect().end.y
	var limit := _panel.get_global_rect().position.y - 6.0
	if bottom > limit:
		_scroll.scroll_vertical += ceili(bottom - limit)
	elif top < _scroll.get_global_rect().position.y:
		_scroll.scroll_vertical -= ceili(_scroll.get_global_rect().position.y - top)


# --- Apoio ----------------------------------------------------------------------------------------

func _find_key(key: String) -> Control:
	if key.is_empty():
		return null
	for node: Node in find_children("*", "Control", true, false):
		if node.has_meta(&"focus_key") and String(node.get_meta(&"focus_key")) == key \
				and not node.is_queued_for_deletion():
			return node as Control
	return null


static func _secondary_cost(level: int) -> Dictionary:
	return {"credits": Economy.SECONDARY_UNLOCK} if level == 0 else Economy.secondary_cost(level)


static func _wing_def(id: String) -> Dictionary:
	for row: Variant in DB.rows("wings"):
		if String((row as Dictionary)["id"]) == id:
			return row
	return {}


static func _cosmetic(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for c: Variant in Store.cosmetics():
		if String((c as Dictionary)["id"]) == id:
			return c
	return {}


## Moldura do encaixe cheio: contorno chanfrado na cor da raridade, brilho no canto e o nível num selo
## escuro embaixo à esquerda (o encaixe do CommandKit desenha o fundo, a colmeia e a figura).
class SlotMark:
	extends Control

	var rarity: int = CommandKit.COMMON
	var level: int = 0

	func _ready() -> void:
		name = "SlotMark"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var color := CommandKit.rarity_color(rarity)
		var rect := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		var cut := minf(9.0, size.x * 0.16)
		var outline := CommandKit.chamfer_points(rect, cut)
		var closed := outline.duplicate()
		closed.append(outline[0])
		var glow := Color(color, 0.2)
		var clear := Color(color, 0.0)
		draw_polygon(outline, PackedColorArray([glow, clear, clear, clear, clear, clear, clear, glow]))
		draw_polyline(closed, Color(color, 0.95), 1.5, true)
		if level <= 0:
			return
		var font := CommandKit.bold(self)
		var fs := UiTheme.scaled(9)
		var text := str(level)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var chip := Rect2(Vector2(1.0, size.y - fs - 5.0), Vector2(tw + 8.0, fs + 4.0))
		var edge := CommandKit.chamfer_points(chip, 3.0, 1.0)
		draw_colored_polygon(edge, Color(UiTheme.ABYSS, 0.92))
		edge.append(edge[0])
		draw_polyline(edge, Color(color, 0.8), 1.0, true)
		draw_string(font, Vector2(chip.position.x + 4.0, chip.end.y - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UiTheme.WHITE)
