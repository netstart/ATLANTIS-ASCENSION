class_name LogbookScreen
extends ListScreen
## Diário de bordo (plano mestre 3.4): registros da Halcyon achados nas missões, glifos e números
## da carreira. Registro ainda não achado aparece como "???" com a missão onde procurar.
##
## Registro achado é um cartão com o título da missão em ouro (é recompensa) e o texto inteiro; os
## que faltam e as conquistas viram linhas compactas num cartão só (cadeado apagado, visto menta).


func title_key() -> String:
	return "logbook.title"


func _fill() -> void:
	var profile := SaveManager.data
	var logs: Array = profile["story"]["logs"]
	add_heading(tr("logbook.logs") % [logs.size(), Economy.CAMPAIGN.size()])
	var missing: Array[String] = []
	for n: Dictionary in Economy.CAMPAIGN:
		var id := String(n["id"])
		if logs.has(id):
			var box := card(UiTheme.GOLD)
			var head := title_row(box, tr("log.%s_title" % id), UiTheme.WHITE, 13, &"diamond", UiTheme.GOLD)
			head.add_child(badge(MapScreen.node_label(n), UiTheme.GOLD))
			text(box, tr("log.%s_text" % id), UiTheme.TEXT)
		elif Economy.mission_unlocked(profile, n["id"]):
			missing.append("%s · ???" % MapScreen.node_label(n))
	if not missing.is_empty():
		var box := card(UiTheme.TEXT_DIM, null, 0.6)
		for line: String in missing:
			title_row(box, line, UiTheme.TEXT_DIM, UiTheme.FONT_SIZE, &"lock", UiTheme.TEXT_DIM)
	var got: Dictionary = profile["achievements"]
	var all := Achievements.all()
	add_heading(tr("logbook.achievements") % [got.size(), all.size()])
	bar(_list, float(got.size()), float(all.size()), UiTheme.MINT)
	var list := card()
	for raw: Variant in all:
		var id := String((raw as Dictionary)["id"])
		var done := got.has(id)
		title_row(list, tr("achievement." + id), UiTheme.TEXT if done else UiTheme.TEXT_DIM, UiTheme.FONT_SIZE,
				&"check" if done else &"ring", UiTheme.MINT if done else Color(UiTheme.TEXT_DIM, 0.6))
	add_heading(tr("logbook.career"))
	var stats: Dictionary = profile["stats"]
	var career := card()
	text(career, tr("logbook.stats") % [int(stats["missions_cleared"]), int(stats["missions_played"]),
			Locale.format_number(int(stats["kills"])), Locale.format_number(int(stats["grazes"])),
			Economy.total_stars(profile), roundi(float(stats["time_played"]) / 60.0)], UiTheme.TEXT)
