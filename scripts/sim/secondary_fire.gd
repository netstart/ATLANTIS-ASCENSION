class_name SecondaryFire
extends RefCounted
## Armas secundárias (plano mestre 4.1), escolhidas no hangar e com nível do módulo (1 a 5):
## - Mísseis: a cada 1,2 s saem 1 a 3 pares que buscam o alvo mais próximo do topo.
## - Drones: 1 a 3 drones orbitam a nave e atiram reto com 30% do dano da arma principal.
## A especial "Enxame de drones" soma 6 drones temporários pelo mesmo caminho.

const MISSILE_INTERVAL := 72
const MISSILE_SPEED := 250.0
const MISSILE_TURN := 7.0
const MISSILE_DAMAGE := 7.0
const MISSILE_RADIUS := 5.0
const MISSILE_LIFE := 240
const DRONE_INTERVAL := 8
const DRONE_ORBIT := 26.0
const DRONE_SHARE := 0.3


static func missile_pairs(level: int) -> int:
	return clampi(1 + floori((level - 1) / 2.0), 1, 3)


static func drone_count(level: int) -> int:
	return clampi(1 + floori((level - 1) / 2.0), 1, 3)


## Um passo das secundárias: dispara, guia e colide os mísseis; posiciona e dispara os drones.
static func step(sim: Sim) -> void:
	var p := sim.player
	if not p.alive:
		return
	var weapon_def: Dictionary = (sim.tables["weapons"] as Dictionary).get(p.weapon, {})
	if sim.secondary == &"missiles" and sim.frame % MISSILE_INTERVAL == 0:
		var dmg := MISSILE_DAMAGE * sim.damage_mult()
		for k: int in range(missile_pairs(sim.secondary_level)):
			for side: float in [-1.0, 1.0]:
				sim.missiles.append({"pos": p.pos + Vector2(side * (10.0 + k * 4.0), 4.0),
						"vel": Vector2(side * 90.0, -160.0), "life": 0, "dmg": dmg,
						"pierce": 1 if sim.mods.harpoon else 0, "last": 0})
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
		if hit or int(m["life"]) > MISSILE_LIFE or not Sim.BOUNDS.has_point(pos):
			sim.missiles.remove_at(i)
		i -= 1
