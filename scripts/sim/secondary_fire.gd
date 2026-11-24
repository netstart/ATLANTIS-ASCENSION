class_name SecondaryFire
extends RefCounted
## Armas secundárias (plano mestre 4.1), escolhidas no hangar e com nível do módulo (1 a 5):
## - Mísseis: a cada 1,2 s saem 1 a 3 pares que buscam o alvo mais próximo do topo.
## - Drones: 1 a 3 drones orbitam a nave e atiram reto com 30% do dano da arma principal.
## A especial "Enxame de drones" soma 6 drones temporários pelo mesmo caminho.
## - Mísseis do mar (revisão 8 da Sim): nas missões de água (Weather.MEDIUM_OF) toda nave solta sozinha um par a cada
##   1 s, que busca primeiro submarinos e navios (Sim.nearest_target), os únicos alvos que o tiro não alcança. Não
##   soma com a secundária "missiles": ela já busca o mar primeiro com mais dano por segundo (≥ 1 par de 7 a cada
##   1,2 s contra 1 par de 5 a cada 1 s), então o lançador do mar fica desligado nessas naves. Durante a luta de um
##   chefe ele só dispara se houver alvo no mar: as lutas ficam com o dano e o ritmo para que foram medidas.

const MISSILE_INTERVAL := 72
const MISSILE_SPEED := 250.0
const MISSILE_TURN := 7.0
const MISSILE_DAMAGE := 7.0
const MISSILE_RADIUS := 5.0
const MISSILE_LIFE := 240
## Submarino (30 de vida) cai em 3 pares, o navio (70) em 7: dá tempo, ele cruza o campo em uns 20 s.
const SEA_INTERVAL := 60
const SEA_DAMAGE := 5.0
## Revisão da Sim (SimRevision) com inimigos do mar e o lançador automático.
const SEA_REVISION := 8
const DRONE_INTERVAL := 8
const DRONE_ORBIT := 26.0
const DRONE_SHARE := 0.3


static func missile_pairs(level: int) -> int:
	return clampi(1 + floori((level - 1) / 2.0), 1, 3)


static func drone_count(level: int) -> int:
	return clampi(1 + floori((level - 1) / 2.0), 1, 3)


## A nave solta os mísseis do mar sozinha nesta partida? (missão de água, revisão 8+, sem a secundária de mísseis)
static func sea_launcher(sim: Sim) -> bool:
	if sim.secondary == &"missiles" or SimRevision.of(sim.loadout) < SEA_REVISION:
		return false
	return Weather.MEDIUM_OF.get(StringName(String(sim.mission.get("backdrop", ""))), &"") == &"water"


## Um passo das secundárias: dispara, guia e colide os mísseis; posiciona e dispara os drones.
static func step(sim: Sim) -> void:
	var p := sim.player
	if not p.alive:
		return
	var weapon_def: Dictionary = (sim.tables["weapons"] as Dictionary).get(p.weapon, {})
	if sim.secondary == &"missiles" and sim.frame % MISSILE_INTERVAL == 0:
		_launch(sim, missile_pairs(sim.secondary_level), MISSILE_DAMAGE)
	elif sim.frame % SEA_INTERVAL == 0 and sea_launcher(sim) and (sim.boss == null or sea_in_field(sim)):
		_launch(sim, 1, SEA_DAMAGE)
	_guide(sim)
	var count := 0
	if sim.secondary == &"drones":
		count = drone_count(sim.secondary_level)
	if sim.special_kind == &"drone_swarm" and sim.special_frames > 0:
		count += 6
	count += ShipTraits.extra_drones(sim)
	sim.drones.clear()
	if sim.mods.rear_cover and sim.frame % 18 == 0:
		var back := BulletKinds.player_index(&"shot_back")
		for deg: float in [60.0, 120.0]:
			sim.player_bullets.spawn(p.pos, Vector2.from_angle(deg_to_rad(deg)) * 360.0, 4.0, back,
					4.0 * sim.damage_mult())
	if count == 0:
		return
	var per := WeaponFire.dps(weapon_def, p.level) * DRONE_SHARE * sim.damage_mult() / (60.0 / DRONE_INTERVAL) \
			/ maxf(1.0, float(mini(count, 3)))
	var shot := BulletKinds.player_index(&"shot_pulsar")
	for k: int in range(count):
		var a := TAU * k / count + sim.frame * 0.05
		var d := Vector2(cos(a) * DRONE_ORBIT, sin(a) * DRONE_ORBIT * 0.55 + 6.0)
		sim.drones.append(p.pos + d)
		if (sim.frame + k * 3) % DRONE_INTERVAL == 0:
			sim.player_bullets.spawn(p.pos + d + Vector2(0, -6), Vector2(0, -WeaponFire.SHOT_SPEED), 3.0, shot, per)


static func _launch(sim: Sim, pairs: int, damage: float) -> void:
	var p := sim.player
	var dmg := damage * sim.damage_mult()
	for k: int in range(pairs):
		for side: float in [-1.0, 1.0]:
			sim.missiles.append({"pos": p.pos + Vector2(side * (10.0 + k * 4.0), 4.0),
					"vel": Vector2(side * 90.0, -160.0), "life": 0, "dmg": dmg,
					"pierce": 1 if sim.mods.harpoon else 0, "last": 0})


static func _guide(sim: Sim) -> void:
	var i := sim.missiles.size() - 1
	while i >= 0:
		var m := sim.missiles[i]
		var pos: Vector2 = m["pos"]
		var vel: Vector2 = m["vel"]
		var target := sim.nearest_target(pos)
		if target != Vector2.INF:
			var want := (target - pos).normalized() * MISSILE_SPEED
			vel = vel.lerp(want, minf(1.0, MISSILE_TURN * Sim.STEP))
		else:
			vel = vel.lerp(Vector2(0, -MISSILE_SPEED), 0.05)
		pos += vel * Sim.STEP
		m["pos"] = pos
		m["vel"] = vel
		m["life"] = int(m["life"]) + 1
		# O arpão atravessa um alvo: o que já levou o golpe fica de fora enquanto o míssil passa por ele.
		var struck := sim.hit_at_id(pos, MISSILE_RADIUS, float(m["dmg"]), int(m.get("last", 0)))
		var hit := struck != 0
		if hit:
			sim.emit(&"hit", {"pos": pos})
			if int(m["pierce"]) > 0:
				m["pierce"] = int(m["pierce"]) - 1
				m["last"] = struck
				hit = false
		if hit or int(m["life"]) > MISSILE_LIFE or not sim.bounds.has_point(pos):
			sim.missiles.remove_at(i)
		i -= 1


## Algum submarino ou navio na superfície dentro do campo?
static func sea_in_field(sim: Sim) -> bool:
	for e: SimEnemy in sim.enemies:
		if e.sea and e.active() and Rect2(Vector2.ZERO, sim.field).has_point(e.pos):
			return true
	return false
