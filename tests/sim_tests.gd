extends RefCounted
## Testes da simulação (regras puras, sem autoloads): pool de balas, DSL de padrões, trajetórias,
## pontuação, orbes, chefe e uma missão inteira jogada pelo bot, duas vezes com a mesma semente
## (mesmo hash) e com outra semente. Chamado por tests/run_tests.gd.

const MAX_FRAMES := 60 * 60 * 10


func run_unit(check: Callable) -> void:
	_pool(check)
	_paths(check)
	_scoring(check)
	_orbs(check)
	_data(check)
	_mission(check)


func _pool(check: Callable) -> void:
	var pool := BulletPool.new(4)
	for i: int in range(5):
		pool.spawn(Vector2(10 * i, 10), Vector2(0, 60), 3.0, 0)
	check.call(pool.count == 4, "Balas: pool cheio recusa (%d)" % pool.count)
	pool.kill(0)
	check.call(pool.count == 3 and pool.pos[0] == Vector2(30, 10), "Balas: matar compacta trazendo o último")
	pool.step(0.5, Rect2(0, 0, 100, 60))
	check.call(pool.count == 3 and is_equal_approx((pool.pos[0] as Vector2).y, 40.0), "Balas: andam")
	pool.step(1.0, Rect2(0, 0, 100, 60))
	check.call(pool.count == 0, "Balas: saem do limite")
	pool.clear()
	pool.spawn(Vector2(50, 50), Vector2.ZERO, 3.0, 0)
	pool.spawn(Vector2(90, 50), Vector2.ZERO, 3.0, 0)
	var cancelled := pool.cancel_near(Vector2(50, 50), 10.0)
	check.call(cancelled.size() == 1 and pool.count == 1, "Balas: cancelamento por raio")


func _paths(check: Callable) -> void:
	var origin := Vector2(100, -20)
	check.call(Paths.position(&"straight", origin, 1.0, {"speed": 60}) == Vector2(100, 40), "Trajetória: reta")
	var stop := Paths.position(&"stop_go", origin, 10.0, {"speed": 70, "stop_y": 120, "hold": 30})
	check.call(stop == Vector2(100, 120), "Trajetória: para em stop_y (%s)" % stop)
	var a := Paths.position(&"sine", origin, 2.5, {"amp": 30, "freq": 0.5, "speed": 80})
	var b := Paths.position(&"sine", origin, 2.5, {"amp": 30, "freq": 0.5, "speed": 80})
	check.call(a == b, "Trajetória: função pura do tempo")


func _scoring(check: Callable) -> void:
	var s := Scoring.new()
	for i: int in range(16):
		s.on_kill(100, 200.0, false)
	check.call(s.multiplier() == 3, "Pontos: 16 abates seguidos dão x3 (%d)" % s.multiplier())
	for i: int in range(Scoring.CHAIN_WINDOW):
		s.tick()
	check.call(s.chain == 0 and s.multiplier() == 1, "Pontos: corrente acaba sem abate na janela")
	var before := s.score
	s.on_kill(100, 10.0, false)
	check.call(s.score - before == 150, "Pontos: queima-roupa vale 1,5x")
	check.call(s.on_medal() == 100 and s.on_medal() == 200, "Medalhas: valor sobe por degrau")
	s.on_medal_missed()
	check.call(s.on_medal() == 100, "Medalhas: perder uma volta ao primeiro degrau")
	s.on_graze()
	check.call(s.grazes == 1 and s.pressure >= 1.0, "Graze: conta e enche a Pressão")


func _orbs(check: Callable) -> void:
	var p := SimPlayer.new()
	p.setup({"signature": "pulsar", "hull": 3}, 1.0)
	check.call(p.collect_orb(&"pulsar") and p.level == 2, "Orbe: mesma cor sobe o nível")
	check.call(p.collect_orb(&"laser") and p.weapon == &"laser" and p.level == 2, "Orbe: outra cor troca e mantém")
	p.collect_orb(&"laser")
	check.call(not p.collect_orb(&"laser") and p.level == 3, "Orbe: fora da assinatura para no nível 3")
	p.take_hit()
	check.call(p.level == 2 and p.hull == 2 and not p.vulnerable(), "Dano: tira casco e nível, dá invulnerabilidade")
	check.call(Sim.orb_weapon(0) == &"pulsar" and Sim.orb_weapon(Sim.ORB_CYCLE) == &"laser", "Orbe: troca de cor no ciclo")


