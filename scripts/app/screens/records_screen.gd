class_name RecordsScreen
extends ListScreen
## Placares locais (top 10 de cada missão e modo) com o replay do recorde: "Assistir" reproduz a
## partida gravada passo a passo (a Sim é determinística, então é exatamente o que aconteceu).

signal watch(key: String)


func title_key() -> String:
	return "events.records"


func _fill() -> void:
	var boards: Dictionary = SaveManager.data.get("boards", {})
	if boards.is_empty():
		add_text(tr("records.none"), UiTheme.TEXT_DIM)
		return
	var keys := boards.keys()
	keys.sort()
	for key: Variant in keys:
		var k := String(key)
		var board: Array = boards[k]
		add_heading(_title_of(k))
		for i: int in range(mini(3, board.size())):
			var row := board[i] as Dictionary
			add_text("%d. %s · %s · %s" % [i + 1, Locale.format_number(int(row["score"])), tr("ship." + String(row["ship"])),
					String(row["date"])], UiTheme.GOLD if i == 0 else UiTheme.TEXT)
		if FileAccess.file_exists("%s/%s.json" % [Replay.DIR, k]):
			add_button(tr("records.watch"), func() -> void: watch.emit(k), true, "Watch_" + k)


func _title_of(key: String) -> String:
	for mode: String in ["daily", "currents", "survival"]:
		if key.begins_with(mode + "_"):
			return tr("mode." + mode)
	return tr("stage." + key)
