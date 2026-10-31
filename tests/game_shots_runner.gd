extends Node
## Capturas da partida para revisão visual (não é teste de aprovação). Sem --headless:
##   godot --path . res://tests/game_shots_runner.tscn -- --shots=<pasta> [--at=12,50,100] [--res=305x678]
##     [--mission=c1m1] [--speed=3] [--zoom=4]
## O bot joga em velocidade acelerada; em cada segundo de jogo pedido grava <pasta>/game_<s>_<res>.png.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const GAME := preload("res://scenes/game/Game.tscn")

var _shots: Array[float] = []
var _out: String = ""
var _label: String = ""
var _game: Game


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	InputSetup.ensure_actions()
	var mission := &"c1m1"
	var res := "305x678"
	var zoom := 2
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--at="):
			for s: String in arg.trim_prefix("--at=").split(",", false):
				_shots.append(float(s))
		elif arg.begins_with("--res="):
			res = arg.trim_prefix("--res=")
		elif arg.begins_with("--zoom="):
			zoom = int(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--mission="):
			mission = StringName(arg.trim_prefix("--mission="))
	if _shots.is_empty():
		_shots = [6.0, 30.0, 52.0, 70.0, 110.0, 150.0]
	DirAccess.make_dir_recursive_absolute(_out)
	var view := Vector2(305, 678)
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		if r["label"] == res:
			view = r["view"]
	_label = res
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(view) * zoom)
	await get_tree().create_timer(0.3).timeout
	get_tree().root.get_node(^"PixelScaler").call("_apply")
	_game = GAME.instantiate() as Game
	_game.configure(mission, &"falcon", 7, true)
	add_child(_game)


func _process(_delta: float) -> void:
	if _game == null or _shots.is_empty():
		return
	if _game.sim.frame >= int(_shots[0] * 60.0) or _game.sim.finished:
		var at := _shots.pop_front() as float
		GameClock.paused = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/game_%03d_%s.png" % [_out, int(at), _label])
		GameClock.paused = false
		if _shots.is_empty() or _game.sim.finished:
			SpriteBank.clear()
			get_tree().quit(0)
