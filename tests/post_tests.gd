extends RefCounted
## Pós-lançamento (plano mestre 13, "Pós-lançamento"): aeronaves 7 a 12 com traço próprio que muda o
## disparo, a captura biomecânica (marcado abatido de perto vira escolta por 10 s) e a Ascension aberta
## pelo final verdadeiro. Chamado por tests/integration_tests.gd.

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")
const NEW_SHIPS: Array[StringName] = [&"ram", &"swarm", &"eclipse", &"nova", &"titan", &"ascension"]


func run(check: Callable) -> void:
	var tables := Sim.load_tables()
	_data(check, tables)
	_traits(check, tables)
	_capture(check, tables)
	_unlocks(check, tables)
	_bot_runs(check, tables)
	_portraits(check)
	_abyss(check, tables)
	_hadal(check)


func _sim(tables: Dictionary, ship: StringName, seed: int = 5) -> Sim:
	var sim := Sim.new()
	sim.setup(Sim.load_mission(&"c1m1"), tables, Sim.default_loadout(ship), seed)
	return sim


## Passos com tiro e sem movimento (o roteiro da 1-1 ainda não trouxe inimigos no começo).
func _fire(sim: Sim, steps: int, special: bool = false) -> void:
	for k: int in range(steps):
		var input := SimInput.new()
		input.special = special and k == 0
		sim.step(input)


func _data(check: Callable, tables: Dictionary) -> void:
	var ships: Dictionary = tables["ships"]
	check.call(ships.size() == 12, "Frota: 12 aeronaves (%d)" % ships.size())
	var traits := {}
	for id: StringName in NEW_SHIPS:
		var def: Dictionary = ships.get(id, {})
		check.call(Economy.released(def), "Frota: %s lançada" % id)
		traits[String(def.get("trait", ""))] = true
		for m: Variant in def.get("sources", []):
			check.call(not Economy.node(StringName(String(m))).is_empty(), "Frota: fonte %s de %s existe" % [m, id])
	check.call(traits.size() == 6 and not traits.has(""), "Frota: 6 traços diferentes")


func _traits(check: Callable, tables: Dictionary) -> void:
	var ram := _sim(tables, &"ram")
	_fire(ram, 2)
	check.call(ram.player_bullets.count > 0 and ram.player_bullets.splash[0] >= ShipTraits.ARTILLERY_SPLASH,
			"Ariete: agulha da Railgun com explosão")
	var eclipse := _sim(tables, &"eclipse")
	_fire(eclipse, 2)
	check.call(eclipse.player_bullets.count > 0 and eclipse.player_bullets.pierce[0] >= 1, "Eclipse: Plasma perfurante")
	var nova := _sim(tables, &"nova")
	var falcon := _sim(tables, &"falcon")
	var top := 0.0
	var low := INF
	for k: int in range(300):
		_fire(nova, 1)
		for i: int in range(nova.player_bullets.count):
			top = maxf(top, nova.player_bullets.damage[i])
			low = minf(low, nova.player_bullets.damage[i])
	check.call(top >= low * ShipTraits.CRIT_MULT * 0.99, "Nova: há críticos x2,5 entre os tiros")
	var swarm := _sim(tables, &"swarm")
	_fire(swarm, 2)
	_fire(falcon, 2)
	check.call(swarm.drones.size() == ShipTraits.EXTRA_DRONES and falcon.drones.is_empty(), "Enxame: 2 drones fixos")
	var asc := _sim(tables, &"ascension")
	var kinds: Array[StringName] = []
	for k: int in range(3):
		asc.player.special_charge = 1.0
		_fire(asc, 1, true)
		kinds.append(asc.special_kind)
	check.call(kinds[0] != kinds[1] and kinds[1] != kinds[2], "Ascension: a especial gira (%s)" % [kinds])
	asc.player.collect_orb(&"laser")
	_fire(asc, 1)
	check.call(asc.player.signature == &"laser" and asc.player.max_level() == 4,
			"Ascension: a arma do orbe vira assinatura (nível máximo 4)")
	var titan := _sim(tables, &"titan")
	var e := _enemy_near(titan)
	e.marked = false
	e.hp = 0.01
	var blast := false
	for k: int in range(30):
		titan.step(SimInput.new())
		for ev: Dictionary in titan.take_events():
			blast = blast or (ev["type"] == &"splash" and is_equal_approx(float(ev["radius"]), ShipTraits.BLAST_RADIUS))
	check.call(blast, "Titã: o abate explode em área")


