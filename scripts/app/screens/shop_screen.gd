class_name ShopScreen
extends ListScreen
## Loja (plano mestre 17): baú grátis a cada 6 h (em dobro com anúncio opcional), cosméticos por
## Pérolas e a compra única "Apoiar". Nada de poder à venda. Pagamento e anúncio são simulados até a
## Fase 4 (Store.simulated); a tela avisa isso para ninguém achar que pagou de verdade.
##
## Clima dourado (o App liga o humor "gold" do fundo): o baú é o cartão de destaque, as pinturas são
## uma vitrine em duas colunas com a própria aeronave pintada, e o preço é o botão de ouro com o ícone
## da pérola. Pintura que não se compra (do apoiador, do passe) é rara: borda violeta e cadeado.


func title_key() -> String:
	return "hub.tab_shop"


func show_wallet() -> bool:
	return true


func max_width() -> float:
	return 420.0


func _fill() -> void:
	var profile := SaveManager.data
	var now := int(Time.get_unix_time_from_system())
	if Store.simulated():
		var note := card(UiTheme.CORAL, null, 0.7)
		text(note, tr("shop.simulated"), UiTheme.CORAL, UiTheme.SMALL_SIZE)
	_fill_chest(profile, now)
	_fill_paints(profile)
	if Store.purchases_enabled() or bool(profile["purchases"].get("supporter", false)):
		add_heading(tr("shop.support"))
		var box := card(UiTheme.GOLD)
		text(box, tr("shop.support_desc"), UiTheme.TEXT)
		if bool(profile["purchases"].get("supporter", false)):
			var thanks := badge(tr("shop.support_thanks"), UiTheme.MINT, &"check")
			thanks.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			box.add_child(thanks)
		else:
			button(box, tr("shop.support_buy"), func() -> void:
				if Store.support(SaveManager.data):
					SaveManager.save_profile(), Store.simulated(), "Support", true)


func _fill_chest(profile: Dictionary, now: int) -> void:
	var box := card(UiTheme.GOLD)
	var head := title_row(box, tr("shop.chest"), UiTheme.GOLD, 16, &"star", UiTheme.GOLD)
	head.add_theme_constant_override("separation", 8)
	var wait := LiveOps.chest_wait(profile, now)
	if wait > 0:
		var span := float(LiveOps.CHEST_SECONDS)
		bar(box, span - float(wait), span, UiTheme.GOLD)
		text(box, tr("shop.chest_wait") % [wait / 3600, (wait % 3600) / 60])
		return
	button(box, tr("shop.chest_open"), func() -> void:
		LiveOps.open_chest(SaveManager.data, now)
		SaveManager.save_profile(), true, "Chest", true)
	if Store.ads_allowed(profile):
		button(box, tr("shop.chest_double"), func() -> void:
			Ads.show_rewarded(SaveManager.data, func(granted: bool) -> void:
				if granted:
					LiveOps.open_chest(SaveManager.data, now, 2)
					SaveManager.save_profile()
					refill()), true, "ChestAd")


func _fill_paints(profile: Dictionary) -> void:
	add_heading(tr("shop.cosmetics"))
	var equipped := String(profile["selected"].get("cosmetic", ""))
	var ship := String(profile["selected"]["ship"])
	var shelf := grid()
	_paint(shelf, "", tr("shop.default_paint"), ship_tint(ship), equipped.is_empty())
	for c: Variant in Store.cosmetics():
		var def := c as Dictionary
		var id := String(def["id"])
		var name := tr("cosmetic." + id)
		var tint := Color(String(def.get("color", "#ffffff")))
		if Store.owned(profile, id):
			_paint(shelf, id, name, tint, equipped == id)
			continue
		var rare := bool(def.get("supporter", false)) or bool(def.get("season", false))
		if rare and not Store.purchases_enabled():
			continue  # Sem compra com dinheiro (release sem Play Billing): pintura impossível de obter não aparece.
		var box := _tile(shelf, name, tint, UiTheme.VIOLET if rare else UiTheme.GOLD, rare)
		if rare:
			var how := tr("shop.supporter_only") if bool(def.get("supporter", false)) else tr("shop.season_only")
			var row := title_row(box, how, UiTheme.VIOLET, UiTheme.SMALL_SIZE, &"lock", UiTheme.VIOLET)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			continue
		var price := int(def["pearls"])
		price_button(box, price, "pearls", func() -> void:
			if Store.buy(SaveManager.data, id):
				AudioManager.play_ui("kenney_ui_confirm")
				SaveManager.save_profile(), Economy.can_pay(profile, {"pearls": price}), "Buy_" + id,
				tr("shop.buy") % [name, price])


## Pintura já da conta: equipada leva o selo menta; senão, "Equipar" em ouro (a ação do cartão).
func _paint(shelf: GridContainer, id: String, name: String, tint: Color, on: bool) -> void:
	var box := _tile(shelf, name, tint, UiTheme.MINT if on else UiTheme.CYAN, false)
	if on:
		var mark := badge(tr("hangar.equipped"), UiTheme.MINT, &"check")
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(mark)
		return
	button(box, tr("hangar.equip"), func() -> void:
		Store.equip(SaveManager.data, id)
		SaveManager.save_profile(), true, "Equip_" + id if not id.is_empty() else "", true)


## Ladrilho da vitrine: a aeronave na pintura, o nome centrado e espaço para a ação.
func _tile(shelf: GridContainer, name: String, tint: Color, accent: Color, dim: bool) -> VBoxContainer:
	var box := card(accent, shelf, 0.7 if dim else 0.84)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(box.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A pintura aparece na nave do jogador como ela está hoje (peças do nível do hangar).
	var selected := StringName(String(SaveManager.data["selected"]["ship"]))
	var view := ship_view(tint, 1, false, Economy.ship_level(SaveManager.data, selected))
	if dim:
		view.modulate = Color(1, 1, 1, 0.55)
	box.add_child(view)
	var l := UiTheme.label(name, 13, UiTheme.WHITE if not dim else UiTheme.TEXT, true)
	_bold(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box
