class_name PracticeScreen
extends ListScreen
## Prática (plano mestre 4.11): qualquer missão já concluída, com o hangar e sem recompensas nem
## estrelas. Serve para estudar um chefe ou um trecho sem medo de perder o recorde.
##
## Uma grade de cartões tocáveis (número da missão em ciano e o nome), duas colunas onde cabe.


func title_key() -> String:
	return "mode.practice"


func _fill() -> void:
	var profile := SaveManager.data
	var intro := card(UiTheme.TURQUOISE, null, 0.7)
	text(intro, tr("practice.desc"))
	var any := false
	var cells: GridContainer = null
	for n: Dictionary in Economy.CAMPAIGN:
		if not Economy.cleared(profile, n["id"]):
			continue
		any = true
		if cells == null:
			cells = grid()
		var id: StringName = n["id"]
		var b := button(cells, "%s · %s" % [MapScreen.node_label(n), tr("stage." + String(id))],
				func() -> void: play_practice.emit(id), true, "Practice_" + String(id))
		b.icon = icon(&"play")
		b.add_theme_constant_override("icon_max_width", UiTheme.scaled(9))
		b.add_theme_color_override("icon_normal_color", UiTheme.CYAN)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not any:
		var none := card(UiTheme.CORAL, null, 0.7)
		title_row(none, tr("practice.none"), UiTheme.CORAL, UiTheme.FONT_SIZE, &"lock", UiTheme.CORAL)