func _data(check: Callable) -> void:
	var tables := Sim.load_tables()
	var patterns: Dictionary = tables["patterns"]
	for id: StringName in tables["enemies"]:
		var pid := String((tables["enemies"][id] as Dictionary).get("pattern", ""))
		check.call(pid.is_empty() or patterns.has(StringName(pid)), "Dados: padrão de %s existe" % id)
	for id: StringName in tables["bosses"]:
		var boss: Dictionary = tables["bosses"][id]
		var part_ids := ["body"]
		for part: Variant in boss.get("parts", []):
			part_ids.append(String((part as Dictionary).get("id", "")))
		for ph: Variant in boss.get("phases", []):
			for entry: Variant in (ph as Dictionary).get("patterns", []):
				var e := entry as Dictionary
				check.call(patterns.has(StringName(String(e.get("pattern", "")))),
						"Dados: padrão %s do chefe %s existe" % [e.get("pattern"), id])
				check.call(String(e.get("anchor", "body")) in part_ids, "Dados: âncora %s do chefe %s" % [e.get("anchor"), id])
	for id: StringName in patterns:
		for step: Variant in (patterns[id] as Dictionary).get("steps", []):
			if String((step as Dictionary).get("op", "")) == "beam":
				check.call(int((step as Dictionary).get("warn_frames", 0)) >= 30,
						"Leitura: feixe de %s avisa ≥ 0,5 s antes" % id)
	var mission := Sim.load_mission(&"c1m1")
	check.call(not mission.is_empty(), "Dados: missão c1m1 carrega")
	for ev: Variant in mission.get("events", []):
		var e := ev as Dictionary
		if String(e.get("op", "")) == "wave":
			check.call((tables["enemies"] as Dictionary).has(StringName(String(e.get("enemy", "")))),
					"Dados: inimigo %s da onda existe" % e.get("enemy"))
		if String(e.get("op", "")) in ["boss", "miniboss"]:
			check.call((tables["bosses"] as Dictionary).has(StringName(String(e.get("id", "")))),
					"Dados: chefe %s existe" % e.get("id"))


## Missão inteira pelo bot: termina, vence, respeita os tetos de balas e é determinística.
func _mission(check: Callable) -> void:
	var tables := Sim.load_tables()
	var mission := Sim.load_mission(&"c1m1")
	var first := run_bot(mission, tables, 7)
	var second := run_bot(mission, tables, 7)
	var other := run_bot(mission, tables, 11)
	var r: Dictionary = first["result"]
	if "--verbose" in OS.get_cmdline_user_args():
		print("Missão c1m1 semente 7: ", r, " pico de balas ", first["peak"])
		print("Missão c1m1 semente 11: ", other["result"])
	check.call(bool(first["finished"]), "Missão: o bot termina a c1m1 (%d passos)" % first["frames"])
	check.call(bool(r.get("cleared", false)), "Missão: o bot vence a c1m1 (%s)" % [r])
	check.call(first["hash"] == second["hash"], "Determinismo: mesma semente, mesmo estado")
	check.call(bool(other["finished"]), "Missão: o bot termina a c1m1 com outra semente")
	check.call(int(first["peak"]) <= 300, "Densidade: no máximo 300 balas inimigas vivas (%d)" % first["peak"])
	var seconds := float(r.get("seconds", 0.0))
	check.call(seconds >= 150.0 and seconds <= 330.0, "Ritmo: missão de 2,5 a 5,5 min (%.0f s)" % seconds)
	check.call(int(r.get("kills", 0)) >= 60, "Missão: o bot derruba a maioria (%d)" % r.get("kills"))


static func run_bot(mission: Dictionary, tables: Dictionary, seed: int) -> Dictionary:
	var sim := Sim.new()
	sim.setup(mission, tables, &"falcon", seed)
	var bot := BotPilot.new()
	var peak := 0
	while not sim.finished and sim.frame < MAX_FRAMES:
		sim.step(bot.decide(sim))
		for ev: Dictionary in sim.take_events():
			if ev["type"] == &"player_hit" and "--verbose" in OS.get_cmdline_user_args():
				print("dano no passo %d: %s em %s (chefe %s)" % [ev["frame"], ev["cause"], ev["pos"],
						sim.boss.id if sim.boss != null else "-"])
		peak = maxi(peak, sim.enemy_bullets.count)
	return {"finished": sim.finished, "frames": sim.frame, "result": sim.result(), "hash": sim.state_hash(),
			"peak": peak}
