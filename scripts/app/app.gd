class_name App
extends Node
## Raiz do jogo: monta a camada de interface com o tema, troca de tela (com histórico para o
## "voltar"), inicia e encerra missões e grava o progresso. As telas pedem navegação pelo sinal
## Screen.navigate e missões pelo Screen.play.
##
## Linha de comando (depois de "--"): --bot ou --mission=<id> começa direto na missão (sem menus),
## com --seed=N; o resto é lido pela própria cena Game.

const GAME_SCENE := preload("res://scenes/game/Game.tscn")
const SCREENS := {
	&"boot": preload("res://scripts/app/screens/boot_screen.gd"),
	&"hub": preload("res://scripts/app/screens/hub_screen.gd"),
	&"map": preload("res://scripts/app/screens/map_screen.gd"),
	&"results": preload("res://scripts/app/screens/results_screen.gd"),
	&"credits": preload("res://scripts/app/screens/credits_screen.gd"),
	&"hangar": preload("res://scripts/app/screens/hangar_screen.gd"),
	&"ships": preload("res://scripts/app/screens/ships_screen.gd"),
	&"options": preload("res://scripts/app/screens/options_screen.gd"),
	&"logbook": preload("res://scripts/app/screens/logbook_screen.gd"),
	&"story": preload("res://scripts/app/screens/story_screen.gd"),
	&"events": preload("res://scripts/app/screens/events_screen.gd"),
	&"shop": preload("res://scripts/app/screens/shop_screen.gd"),
	&"city": preload("res://scripts/app/screens/city_screen.gd"),
	&"practice": preload("res://scripts/app/screens/practice_screen.gd"),
	&"season": preload("res://scripts/app/screens/season_screen.gd"),
	&"records": preload("res://scripts/app/screens/records_screen.gd"),
}
const ROOT_SCREEN := &"boot"

## Data de hoje "AAAA-MM-DD" (os testes fixam um calendário).
static var today_override: String = ""

var current: StringName = &""
var game: Game
var last_result: Dictionary = {}
## Corrida de um modo (Arcade, Boss Rush, Diário, Sobrevivência) ou &"" na campanha; &"practice" não paga.
var run_mode: StringName = &""
var run_queue: Array[Dictionary] = []
var run_score: int = 0
var _run_loadout: Dictionary = {}
var _pending_replay: Replay
var _replay_return: StringName = &""

var _layer: CanvasLayer
var _root: Control
var _screens: Dictionary = {}
var _history: Array[StringName] = []


func _ready() -> void:
	InputSetup.ensure_actions()
	TouchScroll.install(get_tree())
	_layer = CanvasLayer.new()
	add_child(_layer)
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.text_scale = float(Settings.get_value("text_scale"))
	_root.theme = UiTheme.build(Locale.font)
	_layer.add_child(_root)
	Settings.changed.connect(_on_setting_changed)
	Locale.language_changed.connect(_on_language_changed)
	var args := OS.get_cmdline_user_args()
	var mission := ""
	var seed := 7
	for arg: String in args:
		if arg.begins_with("--mission="):
			mission = arg.trim_prefix("--mission=")
		elif arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
	if "--bot" in args or not mission.is_empty():
		# Carga padrão: a partida da linha de comando não depende do save (hash reproduzível).
		play(StringName(mission if not mission.is_empty() else "c1m1"), "--bot" in args, seed,
				Sim.default_loadout(&"falcon"))
		return
	go(ROOT_SCREEN)


func go(screen_name: StringName, remember: bool = true) -> void:
	if screen_name == &"back":
		go(_history.pop_back() if not _history.is_empty() else ROOT_SCREEN, false)
		return
	if not SCREENS.has(screen_name):
		Log.error("App: tela desconhecida " + String(screen_name))
		return
	if remember and not current.is_empty() and current != screen_name:
		_history.append(current)
		if screen_name == ROOT_SCREEN:
			_history.clear()
	for key: StringName in _screens:
		(_screens[key] as Control).visible = key == screen_name
	if not _screens.has(screen_name):
		var screen := (SCREENS[screen_name] as GDScript).new() as Screen
		screen.name = String(screen_name).capitalize().replace(" ", "")
		screen.navigate.connect(go)
		screen.play.connect(_play_from_screen)
		screen.play_mode.connect(func(mode: StringName) -> void: start_mode(mode))
		screen.play_practice.connect(practice)
		if screen.has_signal("watch"):
			screen.connect("watch", func(key: String) -> void: watch_replay(key))
		_root.add_child(screen)
		_screens[screen_name] = screen
	current = screen_name
	(_screens[screen_name] as Screen).on_show(self)
	Events.screen_changed.emit(screen_name)


