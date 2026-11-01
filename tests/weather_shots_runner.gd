extends Node
## Galeria do clima para revisão visual (não é teste de aprovação). Sem --headless:
##   godot --path . res://tests/weather_shots_runner.tscn -- --shots=<pasta> [--only=storm,silt] [--res=305x678]
## Para cada estado de data/weather.json abre uma missão do cenário certo, deixa o bot voar, força o
## clima no auge (mistura 1) e grava <pasta>/weather_<id>.png; na tempestade, com um relâmpago.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const GAME := preload("res://scenes/game/Game.tscn")
## Missão de cada estado (o cenário dela tem o meio do clima).
const MISSION_OF := {"clear": "c3m2", "clouds": "c5m1", "rain": "c3m2", "storm": "c3m2", "eye": "c3m2",
		"snow": "c6m2", "blizzard": "c6m2", "ash": "c4m1", "jetstream": "c7m1", "calm": "c1m1", "plankton": "c1m1",
		"surge": "c1m2", "thermocline": "c2m1", "silt": "c1m3", "abyssal": "c10m1", "vents": "c10m1",
		"storm_above": "c2m3", "vacuum": "c8m1", "solar": "c8m1"}
## Segundos de voo antes de forçar o clima, e quanto ele fica no auge antes da foto.
const WARMUP := 9.0
const HOLD := 1.6

var _out: String = ""
var _ids: Array[String] = []


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	InputSetup.ensure_actions()
	var res := "305x678"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--only="):
			for id: String in arg.trim_prefix("--only=").split(",", false):
				_ids.append(id)
		elif arg.begins_with("--res="):
			res = arg.trim_prefix("--res=")
	if _ids.is_empty():
		for id: String in MISSION_OF:
			_ids.append(id)
	DirAccess.make_dir_recursive_absolute(_out)
	var view := Vector2(305, 678)
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		if r["label"] == res:
			view = r["view"]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(view) * 2)
	await get_tree().create_timer(0.3).timeout
	get_tree().root.get_node(^"PixelScaler").call("_apply")
	for id: String in _ids:
		await _shoot(id)
	SpriteBank.clear()
	get_tree().quit(0)


func _shoot(id: String) -> void:
	var game := GAME.instantiate() as Game
	game.configure(StringName(String(MISSION_OF.get(id, "c1m1"))), &"falcon", 7, true)
	add_child(game)
	GameClock.time_scale = 3.0
	while game.sim.frame < int(WARMUP * 60.0) and not game.sim.finished:
		await get_tree().process_frame
	var w := game.sim.weather
	w.state = StringName(id)
	w.previous = StringName(id)
	w.pending = &""
	w.blend = 1.0
	var until := game.sim.frame + int(HOLD * 60.0)
	while game.sim.frame < until and not game.sim.finished:
		await get_tree().process_frame
	if float(w.fx("flashes")) > 0.0:
		game.weather_view().flash_now()
		await get_tree().process_frame
	GameClock.paused = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/weather_%s.png" % [_out, id])
	GameClock.time_scale = 1.0
	game.queue_free()
	await get_tree().process_frame
	GameClock.paused = false
