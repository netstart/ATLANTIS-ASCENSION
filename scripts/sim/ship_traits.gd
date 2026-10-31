class_name ShipTraits
extends RefCounted
## Traços das aeronaves 7 a 12 (plano mestre 4.2, pós-lançamento) e a captura biomecânica (pesquisa,
## item 18). Cada traço muda o jeito de jogar, não só um número:
## - artillery (Ariete): agulhas da Railgun explodem em área no impacto.
## - drones (Enxame): 2 drones fixos além da secundária e da especial.
## - pierce (Eclipse): todo tiro atravessa mais um alvo (o Plasma vira perfurante).
## - crit (Nova): 1 em 5 tiros é crítico e causa dano x2,5 (fluxo "crit" da semente).
## - blast (Titan): todo abate explode e fere quem estiver perto.
## - hybrid (Ascension): a arma assinatura é a do orbe atual (nível 4 em todas) e a especial gira entre as 6.
##
## Captura: abater um inimigo marcado a curta distância o domina; ele voa ao lado por 10 s e atira junto.

const CAPTURE_RANGE := 56.0
const CAPTURE_FRAMES := 600
const MAX_ESCORTS := 2
const ESCORT_OFFSET := Vector2(30, 10)
const ESCORT_INTERVAL := 10
const ESCORT_SHARE := 0.25
const ARTILLERY_SPLASH := 14.0
const CRIT_CHANCE := 0.2
const CRIT_MULT := 2.5
const BLAST_RADIUS := 34.0
const BLAST_DAMAGE := 10.0
const EXTRA_DRONES := 2
const ROTATION: Array[StringName] = [&"area_bomb", &"focused_burst", &"drone_swarm", &"emp_pulse", &"gravity_rift",
		&"tide_shield"]


static func of(sim: Sim) -> StringName:
	return StringName(String(sim.player.ship.get("trait", "")))


## Ajusta as balas que a arma principal acabou de criar (índices de `from` até o fim do pool).
static func on_fire(sim: Sim, from: int) -> void:
	var t := of(sim)
	var pool := sim.player_bullets
	for i: int in range(from, pool.count):
		match t:
			&"artillery":
				if sim.player.weapon == &"railgun":
					pool.splash[i] = maxf(pool.splash[i], ARTILLERY_SPLASH)
			&"pierce":
				pool.pierce[i] += 1
			&"crit":
				if sim.rng.stream(&"crit").randf() < CRIT_CHANCE:
					pool.damage[i] *= CRIT_MULT
					pool.radius[i] += 1.0


## Especial da vez: a da nave ou, na Ascension, a próxima do rodízio.
static func special_for(sim: Sim) -> StringName:
	if of(sim) == &"hybrid":
		var kind := ROTATION[sim.specials_used % ROTATION.size()]
		sim.specials_used += 1
		return kind
	return StringName(String(sim.player.ship.get("special", "area_bomb")))


static func extra_drones(sim: Sim) -> int:
	return EXTRA_DRONES if of(sim) == &"drones" else 0


## Abate: explosão do Titan e captura de marcado à queima-roupa.
static func on_kill(sim: Sim, e: SimEnemy) -> void:
	if of(sim) == &"blast":
		sim.splash(e.pos, BLAST_RADIUS, BLAST_DAMAGE * sim.damage_mult())
	if e.marked and sim.player.alive and e.pos.distance_to(sim.player.pos) <= CAPTURE_RANGE \
			and sim.escorts.size() < MAX_ESCORTS:
		var used := 0.0
		for esc: Dictionary in sim.escorts:
			used = float(esc["side"])
		sim.escorts.append({"sprite": e.sprite, "tint": String(e.def.get("tint", "#ffffff")), "frames": CAPTURE_FRAMES,
				"side": -1.0 if used > 0.0 else 1.0, "pos": e.pos})
		sim.captured += 1
		sim.emit(&"capture", {"pos": e.pos, "sprite": e.sprite})


## Um passo: assinatura da Ascension e escolta capturada (posição, disparo e fim do domínio).
static func step(sim: Sim) -> void:
	var p := sim.player
	if of(sim) == &"hybrid":
		p.signature = p.weapon
	var i := sim.escorts.size() - 1
	while i >= 0:
		var esc := sim.escorts[i]
		esc["frames"] = int(esc["frames"]) - 1
		if int(esc["frames"]) <= 0 or not p.alive:
			sim.emit(&"escort_lost", {"pos": esc["pos"]})
			sim.escorts.remove_at(i)
			i -= 1
			continue
		var want := p.pos + Vector2(ESCORT_OFFSET.x * float(esc["side"]), ESCORT_OFFSET.y)
		esc["pos"] = (esc["pos"] as Vector2).lerp(want, 0.2)
		if sim.can_fire() and (sim.frame + i * 5) % ESCORT_INTERVAL == 0:
			var weapon_def: Dictionary = (sim.tables["weapons"] as Dictionary).get(p.weapon, {})
			var dmg := WeaponFire.dps(weapon_def, p.level) * ESCORT_SHARE * sim.damage_mult() / (60.0 / ESCORT_INTERVAL)
			sim.player_bullets.spawn(esc["pos"] as Vector2 + Vector2(0, -8), Vector2(0, -WeaponFire.SHOT_SPEED), 3.0,
					BulletKinds.player_index(&"shot_pulsar"), dmg)
		i -= 1
