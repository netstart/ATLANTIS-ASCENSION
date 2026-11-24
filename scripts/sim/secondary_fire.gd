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
## - Nível na fase (revisão 10 da Sim): o módulo da Oficina só dá o nível inicial (start_level); cada orbe sobe 1
##   (até 5) e cada dano tira 1, como a arma principal. Uma escala para as duas secundárias (o lançador do mar é
##   sistema automático das fases de água, não secundária: segue fixo em 1 par de 5, sem nível):
##   níveis 1 a 3 = 1, 2 e 3 pares de mísseis (1, 2 e 3 drones); 4 = "Ogiva I" (+50% de dano, míssil maior com rastro
##   aceso, drones de tiro grosso violeta); 5 = "Ogiva II" (2x dano, ogiva dourada com estilhaço em área, drones
##   dourados). O estilhaço é Sim.splash: não chega ao mar nem ao chefe, que só levam o golpe direto do míssil.

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
## Revisão da Sim com o nível da secundária na fase e o teto dele.
const LEVEL_REVISION := 10
const MAX_LEVEL := 5
## Multiplicador do dano dos mísseis por nível na fase (Ogiva I e II nos níveis 4 e 5).
const TIER_DAMAGE: Array[float] = [1.0, 1.0, 1.0, 1.5, 2.0]
## Parte do dano por segundo da arma principal que os drones da secundária somam, por nível na fase (antes 0,3 em
## qualquer nível): cada drone a mais soma um pouco, e os níveis 4 e 5 são 1,5x e 2x o nível 3.
const DRONE_SHARES: Array[float] = [0.3, 0.35, 0.4, 0.6, 0.8]
## Raio do estilhaço da Ogiva II (Sim.splash: metade do dano do míssil em quem estiver nele).
const WARHEAD_SPLASH := 18.0


static func missile_pairs(level: int) -> int:
	return clampi(1 + floori((level - 1) / 2.0), 1, 3)


static func drone_count(level: int) -> int:
	return clampi(1 + floori((level - 1) / 2.0), 1, 3)


## A partida usa o nível da secundária na fase (revisão 10+)? Antes dela Sim.secondary_level é o da Oficina, fixo.
static func phased(sim: Sim) -> bool:
	return SimRevision.of(sim.loadout) >= LEVEL_REVISION


## Nível inicial na fase para o módulo da Oficina (1 a 5): a mesma quantidade de mísseis e drones que o módulo dava
## antes da revisão 10 (1, 1, 2, 2, 3), para ninguém começar mais fraco; os orbes levam daí até 5.
static func start_level(workshop: int) -> int:
	return missile_pairs(workshop)


## Pares de mísseis, drones da secundária e multiplicador de dano dos mísseis no nível atual da partida.
static func pairs_at(sim: Sim) -> int:
	return mini(sim.secondary_level, 3) if phased(sim) else missile_pairs(sim.secondary_level)


static func drones_at(sim: Sim) -> int:
	return mini(sim.secondary_level, 3) if phased(sim) else drone_count(sim.secondary_level)


static func tier_damage(sim: Sim) -> float:
	return TIER_DAMAGE[clampi(sim.secondary_level, 1, MAX_LEVEL) - 1] if phased(sim) else 1.0


## A nave tem secundária que mostra nível (a escolhida no hangar ou a de um módulo)?
static func shown(sim: Sim) -> bool:
	return phased(sim) and sim.secondary != &""


## Orbe coletado (revisão 10+): sobe 1 nível. Devolve true se subiu um nível que a nave mostra.
static func level_up(sim: Sim) -> bool:
	if not phased(sim) or sim.secondary_level >= MAX_LEVEL:
		return false
	sim.secondary_level += 1
	return shown(sim)


## Dano no casco (revisão 10+): desce 1 nível, como a arma principal.
static func level_down(sim: Sim) -> void:
	if phased(sim):
		sim.secondary_level = maxi(1, sim.secondary_level - 1)


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
		_launch(sim, pairs_at(sim), MISSILE_DAMAGE, true)
	elif sim.frame % SEA_INTERVAL == 0 and sea_launcher(sim) and (sim.boss == null or sea_in_field(sim)):
		_launch(sim, 1, SEA_DAMAGE, false)
	_guide(sim)
	var own := 0
	if sim.secondary == &"drones":
		own = drones_at(sim)
	var count := own
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
	# Revisão 10: os drones da secundária (os primeiros `own` da lista) atiram com o dano do nível na fase e, nos níveis
	# 4 e 5, com um tiro próprio; os do especial e do traço da nave seguem com o dano de antes.
	var own_per := per
	var own_shot := shot
	if own > 0 and phased(sim):
		var lvl := clampi(sim.secondary_level, 1, MAX_LEVEL)
		own_per = WeaponFire.dps(weapon_def, p.level) * DRONE_SHARES[lvl - 1] * sim.damage_mult() \
				/ (60.0 / DRONE_INTERVAL) / own
		own_shot = BulletKinds.player_index([&"shot_pulsar", &"shot_drone_heavy", &"shot_drone_gold"][maxi(0, lvl - 3)])
	for k: int in range(count):
		var a := TAU * k / count + sim.frame * 0.05
		var d := Vector2(cos(a) * DRONE_ORBIT, sin(a) * DRONE_ORBIT * 0.55 + 6.0)
		sim.drones.append(p.pos + d)
		if (sim.frame + k * 3) % DRONE_INTERVAL == 0:
			sim.player_bullets.spawn(p.pos + d + Vector2(0, -6), Vector2(0, -WeaponFire.SHOT_SPEED), 3.0,
					own_shot if k < own else shot, own_per if k < own else per)


## `leveled`: a secundária "missiles" (nível na fase); o lançador do mar dispara sempre o míssil comum.
static func _launch(sim: Sim, pairs: int, damage: float, leveled: bool) -> void:
	var p := sim.player
	var dmg := damage * sim.damage_mult() * (tier_damage(sim) if leveled else 1.0)
	# "tier" é só para o desenho (SecondaryArt: 1 a 3 míssil comum, 4 Ogiva I, 5 Ogiva II).
	var tier := clampi(sim.secondary_level, 1, MAX_LEVEL) if leveled and phased(sim) else 1
	var area := WARHEAD_SPLASH if tier >= MAX_LEVEL else 0.0
	for k: int in range(pairs):
		for side: float in [-1.0, 1.0]:
			sim.missiles.append({"pos": p.pos + Vector2(side * (10.0 + k * 4.0), 4.0),
					"vel": Vector2(side * 90.0, -160.0), "life": 0, "dmg": dmg,
					"pierce": 1 if sim.mods.harpoon else 0, "last": 0, "tier": tier, "splash": area})


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
			if float(m.get("splash", 0.0)) > 0.0:
				sim.splash(pos, float(m["splash"]), float(m["dmg"]), true)
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
