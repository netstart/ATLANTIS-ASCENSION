class_name EventsScreen
extends ListScreen
## Aba Eventos (plano mestre 4.11 e 7.2): sequência de login, tarefas diárias e semanais com resgate,
## Núcleo de Oricalco e os modos (Arcade, Desafio Diário, Sobrevivência, Boss Rush, Prática) com o
## recorde de cada um e o motivo quando ainda está fechado.
##
## Cada bloco é um cartão com barra de progresso chanfrada: tarefa pronta mostra "Resgatar" em ouro
## (é recompensa), resgatada leva visto menta, em andamento mostra a barra e o placar "3/5". Modo
## fechado fica apagado com cadeado e diz onde abre.

const MODE_HINT := {&"arcade": "c2m3", &"daily": "c2m1", &"survival": "c4m1", &"boss_rush": "c9m3",
		&"practice": "c1m1", &"currents": "c3m2", &"second_tide": "c9m3",
		&"abyss": "c7m1", &"coop": "c1m3"}


func title_key() -> String:
	return "hub.tab_events"


func show_wallet() -> bool:
	return true


func _fill() -> void:
	var profile := SaveManager.data
	LiveOps.refresh(profile, App.today())
	var lg: Dictionary = profile["login"]
	var login := card()
	var streak := int(lg.get("streak", 0))
	title_row(login, tr("events.login") % [streak, LiveOps.LOGIN_REWARDS.size()], UiTheme.WHITE, 13, &"star",
			UiTheme.GOLD)
	pips(login, streak, LiveOps.LOGIN_REWARDS.size(), UiTheme.GOLD)
	text(login, tr("events.shield") % int(lg.get("shields_left", 0)), UiTheme.TEXT_DIM, UiTheme.SMALL_SIZE)
	_fill_tasks(profile, "daily")
	_fill_tasks(profile, "weekly")
	var core := int(LiveOps.state(profile)["core"])
	var core_box := card(UiTheme.CYAN)
	title_row(core_box, tr("events.core") % [mini(core, LiveOps.CORE_MAX), LiveOps.CORE_MAX], UiTheme.WHITE, 13,
			&"orichalcum", Color.WHITE)
	bar(core_box, float(core), float(LiveOps.CORE_MAX), UiTheme.CYAN)
	var ready := LiveOps.core_ready(profile)
	button(core_box, tr("events.core_open"), func() -> void:
		if not LiveOps.open_core(SaveManager.data).is_empty():
			AudioManager.play_ui("kenney_weapon_up")
			SaveManager.save_profile(), ready, "OpenCore", ready)
	var tier := Season.tier(profile, App.today())
	var season := card(UiTheme.GOLD)
	title_row(season, tr("events.season") % [Season.id_for(App.today()), tier, Season.TIERS], UiTheme.WHITE, 13)
	pips(season, tier, Season.TIERS, UiTheme.GOLD)
	button(season, tr("events.season_open"), func() -> void: navigate.emit(&"season"), true, "Season")
	button(season, tr("events.records"), func() -> void: navigate.emit(&"records"), true, "Records")
	_fill_modes(profile)


func _fill_modes(profile: Dictionary) -> void:
	add_heading(tr("events.modes"))
	for m: Dictionary in Modes.MODES:
		var mode: StringName = m["id"]
		if not Modes.available(mode):
			continue
		var open := Modes.unlocked(profile, mode)
		var box := card(UiTheme.CYAN if open else UiTheme.TEXT_DIM, null, 0.84 if open else 0.6)
		title_row(box, tr("mode." + String(mode)), UiTheme.WHITE if open else UiTheme.TEXT_DIM, 13,
				&"play" if open else &"lock", UiTheme.CYAN if open else UiTheme.TEXT_DIM)
		text(box, tr("mode.%s_desc" % mode))
		if mode == &"currents":
			text(box, tr("events.mutator") % tr("mutator." + String(Modes.current_mutator(LiveOps.week_of(App.today())))),
					UiTheme.CYAN)
		if not open:
			var need := MapScreen.node_label(Economy.node(StringName(String(MODE_HINT[mode]))))
			text(box, tr("events.locked") % need, UiTheme.CORAL)
			continue
		if mode == &"practice":
			button(box, tr("events.practice"), func() -> void: navigate.emit(&"practice"), true, "Mode_practice")
			continue
		var best := int((profile.get("mode_best", {}) as Dictionary).get(String(mode), 0))
		var label := tr("events.play_mode") % Locale.format_number(best)
		if mode == &"daily":
			var daily: Dictionary = profile["daily"]
			var done := String(daily.get("date", "")) == App.today() and bool(daily.get("attempted", false))
			label = tr("events.daily_done") % Locale.format_number(int(daily["best_score"])) if done else label
		button(box, label, func() -> void: play_mode.emit(mode), true, "Mode_" + String(mode))


func _fill_tasks(profile: Dictionary, kind: String) -> void:
	var list: Array = LiveOps.state(profile)[kind]
	add_heading(tr("events." + kind))
	var box := card(UiTheme.CYAN, null, 0.8)
	box.add_theme_constant_override("separation", 10)
	for i: int in range(list.size()):
		var t := list[i] as Dictionary
		var goal := int(t["goal"])
		var have := mini(int(t["progress"]), goal)
		var claimed := bool(t["claimed"])
		var done := not claimed and LiveOps.done(t)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		col.add_child(UiTheme.label(tr("task." + String(t["id"])) % goal, UiTheme.FONT_SIZE,
				UiTheme.TEXT_DIM if claimed else UiTheme.TEXT, true))
		if not claimed:
			bar(col, float(have), float(goal), UiTheme.MINT if done else UiTheme.CYAN)
		if claimed:
			row.add_child(badge(tr("events.claimed"), UiTheme.MINT, &"check"))
		elif done:
			var b := button(row, tr("events.claim"), func() -> void:
				LiveOps.claim(SaveManager.data, kind, i)
				AudioManager.play_ui("kenney_ui_confirm")
				SaveManager.save_profile(), true, "Claim_%s_%d" % [kind, i], true)
			b.size_flags_horizontal = Control.SIZE_SHRINK_END
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.autowrap_mode = TextServer.AUTOWRAP_OFF
		else:
			var score := UiTheme.label("%d/%d" % [have, goal], UiTheme.SMALL_SIZE, UiTheme.CYAN)
			score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# Coluna fixa: as barras de todas as tarefas terminam no mesmo ponto.
			score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			score.custom_minimum_size = Vector2(UiTheme.scaled(44), 0)
			row.add_child(score)
