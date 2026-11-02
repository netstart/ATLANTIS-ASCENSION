class_name PowerEffects
extends RefCounted
## As 20 primitivas dos poderes (.ai/08-poderes-das-naves.md). Cada efeito vivo é um Dictionary de
## `sim.power_fx` (contrato no topo de scripts/sim/powers.gd) com os parâmetros de data/powers.json em "_spec".
## Tudo determinístico: só o RNG da Sim (fluxo "powers"), sem nós, e no máximo Powers.MAX_SPAWN objetos
## criados por passo. Dano na base do poder, multiplicado pelo dano da nave (Powers.hurt); no chefe, com teto.
##
## Ciclo: prepare() ao lançar → waiting() a cada passo do "delay" → step() a cada passo ativo (false = acabou)
## → finish() uma vez no fim.

const DASH_INVULN := 2
const REFLECT_SPEED := 380.0
const ORBIT_SPIN := 4.0
const RING_SPIN := 2.0
const BEAM_LENGTH := 460.0
const BLAST_FLASH := 12
const IMPLODE_PULL := 220.0
const DRONE_ORBIT := 30.0
const DRONE_INTERVAL := 8
const DRONE_SHARE := 0.3


## Passos ativos do efeito (sem o "delay"). Calculado dos parâmetros para o Poder III saber quanto dura.
static func duration(spec: Dictionary) -> int:
	match StringName(String(spec.get("type", ""))):
		&"salvo":
			return int(spec.get("interval", 0)) * maxi(0, int(spec.get("count", 1)) - 1) + int(spec.get("life", 180)) + 1
		&"wave":
			var height := float(spec.get("height", 28.0))
			return ceili((Playfield.FIELD.y + height * 2.0) / maxf(1.0, float(spec.get("speed", 300.0))) * 60.0)
		&"strike":
			return int(spec.get("interval", 6)) * maxi(0, int(spec.get("count", 1)) - 1) + int(spec.get("warn", 40)) + 1
		&"heal":
			return 1
		&"delayed_blast":
			return int(spec.get("frames", BLAST_FLASH))
	return maxi(1, int(spec.get("frames", 60)))


