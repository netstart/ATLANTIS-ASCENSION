extends RefCounted
## Testes da simulação (regras puras, sem autoloads): pool de balas, DSL de padrões, trajetórias,
## pontuação, orbes, chefe e uma missão inteira jogada pelo bot, duas vezes com a mesma semente
## (mesmo hash) e com outra semente. Chamado por tests/run_tests.gd.

const MAX_FRAMES := 60 * 60 * 10
## Saída das balas (_spawn_spread): balas "novas" (até SPREAD_YOUNG passos de vida), quantas podem se amontoar
## e por quantos passos cada padrão roda. Duas balas se sobrepõem com os centros a menos de SPREAD_DRAW × raio de
## colisão (o desenho tem ≈ 1,7 × o raio; 2,5 = três quartos do diâmetro desenhado).
const SPREAD_YOUNG := 30
const SPREAD_GROUP := 4
const SPREAD_FRAMES := 600
const SPREAD_DRAW := 2.5


var _tables: Dictionary = {}


## Tudo num processo só (sem fatias): as regras rápidas e depois cada missão inteira.
func run_unit(check: Callable) -> void:
	run_basics(check)
	for unit: Dictionary in mission_units():
		(unit["run"] as Callable).call(check)


## Regras rápidas da simulação (sem as missões inteiras pelo bot).
func run_basics(check: Callable) -> void:
	_pool(check)
	_paths(check)
	_scoring(check)
	_orbs(check)
	_data(check)
	_pierce(check)
	_outro(check)
	_spawn_spread(check)


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


## Saída das balas (PatternRunner.muzzle, revisão 2 da Sim): cada padrão de inimigo, chefe e chefe de meio roda
## SPREAD_FRAMES passos saindo do emissor que o usa (raio do inimigo, do corpo ou da parte), na dificuldade de
## balas mais lentas (Brisa). Em nenhum passo um grupo de SPREAD_GROUP ou mais balas novas pode ficar com os centros
## a menos de um raio de desenho umas das outras: é o bolo que aparecia em cima do sprite (Raia-Trovão). Replay
## antigo (revisão 1) mantém a saída antiga, no centro.
func _spawn_spread(check: Callable) -> void:
	var bad: Array[String] = []
	var rows := spawn_spread_report(_tables_once(), SimRevision.CURRENT)
	for row: Dictionary in rows:
		if int(row["group"]) >= SPREAD_GROUP:
			bad.append("%s (%s, raio %d): %d balas no passo %d" % [row["pattern"], row["who"], row["radius"],
					row["group"], row["frame"]])
	check.call(not rows.is_empty() and bad.is_empty(),
			"Saída das balas: %d padrões sem bolo na boca do emissor%s" % [rows.size(),
			"" if bad.is_empty() else "; com bolo: " + ", ".join(bad)])
	# Revisão 3: a curva por capítulo e o rank encurtam as esperas. No fim da curva (capítulo 10), na Brisa (balas mais
	# lentas) e na Abissal com rank cheio (esperas mais curtas), as emissões seguidas ainda não se amontoam.
	for hard: Array in [["brisa", Sim.RANK_START], ["abyssal", 1.0]]:
		var worst: Array[String] = []
		for row: Dictionary in spawn_spread_report(_tables_once(), SimRevision.CURRENT, &"c10m3", hard[0], hard[1]):
			if int(row["group"]) >= SPREAD_GROUP:
				worst.append("%s (%s): %d balas no passo %d" % [row["pattern"], row["who"], row["group"], row["frame"]])
		check.call(worst.is_empty(), "Saída das balas: sem bolo no capítulo 10 (%s, rank %.1f)%s" % [hard[0], hard[1],
				"" if worst.is_empty() else "; com bolo: " + ", ".join(worst)])
	var old := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["rev"] = 1
	old.setup(Sim.load_mission(&"c1m1"), _tables_once(), load, 7)
	var runner := PatternRunner.new({"steps": [{"op": "ring", "count": 4, "speed": 60}, {"op": "wait", "frames": 60}]}, 0,
			30.0)
	runner.step(old, Vector2(135, 100), true)
	var center := old.enemy_bullets.pos[0] == Vector2(135, 100)
	check.call(SimRevision.of(old.loadout) == 1 and old.enemy_bullets.count == 4 and center,
			"Saída das balas: replay de revisão 1 nasce no centro, como antes")
	var replay := Replay.from_dict({"v": Replay.VERSION, "loadout": {"ship": "falcon"}, "blocks": []})
	var fresh := Replay.new({}, 7, {"ship": "falcon"}).to_dict()
	var fresh_rev := int((fresh["loadout"] as Dictionary)["rev"])
	check.call(int(replay.loadout["rev"]) == 1 and fresh_rev == SimRevision.CURRENT,
			"Replay: gravação nova marca a revisão da Sim; a antiga carrega como revisão 1")


