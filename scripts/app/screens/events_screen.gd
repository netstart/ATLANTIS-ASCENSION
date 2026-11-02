class_name EventsScreen
extends ListScreen
## Aba Eventos (plano mestre 4.11 e 7.2): sequência de login, tarefas diárias e semanais com resgate,
## Núcleo de Oricalco, o passe da temporada e os modos (Arcade, Desafio Diário, Sobrevivência, Boss Rush,
## Prática...) com o recorde de cada um e o motivo quando ainda está fechado.
##
## Cada bloco é um cartão com barra de progresso chanfrada: tarefa pronta mostra "Resgatar" em ouro
## (é recompensa), resgatada leva visto menta, em andamento mostra a barra e o placar "3/5".
##
## 1.15 (menus de comando): seções em faixa chevron (CommandKit.ribbon), bolinha "!" (Notices) no Núcleo
## cheio, no nível do passe por resgatar e no Desafio Diário ainda não jogado, e os modos como banners
## ilustrados (ModeBanner: cor e emblema por modo, título em fita, estado "Disponível hoje" ou recorde).
## O banner inteiro é o botão; modo fechado fica apagado com cadeado e diz onde abre. No desktop os
## banners vão em duas colunas.

const MODE_HINT := {&"arcade": "c2m3", &"daily": "c2m1", &"survival": "c4m1", &"boss_rush": "c9m3",
		&"practice": "c1m1", &"currents": "c3m2", &"second_tide": "c9m3",
		&"abyss": "c7m1", &"coop": "c1m3"}

var _modes: GridContainer


func title_key() -> String:
	return "hub.tab_events"


func show_wallet() -> bool:
	return true


func max_width() -> float:
	return 540.0 if NavShell.wide(safe) else MAX_WIDTH


func _layout() -> void:
	super()
	if _modes != null and is_instance_valid(_modes):
		_modes.columns = 2 if NavShell.wide(safe) else 1


func _fill() -> void:
	var profile := SaveManager.data
	var today := App.today()
	LiveOps.refresh(profile, today)
	# O coração da aba vem primeiro: os modos, logo abaixo da faixa do título.
	_fill_modes(profile, today)
	_fill_login(profile, today)
	_fill_tasks(profile, "daily")
	_fill_tasks(profile, "weekly")
	_section(tr("events.section_rewards"))
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
	if Notices.core_ready(profile):
		_dot_on(core_box.get_parent() as Control)
	var tier := Season.tier(profile, today)
	var season := card(UiTheme.GOLD)
	title_row(season, tr("events.season") % [Season.id_for(today), tier, Season.TIERS], UiTheme.WHITE, 13,
			&"diamond", UiTheme.GOLD)
	pips(season, tier, Season.TIERS, UiTheme.GOLD)
	button(season, tr("events.season_open"), func() -> void: navigate.emit(&"season"), true, "Season")
	button(season, tr("events.records"), func() -> void: navigate.emit(&"records"), true, "Records")
	if Notices.season_reward_ready(profile, today):
		_dot_on(season.get_parent() as Control)


## Entrada diária: sete ladrilhos de dia com o prêmio de cada um (ícone e quantidade); os recebidos
## levam visto, o de hoje (ou o próximo) fica aceso em ouro.
func _fill_login(profile: Dictionary, today: String) -> void:
	var lg: Dictionary = profile["login"]
	var streak := int(lg.get("streak", 0))
	var total := LiveOps.LOGIN_REWARDS.size()
	_section(tr("events.login") % [streak, total])
	var got := ((streak - 1) % total) + 1 if streak > 0 else 0
	var current := got
	if String(lg.get("last_date", "")) != today:
		if got >= total:
			got = 0
		current = got + 1
	var row := HBoxContainer.new()
	row.name = "LoginDays"
	row.add_theme_constant_override("separation", 3)
	_list.add_child(row)
	for i: int in range(total):
		row.add_child(_day_tile(i + 1, LiveOps.LOGIN_REWARDS[i], i + 1 <= got, i + 1 == current))
	var shield := text(_list, tr("events.shield") % int(lg.get("shields_left", 0)), UiTheme.TEXT_DIM,
			UiTheme.SMALL_SIZE)
	shield.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _day_tile(day: int, reward: Dictionary, received: bool, current: bool) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.name = "Day_%d" % day
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent := UiTheme.GOLD if current else (UiTheme.MINT if received else UiTheme.CYAN)
	var box := UiTheme.chamfer(Color(UiTheme.DEEP_BLUE.lerp(accent, 0.28 if current else 0.08), 0.92),
			Color(accent, 0.95 if current else 0.4), 2 if current else 1, 5)
	for side: String in ["left", "right"]:
		box.set("content_margin_" + side, 1)
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	if current:
		box.shadow_color = Color(UiTheme.GOLD, 0.35)
		box.shadow_size = 6
	tile.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_child(col)
	var num := UiTheme.label(str(day), 9, UiTheme.GOLD if current else UiTheme.TEXT_DIM)
	_bold(num)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(num)
	var kind := "orichalcum" if reward.has("orichalcum") else ("pearls" if reward.has("pearls") else "credits")
	var icon := glyph(&"check" if received else StringName(kind), UiTheme.MINT if received else Color.WHITE, 14)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var amount := UiTheme.label(Locale.format_number(int(reward[kind])), 9,
			UiTheme.TEXT_DIM if received else UiTheme.WHITE)
	_bold(amount)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(amount)
	var parts := PackedStringArray()
	for k: String in reward:
		parts.append("%s +%s" % [tr("currency." + k), Locale.format_number(int(reward[k]))])
	tile.tooltip_text = "   ".join(parts)
	return tile


