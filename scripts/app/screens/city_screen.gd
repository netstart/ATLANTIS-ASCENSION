class_name CityScreen
extends ListScreen
## Cidade de Thalassa (plano mestre 7.2): os atlantes resgatados nas cápsulas reerguem 5 distritos, e
## cada distrito aberto dá um bônus permanente (créditos, pérolas, desconto na oficina, bomba extra,
## oricalco). Também mostra os Registros Abissais (missões secretas) e os finais vistos.
##
## Cartão de topo com o total resgatado e a barra até o próximo distrito; distrito aberto tem visto
## menta e o bônus em menta (é o que o jogador ganhou), fechado fica apagado com cadeado. Finais são
## raros (violeta).


func title_key() -> String:
	return "city.title"


func _fill() -> void:
	var profile := SaveManager.data
	var rescued := int(profile.get("rescued_total", 0))
	var top := card(UiTheme.MINT)
	title_row(top, tr("city.rescued") % Locale.format_number(rescued), UiTheme.WHITE, 14)
	var goal := 0
	for d: Dictionary in Economy.DISTRICTS:
		if rescued < int(d["rescued"]):
			goal = int(d["rescued"])
			break
	if goal > 0:
		bar(top, float(rescued), float(goal), UiTheme.MINT)
	for d: Dictionary in Economy.DISTRICTS:
		var id := String(d["id"])
		var open := rescued >= int(d["rescued"])
		var bonus := tr("city.bonus_" + String(d["bonus"]))
		if String(d["bonus"]) != "bombs":
			bonus = bonus % roundi(float(d["value"]) * 100.0)
		var box := card(UiTheme.MINT if open else UiTheme.TEXT_DIM, null, 0.84 if open else 0.6)
		title_row(box, tr("district." + id), UiTheme.WHITE if open else UiTheme.TEXT_DIM, 13,
				&"check" if open else &"lock", UiTheme.MINT if open else UiTheme.TEXT_DIM)
		if open:
			text(box, bonus, UiTheme.MINT)
		else:
			text(box, "%s · %s" % [bonus, tr("city.needs") % int(d["rescued"])])
	add_heading(tr("city.records") % [Economy.abyss_records(profile), Economy.SECRETS.size()])
	var records := card(UiTheme.TURQUOISE, null, 0.78)
	pips(records, Economy.abyss_records(profile), Economy.SECRETS.size(), UiTheme.CYAN)
	text(records, tr("city.records_desc"))
	var endings: Array = profile["story"]["endings"]
	add_heading(tr("city.endings") % [endings.size(), 3])
	var end_box := card(UiTheme.VIOLET)
	for e: String in ["shattered", "return", "high_tide"]:
		var seen := endings.has(e)
		title_row(end_box, tr("ending." + e) if seen else "???", UiTheme.WHITE if seen else UiTheme.TEXT_DIM,
				UiTheme.FONT_SIZE, &"star" if seen else &"lock", UiTheme.VIOLET if seen else UiTheme.TEXT_DIM)
