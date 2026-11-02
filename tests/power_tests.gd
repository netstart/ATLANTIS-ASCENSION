extends RefCounted
## Poderes das naves (.ai/08-poderes-das-naves.md; scripts/sim/powers.gd e power_effects.gd), regras puras e
## sem autoloads: dados dos 36 poderes, medidor de Corrente, escolha do nível, cada poder (age, mede e termina
## limpo), teto de dano no chefe, determinismo, replay com PODER e o bot usando poderes. Chamado por
## tests/run_tests.gd.

## Missão vazia: nenhum inimigo do roteiro atrapalha a medida.
const EMPTY := {"id": "power_test", "events": []}
const MAX_STEPS := 1500
const BOT_FRAMES := 90 * 60
const BOSS_ID := &"leviathan_protocol"
## Chefe sem partes para o teto: a parte destruída tira um bloco de vida de uma vez e só adianta o relógio.
const CAP_BOSS := &"storm_eye"

var _tables: Dictionary = {}


func run_unit(check: Callable) -> void:
	_tables = Sim.load_tables()
	_data(check)
	_meter(check)
	_tiers(check)
	_each_power(check)
	_boss_cap(check)
	_determinism(check)


## Unidade pesada (tests/test_shard.gd): 90 s do bot duas vezes, com replay gravado e reproduzido.
func units() -> Array[Dictionary]:
	return [{"name": "Poderes: bot, determinismo e replay", "weight": 90.0 * 3.0, "run": _bot_and_replay}]


func _sim(ship: StringName, seed: int = 5) -> Sim:
	if _tables.is_empty():
		_tables = Sim.load_tables()
	var sim := Sim.new()
	sim.setup(EMPTY, _tables, Sim.default_loadout(ship), seed)
	return sim


## Passo sem tiro e sem movimento (só o poder age).
func _idle(fire: bool = false) -> SimInput:
	var input := SimInput.new()
	input.fire = fire
	return input


## Inimigo parado, ativo e com muita vida, em `at`.
func _dummy(sim: Sim, at: Vector2, hp: float = 5000.0) -> SimEnemy:
	sim.spawn_enemy({"enemy": "skiff", "x": 0.5, "y": 0.0}, 0)
	var e: SimEnemy = sim.enemies[-1]
	e.pos = at
	e.origin = at
	e.params = {"speed": 0.0}
	e.depth = 1.0
	e.entered = true
	e.runner = null
	e.hp = hp
	e.max_hp = hp
	return e


func _data(check: Callable) -> void:
	var powers: Dictionary = _tables.get("powers", {})
	var errors := Powers.validate(powers, _tables["ships"])
	check.call(errors.is_empty(), "Poderes: data/powers.json válido (%s)" % [errors])
	check.call(powers.size() == 36, "Poderes: 36 poderes (%d)" % powers.size())
	var types := {}
	for id: StringName in powers:
		var def: Dictionary = powers[id]
		check.call(String(def.get("icon", "")) == "res://assets/art/generated/powers/icons/power_%s.png" % id
				and String(def.get("sfx", "")) == "power_%s" % id, "Poderes: ícone e som de %s no contrato" % id)
		for fx: Variant in def.get("effects", []):
			types[StringName(String((fx as Dictionary).get("type", "")))] = true
	check.call(types.size() == Powers.TYPES.size(), "Poderes: as 20 primitivas são usadas (%d)" % types.size())
	var broken := {"falcon_1": powers.get(&"falcon_1", {}).duplicate(true)}
	(broken["falcon_1"] as Dictionary)["effects"] = [{"type": "teleport"}]
	check.call(not Powers.validate(broken, {&"falcon": _tables["ships"][&"falcon"]}).is_empty(),
			"Poderes: efeito desconhecido e nível faltando reprovam")


