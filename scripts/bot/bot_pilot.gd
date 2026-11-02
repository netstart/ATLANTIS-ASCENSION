class_name BotPilot
extends RefCounted
## Piloto automático dos testes (plano mestre 14): joga uma missão inteira de forma determinística a
## partir do estado da Sim. Não é a IA de um modo de jogo; serve para provar que toda missão termina,
## que todo padrão tem saída e que a partida é idêntica em 1x, 2x e 3x.
##
## A cada passo avalia 17 movimentos (parado e 16 direções), pontua o perigo das balas projetadas
## alguns passos à frente, dos feixes e do contato, soma a vontade de ficar embaixo do alvo e de pegar
## coletáveis, e escolhe o menor custo.

const STEP_LEN := 3.0
const LOOK_RADIUS := 110.0
const LOOKAHEAD: Array[int] = [0, 4, 8]
const HOME_Y := 380.0
## Distância (borda a borda) a partir da qual uma bala não pesa mais no custo.
const FAR_D := 26.0
## Folga do descarte de balas distantes em _view (bem acima do erro de arredondamento das distâncias).
const CULL_SLACK := 1.0

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
		c.x = clampf(c.x, SimPlayer.MARGIN.x, Playfield.FIELD.x - SimPlayer.MARGIN.x)
		c.y = clampf(c.y, SimPlayer.MARGIN.y, Playfield.FIELD.y - SimPlayer.MARGIN.y)
		spots.append(c)
		reach = maxf(reach, me.distance_to(c))
	var view := _view(sim, me, reach, near, near_vel, near_r)
	var target_x := _target_x(sim)
	var best := INF
	var best_dir := Vector2.ZERO
	for c: Vector2 in spots:
		var cost := _danger(c, view)
		cost += absf(c.x - target_x) * 0.02 + absf(c.y - HOME_Y) * 0.012
		cost -= _pickup_pull(c, view)
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
	var shot_pos := PackedVector2Array()
	var shot_r := PackedFloat32Array()
	for i: int in range(near.size()):
		for ahead: int in LOOKAHEAD:
			var p: Vector2 = near[i] + near_vel[i] * (ahead * Sim.STEP)
			if me.distance_to(p) - reach - near_r[i] - hb < FAR_D + CULL_SLACK:
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
		if e.active():
			foe_pos.append(e.pos)
			foe_reach.append(e.radius + 18.0)
	var boss_on := sim.boss != null and sim.boss.fighting()
	var loot := PackedVector2Array()
	for pk: Dictionary in sim.pickups:
		var kind: StringName = pk["kind"]
		if kind != &"pearl":
			loot.append(pk["pos"])
	return {"hb": hb, "shot_pos": shot_pos, "shot_r": shot_r, "beam_x": beam_x, "beam_y": beam_y,
			"beam_half": beam_half, "beam_base": beam_base, "foe_pos": foe_pos, "foe_reach": foe_reach,
			"boss_on": boss_on, "boss_pos": sim.boss.body_pos() if boss_on else Vector2.ZERO,
			"boss_reach": sim.boss.body_radius() + 30.0 if boss_on else 0.0, "loot": loot}


func _danger(c: Vector2, view: Dictionary) -> float:
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


func _target_x(sim: Sim) -> float:
	if sim.boss != null:
		return sim.boss.body_pos().x
	var best := sim.player.pos.x
	var best_y := -INF
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