static func _vec(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


static func _inside(p: Vector2) -> Vector2:
	return p.clamp(SimPlayer.MARGIN, Playfield.FIELD - SimPlayer.MARGIN)


## Ao lançar: fixa a posição e monta o estado de cada primitiva.
static func prepare(sim: Sim, pw: Powers, e: Dictionary) -> void:
	var spec: Dictionary = e["_spec"]
	var p := sim.player
	match e["type"]:
		&"dash":
			var dir := Vector2.UP if String(spec.get("dir", "")) == "up" or p.last_move.length() < 0.01 \
					else p.last_move.normalized()
			e["angle"] = dir.angle()
			e["from"] = p.pos
			e["width"] = float(spec.get("cut", 14.0)) * 2.0
			e["_dir"] = dir
			e["_hit"] = []
		&"ring":
			e["radius"] = 0.0
			e["max"] = float(spec.get("radius", 300.0))
			e["_hit"] = []
			e["_boss_hit"] = false
		&"salvo":
			e["points"] = PackedVector2Array()
			e["angles"] = PackedFloat32Array()
			e["shots"] = PackedInt32Array()
			e["sprite"] = String(spec.get("sprite", "missile_mini"))
			e["tints"] = (spec.get("tints", []) as Array).duplicate()
			e["_vel"] = PackedVector2Array()
			e["_life"] = PackedInt32Array()
			e["_pierce"] = PackedInt32Array()
			e["_hits"] = []
			e["_next"] = 0
		&"beam":
			e["width"] = float(spec.get("width", 10.0))
			e["length"] = BEAM_LENGTH
			e["angles"] = PackedFloat32Array([-PI / 2.0])
			e["angle"] = -PI / 2.0
		&"chain":
			e["points"] = PackedVector2Array()
			e["flash"] = 0
		&"wave":
			e["width"] = Playfield.FIELD.x
			e["height"] = float(spec.get("height", 28.0))
			e["pos"] = Vector2(Playfield.FIELD.x * 0.5, Playfield.FIELD.y + float(e["height"]))
			e["_hit"] = []
			e["_boss_hit"] = false
		&"vortex":
			e["pos"] = _inside(p.pos + _vec(spec.get("offset"), Vector2(0, -110)))
			e["radius"] = float(spec.get("radius", 110.0))
		&"reflect", &"barrier":
			e["width"] = float(spec.get("width", 64.0))
			e["height"] = float(spec.get("height", 24.0))
			e["points"] = PackedVector2Array()
			e["_vel"] = PackedVector2Array()
		&"orbitals":
			e["points"] = PackedVector2Array()
			e["radius"] = float(spec.get("orb", 9.0))
		&"strike":
			_prepare_strike(sim, e, spec)
		&"drones":
			e["ring"] = bool(spec.get("ring", false))
			e["points"] = PackedVector2Array()
			e["bullets"] = PackedVector2Array()
		&"aura":
			e["radius"] = float(spec.get("radius", 36.0))
		&"eclipse":
			e["radius"] = 400.0
			sim.beams.clear()
		&"delayed_blast":
			e["pos"] = _inside(p.pos + _vec(spec.get("offset"), Vector2.ZERO))
			e["radius"] = float(spec.get("radius", 48.0))
		&"overdrive":
			if bool(spec.get("resonance", false)) and int(e["wait"]) <= 0:
				pw.resonance_on(sim)
		&"heal":
			if int(e["wait"]) <= 0:
				_heal(sim, spec)
	if not e.has("radius"):
		e["radius"] = 0.0


## Alvos da artilharia: os inimigos mais perto ("enemies", completa acima da nave) ou uma grade ("grid").
static func _prepare_strike(sim: Sim, e: Dictionary, spec: Dictionary) -> void:
	var count := maxi(1, int(spec.get("count", 5)))
	var stream := sim.rng.stream(&"powers")
	var points := PackedVector2Array()
	if String(spec.get("aim", "enemies")) == "grid":
		var cols := 4
		for k: int in range(count):
			# Ordem em zigue-zague: os impactos alternam de lado e sobem pela tela.
			var col := (k * 3) % cols
			var row := floori(k / float(cols))
			points.append(Vector2((col + 0.5) * Playfield.FIELD.x / cols + stream.randf_range(-14.0, 14.0),
					sim.player.pos.y - 70.0 - row * 80.0 + stream.randf_range(-12.0, 12.0)))
	else:
		var foes: Array[SimEnemy] = []
		for foe: SimEnemy in sim.enemies:
			if foe.active() and Rect2(Vector2.ZERO, Playfield.FIELD).has_point(foe.pos):
				foes.append(foe)
		var me := sim.player.pos
		foes.sort_custom(func(a: SimEnemy, b: SimEnemy) -> bool:
			return a.pos.distance_squared_to(me) < b.pos.distance_squared_to(me))
		for k: int in range(count):
			if k < foes.size():
				points.append(foes[k].pos)
			elif sim.boss != null and sim.boss.fighting() and k == foes.size():
				points.append(sim.boss.body_pos())
			else:
				points.append(me + Vector2(stream.randf_range(-70.0, 70.0), -90.0 - stream.randf_range(0.0, 120.0)))
	for k: int in range(points.size()):
		points[k] = points[k].clamp(Vector2.ZERO, Playfield.FIELD)
	e["points"] = points
	e["warn"] = int(spec.get("warn", 40))
	e["radius"] = float(spec.get("radius", 26.0))
	var warns := PackedInt32Array()
	for k: int in range(points.size()):
		warns.append(k * int(spec.get("interval", 6)) + int(e["warn"]))
	e["warns"] = warns


## Passo do aviso ("delay"): a Supernova suga as balas antes de explodir; quem começa depois arma o estado.
static func waiting(sim: Sim, pw: Powers, e: Dictionary) -> void:
	var spec: Dictionary = e["_spec"]
	if e["type"] == &"delayed_blast" and bool(spec.get("implode", false)):
		pw.pearls(sim, sim.enemy_bullets.pull(e["pos"], float(e["radius"]) * 0.5, IMPLODE_PULL, Sim.STEP))
	if int(e["wait"]) == 0:
		match e["type"]:
			&"ring":
				e["pos"] = sim.player.pos
			&"overdrive":
				if bool(spec.get("resonance", false)):
					pw.resonance_on(sim)
			&"heal":
				_heal(sim, spec)


static func finish(sim: Sim, pw: Powers, e: Dictionary) -> void:
	if e["type"] == &"overdrive" and bool((e["_spec"] as Dictionary).get("resonance", false)):
		pw.resonance_off(sim)


## Um passo ativo; false encerra o efeito antes de "total".
static func step(sim: Sim, pw: Powers, e: Dictionary) -> bool:
	var spec: Dictionary = e["_spec"]
	match e["type"]:
		&"dash":
			return _dash(sim, pw, e, spec)
		&"ring":
			return _ring(sim, pw, e, spec)
		&"salvo":
			return _salvo(sim, pw, e, spec)
		&"beam":
			return _beam(sim, pw, e, spec)
		&"chain":
			return _chain(sim, pw, e, spec)
		&"wave":
			return _wave(sim, pw, e, spec)
		&"vortex":
			return _vortex(sim, pw, e, spec)
		&"reflect":
			return _reflect(sim, pw, e, spec)
		&"orbitals":
			return _orbitals(sim, pw, e, spec)
		&"barrier":
			return _barrier(sim, pw, e, spec)
		&"strike":
			return _strike(sim, pw, e, spec)
		&"drones":
			return _drones(sim, pw, e, spec)
		&"aura":
			return _aura(sim, pw, e, spec)
		&"eclipse":
			return _eclipse(sim, pw, e, spec)
		&"delayed_blast":
			if int(e["frames"]) == 0:
				var mult := float(spec.get("crit", 1.0))
				pw.area(sim, e["pos"], float(e["radius"]), float(spec.get("damage", 45.0)) * mult,
						bool(spec.get("cancel", true)), StringName(String(e["id"])))
			return true
		&"heal":
			return false
		&"cloak":
			sim.player.invuln = maxi(sim.player.invuln, DASH_INVULN)
	# slow, cloak, overdrive: só seguem a nave (os modificadores saem de Powers._recompute).
	e["pos"] = sim.player.pos
	return true


static func _heal(sim: Sim, spec: Dictionary) -> void:
	var p := sim.player
	if p.hull < p.max_hull:
		p.hull = mini(p.max_hull, p.hull + int(spec.get("amount", 1)))
		sim.emit(&"heal", {"pos": p.pos})


## Fere uma vez cada inimigo (e o chefe) que tocar o círculo; quem já foi atingido fica em "_hit".
static func _sweep(sim: Sim, pw: Powers, e: Dictionary, at: Vector2, reach: float, amount: float) -> void:
	var hit: Array = e["_hit"]
	for foe: SimEnemy in sim.enemies:
		if foe.active() and not hit.has(foe) and at.distance_to(foe.pos) <= reach + foe.radius:
			hit.append(foe)
			pw.hurt(sim, foe, amount)
	var b := sim.boss
	if b != null and b.fighting() and not bool(e.get("_boss_hit", false)) \
			and at.distance_to(b.body_pos()) <= reach + b.body_radius():
		e["_boss_hit"] = true
		pw.hurt_boss(sim, amount)


## Investida: a nave corre `dist` em `frames`; o rastro apaga balas e fere uma vez quem tocar.
static func _dash(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var p := sim.player
	var dir: Vector2 = e["_dir"]
	p.pos = _inside(p.pos + dir * float(spec.get("dist", 72.0)) / maxf(1.0, float(e["total"])))
	p.invuln = maxi(p.invuln, DASH_INVULN)
	e["pos"] = p.pos
	var cut := float(spec.get("cut", 14.0))
	pw.pearls(sim, sim.enemy_bullets.cancel_near(p.pos, cut))
	_sweep(sim, pw, e, p.pos, cut, float(spec.get("damage", 20.0)))
	return true


## Anel de choque que cresce do ponto de lançamento até "max": apaga as balas da faixa e fere uma vez.
static func _ring(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var before := float(e["radius"])
	var r := float(e["max"]) * float(int(e["frames"]) + 1) / maxf(1.0, float(e["total"]))
	e["radius"] = r
	if bool(spec.get("cancel", true)):
		pw.pearls(sim, pw.cancel_ring(sim, e["pos"], before - 4.0, r))
	_sweep(sim, pw, e, e["pos"], r, float(spec.get("damage", 30.0)))
	return true


## Salva teleguiada: projéteis em leque (todos juntos ou um a cada "interval"), cada um busca um alvo.
static func _salvo(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var count := int(spec.get("count", 8))
	var interval := int(spec.get("interval", 0))
	var frames := int(e["frames"])
	var due := 0
	if interval <= 0:
		due = count if frames == 0 else 0
	elif frames % interval == 0:
		due = 1
	due = pw.reserve(mini(due, count - int(e["_next"])))
	var points: PackedVector2Array = e["points"]
	var angles: PackedFloat32Array = e["angles"]
	var shots: PackedInt32Array = e["shots"]
	var vel: PackedVector2Array = e["_vel"]
	var life: PackedInt32Array = e["_life"]
	var pierce: PackedInt32Array = e["_pierce"]
	var hits: Array = e["_hits"]
	var speed := float(spec.get("speed", 240.0))
	var spread := float(spec.get("spread", 120.0))
	for k: int in range(due):
		var n: int = e["_next"]
		var u := float(n) / (count - 1) if count > 1 else 0.5
		if interval > 0:
			# Salvas contínuas alternam de lado: o leque se abre de dentro para fora.
			u = 0.5 + (0.5 if n % 2 == 0 else -0.5) * float(n % 7) / 6.0
		var deg := -90.0 - spread * 0.5 + spread * u
		points.append(sim.player.pos + Vector2(0, -10))
		vel.append(Vector2.from_angle(deg_to_rad(deg)) * speed * 0.6)
		angles.append(deg_to_rad(deg))
		shots.append(n)
		life.append(0)
		pierce.append(int(spec.get("pierce", 0)))
		hits.append([])
		e["_next"] = n + 1
	var strongest := String(spec.get("target", "nearest")) == "strongest"
	var turn := float(spec.get("turn", 6.0))
	var max_life := int(spec.get("life", 180))
	var dmg := float(spec.get("damage", 10.0)) * float(spec.get("crit", 1.0))
	var radius := float(spec.get("radius", 5.0))
	var splash := float(spec.get("splash", 0.0))
	var i := points.size() - 1
	while i >= 0:
		var pos: Vector2 = points[i]
		var target := pw.strongest_target(sim) if strongest else sim.nearest_target(pos)
		var v: Vector2 = vel[i]
		var want := (target - pos).normalized() * speed if target != Vector2.INF else Vector2(0, -speed)
		v = v.lerp(want, minf(1.0, turn * Sim.STEP))
		pos += v * Sim.STEP
		points[i] = pos
		vel[i] = v
		angles[i] = v.angle()
		life[i] += 1
		var hit := _shot_hit(sim, pw, pos, radius, dmg, hits[i] as Array)
		if hit:
			sim.emit(&"hit", {"pos": pos})
			if splash > 0.0:
				pw.area(sim, pos, splash, dmg * 0.5, false, StringName(String(e["id"])))
			if pierce[i] > 0:
				pierce[i] -= 1
				hit = false
		if hit or life[i] > max_life or not Sim.BOUNDS.has_point(pos):
			points.remove_at(i)
			vel.remove_at(i)
			angles.remove_at(i)
			shots.remove_at(i)
			life.remove_at(i)
			pierce.remove_at(i)
			hits.remove_at(i)
		i -= 1
	e["points"] = points
	e["angles"] = angles
	e["shots"] = shots
	e["_vel"] = vel
	e["_life"] = life
	e["_pierce"] = pierce
	return int(e["_next"]) < count or not points.is_empty()


## Acerto de um projétil de poder: inimigo (cada um uma vez por projétil) e depois o corpo do chefe.
static func _shot_hit(sim: Sim, pw: Powers, at: Vector2, r: float, amount: float, hit: Array) -> bool:
	for foe: SimEnemy in sim.enemies:
		if foe.active() and not hit.has(foe) and at.distance_to(foe.pos) <= r + foe.radius:
			hit.append(foe)
			pw.hurt(sim, foe, amount)
			return true
	var b := sim.boss
	if b != null and b.fighting() and not hit.has(b) and at.distance_to(b.body_pos()) <= r + b.body_radius():
		hit.append(b)
		pw.hurt_boss(sim, amount)
		return true
	return false


## Feixe da nave (perfura tudo na faixa): dano = DPS da arma x "mult"; vários feixes varrem em leque.
static func _beam(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var p := sim.player
	var origin := p.pos + Vector2(0, -12)
	e["pos"] = origin
	var count := maxi(1, int(spec.get("count", 1)))
	var sweep := deg_to_rad(float(spec.get("sweep", 0.0)))
	var phase := sin(int(e["frames"]) * TAU / maxf(1.0, float(spec.get("period", 90.0))))
	var angles := PackedFloat32Array()
	for k: int in range(count):
		angles.append(-PI / 2.0 + (k - (count - 1) * 0.5) * sweep * phase)
	e["angles"] = angles
	e["angle"] = angles[0]
	var weapon_def: Dictionary = (sim.tables["weapons"] as Dictionary).get(p.weapon, {})
	var amount := WeaponFire.dps(weapon_def, p.level) * float(spec.get("mult", 2.0)) * Sim.STEP
	var half := float(e["width"]) * 0.5
	var length := float(e["length"])
	for a: float in angles:
		var dir := Vector2.from_angle(a)
		for foe: SimEnemy in sim.enemies:
			if foe.active() and _on_beam(origin, dir, length, half + foe.radius, foe.pos):
				pw.hurt(sim, foe, amount)
		var b := sim.boss
		if b != null and b.fighting() and _on_beam(origin, dir, length, half + b.body_radius(), b.body_pos()):
			pw.hurt_boss(sim, amount)
		if bool(spec.get("cancel", false)):
			pw.pearls(sim, pw.cancel_segment(sim, origin, origin + dir * length, half))
	return true


static func _on_beam(origin: Vector2, dir: Vector2, length: float, reach: float, at: Vector2) -> bool:
	var rel := at - origin
	var t := rel.dot(dir)
	return t >= 0.0 and t <= length and absf(rel.cross(dir)) <= reach


## Raios encadeados: a cada "interval" um raio sai da nave e salta para o inimigo mais perto ainda não atingido
## (ou para a bala mais perto, que some); cada salto fere e o trecho apaga as balas do caminho.
static func _chain(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	e["pos"] = sim.player.pos
	e["flash"] = int(e["flash"]) + 1
	if int(e["frames"]) % maxi(1, int(spec.get("interval", 12))) != 0:
		return true
	e["flash"] = 0
	var reach := float(spec.get("range", 110.0))
	var amount := float(spec.get("damage", 18.0))
	var cut := float(spec.get("cut", 14.0))
	var from := sim.player.pos
	var points := PackedVector2Array([from])
	var hit: Array = []
	var boss_done := false
	for j: int in range(int(spec.get("jumps", 6))):
		var best: SimEnemy = null
		var best_d := reach * reach
		for foe: SimEnemy in sim.enemies:
			var d := from.distance_squared_to(foe.pos)
			if foe.active() and not hit.has(foe) and d <= best_d:
				best_d = d
				best = foe
		var next := Vector2.INF
		var b := sim.boss
		if best != null:
			hit.append(best)
			next = best.pos
			pw.hurt(sim, best, amount)
		elif not boss_done and b != null and b.fighting() and from.distance_to(b.body_pos()) <= reach + b.body_radius():
			boss_done = true
			next = b.body_pos()
			pw.hurt_boss(sim, amount)
		else:
			next = _nearest_bullet(sim, from, reach)
		if next == Vector2.INF:
			break
		pw.pearls(sim, pw.cancel_segment(sim, from, next, cut))
		points.append(next)
		from = next
	e["points"] = points
	return true


static func _nearest_bullet(sim: Sim, from: Vector2, reach: float) -> Vector2:
	var pool := sim.enemy_bullets
	var best := Vector2.INF
	var best_d := reach * reach
	for i: int in range(pool.count):
		var d := from.distance_squared_to(pool.pos[i])
		if d <= best_d:
			best_d = d
			best = pool.pos[i]
	return best


## Onda que sobe a tela inteira: desfaz as balas da faixa em pérolas e fere uma vez quem cruzar.
static func _wave(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var pos: Vector2 = e["pos"]
	pos.y -= float(spec.get("speed", 300.0)) * Sim.STEP
	e["pos"] = pos
	var h := float(e["height"])
	pw.pearls(sim, pw.cancel_rect(sim, Rect2(-40.0, pos.y - h * 0.5, Playfield.FIELD.x + 80.0, h)))
	var hit: Array = e["_hit"]
	var amount := float(spec.get("damage", 20.0))
	for foe: SimEnemy in sim.enemies:
		if foe.active() and not hit.has(foe) and absf(foe.pos.y - pos.y) <= h * 0.5 + foe.radius:
			hit.append(foe)
			pw.hurt(sim, foe, amount)
	var b := sim.boss
	if b != null and b.fighting() and not bool(e["_boss_hit"]) \
			and absf(b.body_pos().y - pos.y) <= h * 0.5 + b.body_radius():
		e["_boss_hit"] = true
		pw.hurt_boss(sim, amount)
	return pos.y > -h


## Redemoinho: puxa as balas (viram pérolas no centro) e os inimigos pequenos, e mói quem estiver dentro.
static func _vortex(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var at: Vector2 = e["pos"]
	var radius := float(e["radius"])
	var pull := float(spec.get("pull", 160.0))
	pw.pearls(sim, sim.enemy_bullets.pull(at, radius, pull, Sim.STEP))
	var amount := float(spec.get("dps", 30.0)) * Sim.STEP
	var small := float(spec.get("small_hp", 30.0))
	for foe: SimEnemy in sim.enemies:
		if foe.active() and at.distance_to(foe.pos) <= radius + foe.radius:
			if foe.max_hp <= small:
				# A trajetória sai da origem: arrastar a origem arrasta o inimigo sem mexer no caminho dele.
				foe.origin += (at - foe.pos).limit_length(pull * 0.4 * Sim.STEP)
			pw.hurt(sim, foe, amount)
	var b := sim.boss
	if b != null and b.fighting() and at.distance_to(b.body_pos()) <= radius + b.body_radius():
		pw.hurt_boss(sim, amount)
	return true


## Égide: escudo à frente da nave; bala que entra volta para cima como projétil do poder (com o teto no chefe).
static func _reflect(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var p := sim.player
	var w := float(e["width"])
	var h := float(e["height"])
	var center := p.pos + Vector2(0, float(spec.get("offset", -22.0)))
	e["pos"] = center
	var rect := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	var points: PackedVector2Array = e["points"]
	var vel: PackedVector2Array = e["_vel"]
	var pool := sim.enemy_bullets
	var i := pool.count - 1
	while i >= 0:
		var at: Vector2 = pool.pos[i]
		if rect.has_point(at):
			var v: Vector2 = pool.vel[i]
			pool.kill(i)
			if pw.reserve(1) > 0:
				points.append(at)
				vel.append(Vector2(v.x * 0.25, -REFLECT_SPEED))
		i -= 1
	var amount := float(spec.get("damage", 6.0))
	var k := points.size() - 1
	while k >= 0:
		points[k] += vel[k] * Sim.STEP
		if _shot_hit(sim, pw, points[k], 4.0, amount, []) or not Sim.BOUNDS.has_point(points[k]):
			points.remove_at(k)
			vel.remove_at(k)
		k -= 1
	e["points"] = points
	e["_vel"] = vel
	return true


## Bastião: orbes girando em volta da nave; cada um apaga as balas e fere quem tocar.
static func _orbitals(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var p := sim.player
	e["pos"] = p.pos
	var count := maxi(1, int(spec.get("count", 3)))
	var orbit := float(spec.get("radius", 30.0))
	var orb := float(e["radius"])
	var amount := float(spec.get("dps", 40.0)) * Sim.STEP
	var points := PackedVector2Array()
	for k: int in range(count):
		var at := p.pos + Vector2.from_angle(TAU * k / count + int(e["frames"]) * ORBIT_SPIN * Sim.STEP) * orbit
		points.append(at)
		pw.pearls(sim, sim.enemy_bullets.cancel_near(at, orb))
		for foe: SimEnemy in sim.enemies:
			if foe.active() and at.distance_to(foe.pos) <= orb + foe.radius:
				pw.hurt(sim, foe, amount)
		var b := sim.boss
		if b != null and b.fighting() and at.distance_to(b.body_pos()) <= orb + b.body_radius():
			pw.hurt_boss(sim, amount)
	e["points"] = points
	return true


## Muralha: barreira de luz acima da nave que absorve toda bala e queima quem encostar.
static func _barrier(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var w := float(e["width"])
	var h := float(e["height"])
	var center := sim.player.pos + Vector2(0, float(spec.get("offset", -40.0)))
	e["pos"] = center
	# A barreira pega também o que vem por cima do retângulo neste passo (balas rápidas não atravessam).
	var rect := Rect2(center - Vector2(w * 0.5, h * 0.5 + 8.0), Vector2(w, h + 8.0))
	pw.pearls(sim, pw.cancel_rect(sim, rect))
	var amount := float(spec.get("dps", 40.0)) * Sim.STEP
	for foe: SimEnemy in sim.enemies:
		if foe.active() and rect.grow(foe.radius).has_point(foe.pos):
			pw.hurt(sim, foe, amount)
	var b := sim.boss
	if b != null and b.fighting() and rect.grow(b.body_radius()).has_point(b.body_pos()):
		pw.hurt_boss(sim, amount)
	return true


## Artilharia: cada alvo tem aviso no chão de "warn" passos e explode em área (apaga as balas do raio).
static func _strike(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var warns: PackedInt32Array = e["warns"]
	var points: PackedVector2Array = e["points"]
	var pending := false
	for k: int in range(warns.size()):
		if warns[k] < 0:
			continue
		warns[k] -= 1
		if warns[k] < 0:
			pw.area(sim, points[k], float(e["radius"]), float(spec.get("damage", 35.0)), bool(spec.get("cancel", true)),
					StringName(String(e["id"])))
		else:
			pending = true
	e["warns"] = warns
	return pending


## Drones do poder em volta da nave. Os comuns atiram reto (cada um com DRONE_SHARE do DPS da arma, tiros do
## próprio efeito, com o teto no chefe); o anel da Rede Neural liga os drones com feixes que apagam balas e
## ferem quem cruzar.
static func _drones(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var p := sim.player
	e["pos"] = p.pos
	var ring := bool(e["ring"])
	var count := maxi(2 if ring else 1, int(spec.get("count", 4)))
	var radius := float(spec.get("radius", DRONE_ORBIT))
	var frames := int(e["frames"])
	var points := PackedVector2Array()
	for k: int in range(count):
		var a := TAU * k / count + frames * (RING_SPIN if ring else ORBIT_SPIN * 0.5) * Sim.STEP
		var d := Vector2.from_angle(a) * radius
		points.append(p.pos + (d if ring else Vector2(d.x, d.y * 0.55 - 4.0)))
	e["points"] = points
	if ring:
		_drone_links(sim, pw, points, spec)
		return true
	var bullets: PackedVector2Array = e["bullets"]
	var weapon_def: Dictionary = (sim.tables["weapons"] as Dictionary).get(p.weapon, {})
	var amount := WeaponFire.dps(weapon_def, p.level) * DRONE_SHARE * DRONE_INTERVAL * Sim.STEP
	for k: int in range(count):
		if (frames + k * 2) % DRONE_INTERVAL == 0 and pw.reserve(1) > 0:
			bullets.append(points[k] + Vector2(0, -6))
	var i := bullets.size() - 1
	while i >= 0:
		bullets[i] += Vector2(0, -WeaponFire.SHOT_SPEED * Sim.STEP)
		if _shot_hit(sim, pw, bullets[i], 3.0, amount, []) or bullets[i].y < Sim.BOUNDS.position.y:
			bullets.remove_at(i)
		i -= 1
	e["bullets"] = bullets
	return true


static func _drone_links(sim: Sim, pw: Powers, points: PackedVector2Array, spec: Dictionary) -> void:
	var cut := float(spec.get("cut", 6.0))
	var amount := float(spec.get("dps", 30.0)) * Sim.STEP
	var count := points.size()
	for k: int in range(count):
		var a := points[k]
		var b := points[(k + 1) % count]
		pw.pearls(sim, pw.cancel_segment(sim, a, b, cut))
		for foe: SimEnemy in sim.enemies:
			if foe.active() and foe.pos.distance_to(Geometry2D.get_closest_point_to_segment(foe.pos, a, b)) <= cut + foe.radius:
				pw.hurt(sim, foe, amount)


## Corona: anel de plasma em volta da nave; apaga as balas que entram e queima quem estiver dentro.
static func _aura(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	var at := sim.player.pos
	e["pos"] = at
	var radius := float(spec.get("radius", 36.0))
	e["radius"] = radius * (1.0 + 0.08 * sin(int(e["frames"]) * 0.3))
	if bool(spec.get("cancel", true)):
		pw.pearls(sim, sim.enemy_bullets.cancel_near(at, radius))
	var amount := float(spec.get("dps", 60.0)) * Sim.STEP
	for foe: SimEnemy in sim.enemies:
		if foe.active() and at.distance_to(foe.pos) <= radius + foe.radius:
			pw.hurt(sim, foe, amount)
	var b := sim.boss
	if b != null and b.fighting() and at.distance_to(b.body_pos()) <= radius + b.body_radius():
		pw.hurt_boss(sim, amount)
	return true


## Eclipse Total: tudo para (Powers.frozen) e, no último passo, as balas viram pérolas e todos levam o dano.
static func _eclipse(sim: Sim, pw: Powers, e: Dictionary, spec: Dictionary) -> bool:
	e["pos"] = sim.player.pos
	if int(e["frames"]) < int(e["total"]) - 1:
		return true
	pw.pearls(sim, sim.enemy_bullets.cancel_all())
	sim.beams.clear()
	var amount := float(spec.get("damage", 160.0))
	for foe: SimEnemy in sim.enemies:
		pw.hurt(sim, foe, amount)
	pw.hurt_boss(sim, amount)
	sim.emit(&"power_blast", {"id": String(e["id"]), "pos": Playfield.FIELD * 0.5, "radius": float(e["radius"])})
	return false