func _meter(check: Callable) -> void:
	var sim := _sim(&"falcon")
	for k: int in range(Powers.TIME_FRAMES):
		sim.step(_idle())
	var segs := 0
	for ev: Dictionary in sim.take_events():
		if ev["type"] == &"power_charge":
			segs = int(ev["segments"])
	check.call(sim.powers.segments(sim) == 1 and segs == 1, "Corrente: 1 segmento a cada 14 s (%.3f)" %
			sim.player.power_charge)
	var g := _sim(&"falcon")
	for k: int in range(100):
		g.powers.on_graze(g)
	check.call(is_equal_approx(g.player.power_charge, 100 * Powers.GRAZE), "Corrente: +0,004 por graze")
	var k := _sim(&"falcon")
	var common := _dummy(k, Vector2(135, 200), 3.0)
	k.powers.on_kill(k, common)
	check.call(is_equal_approx(k.player.power_charge, Powers.KILL_COMMON), "Corrente: +0,06 por inimigo comum")
	var elite := _dummy(k, Vector2(100, 200), 120.0)
	k.powers.on_kill(k, elite)
	check.call(is_equal_approx(k.player.power_charge, Powers.KILL_COMMON + Powers.KILL_ELITE),
			"Corrente: +0,25 por elite")
	var b := SimBoss.new()
	b.setup((_tables["bosses"] as Dictionary)[&"mid_harpoon_trawler"], _tables["patterns"])
	var before := k.player.power_charge
	k.powers.on_boss_defeated(k, b)
	check.call(is_equal_approx(k.player.power_charge - before, Powers.KILL_MINIBOSS), "Corrente: +0,5 por miniboss")
	for n: int in range(2000):
		k.powers.on_graze(k)
	check.call(is_equal_approx(k.player.power_charge, Powers.SEGMENTS), "Corrente: para em 3 segmentos")
	# Chefe de ato: +0,02 a cada 1% de vida tirada.
	var f := _sim(&"falcon")
	f.spawn_boss(BOSS_ID, true)
	for n: int in range(SimBoss.ENTER_FRAMES + 2):
		f.step(_idle())
	var charge := f.player.power_charge
	f.boss.damage_body(f.boss.max_hp * 0.1 / float(f.boss.phase().get("armor", 1.0)), f)
	f.step(_idle())
	check.call(absf(f.player.power_charge - charge - 0.2 - 1.0 / Powers.TIME_FRAMES) < 0.002,
			"Corrente: chefe dá +0,02 por 1%% (%.3f)" % (f.player.power_charge - charge))
	# Durante um poder não enche.
	var a := _sim(&"eclipse")
	a.player.power_charge = 1.0
	var input := _idle()
	input.power = true
	a.step(input)
	var during := a.player.power_charge
	a.powers.on_graze(a)
	a.step(_idle())
	check.call(a.powers.active(a) and is_equal_approx(a.player.power_charge, during),
			"Corrente: não enche com poder vivo")


func _tiers(check: Callable) -> void:
	for t: Array in [[1.4, 1, 0.4], [2.5, 2, 0.5], [3.0, 3, 0.0]]:
		var sim := _sim(&"falcon")
		sim.player.power_charge = float(t[0])
		var input := _idle()
		input.power = true
		sim.step(input)
		var id := ""
		for ev: Dictionary in sim.take_events():
			if ev["type"] == &"power":
				id = String(ev["id"])
		check.call(id == "falcon_%d" % int(t[1]) and is_equal_approx(sim.player.power_charge, float(t[2])),
				"Corrente: %.1f lança o Poder %d e sobra %.1f (%s)" % [t[0], t[1], t[2], id])
	var empty := _sim(&"falcon")
	empty.player.power_charge = 0.7
	check.call(empty.powers.preview_id(empty) == &"", "Corrente: sem segmento cheio, nada a lançar")
	var input := _idle()
	input.power = true
	empty.step(input)
	var got := false
	for ev: Dictionary in empty.take_events():
		got = got or ev["type"] == &"power_empty"
	check.call(got and not empty.powers.active(empty), "Corrente: apertar sem carga avisa e não lança")
	empty.player.power_charge = 2.2
	check.call(empty.powers.preview_id(empty) == &"falcon_2", "Corrente: o HUD sabe o poder que sairia")


## Cada um dos 36 poderes: lança, faz algo medível e termina limpo.
func _each_power(check: Callable) -> void:
	for id: StringName in _tables["powers"]:
		var def: Dictionary = _tables["powers"][id]
		_one_power(check, id, StringName(String(def["ship"])), int(def["tier"]))


