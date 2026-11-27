class_name SimCurve
extends RefCounted
## Curva de dificuldade por capítulo (revisão 3 da Sim, SimRevision; plano mestre 4.7). Do capítulo 1 (posição 0) ao
## 10 (posição 1 na normal; a dificuldade escala a posição com DIFFICULTY "curve" da Sim) as balas ficam mais rápidas,
## os padrões repetem mais depressa (esperas mais curtas) e inimigos e chefes de ato aguentam mais. Nunca adiciona
## padrões nem balas por emissão: só tempo, velocidade e vida. Replays de revisões anteriores ficam na posição 0.
##
## Na normal, no capítulo 10: balas +BULLET, cadência +CADENCE, vida dos inimigos +HP e do chefe de ato +BOSS_HP.

const BULLET := 0.3
const CADENCE := 0.45
const HP := 0.8
const BOSS_HP := 0.15
## Rank na cadência: ±RANK_CADENCE nas esperas dos padrões, além dos ±12% na velocidade das balas (Sim).
const RANK_CADENCE := 0.1
## Co-op (local e LAN): são duas naves atirando, então inimigos comuns e chefes aguentam mais. Só vida: a contagem, a
## cadência e a velocidade das balas ficam as do solo (com mais balas ninguém sobrevive). Medido com
## tests/boss_timing.gd --coop: o tempo de fase e de chefe do par fica perto do solo.
const COOP_HP := 1.7
const COOP_BOSS_HP := 1.8


## Posição na curva de uma partida: 0 antes da revisão 3 ou no capítulo 1; `scale` é o "curve" da dificuldade.
static func position(loadout: Dictionary, mission: Dictionary, scale: float) -> float:
	if SimRevision.of(loadout) < 3:
		return 0.0
	return clampf((int(mission.get("chapter", 1)) - 1) / 9.0, 0.0, 1.0) * scale


## Multiplicador da velocidade das balas inimigas agora (Sim.bullet_speed_mult): dificuldade, rank (±12%), curva,
## chefe desesperado, Segunda Maré, Correntes e Abismo Infinito.
static func bullet_speed(sim: Sim) -> float:
	var diff: Dictionary = Sim.DIFFICULTY[sim.difficulty]
	var mult := float(diff["bullet"])
	if bool(diff["rank"]):
		mult *= 1.0 + 0.12 * (sim.rank - 0.5) * 2.0
	mult *= 1.0 + BULLET * sim.curve
	if sim.boss != null and sim.boss.desperate:
		mult *= 1.15
	if sim.second_tide:
		mult *= 1.15
	if "fast_bullets" in sim.mutators:
		mult *= 1.2
	if sim.abyss_depth > 1:
		mult *= 1.0 + minf(0.45, 0.01 * (sim.abyss_depth - 1))
	return mult


## Multiplicador das esperas ("wait") dos padrões inimigos nesta partida (1 antes da revisão 3).
static func wait_for(sim: Sim) -> float:
	if SimRevision.of(sim.loadout) < 3:
		return 1.0
	return wait_mult(sim.curve, sim.rank if bool((Sim.DIFFICULTY[sim.difficulty] as Dictionary)["rank"]) else -1.0)


## Multiplicador das esperas ("wait") dos padrões inimigos: menor = atira mais depressa. `rank` < 0 = rank desligado.
static func wait_mult(curve: float, rank: float) -> float:
	var pace := 1.0 + CADENCE * curve
	if rank >= 0.0:
		pace *= 1.0 + RANK_CADENCE * (rank - 0.5) * 2.0
	return 1.0 / pace


## Vida de um inimigo comum. Quem desce com o cenário ("scroll": torre de coral, trirreme) fecha a faixa até cair:
## mais vida ali vira parede, não desafio, e ele fica com a vida da tabela.
## `coop`: duas naves atirando (COOP_HP); o inimigo do mar fica de fora, porque só os mísseis o ferem e eles não dobram.
static func apply_enemy(e: SimEnemy, curve: float, coop: bool = false) -> void:
	if curve > 0.0 and e.path != &"scroll":
		e.max_hp *= 1.0 + HP * curve
		e.hp = e.max_hp
	if coop and e.path != &"scroll" and not e.sea:
		e.max_hp *= COOP_HP
		e.hp = e.max_hp


## Vida de um chefe. Só o chefe de ato (o do duelo) sobe: os de meio de fase já sobem por capítulo na tabela
## (tools/gen_bosses_mid.py CHAPTER_HP) e a fase precisa caber em 5,5 min.
static func boss_hp_mult(curve: float, def: Dictionary, coop: bool = false) -> float:
	var mult := 1.0 + BOSS_HP * curve if bool(def.get("duel", false)) else 1.0
	return mult * COOP_BOSS_HP if coop else mult


## Nave que uma bala mirada de `from` procura: no co-op, a mais perto das duas (empate: a nave 1), para a ala também
## correr perigo sem nascer nenhuma bala a mais; no solo, a nave 1.
static func target(sim: Sim, from: Vector2) -> SimPlayer:
	var wing := sim.wing
	if wing != null and wing.alive and from.distance_squared_to(wing.pos) < from.distance_squared_to(sim.player.pos):
		return wing
	return sim.player
