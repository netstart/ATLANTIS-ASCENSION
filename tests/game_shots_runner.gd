extends Node
## Capturas da partida para revisão visual (não é teste de aprovação). Sem --headless:
##   godot --path . res://tests/game_shots_runner.tscn -- --shots=<pasta> [--at=12,50,100] [--res=305x678]
##     [--mission=c1m1] [--speed=3] [--zoom=4] [--lang=de] [--radio=thalassa_hello] [--cutout] [--turbo] [--left]
## --cutout simula o furo da câmera da resolução em cima (área segura); --turbo mostra o botão Turbo (1,5x);
## --left põe os botões na mão esquerda. --paint=paint_solar voa com essa pintura (rastro, tiro e estouro); --ship=<id>
## voa com essa nave (as premium, por exemplo); --level=<1..10> veste a nave com as peças desse nível do hangar.
## --rev=1 joga com as regras de uma revisão antiga da Sim (SimRevision), para
## comparar antes e depois. --window=1102x874 usa uma janela física qualquer (fora da tabela), com a
## tela lógica que o PixelScaler der para ela.
## O bot joga em velocidade acelerada; em cada segundo de jogo pedido grava <pasta>/game_<s>_<res>.png.
## --radio abre essa fala de data/dialogue.json no rádio meio segundo antes de cada captura (retrato com efeito).
##
## Poderes (.ai/08-poderes-das-naves.md): `--powers[=falcon,manta]` voa uma partida por nave (todas, ou as
## pedidas) e lança os Poderes I, II e III em CASTS segundos, gravando cada um no auge (PEAKS: passos depois
## do lançamento) em <pasta>/power_<id>_<passo>_<res>.png; antes do Poder III grava o medidor cheio
## (meter_<nave>_<res>.png). Entre os lançamentos a Corrente fica abaixo de 1 segmento (o bot não gasta).
##
## Mortes (CombatFx): `--deaths` no primeiro segundo de --at para a Sim e faz morrer, lado a lado, um inimigo em
## cada estilo (explosão, derretimento, queda; em cima pequenos, embaixo grandes), gravando o meio de cada um em
## DEATH_SHOTS segundos: <pasta>/deaths_<missão>_<ms>_<res>.png. Use --mission para o mar (c1m1), o chão (c4m1)
## e o espaço (c8m1, onde a queda vira outro estilo).
##
## Objetivos de fase (SimObjectives): `--objectives` joga a missão inteira e grava cada objetivo no aviso, com os alvos
## marcados, com os atlantes nas bolhas (resgate) e na fala do fim:
## <pasta>/objective_<missão>_<n>_<tipo>_<momento>_<res>.png.
##
## Caixas de colisão (Hitboxes, revisão 5): `--hitboxes` liga o desenho dos círculos da Sim (WorldView.debug_hitboxes:
## dano em ciano, contato em laranja, partes em verde, ponto da nave em branco). Com --at grava a partida com eles;
## sem --at, no segundo 4 grava as galerias: todos os inimigos em grade
## (<pasta>/hitbox_enemies_<n>_<res>.png), cada chefe diferente no meio do campo (hitbox_boss_<id>_<res>.png) e cada
## nave do jogador (hitbox_ship_<id>_<res>.png). Use --zoom=4 para ver de perto.
##
## Feixes inimigos (HostileBeams, EnemyBeam): `--beams[=N]` joga a missão e grava os N primeiros feixes de padrão
## (padrão 4) no meio do aviso e aceso: <pasta>/beam_<missão>_<n>_<warn|lit>_<res>.png. `--beam-boss=<id>` só grava
## os feixes da luta com esse chefe; `--beam-phase=<etapa>` ainda adianta a luta até essa etapa (tira vida do chefe na
## hora, só para a captura): os drones do Sky Leviathan com
## --mission=c5m3s --beam-boss=sky_leviathan --beam-phase=storm.
## Secundária (SecondaryFire, revisão 10): `--secondary=missiles:5` (ou drones:N) voa com essa secundária presa no
## nível N da fase (1 a 5) durante toda a partida, para ver mísseis, ogivas e drones de cada nível.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const DeviceWindow := preload("res://tests/device_window.gd")
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
## Momentos (s depois das mortes) gravados no modo --deaths.
const DEATH_SHOTS: Array[float] = [0.1, 0.3, 0.55, 0.85, 1.15, 1.45]
const DEATH_STYLES: Array[StringName] = [CombatFx.EXPLODE, CombatFx.MELT, CombatFx.FALL]

