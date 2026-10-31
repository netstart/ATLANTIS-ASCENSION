class_name HangarScreen
extends ListScreen
## Oficina do hangar (plano mestre 4.9 e 7.2): nível da aeronave, arma secundária, asas e dificuldade.
## Toda regra vem da Economy; a tela só mostra e chama.


func title_key() -> String:
	return "hangar.title"


func show_wallet() -> bool:
	return true


func _fill() -> void:
	var profile := SaveManager.data
	var ship := StringName(String(profile["selected"]["ship"]))
	var level := Economy.ship_level(profile, ship)
	var bonus := Economy.ship_bonus(level)
	add_heading("%s · %s" % [tr("ship." + String(ship)), tr("hangar.level") % level])
	add_text(tr("hangar.bonus") % [roundi(float(bonus["damage"]) * 100.0), int(bonus["hull"])], UiTheme.TEXT_DIM)
	if level < Economy.SHIP_MAX_LEVEL:
		var cost := Economy.ship_level_cost(level)
		add_button(tr("hangar.upgrade") % Locale.format_number(cost), func() -> void:
			if Economy.upgrade_ship(SaveManager.data, ship):
				AudioManager.play_ui("kenney_weapon_up")
				SaveManager.save_profile(), Economy.can_pay(profile, {"credits": cost}), "UpgradeShip")
	else:
		add_text(tr("hangar.max"), UiTheme.GOLD)
	_fill_secondaries(profile)
	_fill_wings(profile)
	_fill_difficulty(profile)


func _fill_secondaries(profile: Dictionary) -> void:
	add_heading(tr("hangar.secondary"))
	var equipped := StringName(String(profile["selected"]["secondary"]))
	for kind: StringName in Economy.SECONDARIES:
		var level := Economy.secondary_level(profile, kind)
		var name := tr("secondary." + String(kind))
		add_text("%s · %s" % [name, tr("secondary.%s_desc" % kind)], UiTheme.TEXT_DIM)
		if level == 0:
			add_button(tr("hangar.buy") % Locale.format_number(Economy.SECONDARY_UNLOCK), func() -> void:
				if Economy.upgrade_secondary(SaveManager.data, kind):
					SaveManager.data["selected"]["secondary"] = String(kind)
					SaveManager.save_profile(), Economy.can_pay(profile, {"credits": Economy.SECONDARY_UNLOCK}))
			continue
		var on := equipped == kind
		add_button((tr("hangar.equipped") if on else tr("hangar.equip")) + " · " + tr("hangar.level") % level,
				func() -> void:
					SaveManager.data["selected"]["secondary"] = "" if on else String(kind)
					SaveManager.save_profile())
		if level < Economy.SECONDARY_MAX_LEVEL:
			var cost := Economy.secondary_cost(level)
			add_button(tr("hangar.upgrade_both") % [Locale.format_number(int(cost["credits"])), int(cost["orichalcum"])],
					func() -> void:
						if Economy.upgrade_secondary(SaveManager.data, kind):
							SaveManager.save_profile(), Economy.can_pay(profile, cost))


func _fill_wings(profile: Dictionary) -> void:
	var wings := DB.rows("wings")
	var available := Economy.wings_available(profile, wings)
	var chosen: Array = profile["selected"]["wings"]
	add_heading(tr("hangar.wings") % [chosen.size(), Economy.MAX_WINGS])
	var stars := Economy.total_stars(profile)
	for row: Variant in wings:
		var def := row as Dictionary
		if not Economy.released(def):
			continue
		var id := StringName(String(def["id"]))
		var text := "%s · %s" % [tr(String(def["name_key"])), tr(String(def["desc_key"]))]
		if not id in available:
			add_text("☆ %s · %s" % [tr("hangar.wing_locked") % [stars, int(def["stars"])], tr(String(def["name_key"]))],
					UiTheme.TEXT_DIM)
			continue
		var on := chosen.has(String(id))
		add_button(("◆ " if on else "◇ ") + text, func() -> void:
			Economy.toggle_wing(SaveManager.data, id, wings)
			SaveManager.save_profile(), on or chosen.size() < Economy.MAX_WINGS)


func _fill_difficulty(profile: Dictionary) -> void:
	add_heading(tr("hangar.difficulty"))
	var current := String(profile["selected"]["difficulty"])
	for diff: StringName in Economy.DIFFICULTIES:
		var on := current == String(diff)
		add_button(("◆ " if on else "◇ ") + tr("difficulty." + String(diff)) + " · " + tr("difficulty.%s_desc" % diff),
				func() -> void:
					SaveManager.data["selected"]["difficulty"] = String(diff)
					SaveManager.save_profile())