## Maior grupo de balas novas sobrepostas de cada uso de padrão (padrão + raio do emissor), com a Sim na revisão
## `rev`, na missão e dificuldade dadas e com o rank fixo em `rank` (curva por capítulo e cadência da revisão 3).
## Linhas {pattern, who, radius, group, frame}.
static func spawn_spread_report(tables: Dictionary, rev: int, mission_id: StringName = &"c1m1",
		difficulty: String = "brisa", rank: float = Sim.RANK_START) -> Array[Dictionary]:
	var patterns: Dictionary = tables["patterns"]
	var uses := {}
	for id: StringName in tables["enemies"]:
		var e: Dictionary = tables["enemies"][id]
		var pid := StringName(String(e.get("pattern", "")))
		if patterns.has(pid):
			uses["%s|%s" % [pid, e.get("radius", 12.0)]] = [pid, String(id), float(e.get("radius", 12.0))]
	for id: StringName in tables["bosses"]:
		var boss := SimBoss.new()
		boss.setup(tables["bosses"][id], patterns)
		for ph: Variant in boss.def.get("phases", []):
			for entry: Variant in (ph as Dictionary).get("patterns", []):
				var pid := StringName(String((entry as Dictionary).get("pattern", "")))
				var r := boss.anchor_radius(StringName(String((entry as Dictionary).get("anchor", "body"))))
				if patterns.has(pid):
					uses["%s|%s" % [pid, r]] = [pid, String(id), r]
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["difficulty"] = difficulty
	load["rev"] = rev
	sim.setup(Sim.load_mission(mission_id), tables, load, 7)
	sim.rank = rank
	var origin := Vector2(sim.field.x * 0.5, 110.0)
	var rows: Array[Dictionary] = []
	for key: String in uses:
		var use: Array = uses[key]
		var pool := sim.enemy_bullets
		pool.clear()
		sim.player.pos = Vector2(origin.x, sim.field.y - 60.0)
		var runner := PatternRunner.new(patterns[use[0]], 0, float(use[2]))
		var worst := 0
		var at := 0
		for f: int in range(SPREAD_FRAMES):
			runner.step(sim, origin, true)
			pool.step(Sim.STEP, sim.bounds)
			var young: Array[int] = []
			for i: int in range(pool.count):
				if pool.age[i] <= SPREAD_YOUNG:
					young.append(i)
			for i: int in young:
				var n := 1
				for j: int in young:
					if j != i:
						var d := maxf(pool.radius[i], pool.radius[j]) * SPREAD_DRAW
						if (pool.pos[i] as Vector2).distance_squared_to(pool.pos[j]) < d * d:
							n += 1
				if n > worst:
					worst = n
					at = f
		rows.append({"pattern": String(use[0]), "who": use[1], "radius": int(use[2]), "group": worst, "frame": at})
	return rows


