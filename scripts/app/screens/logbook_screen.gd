class_name LogbookScreen
extends ListScreen
## Diário de bordo (plano mestre 3.4): registros da Halcyon achados nas missões, glifos e números
## da carreira. Registro ainda não achado aparece como "???" com a missão onde procurar.


func title_key() -> String:
	return "logbook.title"


func _fill() -> void:
	var profile := SaveManager.data
	var logs: Array = profile["story"]["logs"]
	add_heading(tr("logbook.logs") % [logs.size(), Economy.CAMPAIGN.size()])
	for n: Dictionary in Economy.CAMPAIGN:
		var id := String(n["id"])
		if logs.has(id):
			add_text("◆ %s · %s" % [MapScreen.node_label(n), tr("log.%s_title" % id)], UiTheme.GOLD)
			add_text(tr("log.%s_text" % id))
		elif Economy.mission_unlocked(profile, n["id"]):
			add_text("◇ %s · ???" % MapScreen.node_label(n), UiTheme.TEXT_DIM)
	var got: Dictionary = profile["achievements"]
	var all := Achievements.all()
	add_heading(tr("logbook.achievements") % [got.size(), all.size()])
	for raw: Variant in all:
		var id := String((raw as Dictionary)["id"])
		var done := got.has(id)
		add_text(("◆ " if done else "◇ ") + tr("achievement." + id), UiTheme.GOLD if done else UiTheme.TEXT_DIM)
	add_heading(tr("logbook.career"))
	var stats: Dictionary = profile["stats"]
	add_text(tr("logbook.stats") % [int(stats["missions_cleared"]), int(stats["missions_played"]),
			Locale.format_number(int(stats["kills"])), Locale.format_number(int(stats["grazes"])),
			Economy.total_stars(profile), roundi(float(stats["time_played"]) / 60.0)])
