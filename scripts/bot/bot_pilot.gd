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

var _dirs: Array[Vector2] = []


func _init() -> void:
	_dirs.append(Vector2.ZERO)
	for k: int in range(16):
		_dirs.append(Vector2.from_angle(TAU * k / 16.0) * STEP_LEN)


func decide(sim: Sim) -> SimInput:
	var input := SimInput.new()
	input.fire = true
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
	var target_x := _target_x(sim)
	var best := INF
	var best_dir := Vector2.ZERO
	for d: Vector2 in _dirs:
		var c := me + d
		c.x = clampf(c.x, SimPlayer.MARGIN.x, Playfield.FIELD.x - SimPlayer.MARGIN.x)
		c.y = clampf(c.y, SimPlayer.MARGIN.y, Playfield.FIELD.y - SimPlayer.MARGIN.y)
		var cost := _danger(sim, c, near, near_vel, near_r)
		cost += absf(c.x - target_x) * 0.02 + absf(c.y - HOME_Y) * 0.012
		cost -= _pickup_pull(sim, c)
		if cost < best - 0.0001:
			best = cost
			best_dir = c - me
	input.move = best_dir / maxf(sim.player.speed_mult, 0.01)
	var danger_now := _danger(sim, me, near, near_vel, near_r)
	input.bomb = danger_now > 60.0 and sim.player.bombs > 0 and sim.player.vulnerable()
	input.special = sim.player.special_charge >= 1.0 and near.size() > 25
	if sim.boss != null and sim.boss.state == SimBoss.State.DUEL:
		input.taps = 1 if sim.frame % 3 == 0 else 0
	return input


func _danger(sim: Sim, c: Vector2, near: PackedVector2Array, vel: PackedVector2Array,
		radius: PackedFloat32Array) -> float:
	var cost := 0.0
	var hb := sim.player.hitbox
	for i: int in range(near.size()):
		for ahead: int in LOOKAHEAD:
			var p: Vector2 = near[i] + vel[i] * (ahead * Sim.STEP)
			var d := c.distance_to(p) - radius[i] - hb
			if d < 1.5:
				cost += 100.0
			elif d < 26.0:
				cost += 6.0 / (d * d * 0.06 + 1.0)
	# Feixe: acerto certo quando dispara; foge já no aviso.
	# O custo cai em direção à borda da faixa: um passo para fora sempre é melhor que ficar.
	for b: Dictionary in sim.beams:
		var half := float(b["width"]) * 0.5 + hb + 8.0
		var dx := absf(c.x - float(b["x"]))
		if c.y > float(b["y"]) and dx <= half:
			var base := 400.0 if int(b["age"]) >= int(b["warn"]) - 20 else 150.0
			cost += base * (0.5 + (half - dx) / half)
	for e: SimEnemy in sim.enemies:
		if e.active() and c.distance_to(e.pos) < e.radius + 18.0:
			cost += 60.0
	if sim.boss != null and sim.boss.fighting() and c.distance_to(sim.boss.body_pos()) < sim.boss.body_radius() + 30.0:
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


func _pickup_pull(sim: Sim, c: Vector2) -> float:
	var pull := 0.0
	for pk: Dictionary in sim.pickups:
		var kind: StringName = pk["kind"]
		if kind == &"pearl":
			continue
		var d := c.distance_to(pk["pos"])
		if d < 90.0:
			pull += (90.0 - d) * 0.02
	return pull
