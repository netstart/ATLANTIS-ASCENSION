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
}
const ROOT_SCREEN := &"boot"

var current: StringName = &""
var game: Game
var last_result: Dictionary = {}

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
	_root.theme = UiTheme.build(Locale.font)
	_layer.add_child(_root)
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
		screen.play.connect(func(mission_id: StringName) -> void: play(mission_id))
		_root.add_child(screen)
		_screens[screen_name] = screen
	current = screen_name
	(_screens[screen_name] as Screen).on_show(self)
	Events.screen_changed.emit(screen_name)


## Inicia uma missão: esconde os menus e cria a cena Game.
func play(mission_id: StringName, bot: bool = false, seed: int = -1, loadout: Dictionary = {}) -> void:
	if game != null:
		game.queue_free()
	_layer.visible = false
	game = GAME_SCENE.instantiate() as Game
	var run_seed := seed if seed >= 0 else int(Time.get_unix_time_from_system()) % 100000
	game.configure(mission_id, loadout if not loadout.is_empty() else Economy.loadout(SaveManager.data), run_seed,
			bot)
	game.finished.connect(_on_mission_finished)
	add_child(game)
	AudioManager.play_ui("kenney_ui_confirm")


func _on_mission_finished(result: Dictionary) -> void:
	var mission_id := StringName(String(result.get("mission", "")))
	game.queue_free()
	game = null
	_layer.visible = true
	if bool(result.get("restart", false)):
		play(mission_id)
		return
	if bool(result.get("quit", false)):
		AudioManager.play_music("")
		go(&"map")
		return
	last_result = record_result(result)
	go(&"results")


## Grava o resultado no save (Economy.apply_result: estrelas, recorde, moedas, fragmentos, asas,
## missões abertas, registros) e as estatísticas; devolve o resultado com as recompensas.
static func record_result(result: Dictionary) -> Dictionary:
	var out := Economy.apply_result(SaveManager.data, result, DB.rows("ships"), DB.rows("wings"))
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
	for ship: StringName in out["new_ships"]:
		SaveManager.unlocked.emit("ships", ship)
	return out


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


func _on_language_changed(_code: String) -> void:
	_root.theme = UiTheme.build(Locale.font)