func _one_power(check: Callable, id: StringName, ship: StringName, tier: int) -> void:
	var sim := _sim(ship)
	sim.player.hull = sim.player.max_hull - 1
	var foes: Array[SimEnemy] = [_dummy(sim, Vector2(135, 340)), _dummy(sim, Vector2(110, 270)),
			_dummy(sim, Vector2(165, 210))]
	var hp_before := 0.0
	for e: SimEnemy in foes:
		hp_before += e.hp
	var level := sim.player.level
	sim.player.power_charge = float(tier)
	var input := _idle()
	input.power = true
	var m := {"slow": false, "frozen": false, "drones": 0, "boost": false, "invuln": true, "end": false, "echo": ""}
	var bullets := 0
	var steps := 0
	while steps < MAX_STEPS:
		# Chuva de balas vindo de cima na direção da nave: escudos, ondas e anéis têm o que apagar.
		if steps % 6 == 0 and steps < 600:
			for x: float in [95.0, 135.0, 175.0]:
				sim.fire_enemy(Vector2(x, 250), 90.0, 70.0, 1, 0.0, 0.0)
				bullets += 1
		sim.step(input)
		input = _idle()
		steps += 1
		if steps > 30:
			# Depois da invulnerabilidade de saída a nave não cai: o teste mede o poder até o fim.
			sim.player.invuln = maxi(sim.player.invuln, 2)
		m["slow"] = bool(m["slow"]) or sim.powers.time_scale < 1.0
		m["frozen"] = bool(m["frozen"]) or sim.powers.frozen
		for fx: Dictionary in sim.power_fx:
			if fx["type"] == &"drones":
				m["drones"] = maxi(int(m["drones"]), (fx["points"] as PackedVector2Array).size())
		m["boost"] = bool(m["boost"]) or sim.powers.rate > 1.0 or sim.powers.crit > 0.0 or sim.powers.pierce > 0 \
				or sim.powers.kill_blast_radius > 0.0
		if steps <= 30 and not sim.player.invuln > 0:
			m["invuln"] = false
		for ev: Dictionary in sim.take_events():
			if ev["type"] == &"power_end":
				m["end"] = true
			elif ev["type"] == &"power":
				m["echo"] = String(ev["echo"])
		if not sim.powers.active(sim) and steps > 2:
			break
	var hp_after := 0.0
	for e: SimEnemy in foes:
		hp_after += e.hp if e.alive else 0.0
	var dealt := hp_before - hp_after
	var pearls := 0
	for pk: Dictionary in sim.pickups:
		if pk["kind"] == &"pearl":
			pearls += 1
	var healed := sim.player.hull == sim.player.max_hull
	var did := dealt > 1.0 or pearls > 0 or bool(m["slow"]) or bool(m["frozen"]) or int(m["drones"]) > 0 \
			or bool(m["boost"]) or healed
	check.call(did, "Poder %s: age (dano %.0f, pérolas %d, lento %s, congela %s, drones %d, reforço %s)" % [id, dealt,
			pearls, m["slow"], m["frozen"], m["drones"], m["boost"]])
	check.call(bool(m["invuln"]), "Poder %s: invulnerável na saída" % id)
	check.call(sim.power_fx.is_empty() and bool(m["end"]) and steps < MAX_STEPS,
			"Poder %s: termina limpo em %d passos" % [id, steps])
	check.call(sim.powers.rate == 1.0 and sim.powers.dmg == 1.0 and sim.powers.time_scale == 1.0
			and not sim.powers.frozen and sim.powers.pierce == 0
			and sim.powers.crit == 0.0 and sim.powers.kill_blast_radius == 0.0 and sim.player.level <= maxi(level, 1),
			"Poder %s: nenhum modificador sobra depois" % id)
	if id == &"ascension_1":
		check.call(String(m["echo"]).ends_with("_1") and String(m["echo"]) != "ascension_1",
				"Poder ascension_1: ecoa o Poder I da nave do rodízio (%s)" % m["echo"])
	if id == &"atlas_3":
		check.call(healed, "Poder atlas_3: repara 1 de casco")


## Nenhum poder tira mais que o teto do nível (3%, 5%, 8%) da vida do chefe, com a arma no máximo e atirando.
## Compara a mesma luta com e sem o poder, até 1 s depois de ele acabar (tiros no ar já chegaram).
func _boss_cap(check: Callable) -> void:
	for id: StringName in _tables["powers"]:
		var def: Dictionary = _tables["powers"][id]
		var tier := int(def["tier"])
		var ship := StringName(String(def["ship"]))
		var with := _boss_run(ship, id, -1)
		var base := _boss_run(ship, &"", int(with["steps"]))
		var extra := float(with["taken"]) - float(base["taken"])
		check.call(extra <= Powers.BOSS_CAP[tier] * 1.05 + 0.002,
				"Poder %s: no chefe tira %.1f%% (teto %.0f%%)" % [id, extra * 100.0, Powers.BOSS_CAP[tier] * 100.0])