var _shots: Array[float] = []
var _out: String = ""
var _label: String = ""
var _radio: String = ""
var _radio_at: float = -1.0
var _game: Game
var _mission: StringName = &"c1m1"
var _zoom: int = 2
var _view := Vector2(305, 678)
var _turbo := false
## Revisão da Sim pedida por --rev (0 = a atual).
var _rev: int = 0
## Pintura pedida por --paint ("" = a original da nave).
var _paint: String = ""
## Modo poderes: naves que faltam, a nave da vez, o próximo lançamento e as capturas pendentes (passo, id).
var _powers := false
var _ships: Array[StringName] = []
var _ship: StringName = &""
## Nave da partida das capturas (--ship=<id>).
var _play_ship: StringName = &"falcon"
## Nível do hangar da nave (--level=1..10: peças da evolução, ShipLivery); 0 = o da carga padrão.
var _level: int = 0
## Secundária e nível na fase pedidos por --secondary (0 = a da carga, sem prender o nível).
var _secondary: StringName = &""
var _secondary_level: int = 0
var _cast: int = 0
var _cast_frame: int = -1
var _pending: Array[Array] = []
var _meter_done := false
var _busy := false
## Modo mortes: ligado, mortes já lançadas e o relógio desde elas.
var _deaths := false
var _deaths_t: float = -1.0
## Modo objetivos: ligado, momentos já gravados ("<n>_<momento>") e o passo em que o último objetivo terminou.
var _objectives := false
## Modo caixas de colisão (--hitboxes) e se as galerias (sem --at) já começaram.
var _hitboxes := false
var _gallery := false
## Modo --beams: quantos feixes ainda gravar (0 = desligado) e quantos já gravou.
var _beams := 0
var _beam_n := 0
var _beam_seen := {}
## Modo --beams com --beam-boss: só a luta com este chefe (vazio = todos os feixes).
var _beam_boss := ""
## Modo --beams com --beam-phase: etapa do chefe a que a luta é adiantada.
var _beam_phase := ""
var _obj_taken: Dictionary = {}
var _obj_end_frame: int = -1
var _obj_results: int = 0


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	InputSetup.ensure_actions()
	var res := "305x678"
	var only := ""
	var cutout := false
	var window := Vector2i.ZERO
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
		elif arg.begins_with("--rev="):
			_rev = int(arg.trim_prefix("--rev="))
		elif arg.begins_with("--mission="):
			_mission = StringName(arg.trim_prefix("--mission="))
		elif arg.begins_with("--lang="):
			Locale.set_language(arg.trim_prefix("--lang="), false)
		elif arg == "--powers" or arg.begins_with("--powers="):
			_powers = true
			only = arg.trim_prefix("--powers").trim_prefix("=")
		elif arg.begins_with("--window="):
			var wh := arg.trim_prefix("--window=").split("x")
			window = Vector2i(int(wh[0]), int(wh[1]))
		elif arg == "--cutout":
			cutout = true
		elif arg == "--turbo":
			_turbo = true
		elif arg.begins_with("--ship="):
			_play_ship = StringName(arg.trim_prefix("--ship="))
		elif arg.begins_with("--paint="):
			_paint = arg.trim_prefix("--paint=")
		elif arg.begins_with("--level="):
			_level = int(arg.trim_prefix("--level="))
		elif arg.begins_with("--secondary="):
			var pick := arg.trim_prefix("--secondary=").split(":")
			_secondary = StringName(pick[0])
			_secondary_level = clampi(int(pick[1]) if pick.size() > 1 else 1, 1, SecondaryFire.MAX_LEVEL)
		elif arg == "--deaths":
			_deaths = true
		elif arg == "--objectives":
			_objectives = true
		elif arg == "--hitboxes":
			_hitboxes = true
		elif arg == "--beams" or arg.begins_with("--beams="):
			_beams = maxi(1, int(arg.trim_prefix("--beams").trim_prefix("="))) if "=" in arg else 4
			_shots = [9999.0]
		elif arg.begins_with("--beam-phase="):
			_beam_phase = arg.trim_prefix("--beam-phase=")
		elif arg.begins_with("--beam-boss="):
			_beam_boss = arg.trim_prefix("--beam-boss=")
		elif arg == "--left":
			Settings.set_value("handedness", "left")
	_gallery = _hitboxes and _shots.is_empty()
	if _shots.is_empty():
		_shots = [6.0, 30.0, 52.0, 70.0, 110.0, 150.0]
	if _objectives:
		_shots = [0.0]
	DirAccess.make_dir_recursive_absolute(_out)
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		if r["label"] == res:
			_view = r["view"]
			if cutout and DeviceProfiles.is_portrait(r):
				DeviceProfiles.simulate_insets(Vector4(0.0, DeviceProfiles.cutout_logical(r), 0.0, 0.0))
	_label = res
	if window != Vector2i.ZERO:
		_view = Vector2(PixelScaler.logical_for(window))
		_label = "win%dx%d" % [window.x, window.y]
	await DeviceWindow.fit(self, window if window != Vector2i.ZERO else Vector2i(_view) * _zoom)
	if _powers:
		for row: Variant in DB.rows("ships"):
			var id := StringName(String((row as Dictionary)["id"]))
			if only.is_empty() or id in only.split(",", false):
				_ships.append(id)
		_next_ship()
		return
	_game = GAME.instantiate() as Game
	var load: Variant = _play_ship
	if _rev > 0 or not _paint.is_empty() or _level > 0 or _secondary != &"":
		load = Sim.default_loadout(_play_ship)
		load["secondary"] = String(_secondary)
		if _level > 0:
			load["ship_level"] = _level
		if _rev > 0:
			load["rev"] = _rev
		load["cosmetic"] = _paint
	_game.configure(_mission, load, 7, true)
	_game.screen = _view
	add_child(_game)
	if _turbo:
		_game.hud().set_turbo(true, 1.5)


