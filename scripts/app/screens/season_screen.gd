class_name SeasonScreen
extends ListScreen
## Passe de temporada (Season): nível atual, recompensas grátis de cada nível alcançado e a trilha
## "Maré Dourada" com 3 pinturas (compra simulada até a Fase 4 ligar o Play Billing).


func title_key() -> String:
	return "season.title"


func show_wallet() -> bool:
	return true


func _fill() -> void:
	var profile := SaveManager.data
	var date := App.today()
	var s := Season.state(profile, date)
	var tier := Season.tier(profile, date)
	add_heading(tr("season.header") % [Season.id_for(date), tier, Season.TIERS])
	add_text(tr("season.xp") % [int(s["xp"]) % Season.XP_PER_TIER, Season.XP_PER_TIER], UiTheme.TEXT_DIM)
	if bool(s["premium"]):
		var got := Season.claim_premium(profile, date)
		if not got.is_empty():
			SaveManager.save_profile()
		add_text("◆ " + tr("season.gold_owned"), UiTheme.GOLD)
	elif Store.simulated():
		add_button(tr("season.gold_buy"), func() -> void:
			Season.buy_premium(SaveManager.data, date)
			SaveManager.save_profile(), true, "SeasonGold")
	for level: int in range(1, Season.TIERS + 1):
		var reward := Season.free_reward(level)
		var text := tr("season.tier") % [level, HubScreen.reward_text(reward)]
		if Season.PREMIUM_COSMETICS.has(level):
			text += " · " + tr("cosmetic." + String(Season.PREMIUM_COSMETICS[level]))
		if (s["claimed"] as Array).has(level):
			add_text("◆ " + text, UiTheme.GOLD)
		elif level <= tier:
			add_button(text, func() -> void:
				Season.claim(SaveManager.data, date, level)
				SaveManager.save_profile(), true, "Tier_%d" % level)
		else:
			add_text("◇ " + text, UiTheme.TEXT_DIM)
