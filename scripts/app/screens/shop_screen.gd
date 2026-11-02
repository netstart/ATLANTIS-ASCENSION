class_name ShopScreen
extends ListScreen
## Loja (plano mestre 17): baú grátis a cada 6 h (em dobro com anúncio opcional), cosméticos por
## Pérolas e a compra única "Apoiar". Nada de poder à venda, nada de energia, de baú pago aleatório ou de
## urgência falsa. Pagamento e anúncio são simulados até a Fase 4 (Store.simulated); uma tira discreta
## avisa isso para ninguém achar que pagou de verdade. Steam: sem anúncio e sem a sub-aba Apoio.
##
## 1.15 (menus de comando): sub-abas em pílula no topo (Baú | Pinturas | Apoio, PillTabs), o baú num
## cartão-destaque com o Duarte em pixel art ampliado (StoreBanner), seções em faixa chevron e as
## pinturas numa grade de ladrilhos (CommandKit.item_tile) com a raridade na cor da moldura e o estado
## sempre legível embaixo (Equipada, Possuída, preço em pérolas, quanto falta). Tocar num ladrilho abre o
## painel de detalhe (CommandSheet) com a prévia da própria nave pintada e a ação: Comprar ou Equipar.

const TAB_CHEST := &"chest"
const TAB_PAINTS := &"paints"
const TAB_SUPPORT := &"support"
## Largura mínima de cada coluna da grade de pinturas (pontos lógicos).
const CELL := 76.0
## Preço que ainda não dá: coral claro (lê bem sobre o vidro escuro).
const SHORT_COLOR := Color("ff8fa3")

var _tab: StringName = TAB_CHEST
var _tabs: PillTabs
var _sheet: CommandSheet
var _sheet_id: String = ""
var _shelves: Array[GridContainer] = []


func title_key() -> String:
	return "hub.tab_shop"


func show_wallet() -> bool:
	return true


## No desktop (casca larga) a vitrine abre até perto da largura das barras.
func max_width() -> float:
	return 540.0 if NavShell.wide(safe) else 420.0


func _build() -> void:
	super()
	_tabs = PillTabs.new()
	_tabs.changed.connect(func(id: StringName) -> void:
		_tab = id
		_scroll.scroll_vertical = 0
		refill())
	add_child(_tabs)
	_sheet = CommandSheet.new()
	_sheet.closed.connect(_on_sheet_closed)
	add_child(_sheet)


func on_show(app: Node) -> void:
	_sheet.visible = false
	_sheet_id = ""
	super(app)


func refresh_texts() -> void:
	if _tabs != null:
		_set_tabs()
	super()


func back() -> bool:
	if _sheet.is_open():
		_sheet.close()
		return true
	return super()


func layout_controls() -> Array[Control]:
	var out := super()
	if _sheet != null and _sheet.is_open():
		return _sheet.controls()
	if _tabs != null:
		out.append_array(_tabs.buttons())
	return out


func default_focus() -> Control:
	if _sheet.is_open():
		return FocusNav.first(_sheet)
	return super()


## Sub-abas fixas logo abaixo da faixa do título; a lista começa embaixo delas.
func _layout() -> void:
	super()
	if _tabs == null:
		return
	var y := (_ribbon.position.y + _ribbon.size.y if in_shell() else _scroll.position.y) + 6.0
	_tabs.position = Vector2(_scroll.position.x + 3.0, y)
	_tabs.size = Vector2(_width, UiTheme.TOUCH_MIN)
	var list_y := y + UiTheme.TOUCH_MIN + 4.0
	_scroll.position.y = list_y
	_scroll.size.y = maxf(0.0, safe.end.y - list_y)
	for shelf: GridContainer in _shelves:
		shelf.columns = _columns()
	_sheet.position = Vector2.ZERO
	_sheet.size = size
	_sheet.place(safe)