## Saída da missão (SimOutro): o chefe que encerra a c2m3 cai com inimigos, balas, feixes, poder e coletáveis no
## campo. O campo fica limpo no mesmo passo, os coletáveis contam, a nave não leva dano, sobe pelo topo e só então
## a missão termina, em 2,5 a 3 s e igual nas duas vezes. Chefe de meio de fase com ondas depois não encerra, e
## replay antigo (sem "outro" na carga) mantém o fim antigo.
func _outro(check: Callable) -> void:
	var a := _outro_run(true)
	var b := _outro_run(true)
	check.call(bool(a["clean"]), "Saída: o chefe final cai e o campo fica sem inimigos, balas, feixes e poderes")
	check.call(int(a["kills"]) == 0 and int(a["medals"]) >= 7 and bool(a["no_pickups"]),
			"Saída: inimigos somem sem pontos e todos os coletáveis contam (medalhas %d)" % a["medals"])
	check.call(bool(a["safe"]) and bool(a["no_fire"]), "Saída: a nave não leva dano nem atira")
	check.call(bool(a["cleared"]) and bool(a["top"]) and bool(a["late"]),
			"Saída: finished e cleared só quando a nave some pelo topo")
	var seconds := float(a["frames"]) / 60.0
	check.call(seconds >= 2.5 and seconds <= 3.0, "Saída: da morte do chefe ao fim em 2,5 a 3 s (%.2f s)" % seconds)
	check.call(a["hash"] == b["hash"] and a["frames"] == b["frames"], "Saída: determinística (mesmo hash)")
	var legacy := _outro_run(false)
	check.call(bool(legacy["cleared"]) and not bool(legacy["outro_event"]),
			"Saída: replay antigo (sem a marca) termina como antes, sem a saída")
	var mid := Sim.new()
	mid.setup(Sim.load_mission(&"c1m2"), _tables_once(), &"falcon", 7)
	mid.stage.index = _event_index(mid.stage, "miniboss") + 1
	mid.on_boss_defeated(SimBoss.new())
	mid.step(SimInput.new())
	check.call(not mid.outro.active(), "Saída: chefe de meio de fase com ondas depois não encerra a missão")
	var old := Replay.from_dict({"v": Replay.VERSION, "loadout": {"ship": "falcon"}, "blocks": []})
	var fresh := Replay.new({}, 7, {"ship": "falcon"}).to_dict()
	check.call(not bool(old.loadout["outro"]) and bool((fresh["loadout"] as Dictionary)["outro"]),
			"Replay: gravação nova marca \"outro\"; a antiga carrega sem a marca")


## Chefe da c2m3 caindo com o campo cheio; `outro` false = carga de replay antigo. Devolve o que o teste confere.
func _outro_run(outro: bool) -> Dictionary:
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	if not outro:
		load["outro"] = false
	sim.setup(Sim.load_mission(&"c2m3"), _tables_once(), load, 7)
	var k := _event_index(sim.stage, "boss")
	sim.stage.index = k + 1
	sim.stage.frame = roundi(float((sim.stage.events[k] as Dictionary)["t"]) * 60.0)
	sim.stage.waiting_boss = true
	sim.spawn_boss(StringName(String((sim.stage.events[k] as Dictionary)["id"])), true)
	sim.boss.state = SimBoss.State.DUEL
	sim.boss.state_frames = SimBoss.DUEL_FRAMES - 1
	sim.player.pos = Vector2(40, 300)
	sim.spawn_enemy({"enemy": "skiff", "x": 0.5, "y": 120.0}, 0)
	for i: int in range(20):
		sim.fire_enemy(Vector2(20 + i * 10, 200), 90.0, 40.0, 0, 0.0, 0.0)
		sim.player_bullets.spawn(Vector2(20 + i * 10, 250), Vector2(0, -300), 3.0, 0)
	sim.add_beam(Vector2(200, 0), 20.0, 10, 600)
	sim.pickups.append({"kind": &"medal", "pos": Vector2(250, 10), "vel": Vector2.ZERO, "frames": 0})
	sim.power_fx.append({"id": "test", "type": &"slow", "_spec": {}, "wait": 0, "frames": 0, "total": 9999})
	var out := {"clean": false, "safe": true, "no_fire": true, "top": false, "late": true, "outro_event": false}
	var kills := sim.scoring.kills
	var hull := sim.player.hull
	# Depois da morte do chefe a entrada pede tiro, bomba e descida: a saída ignora tudo.
	var input := SimInput.new()
	var frames := 0
	while not sim.finished and frames < 1500:
		var y := sim.player.pos.y
		sim.step(input)
		input.fire = true
		input.bomb = true
		input.move = Vector2(0, 20)
		frames += 1
		for ev: Dictionary in sim.take_events():
			if ev["type"] == &"outro":
				out["outro_event"] = true
			elif (ev["type"] == &"shot" or ev["type"] == &"bomb") and outro and frames > 1:
				out["no_fire"] = false
		if frames == 1:
			out["clean"] = sim.enemies.is_empty() and sim.enemy_bullets.count == 0 and sim.player_bullets.count == 0 \
					and sim.beams.is_empty() and sim.power_fx.is_empty() and sim.outro.active()
		if sim.player.hull != hull:
			out["safe"] = false
		if sim.finished:
			out["top"] = sim.player.pos.y <= SimOutro.EXIT_Y + 0.01 and sim.boss == null
		elif y <= SimOutro.EXIT_Y + 0.01:
			out["late"] = false
	out["kills"] = sim.scoring.kills - kills
	out["medals"] = sim.scoring.medals
	out["no_pickups"] = sim.pickups.is_empty()
	out["cleared"] = sim.cleared
	out["frames"] = frames
	out["hash"] = sim.state_hash()
	return out


