class_name BotPilot
extends RefCounted
## Piloto automático dos testes (plano mestre 14): joga uma missão inteira de forma determinística a
## partir do estado da Sim. Não é a IA de um modo de jogo; serve para provar que toda missão termina,
## que todo padrão tem saída e que a partida é idêntica em 1x, 2x e 3x.
##
## A cada passo avalia 17 movimentos (parado e 16 direções), pontua o perigo das balas projetadas
## alguns passos à frente, dos feixes e do contato, soma a vontade de ficar embaixo do alvo e de pegar
## coletáveis, e escolhe o menor custo. Objetivos de fase (SimObjectives): mira primeiro nos alvos marcados e sobe
## atrás dos atlantes soltos e da relíquia, mas o perigo das balas continua mandando.

const STEP_LEN := 3.0
const LOOK_RADIUS := 110.0
const LOOKAHEAD: Array[int] = [0, 4, 8]
const HOME_Y := 380.0
## Distância (borda a borda) a partir da qual uma bala não pesa mais no custo.
const FAR_D := 26.0
## Folga do descarte de balas distantes em _view (bem acima do erro de arredondamento das distâncias).
const CULL_SLACK := 1.0
## Faixa junto às bordas onde ficar custa (_cornered) e o custo por unidade dentro dela.
const WALL := 30.0
const WALL_COST := 0.6
## PODER: perigo que dispara o Poder I e balas perto que pedem o Poder III.
const POWER_DANGER := 30.0
const POWER_CROWD := 40
## Prêmios (atlantes, relíquia, bomba e núcleo de força): alcance e peso da atração, mais longe e mais forte que a
## dos coletáveis comuns (correr atrás do mensageiro não pode fazer perder a bomba que cai do chefe).
const RESCUE_REACH := 200.0
const RESCUE_PULL := 0.015

var _dirs: Array[Vector2] = []


func _init() -> void:
	_dirs.append(Vector2.ZERO)
	for k: int in range(16):
		_dirs.append(Vector2.from_angle(TAU * k / 16.0) * STEP_LEN)


## Ala do co-op nos testes: o mesmo desvio, decidido com a ala no lugar da nave 1 (só leitura da Sim).
func decide_wing(sim: Sim) -> SimInput:
	if sim.wing == null:
		return SimInput.new()
	var lead := sim.player
	sim.player = sim.wing
	var input := decide(sim)
	sim.player = lead
	input.special = false
	input.power = false
	input.tide = false
	input.choice = -1
	return input


func decide(sim: Sim) -> SimInput:
	var input := SimInput.new()
	input.fire = true
	if not sim.offer.is_empty():
		input.choice = pick_blessing(sim)
		return input
	var me := sim.player.pos
	var near := PackedVector2Array()
	var near_vel := PackedVector2Array()
	var near_r := PackedFloat32Array()
	for i: int in range(sim.enemy_bullets.count):
		var p: Vector2 = sim.enemy_bullets.pos[i]
		if p.distance_squared_to(me) <= LOOK_RADIUS * LOOK_RADIUS:
			near.append(p)
			near_vel.append(sim.enemy_bullets.vel[i])
			near_r.append(sim.enemy_bullets.radius[i])
	var spots := PackedVector2Array()
	var reach := 0.0
	for d: Vector2 in _dirs:
		var c := me + d
		c = c.clamp(SimPlayer.MARGIN, sim.field - SimPlayer.MARGIN)
		spots.append(c)
		reach = maxf(reach, me.distance_to(c))
	var view := _view(sim, me, reach, near, near_vel, near_r)
	var target_x := _target_x(sim)
	var home_y := HOME_Y + sim.field.y - Playfield.FIELD.y
	# Acima do chefe (subiu atrás de um prêmio antes de ele chegar) o tiro não pega e a zona de contato tranca a
	# volta: contorna pelo lado mais perto e desce com mais vontade.
	var climb := 0.012
	if bool(view["boss_on"]) and me.y < (view["boss_pos"] as Vector2).y + 10.0:
		var bx: float = (view["boss_pos"] as Vector2).x
		var side := float(view["boss_reach"]) + 16.0
		target_x = clampf(bx - side if me.x < bx else bx + side, WALL, sim.field.x - WALL)
		climb = 0.05
	var best := INF
	var best_dir := Vector2.ZERO
	for c: Vector2 in spots:
		var cost := _danger(c, view)
		cost += absf(c.x - target_x) * 0.02 + absf(c.y - home_y) * climb
		cost -= _pickup_pull(c, view)
		cost += _cornered(c, sim.field)
		if cost < best - 0.0001:
			best = cost
			best_dir = c - me
	# Como a mão do jogador: desconta a deriva do vento ou da corrente e vence a resistência do meio.
	var want := best_dir - sim.weather.wind * Sim.STEP
	input.move = want / maxf(sim.player.speed_mult * sim.player.resist, 0.01)
	var danger_now := _danger(me, view)
	input.bomb = danger_now > 60.0 and sim.player.bombs > 0 and sim.player.vulnerable()
	input.special = sim.player.special_charge >= 1.0 and near.size() > 25
	input.tide = sim.scoring.pressure >= Scoring.PRESSURE_MAX and (near.size() > 15 or sim.boss != null)
	input.power = want_power(sim, danger_now, near.size())
	if sim.boss != null and sim.boss.state == SimBoss.State.DUEL:
		input.taps = 1 if sim.frame % 3 == 0 else 0
	return input


