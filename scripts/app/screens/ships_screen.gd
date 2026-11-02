class_name ShipsScreen
extends ListScreen
## Coleção de aeronaves (plano mestre 4.2 e 7.2): papel, arma de assinatura, especial, atributos e
## progresso dos fragmentos; uma aeronave aberta pode ser escolhida para a próxima missão.
##
## 1.15 (menus de comando): um palco em cima com a aeronave em foco grande (ShipView, nearest, escala
## inteira) sobre o fundo na cor da raridade, nome em faixa, atributos em pílulas (CommandKit.stat_chip)
## e a ação: "Escolher" em ouro, o selo "Na missão" ou o requisito de quem está fechada (barra dos
## fragmentos e onde caem, ou o final que abre). Embaixo, a grade de ladrilhos (CommandKit.item_tile) com
## raridade por cor, nível, cadeado nas fechadas e a bolinha "!" nas que abriram desde a última visita.
## Tocar num ladrilho só troca o palco; escolher continua sendo um toque explícito.
## O palco lista também os três poderes da aeronave (Corrente, .ai/08-poderes-das-naves.md): ícone, nome,
## nível e a frase do que fazem; o supremo (nível III) em ouro. Só leitura: o foco segue nos ladrilhos e botões.

## Largura mínima de cada coluna da grade (pontos lógicos).
const CELL := 60.0

var _focus_id: String = ""
var _fresh: Array[String] = []
var _shelves: Array[GridContainer] = []
var _refocus: String = ""


func title_key() -> String:
	return "ships.title"


func show_wallet() -> bool:
	return false


func max_width() -> float:
	return 520.0 if NavShell.wide(safe) else MAX_WIDTH


## Abrir a coleção apaga o aviso de aeronave nova da aba (Notices); os ladrilhos das novas guardam a
## bolinha enquanto a tela está aberta, para o jogador achar qual chegou.
func on_show(app: Node) -> void:
	_fresh = Notices.unseen_ships(SaveManager.data)
	if Notices.mark_ships_seen(SaveManager.data):
		SaveManager.save_profile()
	_focus_id = _fresh[0] if not _fresh.is_empty() else ""
	super(app)


func refill() -> void:
	super()
	if not _refocus.is_empty():
		var tile := _list.find_child(_refocus, true, false) as Control
		_refocus = ""
		if tile != null:
			FocusNav.focus(tile)


func _layout() -> void:
	super()
	for shelf: GridContainer in _shelves:
		shelf.columns = _columns()


func _fill() -> void:
	_shelves.clear()
	var profile := SaveManager.data
	var selected := String(profile["selected"]["ship"])
	var defs: Array[Dictionary] = []
	var owned_count := 0
	for row: Variant in DB.rows("ships"):
		var def := row as Dictionary
		if Economy.released(def):
			defs.append(def)
			if _owned(profile, String(def["id"])):
				owned_count += 1
	if defs.filter(func(d: Dictionary) -> bool: return String(d["id"]) == _focus_id).is_empty():
		_focus_id = selected
	for def: Dictionary in defs:
		if String(def["id"]) == _focus_id:
			_stage(profile, def, selected)
	var ribbon := CommandKit.ribbon(tr("ships.collection") % [owned_count, defs.size()])
	ribbon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(ribbon)
	var shelf := GridContainer.new()
	shelf.name = "Collection"
	shelf.columns = _columns()
	shelf.add_theme_constant_override("h_separation", 6)
	shelf.add_theme_constant_override("v_separation", 8)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(shelf)
	_shelves.append(shelf)
	for def: Dictionary in defs:
		_cell(shelf, profile, def, selected)


## Raridade pela origem: as da primeira leva são comuns, as de fragmento caro raras, as do
## pós-lançamento épicas e a do final verdadeiro lendária.
static func ship_rarity(def: Dictionary) -> int:
	if def.has("ending"):
		return CommandKit.LEGENDARY
	if String(def.get("release", "")) == "post":
		return CommandKit.EPIC
	return CommandKit.RARE if int(def.get("fragments", 0)) > 20 else CommandKit.COMMON


static func _owned(profile: Dictionary, id: String) -> bool:
	return (profile["unlocked"]["ships"] as Array).has(id)