static func _event_index(stage: StageScript, op: String) -> int:
	var found := -1
	for k: int in range(stage.events.size()):
		if String((stage.events[k] as Dictionary).get("op", "")) == op:
			found = k
	return found


## Bala perfurante (Railgun, Eclipse, poderes): cada alvo leva dano dela uma vez só, mesmo ficando
## vários passos por cima dele (antes a mesma agulha batia no corpo do chefe a cada passo).
func _pierce(check: Callable) -> void:
	var sim := Sim.new()
	sim.setup(Sim.load_mission(&"c1m1"), Sim.load_tables(), &"falcon", 7)
	sim.enemies.clear()
	sim.player_bullets.clear()
	var boss := SimBoss.new()
	boss.setup({"id": "pierce_test", "hp": 100000.0, "body_radius": 30.0, "phases": [{"id": "a"}],
			"parts": [{"id": "core", "x": 0.0, "y": 0.0, "radius": 10.0, "hp": 1000.0, "leak": 0.0}]}, {})
	boss.pos = Vector2(135, 100)
	boss.phase_index = 0
	boss.state = SimBoss.State.FIGHT
	sim.boss = boss
	var i := sim.player_bullets.spawn(Vector2(135, 100), Vector2.ZERO, 3.0, 0, 10.0)
	sim.player_bullets.pierce[i] = 6
	for k: int in range(20):
		sim._collide_player_bullets()
	var part: Dictionary = boss.parts[0]
	check.call(is_equal_approx(float(part["hp"]), 990.0) and is_equal_approx(boss.hp, 100000.0 - 10.0),
			"Perfuração: 20 passos sobre o chefe acertam a parte e o corpo uma vez cada (parte %.0f, corpo %.0f)"
			% [float(part["hp"]), boss.max_hp - boss.hp])
	check.call(sim.player_bullets.count == 1 and sim.player_bullets.pierce[0] == 4,
			"Perfuração: só gasta perfuração em alvo novo (%d)" % sim.player_bullets.pierce[0])
	sim.boss = null
	sim.player_bullets.clear()
	for y: float in [200.0, 170.0, 140.0]:
		var e := SimEnemy.new()
		e.pos = Vector2(135, y)
		e.radius = 8.0
		e.hp = 100.0
		e.max_hp = 100.0
		sim.enemies.append(e)
	i = sim.player_bullets.spawn(Vector2(135, 215), Vector2(0, -WeaponFire.RAIL_SPEED), 3.0, 0, 10.0)
	sim.player_bullets.pierce[i] = 2
	for k: int in range(15):
		sim.player_bullets.step(Sim.STEP, Sim.BOUNDS)
		sim._collide_player_bullets()
	var hps := PackedFloat32Array()
	for e: SimEnemy in sim.enemies:
		hps.append(e.hp)
	check.call(hps == PackedFloat32Array([90.0, 90.0, 90.0]) and sim.player_bullets.count == 0,
			"Perfuração: atravessa 3 inimigos acertando cada um uma vez e some no último (%s)" % str(hps))
	var pool := BulletPool.new(2)
	pool.spawn(Vector2.ZERO, Vector2.ZERO, 3.0, 0)
	pool.spawn(Vector2.ZERO, Vector2.ZERO, 3.0, 0)
	pool.mark_hit(1, 77)
	pool.kill(0)
	check.call(pool.has_hit(0, 77) and not pool.has_hit(0, 5), "Perfuração: matar uma bala leva o anel de alvos junto")
	pool.spawn(Vector2.ZERO, Vector2.ZERO, 3.0, 0)
	check.call(not pool.has_hit(1, 77), "Perfuração: bala nova nasce sem alvos")


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


