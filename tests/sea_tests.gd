extends RefCounted
## Testes do mar (revisão 8 da Sim): submarinos e navios (SimEnemy.sea) ficam abaixo da nave. Tiro, feixe e estilhaço
## passam por cima; míssil teleguiado e bomba ferem; os mísseis buscam o mar antes do ar; o lançador automático só
## existe nas missões de água; encostar neles não fere; replays de revisão 7 jogam as missões de água sem eles.
## Chamado por tests/run_tests.gd (regras rápidas, sem autoloads).

var _tables: Dictionary = {}


func run_unit(check: Callable) -> void:
	_tables = Sim.load_tables()
	_data(check)
	_bullets_pass(check)
	_missile_hits(check)
	_targets(check)
	_launcher(check)
	_no_contact(check)
	_old_replay(check)


func _sim(backdrop: String, rev: int = SimRevision.CURRENT) -> Sim:
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["rev"] = rev
	sim.setup({"id": "sea_test", "chapter": 1, "backdrop": backdrop, "events": []}, _tables, load, 7)
	sim.player.invuln = 0
	return sim


## Inimigo parado (rolagem 0) já na superfície, em `at`.
func _spawn(sim: Sim, id: String, at: Vector2) -> SimEnemy:
	sim.spawn_enemy({"enemy": id, "x": at.x / Playfield.FIELD.x, "y": at.y, "path": "scroll",
			"params": {"speed": 0.0}}, 0)
	return sim.enemies[-1]


func _data(check: Callable) -> void:
	for id: StringName in [&"sea_submarine", &"sea_warship"]:
		var def: Dictionary = (_tables["enemies"] as Dictionary).get(id, {})
		check.call(String(def.get("layer", "")) == "sea" and not bool(def.get("contact", true))
				and (_tables["patterns"] as Dictionary).has(StringName(String(def.get("pattern", "")))),
				"Mar: %s é do mar, sem contato e com padrão" % id)


func _bullets_pass(check: Callable) -> void:
	var sim := _sim("storm")
	var sub := _spawn(sim, "sea_submarine", Vector2(135, 200))
	check.call(sub.sea and sub.active(), "Mar: submarino nasce do mar")
	sim.player_bullets.spawn(sub.hit_pos(), Vector2.ZERO, 4.0, 0, 50.0)
	sim.step(SimInput.new())
	var still := false
	for i: int in range(sim.player_bullets.count):
		still = still or sim.player_bullets.pos[i] == sub.hit_pos()
	check.call(is_equal_approx(sub.hp, sub.max_hp) and still, "Mar: bala comum passa por cima do submarino")
	sim.player.pos = sub.pos + Vector2(0, 120)
	SimBeam.attack(sim, 30.0, 6000.0)
	check.call(is_equal_approx(sub.hp, sub.max_hp), "Mar: feixe passa por cima do submarino")
	sim.splash(sub.hit_pos(), 30.0, 100.0)
	check.call(is_equal_approx(sub.hp, sub.max_hp), "Mar: estilhaço da arma não chega ao mar")
	sim.powers.hurt(sim, sub, 100.0)
	check.call(is_equal_approx(sub.hp, sub.max_hp), "Mar: poder de anel, feixe ou aura não fere o mar")


func _missile_hits(check: Callable) -> void:
	var sim := _sim("storm")
	var sub := _spawn(sim, "sea_submarine", Vector2(135, 200))
	check.call(sim.hit_at_id(sub.hit_pos(), SecondaryFire.MISSILE_RADIUS, 10.0) == sub.get_instance_id()
			and is_equal_approx(sub.hp, sub.max_hp - 10.0), "Mar: míssil teleguiado fere o submarino")
	sim.powers.area(sim, sub.hit_pos(), 20.0, 5.0, false, &"")
	check.call(sub.hp < sub.max_hp - 10.0, "Mar: explosão de poder fere o submarino")
	var ship := _spawn(sim, "sea_warship", Vector2(60, 150))
	sim.area_blast(Sim.BOMB_DAMAGE)
	check.call(not sub.alive and not ship.alive, "Mar: bomba afunda submarino e navio")
	# Três pares do lançador do mar afundam o submarino (dano sem bônus).
	check.call(SecondaryFire.SEA_DAMAGE * 6.0 >= float(_tables["enemies"][&"sea_submarine"]["hp"]),
			"Mar: 3 pares do lançador afundam o submarino")


func _targets(check: Callable) -> void:
	var sim := _sim("storm")
	var air := _spawn(sim, "skiff", sim.player.pos + Vector2(0, -60))
	var sub := _spawn(sim, "sea_submarine", Vector2(40, 80))
	check.call(sim.nearest_target(sim.player.pos) == sub.pos, "Mar: míssil busca o mar antes do ar mais perto")
	check.call(sim.powers.strongest_target(sim) == sub.pos, "Mar: salva do poder busca o mar primeiro")
	sub.alive = false
	check.call(sim.nearest_target(sim.player.pos) == air.pos, "Mar: sem alvo no mar, o míssil busca o ar")