func _process(_delta: float) -> void:
	if _game == null or _busy:
		return
	if _secondary_level > 0 and _game.sim != null:
		_game.sim.secondary_level = _secondary_level
	if _powers:
		_process_powers()
		return
	if _objectives:
		_process_objectives()
		return
	if _shots.is_empty():
		return
	if _beams > 0:
		_process_beams()
		return
	if _deaths:
		_process_deaths(_delta)
		return
	if _hitboxes:
		(_game.find_children("*", "WorldView", true, false)[0] as WorldView).debug_hitboxes = true
		if _gallery:
			if _game.sim.frame >= 4 * 60:
				_busy = true
				await _hitbox_gallery()
				_quit()
			return
	if not _radio.is_empty() and _radio_at != _shots[0] and _game.sim.frame >= int((_shots[0] - 0.5) * 60.0):
		_radio_at = _shots[0]
		_game.hud().show_radio(_radio)
	if _game.sim.frame >= int(_shots[0] * 60.0) or _game.sim.finished:
		var at := _shots.pop_front() as float
		# Segundos quebrados (--at=221.5) ganham a casa decimal no nome, para não sobrescrever o segundo inteiro.
		var tag := "%03d" % int(at) if is_equal_approx(at, roundf(at)) else "%05.1f" % at
		await _capture("%s/game_%s_%s.png" % [_out, tag, _label])
		if _shots.is_empty() or _game.sim.finished:
			_quit()


