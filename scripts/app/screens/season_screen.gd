class_name SeasonScreen
extends ListScreen
## Passe de temporada (Season): nível atual, recompensas grátis de cada nível alcançado e a trilha
## "Maré Dourada" com 3 pinturas (compra real pelo IAP season_gold, como a Loja; preço da Play quando houver).
##
## Topo: cartão com o nível e a barra de XP. A trilha dourada tem cartão próprio (ouro). Os níveis
## formam uma trilha de linhas: resgatado com visto menta, pronto para resgatar com "Resgatar" em ouro,
## futuro apagado com cadeado; nível com pintura premium ganha um selo violeta (raro).


func title_key() -> String:
	return "season.title"


func show_wallet() -> bool:
	return true


func _fill() -> void:
	var profile := SaveManager.data
	var date := App.today()
	var s := Season.state(profile, date)
	var tier := Season.tier(profile, date)
	var top := card()
	title_row(top, tr("season.header") % [Season.id_for(date), tier, Season.TIERS], UiTheme.WHITE, 14)
	bar(top, float(int(s["xp"]) % Season.XP_PER_TIER), float(Season.XP_PER_TIER), UiTheme.GOLD)
	text(top, tr("season.xp") % [int(s["xp"]) % Season.XP_PER_TIER, Season.XP_PER_TIER])
	if bool(s["premium"]):
		var got := Season.claim_premium(profile, date)
		if not got.is_empty():
			SaveManager.save_profile()
		var gold := card(UiTheme.GOLD)
		title_row(gold, tr("season.gold_owned"), UiTheme.GOLD, 13, &"check", UiTheme.GOLD)
	elif Iap.visible(profile, Iap.SEASON_GOLD):
		_gold_offer()
	var track := card(UiTheme.CYAN, null, 0.78)
	track.add_theme_constant_override("separation", 6)
	for level: int in range(1, Season.TIERS + 1):
		var claimed := (s["claimed"] as Array).has(level)
		var ready := not claimed and level <= tier
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 22)
		var mark := glyph(&"check" if claimed else (&"diamond" if ready else &"lock"),
				UiTheme.MINT if claimed else (UiTheme.GOLD if ready else Color(UiTheme.TEXT_DIM, 0.6)), 12)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var line := UiTheme.label(tr("season.tier") % [level, HubScreen.reward_text(Season.free_reward(level))],
				UiTheme.FONT_SIZE, UiTheme.TEXT if level <= tier else UiTheme.TEXT_DIM, true)
		col.add_child(line)
		if Season.PREMIUM_COSMETICS.has(level):
			var rare := badge(tr("cosmetic." + String(Season.PREMIUM_COSMETICS[level])), UiTheme.VIOLET, &"star")
			rare.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			col.add_child(rare)
		row.add_child(col)
		if ready:
			var b := button(row, tr("events.claim"), func() -> void:
				Season.claim(SaveManager.data, date, level)
				SaveManager.save_profile(), true, "Tier_%d" % level, true)
			b.size_flags_horizontal = Control.SIZE_SHRINK_END
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.autowrap_mode = TextServer.AUTOWRAP_OFF
		track.add_child(row)


## Cartão da trilha dourada à venda (IAP season_gold, como a Loja): o que dá (só as 3 pinturas da trilha), o
## estado da Play (abrindo, pendente, erro) e o botão com o preço quando houver. Refaz quando a Play responde.
func _gold_offer() -> void:
	Iap.on_changed(refill)
	var gold := card(UiTheme.GOLD)
	title_row(gold, tr("season.gold_buy"), UiTheme.GOLD, 13, &"star", UiTheme.GOLD)
	text(gold, tr("store.season_desc"), UiTheme.WHITE)
	var status := Iap.status(Iap.SEASON_GOLD)
	var waiting := status == "busy" or status == "pending"
	if not status.is_empty():
		var says := {"busy": tr("store.turbo_busy"), "pending": tr("store.pending"),
				"canceled": tr("store.turbo_canceled"), "unavailable": tr("store.turbo_unavailable")}
		var line := text(gold, String(says.get(status, tr("store.turbo_failed"))),
				UiTheme.GOLD if waiting else UiTheme.CORAL, UiTheme.SMALL_SIZE)
		line.name = "SeasonGoldStatus"
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var price := Iap.price(Iap.SEASON_GOLD)
	button(gold, tr("store.buy_price") % price if not price.is_empty() else tr("store.buy_money"), func() -> void:
		if Iap.buy(SaveManager.data, Iap.SEASON_GOLD):
			AudioManager.play_ui("kenney_ui_confirm")
			SaveManager.save_profile(), not waiting, "SeasonGold", true)
