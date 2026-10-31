class_name CityScreen
extends ListScreen
## Cidade de Thalassa (plano mestre 7.2): os atlantes resgatados nas cápsulas reerguem 5 distritos, e
## cada distrito aberto dá um bônus permanente (créditos, pérolas, desconto na oficina, bomba extra,
## oricalco). Também mostra os Registros Abissais (missões secretas) e os finais vistos.


func title_key() -> String:
	return "city.title"


func _fill() -> void:
	var profile := SaveManager.data
	var rescued := int(profile.get("rescued_total", 0))
	add_heading(tr("city.rescued") % Locale.format_number(rescued))
	for d: Dictionary in Economy.DISTRICTS:
		var id := String(d["id"])
		var open := rescued >= int(d["rescued"])
		var bonus := tr("city.bonus_" + String(d["bonus"]))
		if String(d["bonus"]) != "bombs":
			bonus = bonus % roundi(float(d["value"]) * 100.0)
		if open:
			add_text("◆ %s · %s" % [tr("district." + id), bonus], UiTheme.GOLD)
		else:
			add_text("◇ %s · %s" % [tr("district." + id), tr("city.needs") % int(d["rescued"])], UiTheme.TEXT_DIM)
	add_heading(tr("city.records") % [Economy.abyss_records(profile), Economy.SECRETS.size()])
	add_text(tr("city.records_desc"), UiTheme.TEXT_DIM)
	var endings: Array = profile["story"]["endings"]
	add_heading(tr("city.endings") % [endings.size(), 3])
	for e: String in ["shattered", "return", "high_tide"]:
		var seen := endings.has(e)
		add_text(("◆ " + tr("ending." + e)) if seen else "◇ ???", UiTheme.GOLD if seen else UiTheme.TEXT_DIM)