## Modo --beams: grava cada feixe de padrão no meio do aviso e 10 passos depois de acender.
func _process_beams() -> void:
	var boss := _game.sim.boss
	if not _beam_boss.is_empty() and (boss == null or String(boss.id) != _beam_boss):
		if _game.sim.finished:
			_quit()
		return
	if not _beam_phase.is_empty() and boss != null and boss.fighting() and String(boss.phase_id()) != _beam_phase:
		var index := boss.phase_index
		while boss.fighting() and boss.phase_index == index:
			boss.damage_body(boss.max_hp * 0.02, _game.sim)
		return
	for b: Dictionary in _game.sim.beams:
		if not HostileBeams.pattern(b):
			continue
		var age := int(b["age"])
		var warn := int(b["warn"])
		# O bot joga acelerado (vários passos por quadro): grava na primeira vez que passa de cada momento.
		var key := "%d:%s" % [_game.sim.frame - age, str(b.get("off", b["x"]))]
		var moment := ""
		if age >= warn + 10 and not _beam_seen.has(key + "lit"):
			moment = "lit"
		elif age >= warn * 0.5 and age < warn and not _beam_seen.has(key + "warn"):
			moment = "warn"
		if moment.is_empty():
			continue
		_beam_seen[key + moment] = true
		_busy = true
		GameClock.paused = true
		await _capture("%s/beam_%s_%d_%s_%s.png" % [_out, _mission, _beam_n, moment, _label])
		GameClock.paused = false
		_busy = false
		if moment == "lit":
			_beam_n += 1
			if _beam_n >= _beams:
				_quit()
		return
	if _game.sim.finished:
		_quit()


## Modo --deaths: no segundo pedido para a Sim (o desenho segue), mata um de cada estilo e grava os momentos.
func _process_deaths(delta: float) -> void:
	var world := _game.find_children("*", "WorldView", true, false)[0] as WorldView
	if _deaths_t < 0.0:
		if _game.sim.frame < int(_shots[0] * 60.0):
			return
		GameClock.paused = true
		_deaths_t = 0.0
		for k: int in range(DEATH_STYLES.size()):
			world.kill_fx(Vector2(50 + 85 * k, 150), &"klaed_fighter", false, 100, DEATH_STYLES[k], 1.0, 0)
			world.kill_fx(Vector2(50 + 85 * k, 290), &"nairan_frigate", true, 400, DEATH_STYLES[k], 1.0, 1)
		return
	_deaths_t += delta
	var shots: Array[float] = []
	shots.assign(DEATH_SHOTS)
	var i := int(world.get_meta(&"death_shot", 0))
	if i >= shots.size():
		_quit()
		return
	if _deaths_t >= shots[i]:
		world.set_meta(&"death_shot", i + 1)
		_busy = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/deaths_%s_%04d_%s.png" % [_out, _mission,
				int(shots[i] * 1000.0), _label])
		_busy = false


## Galerias do modo --hitboxes: o campo limpo e cada nave posta à mão no campo, com os círculos (_hitbox_shot).
func _hitbox_gallery() -> void:
	var sim := _game.sim
	var world := _game.find_children("*", "WorldView", true, false)[0] as WorldView
	var tables := sim.tables
	var enemies: Array = (tables["enemies"] as Dictionary).keys()
	var per_page := 15
	for page: int in range(ceili(enemies.size() / float(per_page))):
		var placed: Array[SimEnemy] = []
		for k: int in range(per_page):
			var i := page * per_page + k
			if i >= enemies.size():
				break
			var e := SimEnemy.new()
			var at := Vector2(45.0 + 90.0 * (k % 3), 70.0 + 110.0 * (k / 3))
			e.setup(tables["enemies"][enemies[i]], at, &"straight", {}, tables["patterns"], false)
			e.fit(Hitboxes.find(tables, sim.loadout, "enemies", e.id))
			e.runner = null
			e.max_hp = 1.0e9
			e.hp = e.max_hp
			placed.append(e)
		await _hitbox_shot("%s/hitbox_enemies_%d_%s.png" % [_out, page + 1, _label], placed, null)
	var seen := {}
	for id: StringName in tables["bosses"]:
		var def: Dictionary = tables["bosses"][id]
		var sig := "%s|%s|%s" % [def.get("sprite", ""), def.get("scale", 1.0), (def.get("parts", []) as Array).size()]
		if seen.has(sig):
			continue
		seen[sig] = true
		var b := SimBoss.new()
		b.setup(def, tables["patterns"], 1.0e6)
		b.fit(Hitboxes.find(tables, sim.loadout, "bosses", id))
		await _hitbox_shot("%s/hitbox_boss_%s_%s.png" % [_out, id, _label], [], b)
	for id: StringName in tables["ships"]:
		sim.player.ship = tables["ships"][id]
		sim.player.hitbox = float(sim.player.ship.get("hitbox", 3.0))
		sim.player.hit_offset = Vector2.ZERO
		sim.player.fit(Hitboxes.find(tables, sim.loadout, "ships", id))
		world.set("_art", SpriteBank.player(id))
		world.touching = true
		await _hitbox_shot("%s/hitbox_ship_%s_%s.png" % [_out, id, _label], [], null)


