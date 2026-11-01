extends Node
## Benchmark da partida (docs/policies/testes.md). Sem --headless e sem VSync:
##   godot --path . res://tests/game_bench.tscn -- [--strict] [--res=305x678] [--stress=1000] [--seconds=20]
##     [--mission=c1m1] [--weather=storm]
## O bot joga a missão (padrão 1-1) com `stress` balas inimigas vivas (além das da fase) na qualidade Alta, com a
## nave no nível do hangar `--level` (padrão: o máximo, a Ascendida, que desenha todas as peças e o rastro).
## `--weather` força um clima de data/weather.json no auge desde o começo (o pior caso de desenho é a tempestade:
## nuvens nas duas camadas, chuva, relâmpagos).
## Critério com --strict: p95 ≤ 8 ms e nenhum quadro > 33 ms depois do aquecimento.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const GAME := preload("res://scenes/game/Game.tscn")
const WARMUP := 90
const P95_MAX := 8.0
const WORST_MAX := 33.4

var _game: Game
var _stats := FrameStats.new()
var _frames: int = 0
var _seconds: float = 20.0
var _strict: bool = false
var _sim_ms := PackedFloat32Array()
var _weather: StringName = &""


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	InputSetup.ensure_actions()
	GfxQuality.set_override(GfxQuality.HIGH)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var res := "305x678"
	var level := Economy.SHIP_MAX_LEVEL
	var mission := &"c1m1"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--res="):
			res = arg.trim_prefix("--res=")
		elif arg.begins_with("--level="):
			level = clampi(int(arg.trim_prefix("--level=")), 1, Economy.SHIP_MAX_LEVEL)
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--mission="):
			mission = StringName(arg.trim_prefix("--mission="))
		elif arg.begins_with("--weather="):
			_weather = StringName(arg.trim_prefix("--weather="))
	_strict = "--strict" in OS.get_cmdline_user_args()
	var view := Vector2(305, 678)
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		if r["label"] == res:
			view = r["view"]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(view) * 2)
	await get_tree().create_timer(0.3).timeout
	get_tree().root.get_node(^"PixelScaler").call("_apply")
	_game = GAME.instantiate() as Game
	var loadout := Sim.default_loadout(&"falcon")
	loadout["ship_level"] = level
	_game.configure(mission, loadout, 7, true)
	if not "--stress=" in " ".join(OS.get_cmdline_user_args()):
		_game.stress = 1000
	add_child(_game)


func _process(_delta: float) -> void:
	if _game == null:
		return
	_frames += 1
	if _weather != &"":
		var w := _game.sim.weather
		w.state = w.valid(_weather)
		w.previous = w.state
		w.blend = 1.0
	if _frames > WARMUP:
		_stats.tick()
		_sim_ms.append(GameClock.last_sim_ms)
	if _frames > WARMUP + int(_seconds * 60.0) or _game.sim.finished:
		var s := _stats.summary()
		var sim_avg := 0.0
		for v: float in _sim_ms:
			sim_avg += v
		sim_avg /= maxf(1.0, _sim_ms.size())
		var ok := float(s["p95_ms"]) <= P95_MAX and float(s["max_ms"]) <= WORST_MAX
		print("%s partida: %s; simulação média %.2f ms; balas inimigas %d; nave nível %d" % ["ok" if ok else "FALHOU",
				FrameStats.describe(s), sim_avg, _game.sim.enemy_bullets.count, int(_game.sim.loadout.get("ship_level", 1))])
		_game = null
		SpriteBank.clear()
		get_tree().quit(1 if _strict and not ok else 0)