## Missão inteira pelo bot, uma unidade por missão (tests/test_shard.gd divide as unidades entre
## processos): termina, vence, respeita os tetos de balas e o ritmo. A c1m1 também confere o
## determinismo: duas vezes com a mesma semente (mesmo hash) e uma com outra semente.
## Peso de cada unidade: a duração do roteiro (length_s), que acompanha o custo da partida.
func mission_units() -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	for id: StringName in mission_ids():
		var length := float(Sim.load_mission(id).get("length_s", 180.0))
		if id == &"c1m1":
			units.append({"name": "Missão c1m1 e determinismo", "weight": length * 3.0,
					"run": _mission_c1m1})
			units.append({"name": "Campo alto (c1m1 em 640) e replay", "weight": length * 2.0, "run": _tall_field})
		else:
			units.append({"name": "Missão %s" % id, "weight": length, "run": _mission_one.bind(id)})
	return units


func _mission_c1m1(check: Callable) -> void:
	var mission := Sim.load_mission(&"c1m1")
	var first := run_bot(mission, _tables_once(), 7)
	var second := run_bot(mission, _tables_once(), 7)
	var other := run_bot(mission, _tables_once(), 11)
	check.call(first["hash"] == second["hash"], "Determinismo: mesma semente, mesmo estado")
	check.call(bool(other["finished"]), "Missão: o bot termina a c1m1 com outra semente")
	_mission_checks(check, &"c1m1", first)


func _mission_one(check: Callable, id: StringName) -> void:
	_mission_checks(check, id, run_bot(Sim.load_mission(id), _tables_once(), 7))


func _mission_checks(check: Callable, id: StringName, run: Dictionary) -> void:
	var r: Dictionary = run["result"]
	if "--verbose" in OS.get_cmdline_user_args():
		print("Missão %s semente 7: " % id, r, " pico de balas ", run["peak"])
	check.call(bool(run["finished"]), "Missão: o bot termina a %s (%d passos)" % [id, run["frames"]])
	check.call(bool(r.get("cleared", false)), "Missão: o bot vence a %s (casco %s)" % [id, r.get("hull")])
	check.call(int(run["peak"]) <= 300, "Densidade %s: no máximo 300 balas vivas (%d)" % [id, run["peak"]])
	var seconds := float(r.get("seconds", 0.0))
	check.call(seconds >= 120.0 and seconds <= 330.0, "Ritmo %s: de 2 a 5,5 min (%.0f s)" % [id, seconds])
	# 50 abates, ou 80% dos inimigos das ondas nas fases curtas (a c7m3s tem 50 ao todo: 50 exigia todos).
	var spawned := 0
	for ev: Variant in Sim.load_mission(id).get("events", []):
		if String((ev as Dictionary).get("op", "")) == "wave":
			spawned += int((ev as Dictionary).get("count", 1))
	var need := mini(50, ceili(spawned * 0.8))
	check.call(int(r.get("kills", 0)) >= need, "Missão %s: o bot derruba a maioria (%d de %d, mínimo %d)" % [id,
			r.get("kills"), spawned, need])
	# Objetivos de fase (SimObjectives): todos os do roteiro começam e terminam antes do fim da missão.
	var planned := (Sim.load_mission(id).get("objectives", []) as Array).size()
	var goals: Array = r.get("objectives", [])
	var ok := 0
	for g: Variant in goals:
		ok += 1 if bool((g as Dictionary)["ok"]) else 0
	check.call(planned >= 2 and goals.size() == planned, "Missão %s: os %d objetivos de fase acontecem (%d, %d com êxito)"
			% [id, planned, goals.size(), ok])


