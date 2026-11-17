extends Node
## Capturas de um poder para revisão visual (não é teste de aprovação). Sem --headless:
##   godot --path . res://tests/power_shots_runner.tscn -- --shots=<pasta> [--power=falcon_3] [--weapon=pulsar]
##     [--level=4] [--at=20,40,170,320,334]
## Abre uma partida da nave do poder com o relógio parado, voa 5 s, põe a nave no meio de baixo do campo com a
## arma e o nível pedidos, lança o poder e grava <pasta>/<poder>_<arma><nível>_<passo>.png em cada passo pedido
## depois do lançamento (a nave atira o tempo todo e fica invulnerável; o desenho anda 1/60 s por passo).

const GAME := preload("res://scenes/game/Game.tscn")
const DeviceWindow := preload("res://tests/device_window.gd")
const VIEW := Vector2(305, 678)
const ZOOM := 2

var _out := ""
var _power: StringName = &"falcon_3"
var _weapon: StringName = &"pulsar"
var _level := 4
var _at: Array[int] = [20, 40, 170, 320, 334]


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	InputSetup.ensure_actions()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--power="):
			_power = StringName(arg.trim_prefix("--power="))
		elif arg.begins_with("--weapon="):
			_weapon = StringName(arg.trim_prefix("--weapon="))
		elif arg.begins_with("--level="):
			_level = int(arg.trim_prefix("--level="))
		elif arg.begins_with("--at="):
			_at.clear()
			for s: String in arg.trim_prefix("--at=").split(",", false):
				_at.append(int(s))
	DirAccess.make_dir_recursive_absolute(_out)
	await DeviceWindow.fit(self, Vector2i(VIEW) * ZOOM)
	var def := DB.row("powers", _power)
	var game := GAME.instantiate() as Game
	game.configure(&"c1m2", StringName(String(def.get("ship", "falcon"))), 7, true)
	add_child(game)
	await get_tree().process_frame
	game.relayout_for(VIEW)
	GameClock.paused = true
	var sim := game.sim
	sim.player.invuln = 1 << 24
	for k: int in range(300):
		sim.step(SimInput.new())
	sim.player.weapon = _weapon
	sim.player.level = _level
	sim.power_fx.clear()
	sim.powers.cast(sim, _power, int(def.get("tier", 1)))
	var step := 0
	for at: int in _at:
		while step < at:
			sim.player.pos = Vector2(sim.field.x * 0.5, sim.field.y * 0.78)
			sim.step(SimInput.new())
			step += 1
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s%d_%03d.png" % [_out, _power, _weapon, _level, at])
	SpriteBank.clear()
	get_tree().quit(0)