## O que o _danger e o _pickup_pull leem da Sim, calculado uma vez por passo em vez de uma vez por
## candidato (são 18 por passo). Mesmas expressões, na mesma ordem: o custo de cada candidato sai
## idêntico, bit a bit, e a partida (o hash) não muda.
##
## Bala projetada longe de todos os candidatos fica de fora: cada candidato está a no máximo `reach`
## de `me`, então a distância até ele é pelo menos a distância até `me` menos `reach` (desigualdade
## triangular). Com CULL_SLACK de folga para o arredondamento, a bala descartada teria d >= 26 em todo
## candidato, e nesse caso o _danger não soma nada por ela.
func _view(sim: Sim, me: Vector2, reach: float, near: PackedVector2Array, near_vel: PackedVector2Array,
		near_r: PackedFloat32Array) -> Dictionary:
	var hb := sim.player.hitbox
	# Ponto da hitbox fora do centro (Hitboxes, revisão 5): o custo é medido nele e o corte ganha a folga.
	var off := sim.player.hit_offset
	var slack := CULL_SLACK + off.length()
	var shot_pos := PackedVector2Array()
	var shot_r := PackedFloat32Array()
	for i: int in range(near.size()):
		for ahead: int in LOOKAHEAD:
			var p: Vector2 = near[i] + near_vel[i] * (ahead * Sim.STEP)
			if me.distance_to(p) - reach - near_r[i] - hb < FAR_D + slack:
				shot_pos.append(p)
				shot_r.append(near_r[i])
	var beam_x := PackedFloat64Array()
	var beam_y := PackedFloat64Array()
	var beam_half := PackedFloat64Array()
	var beam_base := PackedFloat64Array()
	for b: Dictionary in sim.beams:
		beam_x.append(float(b["x"]))
		beam_y.append(float(b["y"]))
		beam_half.append(float(b["width"]) * 0.5 + hb + 8.0)
		beam_base.append(400.0 if int(b["age"]) >= int(b["warn"]) - 20 else 150.0)
	var foe_pos := PackedVector2Array()
	var foe_reach := PackedFloat64Array()
	for e: SimEnemy in sim.enemies:
		if e.active() and e.contact:
			foe_pos.append(e.hit_pos())
			foe_reach.append(e.hurt + 18.0)
	var boss_on := sim.boss != null and sim.boss.fighting()
	var loot := PackedVector2Array()
	var prize := PackedVector2Array()
	for pk: Dictionary in sim.pickups:
		var kind: StringName = pk["kind"]
		if kind == &"bomb" or kind == &"power":
			prize.append(pk["pos"])
		elif kind != &"pearl":
			loot.append(pk["pos"])
	for s: Dictionary in sim.objectives.survivors + sim.objectives.relics:
		prize.append(s["pos"])
	return {"hb": hb, "off": off, "shot_pos": shot_pos, "shot_r": shot_r, "beam_x": beam_x, "beam_y": beam_y,
			"beam_half": beam_half, "beam_base": beam_base, "foe_pos": foe_pos, "foe_reach": foe_reach,
			"boss_on": boss_on, "boss_pos": sim.boss.hurt_pos() if boss_on else Vector2.ZERO,
			"boss_reach": _boss_reach(sim) if boss_on else 0.0, "loot": loot, "prize": prize}


## Parede: custo leve que cresce perto das bordas do campo (lados e fundo). Encostado na parede o bot só desvia
## para um lado e acaba encurralado no canto por uma cortina de balas (c8m3a, Hidra Satélite).
static func _cornered(c: Vector2, field: Vector2) -> float:
	var side := minf(c.x, field.x - c.x)
	var bottom := field.y - c.y
	return maxf(0.0, WALL - side) * WALL_COST + maxf(0.0, WALL - bottom) * WALL_COST


