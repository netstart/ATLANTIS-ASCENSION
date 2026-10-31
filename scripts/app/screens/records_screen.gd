class_name RecordsScreen
extends ListScreen
## Placares locais (top 10 de cada missão e modo) com o replay do recorde: "Assistir" reproduz a
## partida gravada passo a passo (a Sim é determinística, então é exatamente o que aconteceu).
##
## Um cartão por placar: o 1º lugar em ouro (recompensa), pontos alinhados à direita em negrito, nave
## e data apagadas embaixo, e "Assistir" em vidro com o ícone de play.

signal watch(key: String)

const MEDALS: Array[Color] = [UiTheme.GOLD, Color("cfe3f0"), Color("e0a272")]


func title_key() -> String:
	return "events.records"


func _fill() -> void:
	var boards: Dictionary = SaveManager.data.get("boards", {})
	if boards.is_empty():
		var empty := card(UiTheme.TEXT_DIM, null, 0.6)
		text(empty, tr("records.none"))
		return
	var keys := boards.keys()
	keys.sort()
	for key: Variant in keys:
		var k := String(key)
		var board: Array = boards[k]
		var box := card()
		title_row(box, _title_of(k), UiTheme.CYAN, 14)
		for i: int in range(mini(3, board.size())):
			var row := board[i] as Dictionary
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			var rank := UiTheme.label("%d" % (i + 1), 13, MEDALS[i])
			_bold(rank)
			rank.custom_minimum_size = Vector2(UiTheme.scaled(14), 0)
			line.add_child(rank)
			var who := UiTheme.label("%s · %s" % [tr("ship." + String(row["ship"])), String(row["date"])],
					UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM, true)
			who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			line.add_child(who)
			var score := UiTheme.label(Locale.format_number(int(row["score"])), 13 if i == 0 else UiTheme.FONT_SIZE,
					UiTheme.GOLD if i == 0 else UiTheme.TEXT)
			_bold(score)
			score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			line.add_child(score)
			box.add_child(line)
		if FileAccess.file_exists("%s/%s.json" % [Replay.DIR, k]):
			var b := button(box, tr("records.watch"), func() -> void: watch.emit(k), true, "Watch_" + k)
			b.icon = icon(&"play")
			b.add_theme_constant_override("icon_max_width", UiTheme.scaled(10))
			b.add_theme_color_override("icon_normal_color", UiTheme.CYAN)


func _title_of(key: String) -> String:
	for mode: String in ["daily", "currents", "survival", "abyss"]:
		if key.begins_with(mode + "_"):
			return tr("mode." + mode)
	return tr("stage." + key)