## Segura a cena por alguns quadros com a Sim andando (o desenho só acompanha a Sim viva): a cada quadro tira balas e
## coletáveis, devolve os inimigos e o chefe ao lugar e a nave ao meio, e então grava.
func _hitbox_shot(path: String, placed: Array, boss: SimBoss) -> void:
	var sim := _game.sim
	for k: int in range(12):
		sim.enemies.assign(placed)
		for e: SimEnemy in placed:
			e.pos = e.origin
			e.frames = 0
			e.alive = true
		sim.boss = boss
		if boss != null:
			boss.pos = Vector2(sim.field.x * 0.5, sim.field.y * 0.38)
			boss.state = SimBoss.State.FIGHT
			boss.hp = boss.max_hp
		sim.enemy_bullets.clear()
		sim.player_bullets.clear()
		sim.pickups.clear()
		sim.beams.clear()
		sim.missiles.clear()
		sim.power_fx.clear()
		sim.player.pos = Vector2(sim.field.x * 0.5, sim.field.y * (0.5 if placed.is_empty() and boss == null else 0.9))
		sim.player.invuln = 1 << 20
		await RenderingServer.frame_post_draw
	sim.player.invuln = 0
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	# O quadro da própria partida (o SubViewport do aparelho), não o da janela.
	_game.get_viewport().get_texture().get_image().save_png(path)


## Modo --objectives: grava os momentos de cada objetivo de fase; sai quando a missão acaba.
func _process_objectives() -> void:
	var sim := _game.sim
	var obj := sim.objectives
	if sim.finished:
		_quit()
		return
	if obj.results.size() > _obj_results:
		_obj_results = obj.results.size()
		_obj_end_frame = sim.frame
	var moment := ""
	var n := obj.next if not obj.current.is_empty() else obj.results.size()
	var kind := String(obj.current.get("type", obj.results[-1]["type"] if not obj.results.is_empty() else ""))
	if not obj.current.is_empty():
		var frames := int(obj.current["frames"])
		if frames >= 45 and not _obj_taken.has("%d_warn" % n):
			moment = "warn"
		elif frames >= SimObjectives.WARN_FRAMES + 70 and not _obj_taken.has("%d_target" % n):
			moment = "target"
		elif not obj.survivors.is_empty() and int(obj.survivors[0]["frames"]) >= 50 \
				and not _obj_taken.has("%d_bubbles" % n):
			moment = "bubbles"
	elif _obj_end_frame >= 0 and sim.frame >= _obj_end_frame + 24 and not _obj_taken.has("%d_end" % n):
		moment = "end"
	if moment.is_empty():
		return
	_obj_taken["%d_%s" % [n, moment]] = true
	await _capture("%s/objective_%s_%d_%s_%s_%s.png" % [_out, _mission, n, kind, moment, _label])


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
	_game.screen = _view
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