## Campo alto (Playfield.MAX_HEIGHT): a nave começa à mesma distância do fundo, o bot ainda vence, o replay
## (que guarda field_h na carga) reproduz o mesmo hash, e um replay antigo, sem field_h, roda no campo de 450.
func _tall_field(check: Callable) -> void:
	var mission := Sim.load_mission(&"c1m1")
	var tall := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["field_h"] = Playfield.MAX_HEIGHT
	tall.setup(mission, _tables_once(), load, 7)
	check.call(tall.field == Vector2(270, 640) and tall.player.pos.y == SimPlayer.START.y + 190.0
			and tall.bounds.end.y == Sim.BOUNDS.end.y + 190.0, "Campo alto: 270x640, nave e limite das balas descem 190")
	var odd := Sim.new()
	var big := Sim.default_loadout(&"falcon")
	big["field_h"] = 9000.0
	odd.setup(mission, _tables_once(), big, 7)
	check.call(odd.field.y == Playfield.MAX_HEIGHT, "Campo alto: altura fora da faixa vira o teto")
	var run := run_bot(mission, _tables_once(), 7, Playfield.MAX_HEIGHT)
	_mission_checks(check, &"c1m1", run)
	var rec: Replay = run["replay"]
	var again := Replay.from_dict(rec.to_dict()).make_sim()
	_replay(again, rec)
	check.call(again.field.y == Playfield.MAX_HEIGHT and again.state_hash() == run["hash"],
			"Replay: guarda a altura do campo e reproduz o mesmo estado")
	var short := run_bot(mission, _tables_once(), 7)
	var old := (short["replay"] as Replay).to_dict()
	(old["loadout"] as Dictionary).erase("field_h")
	var legacy := Replay.from_dict(old)
	var legacy_sim := legacy.make_sim()
	_replay(legacy_sim, legacy)
	check.call(legacy_sim.field.y == Playfield.FIELD.y and legacy_sim.state_hash() == short["hash"],
			"Replay antigo (sem field_h): roda no campo de 450 e dá o mesmo estado")


static func _replay(sim: Sim, rec: Replay) -> void:
	rec.rewind()
	var input := rec.next_input()
	while input != null:
		sim.step(input)
		sim.take_events()
		input = rec.next_input()


## As tabelas são só leitura na Sim: uma carga por processo serve a todas as missões.
func _tables_once() -> Dictionary:
	if _tables.is_empty():
		_tables = Sim.load_tables()
	return _tables


## Ids das missões em data/stages/, em ordem.
static func mission_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for file: String in DirAccess.get_files_at("res://data/stages"):
		if file.ends_with(".json"):
			ids.append(StringName(file.get_basename()))
	ids.sort()
	return ids


## `field_h` 0 = sem altura na carga (campo de 450, como os replays antigos). Devolve também o replay gravado.
static func run_bot(mission: Dictionary, tables: Dictionary, seed: int, field_h: float = 0.0) -> Dictionary:
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	if field_h > 0.0:
		load["field_h"] = field_h
	sim.setup(mission, tables, load, seed)
	var rec := Replay.new(mission, seed, load)
	var bot := BotPilot.new()
	var peak := 0
	while not sim.finished and sim.frame < MAX_FRAMES:
		var input := bot.decide(sim)
		rec.record(input)
		sim.step(input)
		for ev: Dictionary in sim.take_events():
			if ev["type"] == &"player_hit" and "--verbose" in OS.get_cmdline_user_args():
				print("dano no passo %d: %s em %s (chefe %s)" % [ev["frame"], ev["cause"], ev["pos"],
						sim.boss.id if sim.boss != null else "-"])
		peak = maxi(peak, sim.enemy_bullets.count)
	return {"finished": sim.finished, "frames": sim.frame, "result": sim.result(), "hash": sim.state_hash(),
			"peak": peak, "replay": rec}