## Inimigo parado logo acima da nave (ativo, sem padrão de tiro relevante).
func _enemy_near(sim: Sim) -> SimEnemy:
	var id: StringName = (sim.tables["enemies"] as Dictionary).keys()[0]
	sim.spawn_enemy({"enemy": String(id), "x": 0.5, "y": 0.0}, 0)
	var e: SimEnemy = sim.enemies[-1]
	e.pos = sim.player.pos + Vector2(0, -30)
	e.origin = e.pos
	e.params = {"speed": 0.0}
	e.depth = 1.0
	e.entered = true
	return e


func _capture(check: Callable, tables: Dictionary) -> void:
	var sim := _sim(tables, &"falcon")
	var e := _enemy_near(sim)
	e.marked = true
	e.hp = 0.01
	var got := false
	for k: int in range(30):
		sim.step(SimInput.new())
		for ev: Dictionary in sim.take_events():
			got = got or ev["type"] == &"capture"
	check.call(got and sim.escorts.size() == 1 and sim.captured == 1, "Captura: marcado abatido de perto vira escolta")
	var shots_before := sim.player_bullets.count
	check.call(shots_before > 0, "Captura: a escolta voa e atira")
	for k: int in range(ShipTraits.CAPTURE_FRAMES):
		sim.step(SimInput.new())
	check.call(sim.escorts.is_empty(), "Captura: o domínio acaba em 10 s")
	var far := _sim(tables, &"falcon")
	var f := _enemy_near(far)
	f.marked = true
	f.hp = 0.01
	f.pos = far.player.pos + Vector2(0, -200)
	f.origin = f.pos
	for k: int in range(60):
		far.step(SimInput.new())
	check.call(far.escorts.is_empty(), "Captura: de longe não captura")


func _unlocks(check: Callable, tables: Dictionary) -> void:
	var ships: Array = (tables["ships"] as Dictionary).values()
	var p := SaveManagerScript.default_profile()
	var won := {"mission": "c9m3", "cleared": true, "stars": [true, false, false, false], "score": 1000,
			"ending": "return"}
	Economy.apply_result(p, won, ships, [])
	check.call(not (p["unlocked"]["ships"] as Array).has("ascension"), "Ascension: fechada sem o final verdadeiro")
	won["ending"] = "high_tide"
	var out := Economy.apply_result(p, won, ships, [])
	check.call((p["unlocked"]["ships"] as Array).has("ascension") and (out["new_ships"] as Array).has(&"ascension"),
			"Ascension: abre com o final Maré Alta")
	var q := SaveManagerScript.default_profile()
	var r := {"mission": "c7m1", "cleared": true, "stars": [true, false, false, false], "score": 1000}
	Economy.apply_result(q, r, ships, [])
	r["mission"] = "c7m2"
	var out2 := Economy.apply_result(q, r, ships, [])
	check.call((out2["new_ships"] as Array).has(&"ram"), "Ariete: 2 missões-fonte abrem a nave")
	for id: StringName in NEW_SHIPS:
		(q["unlocked"]["ships"] as Array).append(String(id))
	while (q["unlocked"]["ships"] as Array).size() < 12:
		(q["unlocked"]["ships"] as Array).append("x%d" % (q["unlocked"]["ships"] as Array).size())
	check.call(Achievements.check(q, {}).has("armada"),
			"Conquista: Armada atlante com 12 aeronaves")


## O bot vence a 1-1 com cada aeronave nova; mesma semente, mesmo hash.
func _bot_runs(check: Callable, tables: Dictionary) -> void:
	var mission := Sim.load_mission(&"c1m1")
	for id: StringName in NEW_SHIPS:
		var hashes: Array[String] = []
		var sim: Sim
		for k: int in range(2):
			sim = Sim.new()
			sim.setup(mission, tables, Sim.default_loadout(id), 7)
			var bot := BotPilot.new()
			while not sim.finished and sim.frame < 60 * 60 * 8:
				sim.step(bot.decide(sim))
			hashes.append(sim.state_hash())
		check.call(sim.cleared, "Bot: vence a 1-1 com %s (%.0f s, %d pontos)" % [id, sim.frame / 60.0, sim.scoring.score])
		check.call(hashes[0] == hashes[1], "Determinismo: %s dá o mesmo hash" % id)


