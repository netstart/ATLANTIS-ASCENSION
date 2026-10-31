class_name EventsScreen
extends ListScreen
## Aba Eventos (plano mestre 4.11 e 7.2): sequência de login, tarefas diárias e semanais com resgate,
## Núcleo de Oricalco e os modos (Arcade, Desafio Diário, Sobrevivência, Boss Rush, Prática) com o
## recorde de cada um e o motivo quando ainda está fechado.

const MODE_HINT := {&"arcade": "c2m3", &"daily": "c2m1", &"survival": "c4m1", &"boss_rush": "c9m3",
		&"practice": "c1m1", &"currents": "c3m2", &"second_tide": "c9m3",
		&"abyss": "c7m1"}


func title_key() -> String:
	return "hub.tab_events"


func show_wallet() -> bool:
	return true


func _fill() -> void:
	var profile := SaveManager.data
	LiveOps.refresh(profile, App.today())
	var lg: Dictionary = profile["login"]
	add_heading(tr("events.login") % [int(lg.get("streak", 0)), LiveOps.LOGIN_REWARDS.size()])
	add_text(tr("events.shield") % int(lg.get("shields_left", 0)), UiTheme.TEXT_DIM)
	_fill_tasks(profile, "daily")
	_fill_tasks(profile, "weekly")
	var core := int(LiveOps.state(profile)["core"])
	add_heading(tr("events.core") % [mini(core, LiveOps.CORE_MAX), LiveOps.CORE_MAX])
	add_button(tr("events.core_open"), func() -> void:
		if not LiveOps.open_core(SaveManager.data).is_empty():
			AudioManager.play_ui("kenney_weapon_up")
			SaveManager.save_profile(), LiveOps.core_ready(profile), "OpenCore")
	var tier := Season.tier(profile, App.today())
	add_heading(tr("events.season") % [Season.id_for(App.today()), tier, Season.TIERS])
	add_button(tr("events.season_open"), func() -> void: navigate.emit(&"season"), true, "Season")
	add_button(tr("events.records"), func() -> void: navigate.emit(&"records"), true, "Records")
	add_heading(tr("events.modes"))
	for m: Dictionary in Modes.MODES:
		var mode: StringName = m["id"]
		var best := int((profile.get("mode_best", {}) as Dictionary).get(String(mode), 0))
		add_text("%s · %s" % [tr("mode." + String(mode)), tr("mode.%s_desc" % mode)], UiTheme.TEXT_DIM)
		if mode == &"currents":
			add_text(tr("events.mutator") % tr("mutator." + String(Modes.current_mutator(LiveOps.week_of(App.today())))),
					UiTheme.CYAN)
		if not Modes.unlocked(profile, mode):
			var need := MapScreen.node_label(Economy.node(StringName(String(MODE_HINT[mode]))))
			add_text("◇ " + tr("events.locked") % need, UiTheme.CORAL)
			continue
		if mode == &"practice":
			add_button(tr("events.practice"), func() -> void: navigate.emit(&"practice"), true, "Mode_practice")
			continue
		var label := tr("events.play_mode") % Locale.format_number(best)
		var enabled := true
		if mode == &"daily":
			var daily: Dictionary = profile["daily"]
			var done := String(daily.get("date", "")) == App.today() and bool(daily.get("attempted", false))
			label = tr("events.daily_done") % Locale.format_number(int(daily["best_score"])) if done else label
		add_button(label, func() -> void: play_mode.emit(mode), enabled, "Mode_" + String(mode))


func _fill_tasks(profile: Dictionary, kind: String) -> void:
	var list: Array = LiveOps.state(profile)[kind]
	add_heading(tr("events." + kind))
	for i: int in range(list.size()):
		var t := list[i] as Dictionary
		var text := tr("task." + String(t["id"])) % int(t["goal"])
		var progress := "%d/%d" % [mini(int(t["progress"]), int(t["goal"])), int(t["goal"])]
		if bool(t["claimed"]):
			add_text("◆ %s · %s" % [text, tr("events.claimed")], UiTheme.GOLD)
		elif LiveOps.done(t):
			add_button("%s · %s" % [text, tr("events.claim")], func() -> void:
				LiveOps.claim(SaveManager.data, kind, i)
				AudioManager.play_ui("kenney_ui_confirm")
				SaveManager.save_profile(), true, "Claim_%s_%d" % [kind, i])
		else:
			add_text("◇ %s · %s" % [text, progress], UiTheme.TEXT)