## Distância do chefe que o bot evita: o raio do corpo + 30 (antes da revisão 5) ou o contato medido + 30 (o círculo
## de dano da HD cobre o casco inteiro e afastaria o bot demais).
static func _boss_reach(sim: Sim) -> float:
	return (sim.boss.contact_radius() if Hitboxes.enabled(sim.loadout) else sim.boss.body_radius()) + 30.0


func _danger(at: Vector2, view: Dictionary) -> float:
	var c: Vector2 = at + (view["off"] as Vector2)
	var cost := 0.0
	var hb: float = view["hb"]
	var shot_pos: PackedVector2Array = view["shot_pos"]
	var shot_r: PackedFloat32Array = view["shot_r"]
	for i: int in range(shot_pos.size()):
		var d := c.distance_to(shot_pos[i]) - shot_r[i] - hb
		if d < 1.5:
			cost += 100.0
		elif d < FAR_D:
			cost += 6.0 / (d * d * 0.06 + 1.0)
	# Feixe: acerto certo quando dispara; foge já no aviso.
	# O custo cai em direção à borda da faixa: um passo para fora sempre é melhor que ficar.
	var beam_x: PackedFloat64Array = view["beam_x"]
	var beam_y: PackedFloat64Array = view["beam_y"]
	var beam_half: PackedFloat64Array = view["beam_half"]
	var beam_base: PackedFloat64Array = view["beam_base"]
	for k: int in range(beam_x.size()):
		var half := beam_half[k]
		var dx := absf(c.x - beam_x[k])
		if c.y > beam_y[k] and dx <= half:
			cost += beam_base[k] * (0.5 + (half - dx) / half)
	var foe_pos: PackedVector2Array = view["foe_pos"]
	var foe_reach: PackedFloat64Array = view["foe_reach"]
	for k: int in range(foe_pos.size()):
		if c.distance_to(foe_pos[k]) < foe_reach[k]:
			cost += 60.0
	if bool(view["boss_on"]) and c.distance_to(view["boss_pos"]) < float(view["boss_reach"]):
		cost += 60.0
	return cost


## PODER: com chefe na tela ou mais de POWER_CROWD balas perto, espera o Poder III; fora disso gasta o que
## tiver (Poder I ou II) quando o perigo chega perto.
func want_power(sim: Sim, danger_now: float, near_count: int) -> bool:
	var seg := sim.powers.segments(sim)
	if seg < 1 or sim.powers.active(sim) or not sim.player.alive:
		return false
	var boss_on := sim.boss != null and sim.boss.fighting()
	if boss_on or near_count > POWER_CROWD:
		return seg >= 3
	return danger_now > POWER_DANGER


func _target_x(sim: Sim) -> float:
	if sim.boss != null:
		return sim.boss.body_pos().x
	var best := sim.player.pos.x
	var best_y := -INF
	# Alvo de objetivo acima da nave vem antes de qualquer outro.
	for e: SimEnemy in sim.enemies:
		if e.objective != &"" and e.active() and e.pos.y < sim.player.pos.y - 40.0 and e.pos.y > best_y:
			best_y = e.pos.y
			best = e.pos.x
	if best_y > -INF:
		return best
	for e: SimEnemy in sim.enemies:
		if e.active() and e.pos.y < sim.player.pos.y - 40.0 and e.pos.y > best_y:
			best_y = e.pos.y
			best = e.pos.x
	return best


func _pickup_pull(c: Vector2, view: Dictionary) -> float:
	var pull := 0.0
	for pos: Vector2 in view["loot"] as PackedVector2Array:
		var d := c.distance_to(pos)
		if d < 90.0:
			pull += (90.0 - d) * 0.02
	for pos: Vector2 in view["prize"] as PackedVector2Array:
		var d := c.distance_to(pos)
		if d < RESCUE_REACH:
			pull += (RESCUE_REACH - d) * RESCUE_PULL
	return pull


## Escolha determinística: prefere sinergia (deus já escolhido), depois proteção, depois dano.
func pick_blessing(sim: Sim) -> int:
	var best := 0
	var best_score := -INF
	var table: Dictionary = sim.tables.get("blessings", {})
	for i: int in range(sim.offer.size()):
		var def: Dictionary = table.get(sim.offer[i], {})
		var deity := StringName(String(def.get("deity", "")))
		var score := float(sim.mods.deity_count(deity)) * 2.0
		if deity == &"tethys":
			score += 1.0
		if score > best_score:
			best_score = score
			best = i
	return best