## Jogar pedido por uma tela: "Tentar de novo" no resultado de um modo recomeça o modo; o resto é campanha.
func _play_from_screen(mission_id: StringName) -> void:
	if current == &"results" and run_mode not in [&"", &"practice"]:
		start_mode(run_mode)
		return
	if current == &"results" and String(last_result.get("mode", "")) == "practice":
		practice(mission_id)
		return
	run_mode = &""
	play(mission_id)


static func today() -> String:
	return today_override if not today_override.is_empty() else Time.get_date_string_from_system()


## Começa um modo: monta a fila (Modes.run) e joga a primeira missão. Arcade, Boss Rush e Diário usam a
## aeronave escolhida sem o hangar (todos em pé de igualdade); a Sobrevivência usa o hangar.
func start_mode(mode: StringName, bot: bool = false) -> void:
	run_mode = mode
	run_score = 0
	run_queue = Modes.run(mode, SaveManager.data, today(), Modes.date_seed(today()))
	_run_loadout = Modes.loadout_for(mode, SaveManager.data, today())
	_next_in_run(bot)


## Assiste a um replay gravado (recorde de uma missão ou modo); ao fim volta para a tela de onde veio.
func watch_replay(key: String) -> bool:
	var r := Replay.load_key(key)
	if r == null:
		return false
	_replay_return = current
	run_mode = &""
	_pending_replay = r
	play_mission(r.mission, false, r.seed, r.loadout)
	return true


## Prática: missão concluída sem recompensas (nem estrelas nem moedas).
func practice(mission_id: StringName) -> void:
	run_mode = &"practice"
	run_queue = []
	run_score = 0
	play(mission_id)


func _next_in_run(bot: bool = false) -> void:
	var mission: Dictionary = run_queue.pop_front()
	play_mission(mission, bot, Modes.date_seed(today()) % 100000 if run_mode == &"daily" else -1, _run_loadout)


## Inicia uma missão: esconde os menus e cria a cena Game.
func play(mission_id: StringName, bot: bool = false, seed: int = -1, loadout: Dictionary = {}) -> void:
	play_mission(Sim.load_mission(mission_id), bot, seed, loadout)


## Inicia uma missão a partir do dicionário (data/stages ou montada pelos Modes).
func play_mission(mission: Dictionary, bot: bool = false, seed: int = -1, loadout: Dictionary = {}) -> void:
	if game != null:
		game.queue_free()
	_layer.visible = false
	game = GAME_SCENE.instantiate() as Game
	var run_seed := seed if seed >= 0 else int(Time.get_unix_time_from_system()) % 100000
	game.configure(mission, loadout if not loadout.is_empty() else Economy.loadout(SaveManager.data), run_seed, bot)
	game.can_revive = not bot and run_mode in [&"", &"survival", &"abyss"]
	if not bot and bool(Settings.get_value("ghost")) and run_mode in [&"", &"practice"]:
		game.ghost = Replay.load_key(Replay.key_for(String(mission.get("id", "")), ""))
	if _pending_replay != null:
		game.playback = _pending_replay
		_pending_replay = null
	game.finished.connect(_on_mission_finished)
	add_child(game)
	AudioManager.play_ui("kenney_ui_confirm")


