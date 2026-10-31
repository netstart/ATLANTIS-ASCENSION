class_name SeasonScreen
extends ListScreen
## Passe de temporada (Season): nível atual, recompensas grátis de cada nível alcançado e a trilha
## "Maré Dourada" com 3 pinturas (compra simulada até a Fase 4 ligar o Play Billing).
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
	elif Store.simulated():
		var gold := card(UiTheme.GOLD)
		button(gold, tr("season.gold_buy"), func() -> void:
			Season.buy_premium(SaveManager.data, date)
			SaveManager.save_profile(), true, "SeasonGold", true)
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