func _fill_modes(profile: Dictionary, today: String) -> void:
	_modes = GridContainer.new()
	_modes.name = "Modes"
	_modes.tooltip_text = tr("events.modes")
	_modes.columns = 2 if NavShell.wide(safe) else 1
	_modes.add_theme_constant_override("h_separation", 8)
	_modes.add_theme_constant_override("v_separation", 8)
	_modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_modes)
	for m: Dictionary in Modes.MODES:
		var mode: StringName = m["id"]
		if not Modes.available(mode):
			continue
		var open := Modes.unlocked(profile, mode)
		var banner := ModeBanner.new(mode, tr("mode." + String(mode)), tr("mode.%s_desc" % mode), open)
		_modes.add_child(banner)
		if mode == &"currents":
			var rule := UiTheme.label(tr("events.mutator") % tr("mutator." + String(
					Modes.current_mutator(LiveOps.week_of(today)))), UiTheme.SMALL_SIZE, Color("9cc0ff"), true)
			banner.body.add_child(rule)
			banner.body.move_child(rule, 2)
		if not open:
			var need := MapScreen.node_label(Economy.node(StringName(String(MODE_HINT[mode]))))
			banner.set_status(tr("events.locked") % need, Color("ff8fa3"), &"lock")
			continue
		_mode_status(banner, profile, mode, today)
		banner.button.pressed.connect(_press.bind(func() -> void:
			if mode == &"practice":
				navigate.emit(&"practice")
			else:
				play_mode.emit(mode)))


## Estado do modo aberto: Prática chama para escolher missão; o Diário diz se ainda vale hoje (com a
## bolinha) ou o placar de hoje; os outros, o recorde.
func _mode_status(banner: ModeBanner, profile: Dictionary, mode: StringName, today: String) -> void:
	if mode == &"practice":
		banner.set_status(tr("events.practice"), UiTheme.WHITE, &"play")
		return
	var best := int((profile.get("mode_best", {}) as Dictionary).get(String(mode), 0))
	banner.button.tooltip_text = tr("events.play_mode") % Locale.format_number(best)
	if mode == &"daily":
		var daily: Dictionary = profile["daily"]
		var done := String(daily.get("date", "")) == today and bool(daily.get("attempted", false))
		if done:
			banner.set_status(tr("events.daily_done") % Locale.format_number(int(daily["best_score"])), UiTheme.MINT,
					&"check")
		else:
			banner.set_status(tr("events.today"), UiTheme.GOLD, &"star")
		banner.set_notice(Notices.daily_event_open(profile, today))
		return
	if best > 0:
		banner.set_status(tr("events.best") % Locale.format_number(best), UiTheme.WHITE, &"star")
	else:
		banner.set_status(tr("events.play"), UiTheme.WHITE, &"play")


## Tarefas compactas: uma linha por tarefa — ícone, texto e barra fina, e à direita a fração, o
## "Resgatar" dourado (pronta) ou o visto menta (resgatada).
func _fill_tasks(profile: Dictionary, kind: String) -> void:
	var list: Array = LiveOps.state(profile)[kind]
	_section(tr("events." + kind))
	var box := card(UiTheme.CYAN, null, 0.8)
	box.add_theme_constant_override("separation", 7)
	(box.get_parent() as PanelContainer).get_theme_stylebox("panel").set("content_margin_top", 8)
	for i: int in range(list.size()):
		var t := list[i] as Dictionary
		var goal := int(t["goal"])
		var have := mini(int(t["progress"]), goal)
		var claimed := bool(t["claimed"])
		var done := not claimed and LiveOps.done(t)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var mark := glyph(&"check" if claimed else (&"star" if done else &"ring"),
				UiTheme.MINT if claimed else (UiTheme.GOLD if done else UiTheme.CYAN), 12)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		var name := UiTheme.label(tr("task." + String(t["id"])) % goal, UiTheme.SMALL_SIZE,
				UiTheme.TEXT_DIM if claimed else UiTheme.TEXT, true)
		col.add_child(name)
		if not claimed:
			var b := bar(col, float(have), float(goal), UiTheme.MINT if done else UiTheme.CYAN)
			b.custom_minimum_size.y = 5
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
			b.custom_minimum_size.y = UiTheme.TOUCH_MIN
		else:
			var score := UiTheme.label("%d/%d" % [have, goal], UiTheme.SMALL_SIZE, UiTheme.CYAN)
			_bold(score)
			score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# Coluna fixa: as barras de todas as tarefas terminam no mesmo ponto.
			score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			score.custom_minimum_size = Vector2(UiTheme.scaled(44), 0)
			row.add_child(score)


## Bolinha "!" no canto de um cartão: numa camada comum por cima (o PanelContainer esticaria a bolinha).
static func _dot_on(panel: Control) -> void:
	var layer := Control.new()
	layer.name = "NoticeLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(layer)
	CommandKit.notice_dot(layer)


## Faixa de seção em chevron, com um respiro acima quando não é a primeira.
func _section(value: String) -> void:
	if _list.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 2)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(gap)
	var r := CommandKit.ribbon(value)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(r)