func _set_tabs() -> void:
	var profile := SaveManager.data
	var items: Array[Dictionary] = [
		{"id": TAB_CHEST, "text": tr("store.tab_chest"),
				"notice": Notices.free_chest_ready(profile, int(Time.get_unix_time_from_system()))},
		{"id": TAB_PAINTS, "text": tr("store.tab_paints")}]
	if _support_visible(profile):
		items.append({"id": TAB_SUPPORT, "text": tr("store.tab_support")})
	elif _tab == TAB_SUPPORT:
		_tab = TAB_CHEST
	_tabs.set_tabs(items, _tab)


func _fill() -> void:
	_shelves.clear()
	var profile := SaveManager.data
	var now := int(Time.get_unix_time_from_system())
	_tabs.set_notice(TAB_CHEST, Notices.free_chest_ready(profile, now))
	if Store.simulated():
		_test_strip()
	match _tab:
		TAB_PAINTS:
			_fill_paints(profile, false)
		TAB_SUPPORT:
			_fill_support(profile)
		_:
			_fill_chest(profile, now)
			_fill_paints(profile, true)


# --- Baú ---------------------------------------------------------------------------------------------

func _fill_chest(profile: Dictionary, now: int) -> void:
	var banner := StoreBanner.new(UiTheme.GOLD, tr("shop.chest"), "duarte", "smile")
	_list.add_child(banner)
	var wait := LiveOps.chest_wait(profile, now)
	for kind: String in ["credits", "pearls"]:
		banner.body.add_child(_reward(kind, int(LiveOps.CHEST_REWARD[kind])))
	text(banner.body, tr("store.chest_every") % (LiveOps.CHEST_SECONDS / 3600), UiTheme.TEXT, UiTheme.SMALL_SIZE)
	if wait > 0:
		var span := float(LiveOps.CHEST_SECONDS)
		bar(banner.actions, span - float(wait), span, UiTheme.GOLD)
		var left := text(banner.actions, tr("shop.chest_wait") % [wait / 3600, (wait % 3600) / 60], UiTheme.WHITE)
		left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var ready := badge(tr("store.chest_ready"), UiTheme.MINT, &"check")
	ready.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	banner.body.add_child(ready)
	var open := button(banner.actions, tr("shop.chest_open"), func() -> void:
		LiveOps.open_chest(SaveManager.data, now)
		AudioManager.play_ui("kenney_ui_confirm")
		SaveManager.save_profile(), true, "Chest", true)
	open.custom_minimum_size.y = 44.0
	if Store.ads_allowed(profile):
		button(banner.actions, tr("shop.chest_double"), func() -> void:
			Ads.show_rewarded(SaveManager.data, func(granted: bool) -> void:
				if granted:
					LiveOps.open_chest(SaveManager.data, now, 2)
					SaveManager.save_profile()
					refill()), true, "ChestAd")


