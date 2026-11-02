extends Node
## Capturas da partida para revisão visual (não é teste de aprovação). Sem --headless:
##   godot --path . res://tests/game_shots_runner.tscn -- --shots=<pasta> [--at=12,50,100] [--res=305x678]
##     [--mission=c1m1] [--speed=3] [--zoom=4] [--lang=de] [--radio=thalassa_hello]
## O bot joga em velocidade acelerada; em cada segundo de jogo pedido grava <pasta>/game_<s>_<res>.png.
## --radio abre essa fala de data/dialogue.json no rádio meio segundo antes de cada captura (retrato com efeito).
##
## Poderes (.ai/08-poderes-das-naves.md): `--powers[=falcon,manta]` voa uma partida por nave (todas, ou as
## pedidas) e lança os Poderes I, II e III em CASTS segundos, gravando cada um no auge (PEAKS: passos depois
## do lançamento) em <pasta>/power_<id>_<passo>_<res>.png; antes do Poder III grava o medidor cheio
## (meter_<nave>_<res>.png). Entre os lançamentos a Corrente fica abaixo de 1 segmento (o bot não gasta).

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const GAME := preload("res://scenes/game/Game.tscn")
## Segundos de jogo em que saem os Poderes I, II e III de cada nave.
const CASTS: Array[float] = [9.0, 17.0, 26.0]
## Passos depois do lançamento em que cada poder está no auge (padrão: 30).
const PEAKS := {
	&"falcon_1": [5], &"falcon_2": [20], &"falcon_3": [22, 42],
	&"manta_1": [8], &"manta_2": [60], &"manta_3": [60],
	&"hydra_1": [25], &"hydra_2": [35], &"hydra_3": [80],
	&"tempest_1": [4], &"tempest_2": [60], &"tempest_3": [62],
	&"trident_1": [35], &"trident_2": [60], &"trident_3": [70],
	&"atlas_1": [40], &"atlas_2": [40], &"atlas_3": [40],
	&"ram_1": [30], &"ram_2": [12], &"ram_3": [40, 100],
	&"swarm_1": [60], &"swarm_2": [60], &"swarm_3": [40],
	&"eclipse_1": [40], &"eclipse_2": [60], &"eclipse_3": [60, 116],
	&"nova_1": [60], &"nova_2": [20], &"nova_3": [42, 64],
	&"titan_1": [22], &"titan_2": [60], &"titan_3": [50],
	&"ascension_1": [6], &"ascension_2": [25], &"ascension_3": [60],
}
## Segundos antes do Poder III em que a Corrente enche (o halo do nível III aparece na captura do medidor).
const METER_LEAD := 1.0

var _shots: Array[float] = []
var _out: String = ""
var _label: String = ""
var _radio: String = ""
var _radio_at: float = -1.0
var _game: Game
var _mission: StringName = &"c1m1"
var _zoom: int = 2
var _view := Vector2(305, 678)
## Modo poderes: naves que faltam, a nave da vez, o próximo lançamento e as capturas pendentes (passo, id).
var _powers := false
var _ships: Array[StringName] = []
var _ship: StringName = &""
var _cast: int = 0
var _cast_frame: int = -1
var _pending: Array[Array] = []
var _meter_done := false
var _busy := false


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	InputSetup.ensure_actions()
	var res := "305x678"
	var only := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--at="):
			for s: String in arg.trim_prefix("--at=").split(",", false):
				_shots.append(float(s))
		elif arg.begins_with("--res="):
			res = arg.trim_prefix("--res=")
		elif arg.begins_with("--zoom="):
			_zoom = int(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--radio="):
			_radio = arg.trim_prefix("--radio=")
		elif arg.begins_with("--mission="):
			_mission = StringName(arg.trim_prefix("--mission="))
		elif arg.begins_with("--lang="):
			Locale.set_language(arg.trim_prefix("--lang="), false)
		elif arg == "--powers" or arg.begins_with("--powers="):
			_powers = true
			only = arg.trim_prefix("--powers").trim_prefix("=")
	if _shots.is_empty():
		_shots = [6.0, 30.0, 52.0, 70.0, 110.0, 150.0]
	DirAccess.make_dir_recursive_absolute(_out)
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		if r["label"] == res:
			_view = r["view"]
	_label = res
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(_view) * _zoom)
	await get_tree().create_timer(0.3).timeout
	get_tree().root.get_node(^"PixelScaler").call("_apply")
	if _powers:
		for row: Variant in DB.rows("ships"):
			var id := StringName(String((row as Dictionary)["id"]))
			if only.is_empty() or id in only.split(",", false):
				_ships.append(id)
		_next_ship()
		return
	_game = GAME.instantiate() as Game
	_game.configure(_mission, &"falcon", 7, true)
	add_child(_game)