func _columns() -> int:
	return clampi(floori((_width + 6.0) / (CELL + 6.0)), 4, 8)


# --- Palco -------------------------------------------------------------------------------------------

func _stage(profile: Dictionary, def: Dictionary, selected: String) -> void:
	var id := String(def["id"])
	var owned := _owned(profile, id)
	var on := owned and id == selected
	var rarity := ship_rarity(def)
	var accent := CommandKit.rarity_color(rarity)
	var level := Economy.ship_level(profile, StringName(id)) if owned else 1
	var stage := PanelContainer.new()
	stage.name = "Stage"
	stage.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := StoreBanner.Backdrop.new()
	back.accent = accent
	back.rays = owned
	back.dim = not owned
	stage.add_child(back)
	var pad := MarginContainer.new()
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 12)
	stage.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)
	var strip := StoreBanner.Strip.new()
	strip.accent = accent if owned else accent.darkened(0.35)
	strip.set_text(tr(String(def["name_key"])))
	col.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var cosmetic := String(profile["selected"].get("cosmetic", "")) if on else ""
	var view := ship_view(ship_tint(id, cosmetic), 2, not owned, level)
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(view)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var tag := badge(_rarity_name(rarity), accent, &"diamond")
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(tag)
	text(info, tr("role." + String(def["role"])), UiTheme.CYAN if owned else UiTheme.TEXT, 13)
	if owned:
		pips(info, level, Economy.SHIP_MAX_LEVEL)
		text(info, tr("hangar.level") % level, UiTheme.GOLD, UiTheme.SMALL_SIZE)
	if on:
		var mark := badge(tr("ships.selected"), UiTheme.MINT, &"check")
		mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		info.add_child(mark)
	col.add_child(_chips(def))
	if def.has("trait"):
		text(col, tr("trait." + String(def["trait"])), UiTheme.TEXT)
	_powers(col, id, owned)
	_stage_action(col, profile, def, owned, on, level)
	_list.add_child(stage)