func _on_mission_finished(result: Dictionary) -> void:
	var mission_id := StringName(String(result.get("mission", "")))
	var recording := game.recording
	game.queue_free()
	game = null
	_layer.visible = true
	if bool(result.get("replay", false)):
		AudioManager.play_music("")
		go(_replay_return if _replay_return != &"" else &"records")
		return
	if bool(result.get("restart", false)):
		if run_mode in [&"", &"practice"]:
			play(mission_id)
		else:
			start_mode(run_mode)
		return
	if bool(result.get("quit", false)):
		AudioManager.play_music("")
		var back_to := &"events" if run_mode not in [&"", &"practice"] else &"map"
		run_mode = &""
		go(back_to)
		return
	run_score += int(result.get("score", 0))
	if run_mode not in [&"", &"practice"] and bool(result.get("cleared", false)) and not run_queue.is_empty():
		_next_in_run()
		return
	result["mode"] = String(run_mode)
	result["run_score"] = run_score
	last_result = record_result(result, run_mode)
	_save_record(result, recording)
	run_mode = &"" if run_mode == &"practice" else run_mode
	go(&"results")


## Grava o resultado no save (Economy.apply_result: estrelas, recorde, moedas, fragmentos, asas,
## missões abertas, registros) e as estatísticas; devolve o resultado com as recompensas.
static func record_result(result: Dictionary, mode: StringName = &"") -> Dictionary:
	var out := result.duplicate(true)
	if mode == &"":
		out = Economy.apply_result(SaveManager.data, result, DB.rows("ships"), DB.rows("wings"))
	elif mode != &"practice":
		out = Modes.apply_result(SaveManager.data, mode, result)
	if mode != &"practice":
		LiveOps.refresh(SaveManager.data, today())
		LiveOps.track(SaveManager.data, out)
		out["season_xp"] = Season.add_result(SaveManager.data, today(), out)
		out["achievements"] = Achievements.check(SaveManager.data, out)
	SaveManager.add_stat("missions_played", 1)
	SaveManager.add_stat("kills", float(result.get("kills", 0)))
	SaveManager.add_stat("grazes", float(result.get("grazes", 0)))
	SaveManager.add_stat("bombs_used", float(result.get("bombs_used", 0)))
	SaveManager.add_stat("time_played", float(result.get("seconds", 0.0)))
	if bool(result.get("cleared", false)):
		SaveManager.add_stat("missions_cleared", 1)
	else:
		SaveManager.add_stat("deaths", 1)
	SaveManager.save_profile()
	for ship: Variant in out.get("new_ships", []):
		SaveManager.unlocked.emit("ships", StringName(String(ship)))
	return out


## Placar local e replay do recorde (missões avulsas: campanha, Diário, Correntes, Sobrevivência).
func _save_record(result: Dictionary, recording: Replay) -> void:
	if run_mode in [&"practice", &"arcade", &"boss_rush", &"second_tide"] or recording == null:
		return
	var key := Replay.key_for(String(result.get("mission", "")), String(run_mode))
	var pos := Replay.submit(SaveManager.data, key, int(result.get("score", 0)), today(),
			String(SaveManager.data["selected"]["ship"]))
	last_result["board_pos"] = pos
	if pos == 0:
		recording.score = int(result.get("score", 0))
		recording.save(key)
	SaveManager.save_profile()


## Tela já criada (testes).
func screen(screen_name: StringName) -> Screen:
	return _screens.get(screen_name) as Screen


## Raiz das telas (testes ajustam o tamanho para simular cada aparelho).
func root() -> Control:
	return _root


func back() -> void:
	if game != null:
		game.set_paused(not game.paused)
		return
	var screen := screen(current)
	if screen != null and screen.back():
		return
	if current != ROOT_SCREEN:
		go(&"back")
		return
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func _unhandled_input(event: InputEvent) -> void:
	if game == null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui("kenney_ui_back")
		back()


## Escala de texto nova: recria as telas (os rótulos guardam o tamanho) e volta para a mesma tela.
func _on_setting_changed(key: String) -> void:
	if key != "text_scale":
		return
	UiTheme.text_scale = float(Settings.get_value("text_scale"))
	_root.theme = UiTheme.build(Locale.font)
	var here := current
	for screen: Node in _screens.values():
		screen.queue_free()
	_screens.clear()
	current = &""
	go(here, false)


func _on_language_changed(_code: String) -> void:
	_root.theme = UiTheme.build(Locale.font)