## Linha "moeda +N" do conteúdo do baú (ícone grande, número branco em negrito).
func _reward(kind: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.tooltip_text = tr("currency." + kind)
	row.add_child(glyph(StringName(kind), Color.WHITE, 16))
	var value := UiTheme.label("+" + Locale.format_number(amount), 15, UiTheme.WHITE)
	_bold(value)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	return row


# --- Pinturas ----------------------------------------------------------------------------------------

## Grade de pinturas. `featured`: só uma fileira das que ainda dá para comprar, com "Ver todas".
func _fill_paints(profile: Dictionary, featured: bool) -> void:
	var paints := _paints(profile)
	if featured:
		paints = paints.filter(func(p: Dictionary) -> bool: return not bool(p["owned"]) and not bool(p["rare"]))
		if paints.is_empty():
			return
		paints = paints.slice(0, _columns())
		_list.add_child(_section(tr("shop.cosmetics")))
	var shelf := GridContainer.new()
	shelf.name = "Paints"
	shelf.columns = _columns()
	shelf.add_theme_constant_override("h_separation", 6)
	shelf.add_theme_constant_override("v_separation", 10)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(shelf)
	_shelves.append(shelf)
	for p: Dictionary in paints:
		_paint_cell(shelf, p, profile)
	if featured:
		button(_list, tr("store.see_all"), func() -> void: _tabs.button(TAB_PAINTS).pressed.emit(), true, "SeeAll")


## Pinturas na ordem da vitrine: a original, as de pérolas e por fim as raras. As raras que não se
## compram (apoiador, passe) só aparecem se a conta já tem ou se o build tem compra com dinheiro.
func _paints(profile: Dictionary) -> Array[Dictionary]:
	var equipped := String(profile["selected"].get("cosmetic", ""))
	var ship := String(profile["selected"]["ship"])
	var out: Array[Dictionary] = [{"id": "", "name": tr("shop.default_paint"), "tint": ship_tint(ship),
			"rarity": CommandKit.COMMON, "owned": true, "equipped": equipped.is_empty(), "rare": false, "price": 0,
			"how": ""}]
	for c: Variant in Store.cosmetics():
		var def := c as Dictionary
		var id := String(def["id"])
		var owned := Store.owned(profile, id)
		var rare := bool(def.get("supporter", false)) or bool(def.get("season", false))
		if rare and not owned and not Store.purchases_enabled():
			continue  # Sem compra com dinheiro (release sem Play Billing): pintura impossível de obter não aparece.
		out.append({"id": id, "name": tr("cosmetic." + id), "tint": Color(String(def.get("color", "#ffffff"))),
				"rarity": paint_rarity(def), "owned": owned, "equipped": owned and equipped == id, "rare": rare,
				"price": int(def.get("pearls", 0)), "how": tr("shop.supporter_only")
						if bool(def.get("supporter", false)) else tr("shop.season_only")})
	return out


## Raridade pela origem e pelo preço: as de apoiador e do passe são lendárias; as de pérolas sobem com o
## preço (até 40 comum, 60 rara, 90 ou mais épica).
static func paint_rarity(def: Dictionary) -> int:
	if bool(def.get("supporter", false)) or bool(def.get("season", false)):
		return CommandKit.LEGENDARY
	var price := int(def.get("pearls", 0))
	if price >= 90:
		return CommandKit.EPIC
	return CommandKit.RARE if price >= 60 else CommandKit.COMMON


## Ladrilho da pintura (a nave pintada), o nome e o estado embaixo, sempre em cor clara.
func _paint_cell(shelf: GridContainer, p: Dictionary, profile: Dictionary) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 3)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf.add_child(cell)
	var id := String(p["id"])
	var tile := CommandKit.item_tile(ShipIcon.texture(p["tint"]), 0, int(p["rarity"]))
	tile.name = "Paint_" + (id if not id.is_empty() else "default")
	tile.custom_minimum_size = Vector2(CommandKit.TILE, 64.0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.selected = bool(p["equipped"])
	tile.locked = bool(p["rare"]) and not bool(p["owned"])
	tile.tooltip_text = String(p["name"])
	tile.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_click")
		_open(id))
	cell.add_child(tile)
	var name := UiTheme.label(String(p["name"]), UiTheme.SMALL_SIZE, UiTheme.WHITE, true)
	_bold(name)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(name)
	cell.add_child(_state_row(p, profile))


