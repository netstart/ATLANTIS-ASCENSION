class_name ShipsScreen
extends ListScreen
## Coleção de aeronaves (plano mestre 4.2 e 7.2): papel, arma de assinatura, especial e progresso
## dos fragmentos; uma aeronave aberta pode ser escolhida para a próxima missão.
##
## Um cartão por aeronave com a miniatura na cor dela: a escolhida tem borda menta e selo; as abertas
## têm "Escolher" em ouro (é a ação de equipar); as fechadas ficam em silhueta, com cadeado e a barra
## dos fragmentos. As que só abrem com um final são raras (violeta).


func title_key() -> String:
	return "ships.title"


func show_wallet() -> bool:
	return false


func _fill() -> void:
	var profile := SaveManager.data
	var selected := String(profile["selected"]["ship"])
	var cosmetic := String(profile["selected"].get("cosmetic", ""))
	for row: Variant in DB.rows("ships"):
		var def := row as Dictionary
		if not Economy.released(def):
			continue
		var id := String(def["id"])
		var owned := (profile["unlocked"]["ships"] as Array).has(id)
		var on := owned and id == selected
		var accent := UiTheme.MINT if on else (UiTheme.VIOLET if def.has("ending") else UiTheme.CYAN)
		var box := card(accent, null, 0.84 if owned else 0.66)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		box.add_child(top)
		var view := ship_view(ship_tint(id, cosmetic if on else ""), 1, not owned)
		view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(view)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 3)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_child(info)
		var head := title_row(info, tr(String(def["name_key"])), UiTheme.WHITE if owned else UiTheme.TEXT, 14,
				&"" if owned else &"lock", UiTheme.TEXT_DIM)
		if on:
			head.add_child(badge(tr("ships.selected"), UiTheme.MINT, &"check"))
		text(info, tr("role." + String(def["role"])), UiTheme.CYAN if owned else UiTheme.TEXT_DIM, UiTheme.SMALL_SIZE)
		text(info, "%s %s · %s %s" % [tr("ships.weapon"), tr("weapon." + String(def["signature"])), tr("ships.special"),
				tr("special." + String(def["special"]))])
		if def.has("trait"):
			text(box, tr("trait." + String(def["trait"])), UiTheme.TEXT if owned else UiTheme.TEXT_DIM)
		if owned:
			var level := Economy.ship_level(profile, StringName(id))
			pips(box, level, Economy.SHIP_MAX_LEVEL)
			if on:
				text(box, tr("hangar.level") % level, UiTheme.GOLD, UiTheme.SMALL_SIZE)
			else:
				button(box, tr("ships.select") + " · " + tr("hangar.level") % level, func() -> void:
					SaveManager.data["selected"]["ship"] = id
					SaveManager.save_profile(), true, "Select_" + id, true)
		elif def.has("ending"):
			text(box, tr("ships.ending_unlock") % tr("ending." + String(def["ending"])), UiTheme.VIOLET)
		else:
			var have := int((profile["hangar"]["fragments"] as Dictionary).get(id, 0))
			var sources := PackedStringArray()
			for m: Variant in def.get("sources", []):
				sources.append(MapScreen.node_label(Economy.node(StringName(String(m)))))
			bar(box, float(have), float(int(def["fragments"])), UiTheme.CORAL)
			text(box, tr("ships.fragments") % [have, int(def["fragments"]), ", ".join(sources)], UiTheme.CORAL)
