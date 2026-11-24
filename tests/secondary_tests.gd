extends RefCounted
## Testes da secundária com nível na fase (revisão 10 da Sim, SecondaryFire): a Oficina dá o nível inicial, cada orbe
## sobe a arma principal e a secundária (teto 5), cada dano desce 1; mísseis 2/4/6 nos níveis 1 a 3 e dano x1,5/x2
## (com estilhaço no 5); drones 1/2/3 e dano crescente com tiro próprio nos níveis 4 e 5; o lançador do mar fica fixo
## (1 par de 5, sem nível); replays de revisão 9 continuam com o nível fixo da Oficina.
## Chamado por tests/run_tests.gd (regras rápidas, sem autoloads).

var _tables: Dictionary = {}


func run_unit(check: Callable) -> void:
	_tables = Sim.load_tables()
	_start_levels(check)
	_orbs_and_hits(check)
	_missiles(check)
	_warhead_splash(check)
	_drones(check)
	_sea_launcher(check)
	_old_revision(check)


func _sim(kind: String, workshop: int, rev: int = SimRevision.CURRENT, backdrop: String = "storm") -> Sim:
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["rev"] = rev
	load["secondary"] = kind
	load["secondary_level"] = workshop
	sim.setup({"id": "secondary_test", "chapter": 1, "backdrop": backdrop, "events": []}, _tables, load, 7)
	sim.player.invuln = 0
	return sim


## Um disparo dos mísseis (quadro múltiplo do intervalo): devolve os mísseis lançados.
func _volley(sim: Sim) -> Array[Dictionary]:
	sim.missiles.clear()
	sim.frame = 0
	SecondaryFire.step(sim)
	return sim.missiles.duplicate()


func _start_levels(check: Callable) -> void:
	var got: Array[int] = []
	for w: int in range(1, 6):
		got.append(_sim("missiles", w).secondary_level)
	check.call(got == [1, 1, 2, 2, 3], "Secundária: Oficina 1..5 começa a fase nos níveis 1,1,2,2,3 (%s)" % [got])
	check.call(SimRevision.CURRENT >= SecondaryFire.LEVEL_REVISION, "Secundária: nível na fase ativo nas partidas novas")


func _orbs_and_hits(check: Callable) -> void:
	var sim := _sim("missiles", 1)
	var ups: Array[bool] = []
	sim.events.clear()
	sim.collect(&"orb", 0)
	var ev: Dictionary = sim.events[-1]
	check.call(sim.player.level == 2 and sim.secondary_level == 2 and bool(ev.get("secondary_up", false)),
			"Secundária: orbe sobe a arma principal e a secundária")
	for k: int in range(8):
		sim.collect(&"power", 0)
		ups.append(bool(sim.events[-1].get("secondary_up", false)))
	check.call(sim.secondary_level == SecondaryFire.MAX_LEVEL and not ups[-1],
			"Secundária: teto no nível 5 (sem som de subida depois dele)")
	sim._player_hit(&"test")
	check.call(sim.secondary_level == 4 and sim.player.alive, "Secundária: dano desce 1 nível")
	var bare := _sim("", 1)
	bare.collect(&"orb", 0)
	check.call(not bool(bare.events[-1].get("secondary_up", false)) and not SecondaryFire.shown(bare),
			"Secundária: sem secundária (e fora do mar) não mostra nem toca subida")


func _missiles(check: Callable) -> void:
	var counts: Array[int] = []
	var dmg: Array[float] = []
	var splash: Array[float] = []
	var tiers: Array[int] = []
	var sim := _sim("missiles", 1)
	for lvl: int in range(1, 6):
		sim.secondary_level = lvl
		var volley := _volley(sim)
		counts.append(volley.size())
		dmg.append(float(volley[0]["dmg"]) / sim.damage_mult())
		splash.append(float(volley[0]["splash"]))
		tiers.append(int(volley[0]["tier"]))
	check.call(counts == [2, 4, 6, 6, 6], "Secundária: 2, 4 e 6 mísseis nos níveis 1 a 3 (%s)" % [counts])
	var base := SecondaryFire.MISSILE_DAMAGE
	check.call(is_equal_approx(dmg[2], base) and is_equal_approx(dmg[3], base * 1.5)
			and is_equal_approx(dmg[4], base * 2.0), "Secundária: Ogiva I x1,5 e Ogiva II x2 de dano (%s)" % [dmg])
	check.call(splash[3] == 0.0 and splash[4] == SecondaryFire.WARHEAD_SPLASH and tiers == [1, 2, 3, 4, 5],
			"Secundária: só a Ogiva II tem estilhaço; o nível vai no míssil para o desenho")