func _process(_delta: float) -> void:
	if _game == null or _busy:
		return
	if _powers:
		_process_powers()
		return
	if _shots.is_empty():
		return
	if not _radio.is_empty() and _radio_at != _shots[0] and _game.sim.frame >= int((_shots[0] - 0.5) * 60.0):
		_radio_at = _shots[0]
		_game.hud().show_radio(_radio)
	if _game.sim.frame >= int(_shots[0] * 60.0) or _game.sim.finished:
		var at := _shots.pop_front() as float
		await _capture("%s/game_%03d_%s.png" % [_out, int(at), _label])
		if _shots.is_empty() or _game.sim.finished:
			_quit()


func _next_ship() -> void:
	if _game != null:
		# A partida que sai pausa o GameClock ao deixar a árvore: ela sai antes de a próxima entrar.
		_busy = true
		_game.queue_free()
		_game = null
		await get_tree().process_frame
		_busy = false
	if _ships.is_empty():
		_quit()
		return
	_ship = _ships.pop_front()
	_cast = 0
	_cast_frame = int(CASTS[0] * 60.0)
	_pending.clear()
	_game = GAME.instantiate() as Game
	_game.configure(_mission, _ship, 7, true)
	add_child(_game)


## Um quadro do modo poderes: segura a Corrente, lança na hora marcada e grava os auges.
func _process_powers() -> void:
	var sim := _game.sim
	if sim.finished or not sim.player.alive:
		_next_ship()
		return
	var frame := sim.frame
	if _cast < CASTS.size() and sim.power_fx.is_empty():
		var tier := _cast + 1
		var meter := tier == 3 and frame >= _cast_frame - int(METER_LEAD * 60.0)
		sim.player.power_charge = Powers.SEGMENTS if meter else 0.9
		if meter and not _meter_done and frame >= _cast_frame - 6:
			_meter_done = true
			await _capture("%s/meter_%s_%s.png" % [_out, _ship, _label])
			return
	if _cast < CASTS.size() and frame >= _cast_frame:
		var tier := _cast + 1
		sim.power_fx.clear()
		sim.player.power_charge = float(tier)
		sim.powers.press(sim, true)
		var id := StringName("%s_%d" % [_ship, tier])
		for peak: int in PEAKS.get(id, [30]):
			_pending.append([frame + peak, id, peak])
		_cast += 1
		_meter_done = false
		_cast_frame = int(CASTS[_cast] * 60.0) if _cast < CASTS.size() else -1
	if not _pending.is_empty() and frame >= int(_pending[0][0]):
		var shot: Array = _pending.pop_front()
		await _capture("%s/power_%s_%03d_%s.png" % [_out, shot[1], int(shot[2]), _label])
		return
	if _cast >= CASTS.size() and _pending.is_empty():
		_next_ship()


func _capture(path: String) -> void:
	_busy = true
	GameClock.paused = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	GameClock.paused = false
	_busy = false


func _quit() -> void:
	SpriteBank.clear()
	get_tree().quit(0)
