class_name HangarScreen
extends ListScreen
## Oficina do hangar (plano mestre 4.9 e 7.2): nível da aeronave, arma secundária, asas e dificuldade.
## Toda regra vem da Economy; a tela só mostra e chama.
##
## A aeronave é a estrela: aparece grande (escala inteira, com halo) no cartão de cima, com as barras
## de nível e o ganho do próximo nível em menta ("antes → depois"), para o jogador ver o que compra.


func title_key() -> String:
	return "hangar.title"


func show_wallet() -> bool:
	return true


func _fill() -> void:
	var profile := SaveManager.data
	var ship := StringName(String(profile["selected"]["ship"]))
	var level := Economy.ship_level(profile, ship)
	var hero := card(UiTheme.CYAN, null, 0.78)
	# Escala 3 só onde sobra altura; nas telas baixas (270x480) a nave em 2x deixa a oficina à vista.
	var zoom := 3 if _width >= 300.0 and safe.size.y >= 600.0 else 2
	hero.add_child(ship_view(ship_tint(String(ship), String(profile["selected"].get("cosmetic", ""))), zoom))
	var head := title_row(hero, tr("ship." + String(ship)), UiTheme.WHITE, 18)
	head.add_child(badge(tr("hangar.level") % level, UiTheme.GOLD))
	pips(hero, level, Economy.SHIP_MAX_LEVEL)
	var bonus := Economy.ship_bonus(level)
	text(hero, tr("hangar.bonus") % [roundi(float(bonus["damage"]) * 100.0), int(bonus["hull"])])
	if level < Economy.SHIP_MAX_LEVEL:
		var next := Economy.ship_bonus(level + 1)
		text(hero, "→ " + tr("hangar.bonus") % [roundi(float(next["damage"]) * 100.0), int(next["hull"])], UiTheme.MINT)
		var cost := Economy.ship_level_cost(level)
		button(hero, tr("hangar.upgrade") % Locale.format_number(cost), func() -> void:
			if Economy.upgrade_ship(SaveManager.data, ship):
				AudioManager.play_ui("kenney_weapon_up")
				SaveManager.save_profile(), Economy.can_pay(profile, {"credits": cost}), "UpgradeShip", true)
	else:
		hero.add_child(badge(tr("hangar.max"), UiTheme.GOLD, &"star"))
	_fill_secondaries(profile)
	_fill_wings(profile)
	_fill_difficulty(profile)


func _fill_secondaries(profile: Dictionary) -> void:
	add_heading(tr("hangar.secondary"))
	var equipped := StringName(String(profile["selected"]["secondary"]))
	for kind: StringName in Economy.SECONDARIES:
		var level := Economy.secondary_level(profile, kind)
		var on := level > 0 and equipped == kind
		var box := card(UiTheme.MINT if on else UiTheme.CYAN)
		var head := title_row(box, tr("secondary." + String(kind)), UiTheme.WHITE, 13,
				&"diamond" if level > 0 else &"lock", UiTheme.CYAN if level > 0 else UiTheme.TEXT_DIM)
		if on:
			head.add_child(badge(tr("hangar.equipped"), UiTheme.MINT, &"check"))
		text(box, tr("secondary.%s_desc" % kind))
		if level == 0:
			button(box, tr("hangar.buy") % Locale.format_number(Economy.SECONDARY_UNLOCK), func() -> void:
				if Economy.upgrade_secondary(SaveManager.data, kind):
					SaveManager.data["selected"]["secondary"] = String(kind)
					SaveManager.save_profile(), Economy.can_pay(profile, {"credits": Economy.SECONDARY_UNLOCK}),
					"", true)
			continue
		var levels := HBoxContainer.new()
		levels.add_theme_constant_override("separation", 8)
		box.add_child(levels)
		var lvl := UiTheme.label(tr("hangar.level") % level, UiTheme.SMALL_SIZE, UiTheme.GOLD)
		levels.add_child(lvl)
		var track := VBoxContainer.new()
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.alignment = BoxContainer.ALIGNMENT_CENTER
		levels.add_child(track)
		pips(track, level, Economy.SECONDARY_MAX_LEVEL)
		# Equipar é a ação principal enquanto a arma está guardada; equipada, a principal vira subir
		# o nível. Tocar "Equipada" de novo desequipa (como antes).
		button(box, tr("hangar.equipped") if on else tr("hangar.equip"), func() -> void:
			SaveManager.data["selected"]["secondary"] = "" if on else String(kind)
			SaveManager.save_profile(), true, "", not on)
		if level < Economy.SECONDARY_MAX_LEVEL:
			var cost := Economy.secondary_cost(level)
			button(box, tr("hangar.upgrade_both") % [Locale.format_number(int(cost["credits"])), int(cost["orichalcum"])],
					func() -> void:
						if Economy.upgrade_secondary(SaveManager.data, kind):
							SaveManager.save_profile(), Economy.can_pay(profile, cost), "", on)


func _fill_wings(profile: Dictionary) -> void:
	var wings := DB.rows("wings")
	var available := Economy.wings_available(profile, wings)
	var chosen: Array = profile["selected"]["wings"]
	add_heading(tr("hangar.wings") % [chosen.size(), Economy.MAX_WINGS])
	var stars := Economy.total_stars(profile)
	var locked: Array[Dictionary] = []
	for row: Variant in wings:
		var def := row as Dictionary
		if not Economy.released(def):
			continue
		var id := StringName(String(def["id"]))
		if not id in available:
			locked.append(def)
			continue
		var on := chosen.has(String(id))
		choice(tr(String(def["name_key"])), tr(String(def["desc_key"])), on, func() -> void:
			Economy.toggle_wing(SaveManager.data, id, wings)
			SaveManager.save_profile(), on or chosen.size() < Economy.MAX_WINGS)
	if locked.is_empty():
		return
	# Asas fechadas: um cartão só, apagado, com o cadeado e as estrelas que faltam em cada uma.
	var box := card(UiTheme.TEXT_DIM, null, 0.6)
	for def: Dictionary in locked:
		var row := title_row(box, tr(String(def["name_key"])), UiTheme.TEXT_DIM, UiTheme.FONT_SIZE, &"lock",
				UiTheme.TEXT_DIM)
		var need := HBoxContainer.new()
		need.add_theme_constant_override("separation", 3)
		need.add_child(glyph(&"star", UiTheme.GOLD, 10))
		need.add_child(UiTheme.label("%d/%d" % [stars, int(def["stars"])], UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
		need.tooltip_text = tr("hangar.wing_locked") % [stars, int(def["stars"])]
		row.add_child(need)


func _fill_difficulty(profile: Dictionary) -> void:
	add_heading(tr("hangar.difficulty"))
	var current := String(profile["selected"]["difficulty"])
	for diff: StringName in Economy.DIFFICULTIES:
		var on := current == String(diff)
		choice(tr("difficulty." + String(diff)), tr("difficulty.%s_desc" % diff), on, func() -> void:
			SaveManager.data["selected"]["difficulty"] = String(diff)
			SaveManager.save_profile())