func _warhead_splash(check: Callable) -> void:
	var sim := _sim("missiles", 1)
	sim.secondary_level = SecondaryFire.MAX_LEVEL
	var a := _spawn(sim, "skiff", Vector2(135, 150))
	var b := _spawn(sim, "skiff", Vector2(147, 150))
	var sub := _spawn(sim, "sea_submarine", Vector2(123, 150))
	sim.missiles.append({"pos": a.hit_pos(), "vel": Vector2(0, -SecondaryFire.MISSILE_SPEED), "life": 0,
			"dmg": 14.0, "pierce": 0, "last": 0, "tier": 5, "splash": SecondaryFire.WARHEAD_SPLASH})
	sim.frame = 1
	SecondaryFire.step(sim)
	check.call(b.hp < b.max_hp and is_equal_approx(sub.hp, sub.max_hp),
			"Secundária: estilhaço da Ogiva II fere o vizinho no ar e não chega ao mar")


func _spawn(sim: Sim, id: String, at: Vector2) -> SimEnemy:
	sim.spawn_enemy({"enemy": id, "x": at.x / Playfield.FIELD.x, "y": at.y, "path": "scroll",
			"params": {"speed": 0.0}}, 0)
	return sim.enemies[-1]


func _drones(check: Callable) -> void:
	var counts: Array[int] = []
	var per: Array[float] = []
	var kinds: Array[int] = []
	var sim := _sim("drones", 1)
	for lvl: int in range(1, 6):
		sim.secondary_level = lvl
		sim.player_bullets.clear()
		sim.frame = 0
		SecondaryFire.step(sim)
		counts.append(sim.drones.size())
		per.append(sim.player_bullets.damage[0] * sim.drones.size())
		kinds.append(sim.player_bullets.kind[0])
	check.call(counts == [1, 2, 3, 3, 3], "Secundária: 1, 2 e 3 drones nos níveis 1 a 3 (%s)" % [counts])
	check.call(per[0] < per[1] and per[1] < per[2] and is_equal_approx(per[3], per[2] * 1.5)
			and is_equal_approx(per[4], per[2] * 2.0),
			"Secundária: drones mais fortes a cada nível, x1,5 e x2 no 4 e 5 (%s)" % [per])
	check.call(kinds[2] == BulletKinds.player_index(&"shot_pulsar")
			and kinds[3] == BulletKinds.player_index(&"shot_drone_heavy")
			and kinds[4] == BulletKinds.player_index(&"shot_drone_gold"), "Secundária: tiro próprio dos drones nos níveis 4 e 5")


func _sea_launcher(check: Callable) -> void:
	var sim := _sim("", 1, SimRevision.CURRENT, "ocean")
	check.call(SecondaryFire.sea_launcher(sim) and not SecondaryFire.shown(sim),
			"Secundária: o lançador do mar não é secundária (sem nível no HUD)")
	var counts: Array[int] = []
	var dmg: Array[float] = []
	for lvl: int in [1, 3, 5]:
		sim.secondary_level = lvl
		sim.missiles.clear()
		sim.frame = SecondaryFire.SEA_INTERVAL
		SecondaryFire.step(sim)
		counts.append(sim.missiles.size())
		dmg.append(float(sim.missiles[0]["dmg"]) / sim.damage_mult())
	check.call(counts == [2, 2, 2] and is_equal_approx(dmg[2], SecondaryFire.SEA_DAMAGE)
			and int(sim.missiles[0]["tier"]) == 1, "Secundária: lançador do mar fixo em 1 par de 5 em qualquer nível (%s, %s)"
			% [counts, dmg])


func _old_revision(check: Callable) -> void:
	var old := SecondaryFire.LEVEL_REVISION - 1
	var sim := _sim("missiles", 5, old)
	sim.collect(&"orb", 0)
	sim._player_hit(&"test")
	var volley := _volley(sim)
	check.call(sim.secondary_level == 5 and volley.size() == 6
			and is_equal_approx(float(volley[0]["dmg"]) / sim.damage_mult(), SecondaryFire.MISSILE_DAMAGE),
			"Secundária: revisão 9 mantém o nível fixo da Oficina (6 mísseis de 7)")
	var low := _sim("missiles", 2, old)
	check.call(low.secondary_level == 2 and _volley(low).size() == 2, "Secundária: revisão 9, Oficina 2 = 1 par")
	var sea := _sim("", 1, old, "ocean")
	sea.secondary_level = 5
	sea.frame = SecondaryFire.SEA_INTERVAL
	SecondaryFire.step(sea)
	check.call(sea.missiles.size() == 2, "Secundária: revisão 9, lançador do mar sempre 1 par")
	var drones := _sim("drones", 5, old)
	drones.frame = 0
	SecondaryFire.step(drones)
	var weapon_def: Dictionary = (_tables["weapons"] as Dictionary).get(drones.player.weapon, {})
	var want := WeaponFire.dps(weapon_def, drones.player.level) * SecondaryFire.DRONE_SHARE * drones.damage_mult() \
			/ (60.0 / SecondaryFire.DRONE_INTERVAL) / 3.0
	check.call(drones.drones.size() == 3 and is_equal_approx(drones.player_bullets.damage[0], want),
			"Secundária: revisão 9, drones com o dano de antes")
