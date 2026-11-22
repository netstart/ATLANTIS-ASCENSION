extends RefCounted
## Testes dos objetivos de fase (SimObjectives, revisão 4 da Sim): resgate (todos, parcial, jaula que foge),
## sabotagem (acerto e reforços), interceptação (relíquia e fuga), roteiro gerado de cada missão e replay antigo
## igual ao de antes. Chamado por tests/run_tests.gd (regras rápidas, sem autoloads).

const MAX_STEPS := 60 * 45

var _tables: Dictionary = {}


func run_unit(check: Callable) -> void:
	_tables = Sim.load_tables()
	_rescue(check)
	_sabotage(check)
	_intercept(check)
	_schedule(check)
	_old_replay(check)
	_art(check)


## Sim de teste num campo vazio (sem ondas) com estes objetivos; `rev` = revisão das regras.
func _sim(objectives: Array, rev: int = SimRevision.CURRENT) -> Sim:
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["rev"] = rev
	sim.setup({"id": "objective_test", "chapter": 1, "events": [], "objectives": objectives}, _tables, load, 7)
	sim.player.invuln = 1 << 20
	return sim


## Passos até o alvo entrar (aviso de 1,5 s, o tempo do rádio); devolve os eventos vistos.
static func _until_start(sim: Sim) -> Array[StringName]:
	var seen: Array[StringName] = []
	for k: int in range(SimObjectives.WARN_FRAMES + 2):
		sim.step(SimInput.new())
		for ev: Dictionary in sim.take_events():
			seen.append(StringName(ev["type"]))
	return seen


## Passos até o alvo estar bem dentro do campo.
static func _until_inside(sim: Sim, e: SimEnemy) -> void:
	while e.pos.y < 70.0:
		sim.step(SimInput.new())
		sim.take_events()


static func _targets(sim: Sim) -> Array:
	return sim.objectives.current.get("targets", [])


## Passos até o objetivo acabar. `catch` = quantos atlantes a nave vai buscar (ela pula para cima de cada um).
static func _run(sim: Sim, catch: int = 0) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var steps := 0
	while not sim.objectives.current.is_empty() and steps < MAX_STEPS:
		# Espera as bolhas se afastarem umas das outras (1 s) para pegar uma de cada vez.
		if catch > 0 and not sim.objectives.survivors.is_empty() and int(sim.objectives.survivors[0]["frames"]) > 60:
			sim.player.pos = sim.objectives.survivors[0]["pos"]
		else:
			# Longe de tudo: no canto de baixo, fora do caminho dos atlantes e dos alvos.
			sim.player.pos = Vector2(SimPlayer.MARGIN.x, sim.field.y - SimPlayer.MARGIN.y)
		var before := sim.rescued
		sim.step(SimInput.new())
		catch -= sim.rescued - before
		events.append_array(sim.take_events())
		steps += 1
	return events


static func _count(events: Array[Dictionary], type: StringName) -> int:
	var n := 0
	for ev: Dictionary in events:
		if StringName(ev["type"]) == type:
			n += 1
	return n