## Fração da vida do chefe tirada com o poder `id` lançado no começo da luta (até 60 passos depois do fim) ou,
## sem poder, em `steps` passos.
func _boss_run(ship: StringName, id: StringName, steps: int) -> Dictionary:
	var sim := _sim(ship, 3)
	sim.player.level = sim.player.max_level()
	sim.spawn_boss(CAP_BOSS, false)
	while sim.boss != null and not sim.boss.fighting():
		sim.step(_idle())
	var spot := Vector2(sim.boss.body_pos().x, 330)
	var start := sim.boss.hp
	var max_hp := sim.boss.max_hp
	if id != &"":
		sim.powers.cast(sim, id, int(_tables["powers"][id]["tier"]))
	var k := 0
	var after := 0
	while (steps < 0 and after < 60 and k < MAX_STEPS) or k < steps:
		sim.player.invuln = 60
		# Nave fixa: a investida não aproxima a arma do chefe (só o dano do poder entra na conta).
		sim.player.pos = spot
		sim.step(_idle(true))
		k += 1
		if not sim.powers.active(sim):
			after += 1
	var hp := sim.boss.hp if sim.boss != null else 0.0
	return {"taken": (start - hp) / max_hp, "steps": k}


## Mesma semente e mesma entrada, com poderes no meio: mesmo estado.
func _determinism(check: Callable) -> void:
	var hashes: Array[String] = []
	for run: int in range(2):
		var sim := _sim(&"tempest", 9)
		for n: int in range(3):
			_dummy(sim, Vector2(80 + n * 50, 200))
		for k: int in range(900):
			var input := _idle(true)
			input.axis = Vector2(sin(k * 0.05), 0.0)
			if k % 200 == 10:
				sim.player.power_charge = 1.0 + float(k / 200 % 3)
				input.power = true
			if k % 50 == 0:
				sim.fire_enemy(Vector2(135, 40), 90.0 + float(k % 40), 90.0, 0, 0.0, 0.0)
			sim.step(input)
			sim.take_events()
		hashes.append(sim.state_hash())
	check.call(hashes[0] == hashes[1], "Poderes: mesma semente e mesma entrada, mesmo estado")


## O bot joga 90 s da 1-1 (usa os poderes): duas vezes dá o mesmo hash, e o replay gravado reproduz igual.
func _bot_and_replay(check: Callable) -> void:
	var mission := Sim.load_mission(&"c1m1")
	var loadout := Sim.default_loadout(&"falcon")
	var runs: Array[Dictionary] = []
	for run: int in range(2):
		var sim := Sim.new()
		sim.setup(mission, Sim.load_tables(), loadout, 7)
		var rec := Replay.new(mission, 7, loadout)
		var bot := BotPilot.new()
		var presses := 0
		while not sim.finished and sim.frame < BOT_FRAMES:
			var input := bot.decide(sim)
			presses += 1 if input.power else 0
			rec.record(input)
			sim.step(input)
			sim.take_events()
		runs.append({"hash": sim.state_hash(), "casts": sim.powers.casts, "presses": presses, "rec": rec})
	check.call(runs[0]["hash"] == runs[1]["hash"], "Poderes: o bot joga igual com a mesma semente")
	check.call(int(runs[0]["casts"]) > 0, "Poderes: o bot usa o PODER (%d vezes em 90 s)" % runs[0]["casts"])
	var rec: Replay = runs[0]["rec"]
	var json := JSON.new()
	json.parse(JSON.stringify(rec.to_dict(), "", false, true))
	var loaded := Replay.from_dict(json.data)
	var again := loaded.make_sim()
	var input: SimInput = loaded.next_input()
	var presses := 0
	while input != null and not again.finished:
		presses += 1 if input.power else 0
		again.step(input)
		again.take_events()
		input = loaded.next_input()
	check.call(presses == int(runs[0]["presses"]) and again.state_hash() == runs[0]["hash"],
			"Replay: grava o PODER e reproduz o mesmo estado (%d toques)" % presses)
