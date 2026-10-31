class_name ShipsScreen
extends ListScreen
## Coleção de aeronaves (plano mestre 4.2 e 7.2): papel, arma de assinatura, especial e progresso
## dos fragmentos; uma aeronave aberta pode ser escolhida para a próxima missão.


func title_key() -> String:
	return "ships.title"


func show_wallet() -> bool:
	return false


func _fill() -> void:
	var profile := SaveManager.data
	var selected := String(profile["selected"]["ship"])
	for row: Variant in DB.rows("ships"):
		var def := row as Dictionary
		if not Economy.released(def):
			continue
		var id := String(def["id"])
		var owned := (profile["unlocked"]["ships"] as Array).has(id)
		add_heading(tr(String(def["name_key"])))
		add_text("%s · %s %s · %s %s" % [tr("role." + String(def["role"])), tr("ships.weapon"),
				tr("weapon." + String(def["signature"])), tr("ships.special"), tr("special." + String(def["special"]))],
				UiTheme.TEXT_DIM)
		if owned:
			var level := Economy.ship_level(profile, StringName(id))
			if id == selected:
				add_text("◆ %s · %s" % [tr("ships.selected"), tr("hangar.level") % level], UiTheme.GOLD)
			else:
				add_button(tr("ships.select") + " · " + tr("hangar.level") % level, func() -> void:
					SaveManager.data["selected"]["ship"] = id
					SaveManager.save_profile(), true, "Select_" + id)
		else:
			var have := int((profile["hangar"]["fragments"] as Dictionary).get(id, 0))
			var sources := PackedStringArray()
			for m: Variant in def.get("sources", []):
				sources.append(MapScreen.node_label(Economy.node(StringName(String(m)))))
			add_text(tr("ships.fragments") % [have, int(def["fragments"]), ", ".join(sources)], UiTheme.CORAL)