func _rescue(check: Callable) -> void:
	var spec := {"t": 0.0, "type": "rescue", "count": 4, "x": 0.5, "speed": 40.0}
	var sim := _sim([spec])
	var seen := _until_start(sim)
	check.call(&"objective_warn" in seen and &"objective_start" in seen and _targets(sim).size() == 1,
			"Objetivo resgate: aviso, depois a jaula entra")
	var barge: SimEnemy = _targets(sim)[0]
	_until_inside(sim, barge)
	check.call(barge.id == &"prison_barge" and not barge.contact, "Objetivo resgate: a jaula no chão não fere no contato")
	var score := sim.scoring.score
	sim.kill_enemy(barge)
	check.call(sim.objectives.survivors.size() == 4, "Objetivo resgate: a jaula abre e solta 4 atlantes")
	var events := _run(sim, 4)
	var r: Dictionary = sim.objectives.results[0] if not sim.objectives.results.is_empty() else {}
	check.call(sim.rescued == 4 and int(r.get("done", 0)) == 4 and bool(r.get("ok", false)) and _count(events,
			&"survivor") == 4, "Objetivo resgate: 4/4 salvos contam em Sim.rescued (%d)" % sim.rescued)
	check.call(sim.objectives.orichalcum == SimObjectives.SUCCESS_ORICHALCUM + SimObjectives.PERFECT_ORICHALCUM
			and sim.scoring.score > score, "Objetivo resgate: perfeito vale pontos e oricalco extra")
	check.call(int(sim.result()["orichalcum"]) >= sim.objectives.orichalcum
			and (sim.result()["objectives"] as Array).size() == 1, "Objetivo resgate: entra no resultado da missão")
	# Parcial: 5 presos, a nave pega 2 e o resto sobe para a superfície (perdidos).
	var partial := _sim([dict_with(spec, "count", 5)])
	_until_start(partial)
	_until_inside(partial, _targets(partial)[0])
	partial.kill_enemy(_targets(partial)[0])
	events = _run(partial, 2)
	r = partial.objectives.results[0] if not partial.objectives.results.is_empty() else {}
	check.call(partial.rescued == 2 and int(r.get("done", -1)) == 2 and not bool(r.get("ok", true))
			and _count(events, &"survivor_lost") == 3, "Objetivo resgate parcial: 2/5, 3 perdidos, não vale")
	# Fuga: ninguém atira e a jaula sai do campo inteira.
	var gone := _sim([spec])
	_until_start(gone)
	events = _run(gone)
	r = gone.objectives.results[0] if not gone.objectives.results.is_empty() else {}
	var end := _last(events, &"objective_end")
	check.call(not bool(r.get("ok", true)) and gone.rescued == 0 and not bool(end.get("released", true)),
			"Objetivo resgate: a jaula que escapa leva os atlantes")
	# Céu e espaço: a cápsula-prisão à deriva no lugar da jaula.
	var pod := _sim([dict_with(spec, "pod", true)])
	_until_start(pod)
	check.call((_targets(pod)[0] as SimEnemy).id == &"prison_pod", "Objetivo resgate: sem chão, cápsula-prisão")


func _sabotage(check: Callable) -> void:
	var wave := {"op": "wave", "enemy": "skiff", "formation": "line", "count": 5, "x": 0.5, "path": "straight",
			"params": {"speed": 60}, "spacing": 40}
	var spec := {"t": 0.0, "type": "sabotage", "count": 3, "seconds": 10.0, "reinforce": wave}
	var sim := _sim([spec])
	_until_start(sim)
	var beacons := _targets(sim)
	check.call(beacons.size() == 3 and sim.objectives.progress()["left"] > 9.0,
			"Objetivo sabotagem: 3 faróis e o prazo correndo")
	for e: SimEnemy in beacons:
		sim.kill_enemy(e)
	var events := _run(sim)
	check.call(bool(sim.objectives.results[0]["ok"]) and _count(events, &"reinforcements") == 0,
			"Objetivo sabotagem: os 3 derrubados a tempo, sem reforço")
	var late := _sim([spec])
	_until_start(late)
	late.kill_enemy(_targets(late)[0])
	var before := late.enemies.size()
	events = _run(late)
	var r: Dictionary = late.objectives.results[0]
	check.call(not bool(r["ok"]) and int(r["done"]) == 1 and _count(events, &"reinforcements") == 1
			and late.enemies.size() >= before + 4, "Objetivo sabotagem: prazo vencido chama a onda de reforço")


func _intercept(check: Callable) -> void:
	var spec := {"t": 0.0, "type": "intercept", "x": 0.25, "speed": 80, "hold": 2.0}
	var sim := _sim([spec])
	_until_start(sim)
	var courier: SimEnemy = _targets(sim)[0]
	sim.kill_enemy(courier)
	check.call(sim.objectives.relics.size() == 1, "Objetivo interceptação: o mensageiro abatido solta a relíquia")
	var events := _run(sim)
	for k: int in range(240):
		sim.step(SimInput.new())
		events.append_array(sim.take_events())
	check.call(bool(sim.objectives.results[0]["ok"]) and _count(events, &"relic") == 1
			and sim.objectives.relics.is_empty(), "Objetivo interceptação: a relíquia voa até a nave")
	var away := _sim([spec])
	_until_start(away)
	_run(away)
	check.call(not bool(away.objectives.results[0]["ok"]), "Objetivo interceptação: o mensageiro foge pelo lado")


