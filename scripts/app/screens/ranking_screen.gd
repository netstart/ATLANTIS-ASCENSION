class_name RankingScreen
extends ListScreen
## Ranking mundial de abates (Google Play Games, PlayRanking): os 100 primeiros de todos os tempos, com
## posição, nome do jogador no Play Games, abates da carreira e tempo jogado (KillRanking). Ouro, prata e
## bronze nos três primeiros; a linha do próprio jogador em menta.
##
## Estados sem lista: só no Android (PC e Steam), indisponível (IDs do Play Console ainda vazios), precisa
## entrar (com o botão de login), carregando, sem conexão e vazio. Cada linha recebe foco: com o teclado ou
## o controle a lista rola seguindo o foco (FocusNav); no toque rola pelo dedo (TouchScroll).

const SHOWN := 100
## Coluna da posição: cabe "100".
const RANK_W := 22

## O on_show já monta a lista: o aviso do PlayRanking.refresh() dele não monta de novo.
var _opening: bool = false


func title_key() -> String:
	return "ranking.title"


func _build() -> void:
	super()
	PlayRanking.changed.connect(func() -> void:
		if is_visible_in_tree() and not _opening:
			refill())


func on_show(app: Node) -> void:
	_opening = true
	PlayRanking.refresh()
	_opening = false
	super(app)


## Chave do aviso que ocupa o lugar da lista; "" quando há pontuações para mostrar.
static func status_key() -> String:
	if not PlayRanking.available:
		return "ranking.unavailable" if OS.get_name() == "Android" else "ranking.android_only"
	if not PlayRanking.authenticated:
		return "ranking.sign_in_hint"
	if not PlayRanking.scores.is_empty():
		return ""
	if PlayRanking.loading:
		return "ranking.loading"
	return "ranking.offline" if PlayRanking.offline else "ranking.empty"


func _fill() -> void:
	var key := status_key()
	if not key.is_empty():
		var status := text(card(UiTheme.TEXT_DIM, null, 0.6), tr(key))
		status.name = "Status"
		if key == "ranking.sign_in_hint":
			add_button(tr("ranking.sign_in"), PlayRanking.sign_in_user, true, "SignIn", true)
		return
	add_text(tr("ranking.rule"), UiTheme.TEXT_DIM)
	var hours := tr("ranking.time_hours")
	var minutes := tr("ranking.time_minutes")
	var boxes: Dictionary = {}
	for i: int in range(mini(SHOWN, PlayRanking.scores.size())):
		_list.add_child(row(KillRanking.entry(PlayRanking.scores[i], PlayRanking.player_id), hours, minutes, boxes))


## Cor da linha: menta para o próprio jogador, medalha nos três primeiros, ciano apagado no resto.
static func accent_of(entry: Dictionary) -> Color:
	if bool(entry["me"]):
		return UiTheme.MINT
	var rank := int(entry["rank"])
	return RecordsScreen.MEDALS[rank - 1] if rank >= 1 and rank <= 3 else UiTheme.TEXT_DIM


## Uma linha do ranking: posição, nome (uma linha, com reticências), abates em negrito e o tempo embaixo.
## `boxes` guarda uma caixa por cor (100 linhas, 5 caixas).
static func row(entry: Dictionary, hours: String, minutes: String, boxes: Dictionary = {}) -> PanelContainer:
	var accent := accent_of(entry)
	var strong := accent != UiTheme.TEXT_DIM
	if not boxes.has(accent):
		var box := UiTheme.chamfer(Color(UiTheme.DEEP_BLUE.lerp(accent, 0.12 if bool(entry["me"]) else 0.0), 0.8),
				Color(accent, 0.6 if strong else 0.2), 1, UiTheme.CUT_SMALL)
		box.content_margin_left = 6
		box.content_margin_right = 8
		box.content_margin_top = 3
		box.content_margin_bottom = 3
		boxes[accent] = box
	var panel := PanelContainer.new()
	panel.name = "Rank_%d" % int(entry["rank"])
	panel.add_theme_stylebox_override("panel", boxes[accent])
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# O arrasto do dedo passa pela linha e chega à rolagem.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.focus_mode = Control.FOCUS_ALL
	panel.focus_entered.connect(panel.queue_redraw)
	panel.focus_exited.connect(panel.queue_redraw)
	panel.draw.connect(func() -> void:
		if panel.has_focus():
			panel.draw_rect(Rect2(Vector2.ZERO, panel.size), UiTheme.CYAN, false, 1.0))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	var rank := _cell("Rank", str(int(entry["rank"])), 13, accent if strong else UiTheme.TEXT)
	_bold(rank)
	rank.custom_minimum_size.x = UiTheme.scaled(RANK_W)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(rank)
	var holder := _cell("Name", String(entry["name"]), UiTheme.FONT_SIZE,
			UiTheme.MINT if bool(entry["me"]) else UiTheme.TEXT)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.clip_text = true
	holder.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	holder.custom_minimum_size.x = 24
	line.add_child(holder)
	var numbers := VBoxContainer.new()
	numbers.add_theme_constant_override("separation", -2)
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(numbers)
	var kills := _cell("Kills", Locale.format_number(int(entry["kills"])), 13, UiTheme.GOLD if strong else UiTheme.TEXT)
	_bold(kills)
	kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	numbers.add_child(kills)
	var time := _cell("Time", KillRanking.format_time(int(entry["seconds"]), hours, minutes), UiTheme.SMALL_SIZE,
			UiTheme.TEXT_DIM)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	numbers.add_child(time)
	return panel


## Rótulo de uma célula; o nome do jogador e os números não passam pela tradução.
static func _cell(cell_name: String, value: String, size: int, color: Color) -> Label:
	var l := UiTheme.label(value, size, color)
	l.name = cell_name
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