func _launcher(check: Callable) -> void:
	var counts := {}
	for c: Array in [["ocean", SimRevision.CURRENT], ["hadal", SimRevision.CURRENT], ["storm", SimRevision.CURRENT],
			["orbit", SimRevision.CURRENT], ["ocean", SecondaryFire.SEA_REVISION - 1]]:
		var sim := _sim(String(c[0]), int(c[1]))
		var launched := 0
		for k: int in range(SecondaryFire.SEA_INTERVAL * 2):
			var before := sim.missiles.size()
			sim.step(SimInput.new())
			launched += maxi(0, sim.missiles.size() - before)
		counts["%s/%d" % c] = launched
	check.call(int(counts["ocean/%d" % SimRevision.CURRENT]) == 4 and int(counts["hadal/%d" % SimRevision.CURRENT]) == 4,
			"Mar: lançador do mar solta um par por segundo nas missões de água (%s)" % counts)
	check.call(int(counts["storm/%d" % SimRevision.CURRENT]) == 0 and int(counts["orbit/%d" % SimRevision.CURRENT]) == 0,
			"Mar: sem lançador do mar no céu e no espaço")
	check.call(int(counts["ocean/%d" % (SecondaryFire.SEA_REVISION - 1)]) == 0,
			"Mar: replay de revisão 7 não ganha o lançador do mar")
	var sim := _sim("ocean")
	sim.secondary = &"missiles"
	check.call(not SecondaryFire.sea_launcher(sim), "Mar: com a secundária de mísseis o lançador do mar não soma")
	sim = _sim("ocean")
	sim.spawn_boss(&"tidebreaker", false)
	var during := 0
	for k: int in range(SecondaryFire.SEA_INTERVAL * 2):
		var before := sim.missiles.size()
		sim.step(SimInput.new())
		during += maxi(0, sim.missiles.size() - before)
	check.call(sim.boss != null and during == 0, "Mar: na luta de chefe sem alvo no mar o lançador espera")
	_spawn(sim, "sea_submarine", Vector2(135, 300))
	for k: int in range(SecondaryFire.SEA_INTERVAL):
		sim.step(SimInput.new())
	check.call(SecondaryFire.sea_in_field(sim) and not sim.missiles.is_empty(),
			"Mar: na luta de chefe com submarino o lançador dispara")


func _no_contact(check: Callable) -> void:
	var sim := _sim("storm")
	var ship := _spawn(sim, "sea_warship", Vector2(135, 300))
	sim.player.pos = ship.hit_pos()
	var hull := sim.player.hull
	sim.step(SimInput.new())
	check.call(ship.alive and sim.player.hull == hull and sim.last_cause == &"",
			"Mar: navio por baixo da nave não fere por contato")


## Missão de água com mar: a revisão 7 joga igual, passo a passo, à mesma missão sem as ondas do mar; a atual as joga.
func _old_replay(check: Callable) -> void:
	var mission := Sim.load_mission(&"c1m2")
	var stripped := mission.duplicate(true)
	stripped["events"] = (stripped["events"] as Array).filter(func(ev: Variant) -> bool:
		return not String((ev as Dictionary).get("enemy", "")).begins_with("sea_"))
	var sea_waves := (mission["events"] as Array).size() - (stripped["events"] as Array).size()
	var a := _run(mission, SecondaryFire.SEA_REVISION - 1)
	var b := _run(stripped, SecondaryFire.SEA_REVISION - 1)
	var now := _run(mission, SimRevision.CURRENT)
	check.call(sea_waves > 0 and a["hashes"] == b["hashes"] and int(a["sea"]) == 0,
			"Mar: replay de revisão 7 da c1m2 igual, passo a passo, ao de antes do mar")
	check.call(int(now["sea"]) > 0 and now["hashes"] != a["hashes"], "Mar: a revisão atual põe navios na c1m2")


func _run(mission: Dictionary, rev: int) -> Dictionary:
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["rev"] = rev
	sim.setup(mission, _tables, load, 7)
	var bot := BotPilot.new()
	var hashes := PackedStringArray()
	var sea := 0
	while sim.frame < 60 * 50 and not sim.finished:
		sim.step(bot.decide(sim))
		for ev: Dictionary in sim.take_events():
			if ev["type"] == &"sea_contact":
				sea += 1
		if sim.frame % 60 == 0:
			hashes.append(sim.state_hash())
	return {"hashes": hashes, "sea": sea}
