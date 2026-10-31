class_name PracticeScreen
extends ListScreen
## Prática (plano mestre 4.11): qualquer missão já concluída, com o hangar e sem recompensas nem
## estrelas. Serve para estudar um chefe ou um trecho sem medo de perder o recorde.


func title_key() -> String:
	return "mode.practice"


func _fill() -> void:
	var profile := SaveManager.data
	add_text(tr("practice.desc"), UiTheme.TEXT_DIM)
	var any := false
	for n: Dictionary in Economy.CAMPAIGN:
		if not Economy.cleared(profile, n["id"]):
			continue
		any = true
		var id: StringName = n["id"]
		add_button("%s · %s" % [MapScreen.node_label(n), tr("stage." + String(id))],
				func() -> void: play_practice.emit(id), true, "Practice_" + String(id))
	if not any:
		add_text(tr("practice.none"), UiTheme.CORAL)
