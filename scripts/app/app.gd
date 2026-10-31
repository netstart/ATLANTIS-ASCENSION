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
}
const ROOT_SCREEN := &"boot"
## Créditos por missão (plano mestre 18.1): base + pontuação / 2.000 + 25 por estrela nova.
const CREDITS_BASE := 50
const CREDITS_PER_SCORE := 2000
const CREDITS_PER_STAR := 25

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
		play(StringName(mission if not mission.is_empty() else "c1m1"), "--bot" in args, seed)
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
func play(mission_id: StringName, bot: bool = false, seed: int = -1) -> void:
	if game != null:
		game.queue_free()
	_layer.visible = false
	game = GAME_SCENE.instantiate() as Game
	var run_seed := seed if seed >= 0 else int(Time.get_unix_time_from_system()) % 100000
	game.configure(mission_id, StringName(String(SaveManager.data["selected"]["ship"])), run_seed, bot)
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


## Grava o resultado no save (melhor pontuação, estrelas somadas, créditos) e devolve o resultado com
## os campos de recompensa: credits, new_stars, record.
static func record_result(result: Dictionary) -> Dictionary:
	var out := result.duplicate(true)
	var record := SaveManager.mission_record(StringName(String(result.get("mission", ""))))
	var stars: Array = record["stars"]
	var got: Array = result.get("stars", [false, false, false, false])
	var fresh := 0
	for i: int in range(mini(stars.size(), got.size())):
		if bool(got[i]) and not bool(stars[i]):
			stars[i] = true
			fresh += 1
	var score := int(result.get("score", 0))
	out["record"] = score > int(record["best_score"])
	record["best_score"] = maxi(int(record["best_score"]), score)
	if bool(result.get("cleared", false)):
		record["cleared"] = true
	var credits := CREDITS_BASE + floori(score / float(CREDITS_PER_SCORE)) + CREDITS_PER_STAR * fresh
	SaveManager.add_currency("credits", credits)
	SaveManager.add_stat("missions_played", 1)
	SaveManager.add_stat("kills", float(result.get("kills", 0)))
	SaveManager.add_stat("grazes", float(result.get("grazes", 0)))
	if bool(result.get("cleared", false)):
		SaveManager.add_stat("missions_cleared", 1)
	else:
		SaveManager.add_stat("deaths", 1)
	SaveManager.save_profile()
	out["credits"] = credits
	out["new_stars"] = fresh
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