## Atributos em placas compactas (ícone, nome pequeno em cima e valor em negrito): casco, velocidade,
## cadência, área de acerto, arma e especial. Duas colunas no celular, três no desktop.
func _chips(def: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Stats"
	grid.columns = 3 if NavShell.wide(safe) else 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.add_child(_stat(&"diamond", tr("ships.stat_hull"), str(int(def.get("hull", 3))), UiTheme.MINT))
	grid.add_child(_stat(&"play", tr("ships.stat_speed"), "%d%%" % roundi(float(def.get("speed", 1.0)) * 100.0),
			UiTheme.CYAN))
	grid.add_child(_stat(&"bolt", tr("ships.stat_rate"), "%d%%" % roundi(float(def.get("fire_rate", 1.0)) * 100.0),
			UiTheme.GOLD))
	grid.add_child(_stat(&"ring", tr("ships.stat_hitbox"), String.num(float(def.get("hitbox", 3.0)), 1),
			UiTheme.TEXT_DIM))
	grid.add_child(_stat(&"star", tr("ships.weapon"), tr("weapon." + String(def["signature"])), UiTheme.CYAN))
	grid.add_child(_stat(&"orichalcum", tr("ships.special"), tr("special." + String(def["special"])),
			UiTheme.VIOLET))
	return grid


func _stat(icon_kind: StringName, label: String, value: String, color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := UiTheme.pill_box(color)
	box.bg_color = Color(UiTheme.ABYSS, 0.72)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var g := glyph(icon_kind, color, 13)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(g)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := UiTheme.label(label, 9, UiTheme.TEXT_DIM)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name)
	var number := UiTheme.label(value, UiTheme.FONT_SIZE, UiTheme.WHITE)
	_bold(number)
	number.name = "Value"
	number.clip_text = true
	number.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(number)
	row.add_child(col)
	pill.add_child(row)
	return pill


## Os três poderes da aeronave, um por linha numa placa escura: ícone 24x24 (pixel art, sem filtro), nome em
## negrito com o nível numa pílula e a descrição embaixo. Nada aqui recebe foco.
func _powers(col: VBoxContainer, ship: String, owned: bool) -> void:
	var table := DB.table("powers")
	var panel := PanelContainer.new()
	panel.name = "Powers"
	var box := UiTheme.panel_box(UiTheme.CYAN, 0.55)
	box.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", box)
	col.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	panel.add_child(list)
	var head := UiTheme.label(tr("power.list"), UiTheme.SMALL_SIZE, UiTheme.CYAN if owned else UiTheme.TEXT_DIM)
	_bold(head)
	list.add_child(head)
	for tier: int in [1, 2, 3]:
		var def: Dictionary = table.get(StringName("%s_%d" % [ship, tier]), {})
		if def.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var icon := TextureRect.new()
		icon.texture = SpriteBank.texture(String(def.get("icon", "")))
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not owned:
			icon.modulate = Color(0.6, 0.65, 0.75, 0.6)
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var supreme := tier >= 3
		var name_color := (UiTheme.GOLD if supreme else UiTheme.WHITE) if owned else UiTheme.TEXT
		var title := title_row(info, tr(String(def.get("name_key", ""))), name_color, 12)
		title.add_child(badge(tr("power.tier") % tier, UiTheme.GOLD if supreme else UiTheme.CYAN))
		text(info, tr(String(def.get("desc_key", ""))), UiTheme.TEXT_DIM, UiTheme.SMALL_SIZE)


func _stage_action(col: VBoxContainer, profile: Dictionary, def: Dictionary, owned: bool, on: bool,
		level: int) -> void:
	var id := String(def["id"])
	if owned:
		if not on:
			var pick := button(col, tr("ships.select") + " · " + tr("hangar.level") % level, func() -> void:
				SaveManager.data["selected"]["ship"] = id
				AudioManager.play_ui("kenney_ui_confirm")
				SaveManager.save_profile(), true, "Select_" + id, true)
			pick.custom_minimum_size.y = 42.0
		return
	if def.has("ending"):
		var lock := title_row(col, tr("ships.ending_unlock") % tr("ending." + String(def["ending"])), UiTheme.VIOLET,
				UiTheme.FONT_SIZE, &"lock", UiTheme.VIOLET)
		lock.name = "Requirement"
		return
	var have := int((profile["hangar"]["fragments"] as Dictionary).get(id, 0))
	var sources := PackedStringArray()
	for m: Variant in def.get("sources", []):
		sources.append(MapScreen.node_label(Economy.node(StringName(String(m)))))
	bar(col, float(have), float(int(def["fragments"])), UiTheme.CORAL)
	var need := title_row(col, tr("ships.fragments") % [have, int(def["fragments"]), ", ".join(sources)],
			Color("ff8fa3"), UiTheme.FONT_SIZE, &"lock", Color("ff8fa3"))
	need.name = "Requirement"


# --- Grade -------------------------------------------------------------------------------------------

func _cell(shelf: GridContainer, profile: Dictionary, def: Dictionary, selected: String) -> void:
	var id := String(def["id"])
	var owned := _owned(profile, id)
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf.add_child(cell)
	var tile := CommandKit.item_tile(ShipIcon.texture(ship_tint(id) if owned else Color.WHITE),
			Economy.ship_level(profile, StringName(id)) if owned else 0, ship_rarity(def), _fresh.has(id))
	tile.name = "Ship_" + id
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.selected = id == _focus_id
	tile.locked = not owned
	tile.tooltip_text = tr(String(def["name_key"]))
	tile.pressed.connect(func() -> void:
		if _focus_id == id:
			return
		AudioManager.play_ui("kenney_ui_tab")
		_focus_id = id
		_fresh.erase(id)
		_refocus = "Ship_" + id if FocusNav.pad else ""
		_scroll.scroll_vertical = 0 if not FocusNav.pad else _scroll.scroll_vertical
		refill())
	cell.add_child(tile)
	if owned and id == selected:
		var mark := CommandKit.glyph(&"check", UiTheme.MINT, 11)
		mark.position = Vector2(4, 3)
		tile.add_child(mark)
	var name := UiTheme.label(tr(String(def["name_key"])), UiTheme.SMALL_SIZE,
			UiTheme.WHITE if owned else UiTheme.TEXT_DIM)
	_bold(name)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.add_child(name)


func _rarity_name(rarity: int) -> String:
	return [tr("store.rarity_common"), tr("store.rarity_rare"), tr("store.rarity_epic"),
			tr("store.rarity_legendary")][clampi(rarity, 0, 3)]