## Todo personagem que fala (menos o narrador) tem retrato nas 3 expressões; toda "mood" usada existe.
func _portraits(check: Callable) -> void:
	var speakers := {}
	var moods := {}
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue.json"))
	for scene: Variant in JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json")):
		rows.append_array((scene as Dictionary)["panels"])
	for row: Variant in rows:
		var r := row as Dictionary
		speakers[String(r.get("speaker", ""))] = true
		moods[String(r.get("mood", "calm"))] = true
	speakers.erase("narrator")
	for s: String in speakers:
		for mood: String in Portraits.MOODS:
			check.call(Portraits.texture(s, mood) != null, "Retrato: %s (%s)" % [s, mood])
	for mood: String in moods:
		check.call(mood in Portraits.MOODS, "Retrato: expressão %s conhecida" % mood)
	check.call(Portraits.texture("narrator") == null, "Retrato: o narrador não tem rosto")
	var tex := Portraits.texture("mare", "alert")
	check.call(tex != null and tex.get_size() == Vector2(64, 64), "Retrato: 64x64")


## Abismo Infinito: roteiro por semente, módulos só no modo, profundidade acelera e paga, o bot desce.
func _abyss(check: Callable, tables: Dictionary) -> void:
	var a := Modes.abyss(42)
	check.call(JSON.stringify(a) == JSON.stringify(Modes.abyss(42)), "Abismo: mesma semente, mesmo roteiro")
	var ops := {}
	var boss_at_10 := false
	var depth := 0
	for ev: Variant in a["events"]:
		var op := String((ev as Dictionary)["op"])
		ops[op] = int(ops.get(op, 0)) + 1
		if op == "abyss":
			depth = int(ev["depth"])
		boss_at_10 = boss_at_10 or (op == "boss" and depth == 10)
	check.call(int(ops.get("abyss", 0)) == Modes.ABYSS_STAGES, "Abismo: %d profundidades" % Modes.ABYSS_STAGES)
	check.call(int(ops.get("module", 0)) == Modes.ABYSS_STAGES / 2, "Abismo: módulo a cada 2 profundidades")
	check.call(boss_at_10, "Abismo: chefe de ato na profundidade 10")
	var camp := _sim(tables, &"falcon")
	camp.offer_blessings()
	var leaked := false
	for id: StringName in camp.offer:
		leaked = leaked or String(id).begins_with("abyss_")
	check.call(not camp.offer.is_empty() and not leaked, "Abismo: módulos nunca aparecem como bênção na campanha")
	var p := SaveManagerScript.default_profile()
	var loadout := Modes.loadout_for(&"abyss", p, "2026-11-01")
	loadout["damage"] = 0.36
	loadout["hull"] = 3
	var hashes: Array[String] = []
	var sim: Sim
	for k: int in range(2):
		sim = Sim.new()
		sim.setup(a, tables, loadout, 42)
		var bot := BotPilot.new()
		while not sim.finished and sim.frame < 60 * 60 * 4:
			sim.step(bot.decide(sim))
		hashes.append(sim.state_hash())
	var modules := 0
	for id: StringName in sim.mods.taken:
		modules += 1 if String(id).begins_with("abyss_") else 0
	check.call(sim.abyss_depth >= 5, "Abismo: o bot desce ao menos 5 profundidades em 4 min (%d)" % sim.abyss_depth)
	check.call(modules >= 2, "Abismo: módulos escolhidos no caminho (%d)" % modules)
	check.call(hashes[0] == hashes[1], "Abismo: determinístico pela semente")
	var deep := Sim.new()
	deep.setup(a, tables, loadout, 42)
	var base := deep.bullet_speed_mult()
	deep.on_stage_event({"op": "abyss", "depth": 30})
	check.call(deep.bullet_speed_mult() > base and deep.scoring.point_mult > 1.0,
			"Abismo: mais fundo, balas mais rápidas e mais pontos")
	var out := Modes.apply_result(p, &"abyss", {"score": 50000, "depth": 31})
	check.call(int(p["abyss_depth"]) == 31 and int(out["orichalcum_gain"]) == 12,
			"Abismo: guarda a profundidade e paga Oricalco")
	check.call(Achievements.check(p, {}).has("abyss_30"), "Conquista: Trinta braças")


## Capítulo bônus: abre depois da 9-3 e fica no fundo do mapa, com chefe e cena final próprios.
func _hadal(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	check.call(not Economy.mission_unlocked(p, &"c10m1"), "Fossa Hadal: fechada antes da 9-3")
	p["missions"]["c9m3"] = {"cleared": true, "stars": [true, false, false, false], "best_score": 1}
	check.call(Economy.mission_unlocked(p, &"c10m1"), "Fossa Hadal: abre com a 9-3")
	check.call(float(Economy.node(&"c10m3")["y"]) < float(Economy.node(&"c1m1")["y"]),
			"Fossa Hadal: abaixo do primeiro mar no mapa")
	var bosses: Dictionary = Sim.load_tables()["bosses"]
	check.call(bosses.has(&"hadal_matriarch") and bosses.has(&"hadal_angler"), "Fossa Hadal: chefes nos dados")