## Roteiro gerado (tools/gen_missions.py): toda missão tem 2 ou 3 objetivos (3 a partir do capítulo 4, quando cabem),
## em ordem, com um resgate, e nenhum em cima de chefe ou perigo.
func _schedule(check: Callable) -> void:
	var bad: Array[String] = []
	var blockers := ["boss", "miniboss", "lightning", "gravity_breach", "cover", "capsule", "ocean_shift", "current",
			"wind"]
	for path: String in DirAccess.get_files_at("res://data/stages"):
		if not path.ends_with(".json"):
			continue
		var m := Sim.load_mission(StringName(path.get_basename()))
		var list: Array = m.get("objectives", [])
		var kinds: Array[String] = []
		var last := -1.0
		for o: Variant in list:
			var t := float((o as Dictionary)["t"])
			kinds.append(String((o as Dictionary)["type"]))
			if t < last:
				bad.append("%s fora de ordem" % path)
			last = t
			for ev: Variant in m.get("events", []):
				var at := float((ev as Dictionary)["t"])
				if String((ev as Dictionary)["op"]) in blockers and at >= t and at <= t + 6.0:
					bad.append("%s: %s em %.1f dentro do objetivo de %.1f" % [path, (ev as Dictionary)["op"], at, t])
		if list.size() < 2 or list.size() > 3 or not "rescue" in kinds:
			bad.append("%s: %s" % [path, kinds])
		var pod := String(m.get("backdrop", "")) in ["stratosphere", "orbit", "core"]
		for o: Variant in list:
			if String((o as Dictionary)["type"]) == "rescue" and bool((o as Dictionary).get("pod", false)) != pod:
				bad.append("%s: jaula no chão sem chão (ou cápsula com chão)" % path)
	check.call(bad.is_empty(), "Objetivos: roteiro de toda missão com 2 ou 3, resgate e longe de chefes e perigos%s"
			% ("" if bad.is_empty() else ": " + "; ".join(bad)))


## Replay antigo: a revisão 3 roda a mesma missão (com "objectives" no JSON) igual à mesma missão sem eles, passo a
## passo, e sem nenhum evento de objetivo; a revisão atual com a mesma semente usa os objetivos. Um replay gravado
## antes (sem "rev") carrega como revisão 1.
func _old_replay(check: Callable) -> void:
	var mission := Sim.load_mission(&"c2m3")
	var stripped := mission.duplicate(true)
	stripped.erase("objectives")
	var a := _replay_run(mission, 3)
	var b := _replay_run(stripped, 3)
	var now := _replay_run(mission, SimRevision.CURRENT)
	check.call(not (mission.get("objectives", []) as Array).is_empty() and a["hashes"] == b["hashes"]
			and int(a["objective_events"]) == 0, "Objetivos: replay de revisão 3 igual, passo a passo, ao de antes")
	check.call(int(now["objective_events"]) > 0 and now["hashes"] != a["hashes"],
			"Objetivos: a revisão atual joga os objetivos da mesma missão")
	var old := Replay.from_dict({"v": Replay.VERSION, "loadout": {"ship": "falcon"}, "blocks": []})
	var sim := Sim.new()
	sim.setup(mission, _tables, old.loadout, 7)
	check.call(not sim.objectives.enabled, "Objetivos: replay sem \"rev\" (revisão 1) ignora os objetivos")


## O bot joga 40 s (passa da interceptação da c2m3, a primeira); hash a cada segundo e quantos eventos de objetivo
## saíram.
func _replay_run(mission: Dictionary, rev: int) -> Dictionary:
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["rev"] = rev
	sim.setup(mission, _tables, load, 7)
	var bot := BotPilot.new()
	var hashes := PackedStringArray()
	var events := 0
	while sim.frame < 60 * 40 and not sim.finished:
		sim.step(bot.decide(sim))
		for ev: Dictionary in sim.take_events():
			if String(ev["type"]).begins_with("objective"):
				events += 1
		if sim.frame % 60 == 0:
			hashes.append(sim.state_hash())
	return {"hashes": hashes, "objective_events": events}


## Arte dos alvos e coletáveis (tools/gen_sprites.py) e o nome de cada alvo em data/enemies.json.
func _art(check: Callable) -> void:
	var missing: Array[String] = []
	for id: StringName in [&"prison_barge", &"prison_pod", &"protocol_beacon", &"relic_courier"]:
		var def: Dictionary = (_tables["enemies"] as Dictionary).get(id, {})
		if def.is_empty() or SpriteBank.ship(StringName(String(def.get("sprite", "")))).get("base") == null:
			missing.append(String(id))
	for name: String in ["pickups/survivor", "pickups/relic", "fx/target_marker"]:
		if SpriteBank.generated(name) == null:
			missing.append(name)
	check.call(missing.is_empty(), "Objetivos: alvos e coletáveis com arte própria %s" % [missing])
	SpriteBank.clear()


static func dict_with(d: Dictionary, key: String, value: Variant) -> Dictionary:
	var out := d.duplicate(true)
	out[key] = value
	return out


static func _last(events: Array[Dictionary], type: StringName) -> Dictionary:
	for k: int in range(events.size() - 1, -1, -1):
		if StringName(events[k]["type"]) == type:
			return events[k]
	return {}