## Estado do ladrilho: Equipada (menta), Possuída, origem da rara (violeta) ou o preço com a pérola
## (branco; coral claro quando ainda não dá).
func _state_row(p: Dictionary, profile: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "State"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	var color := UiTheme.TEXT
	var value := ""
	var kind := &""
	if bool(p["equipped"]):
		color = UiTheme.MINT
		value = tr("hangar.equipped")
		kind = &"check"
	elif bool(p["owned"]):
		value = tr("store.owned")
	elif bool(p["rare"]):
		color = UiTheme.VIOLET
		value = String(p["how"])
		kind = &"lock"
	else:
		var price := int(p["price"])
		color = UiTheme.WHITE if price <= int(profile["wallet"]["pearls"]) else SHORT_COLOR
		value = Locale.format_number(price)
		kind = &"pearls"
	if kind != &"":
		var g := glyph(kind, Color.WHITE if kind == &"pearls" else color, 11)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(g)
	var l := UiTheme.label(value, UiTheme.SMALL_SIZE, color, kind == &"lock")
	_bold(l)
	l.name = "StateText"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if kind == &"lock":
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _columns() -> int:
	return clampi(floori((_width + 6.0) / (CELL + 6.0)), 3, 6)


# --- Detalhe da pintura ------------------------------------------------------------------------------

func _open(id: String) -> void:
	_sheet_id = id
	_show_sheet()


func _show_sheet() -> void:
	var profile := SaveManager.data
	var p: Dictionary = {}
	for each: Dictionary in _paints(profile):
		if String(each["id"]) == _sheet_id:
			p = each
	if p.is_empty():
		_sheet.close()
		return
	var accent := CommandKit.rarity_color(int(p["rarity"]))
	var box := _sheet.open(String(p["name"]), accent)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(badge(_rarity_name(int(p["rarity"])), accent, &"diamond"))
	box.add_child(head)
	var ship := StringName(String(profile["selected"]["ship"]))
	box.add_child(ship_view(p["tint"], 2, false, Economy.ship_level(profile, ship)))
	var hint := text(box, tr("store.preview"), UiTheme.TEXT_DIM, UiTheme.SMALL_SIZE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var main: Button = null
	var id := _sheet_id
	# Ações numa linha: Fechar à esquerda, a ação principal (larga) à direita.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if bool(p["equipped"]):
		var on := badge(tr("hangar.equipped"), UiTheme.MINT, &"check")
		on.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(on)
	elif bool(p["owned"]):
		main = _sheet_button(row, tr("hangar.equip"), func() -> void: Store.equip(SaveManager.data, id),
				"Equip_" + (id if not id.is_empty() else "default"), true)
	elif bool(p["rare"]):
		var how := text(box, String(p["how"]), UiTheme.VIOLET)
		how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		main = _buy_button(box, row, p, profile)
	box.add_child(row)
	var close := _sheet_button(row, tr("store.close"), _sheet.close, "Close", false)
	row.move_child(close, 0)
	if FocusNav.pad:
		FocusNav.focus(main if main != null and not main.disabled else close)


## Botão de compra: ouro com "Comprar", a pérola e o preço. Sem pérolas suficientes vira vidro com filete
## dourado e o texto continua claro (ouro sobre azul escuro), com "Faltam N" logo acima.
func _buy_button(box: VBoxContainer, row_box: HBoxContainer, p: Dictionary, profile: Dictionary) -> Button:
	var price := int(p["price"])
	var short := price - int(profile["wallet"]["pearls"])
	if short > 0:
		var miss := text(box, tr("store.short") % Locale.format_number(short), SHORT_COLOR)
		miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var id := String(p["id"])
	var b := _sheet_button(row_box, "", func() -> void:
		if Store.buy(SaveManager.data, id):
			AudioManager.play_ui("kenney_ui_confirm"), "Buy_" + id, true)
	b.disabled = short > 0
	b.tooltip_text = tr("shop.buy") % [String(p["name"]), price]
	var ink := UiTheme.GOLD_DARK if short <= 0 else UiTheme.GOLD
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var word := UiTheme.label(tr("store.buy"), 14, ink)
	_bold(word)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(word)
	var mark := glyph(&"pearls", Color.WHITE, 15)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var value := UiTheme.label(Locale.format_number(price), 14, ink)
	_bold(value)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	b.add_child(row)
	b.custom_minimum_size = Vector2(row.get_combined_minimum_size().x + 20.0, 44.0)
	return b


## Botão do painel: roda a ação, grava, remonta a tela e o próprio painel (Comprar vira Equipar).
func _sheet_button(box: Container, value: String, action: Callable, button_name: String,
		primary: bool) -> Button:
	var b := Button.new()
	b.name = button_name
	b.text = value
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 1.6 if primary else 1.0
	if primary:
		UiTheme.style_primary(b, 14)
		b.custom_minimum_size.y = 44.0
	b.pressed.connect(func() -> void:
		if button_name == "Close":
			action.call()
			return
		AudioManager.play_ui("kenney_ui_click")
		action.call()
		SaveManager.save_profile()
		refill()
		_show_sheet())
	box.add_child(b)
	return b


func _on_sheet_closed() -> void:
	var tile := _list.find_child("Paint_" + (_sheet_id if not _sheet_id.is_empty() else "default"), true, false)
	_sheet_id = ""
	if tile != null and FocusNav.pad:
		FocusNav.focus(tile as Control)


func _rarity_name(rarity: int) -> String:
	return [tr("store.rarity_common"), tr("store.rarity_rare"), tr("store.rarity_epic"),
			tr("store.rarity_legendary")][clampi(rarity, 0, 3)]


# --- Apoio -------------------------------------------------------------------------------------------

static func _support_visible(profile: Dictionary) -> bool:
	return Store.purchases_enabled() or bool(profile["purchases"].get("supporter", false))


## "Apoiar": compra única, preço e efeito ditos às claras (sem pacote, sem porcentagem, sem relógio).
func _fill_support(profile: Dictionary) -> void:
	var banner := StoreBanner.new(UiTheme.VIOLET, tr("shop.support"), "thalassa", "smile")
	_list.add_child(banner)
	text(banner.body, tr("shop.support_desc"), UiTheme.WHITE)
	var gift := HBoxContainer.new()
	gift.add_theme_constant_override("separation", 6)
	var swatch := CommandKit.item_tile(ShipIcon.texture(Color(Store.tint_of("tint_supporter"))), 0,
			CommandKit.LEGENDARY)
	swatch.focus_mode = Control.FOCUS_NONE
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(44, 44)
	gift.add_child(swatch)
	var gift_name := UiTheme.label(tr("cosmetic.tint_supporter"), UiTheme.SMALL_SIZE, UiTheme.GOLD, true)
	_bold(gift_name)
	gift_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gift.add_child(gift_name)
	banner.body.add_child(gift)
	if bool(profile["purchases"].get("supporter", false)):
		var thanks := badge(tr("shop.support_thanks"), UiTheme.MINT, &"check")
		thanks.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		banner.actions.add_child(thanks)
		return
	button(banner.actions, tr("shop.support_buy"), func() -> void:
		if Store.support(SaveManager.data):
			SaveManager.save_profile(), Store.simulated(), "Support", true)
	var honest := text(banner.actions, tr("store.support_note"), UiTheme.TEXT, UiTheme.SMALL_SIZE)
	honest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# --- Peças -------------------------------------------------------------------------------------------

## Faixa de seção em chevron (CommandKit.ribbon) dentro da lista.
func _section(value: String) -> Control:
	var r := CommandKit.ribbon(value)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


## Tira discreta da versão de teste (o texto completo fica no balão de ajuda).
func _test_strip() -> void:
	var strip := PanelContainer.new()
	strip.name = "TestStrip"
	var box := UiTheme.chamfer(Color(UiTheme.CORAL, 0.08), Color(UiTheme.CORAL, 0.35), 1, 4)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	box.content_margin_left = 8
	box.content_margin_right = 8
	strip.add_theme_stylebox_override("panel", box)
	strip.tooltip_text = tr("shop.simulated")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := glyph(&"diamond", UiTheme.CORAL, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var l := UiTheme.label(tr("store.test_strip"), UiTheme.SMALL_SIZE, Color("ffb3c0"), true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	strip.add_child(row)
	_list.add_child(strip)
