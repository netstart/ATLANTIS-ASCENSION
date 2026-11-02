class_name Powers
extends RefCounted
## Poderes das naves (.ai/08-poderes-das-naves.md): o medidor de Corrente (3 segmentos, 0,0 a 3,0) e os 36
## poderes de data/powers.json, cada um uma lista de efeitos primitivos (PowerEffects). Uma instância por Sim
## (`sim.powers`); os efeitos vivos ficam em `sim.power_fx`, que a visualização só lê.
##
## Corrente: +0,06 por inimigo comum, +0,25 por elite ou torre, +0,5 por miniboss, +0,004 por graze, 1 segmento
## a cada 14 s e, no chefe de ato, +0,02 a cada 1% de vida tirada. Não enche enquanto houver efeito vivo.
## PODER gasta todos os segmentos cheios e lança o poder do nível alcançado (`<nave>_<1..3>`).
## Invulnerabilidade: 0,5 s no Poder I, 1 s no II e a duração inteira no III (que também dá pausa de impacto).
## Teto no chefe: o dano de um poder (efeitos diretos e o bônus da sobrecarga) não passa de 3%, 5% ou 8% da vida.
##
## Contrato de `sim.power_fx` (Array[Dictionary], um por efeito vivo; chaves com "_" são internas):
## - Todas: "id" (String, poder), "type" (StringName, primitiva), "tier" (int), "color" (String, "#rrggbb"),
##   "pos" (Vector2), "frames" (passos já ativos), "total" (passos ativos ao todo), "wait" (passos até começar;
##   > 0 = ainda no aviso, como a implosão da Supernova).
## - dash: "angle" (rad, direção), "from" (Vector2, início), "width" (largura do rastro que corta balas).
## - ring: "radius" (raio atual), "max" (raio final). Centro em "pos".
## - salvo: "points" (PackedVector2Array), "angles" (PackedFloat32Array, rumo de cada projétil), "sprite" (String:
##   feather, missile_mini, torpedo, kamikaze, lance), "tints" (Array de "#rrggbb" por índice de disparo ou vazio),
##   "shots" (PackedInt32Array, índice de disparo de cada ponto, para a cor).
## - beam: "angle" (rad do primeiro feixe; -PI/2 = para cima), "angles" (PackedFloat32Array, um por feixe),
##   "width", "length". Origem em "pos".
## - slow: "factor" (velocidade das balas inimigas). - cloak, overdrive: só "pos" (a nave).
## - chain: "points" (PackedVector2Array, vértices do raio atual), "flash" (passos desde o último raio).
## - wave: "pos" (centro da onda), "width", "height". - vortex, aura, eclipse: "radius".
## - reflect, barrier: "width", "height" (retângulo centrado em "pos"); reflect: "points" (balas devolvidas).
## - orbitals: "points" (orbes), "radius" (raio de cada orbe).
## - drones: "ring" (bool), "points" (drones), "bullets" (PackedVector2Array, tiros dos drones comuns; sobem).
## - strike: "points" (alvos), "warns" (PackedInt32Array: passos até o impacto; <= "warn" = mostrar o aviso,
##   < 0 = já explodiu), "warn", "radius".
## - delayed_blast: "radius"; explode quando "wait" chega a 0 e fica "total" passos como clarão.
## Eventos: &"power" {"id", "tier", "pos", "echo"} ao lançar; &"power_charge" {"segments"} a cada segmento cheio;
## &"power_empty" {} ao apertar sem carga; &"power_blast" {"id", "pos", "radius"} em cada explosão;
## &"power_end" {"id"} quando o último efeito acaba.

const SEGMENTS := 3.0
const TIME_FRAMES := 14 * 60
const KILL_COMMON := 0.06
const KILL_ELITE := 0.25
const KILL_MINIBOSS := 0.5
const GRAZE := 0.004
## 0,02 a cada 1% de vida do chefe de ato.
const BOSS_FILL := 2.0
const ELITE_HP := 80.0
const TOWERS: Array[StringName] = [&"coral_turret", &"sentinel_buoy"]
const EXIT_INVULN: Array[int] = [0, 30, 60, 60]
const SUPREME_INVULN_MAX := 480
const BOSS_CAP: Array[float] = [0.0, 0.03, 0.05, 0.08]
const SUPREME_HITSTOP := 10
## A sobrecarga e os drones do poder desligam no chefe ao chegar a esta parte do teto.
const OVERDRIVE_SHARE := 0.7
## Nenhum poder cria mais que isto por passo (pérolas, projéteis, balas devolvidas).
const MAX_SPAWN := 64
const KILL_BLAST_DEPTH := 8
## Marca do crítico do poder no tiro da nave (o campo "grazed" só serve às balas inimigas): no teto do chefe, os
## tiros marcados ainda no ar voltam ao dano normal.
const CRIT_MARK := 2
const TYPES: Array[StringName] = [&"dash", &"ring", &"salvo", &"beam", &"slow", &"chain", &"wave", &"vortex",
		&"reflect", &"orbitals", &"barrier", &"strike", &"drones", &"cloak", &"aura", &"eclipse", &"overdrive",
		&"heal", &"delayed_blast", &"echo"]
## Eco de Atlântida: a especial do rodízio da Ascension aponta a nave cujo Poder I sai.
const ECHO_SHIPS := {
	&"area_bomb": &"falcon", &"focused_burst": &"manta", &"drone_swarm": &"hydra", &"emp_pulse": &"tempest",
	&"gravity_rift": &"trident", &"tide_shield": &"atlas",
}

## Modificadores dos efeitos vivos, refeitos a cada passo (a Sim e as armas leem).
var rate: float = 1.0
var dmg: float = 1.0
var crit: float = 0.0
var pierce: int = 0
var time_scale: float = 1.0
var frozen: bool = false
var kill_blast_radius: float = 0.0
var kill_blast_damage: float = 0.0
var casts: int = 0
var _budget: float = 0.0
var _dealt: float = 0.0
var _boss: SimBoss
var _boss_hp: float = 0.0
var _spawned: int = 0
var _level_restore: int = -1
var _depth: int = 0


## Erros de data/powers.json (vazio = válido): toda nave com os níveis 1, 2 e 3, efeitos conhecidos.
static func validate(powers: Dictionary, ships: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for ship_id: Variant in ships:
		for tier: int in [1, 2, 3]:
			var id := StringName("%s_%d" % [ship_id, tier])
			var def: Dictionary = powers.get(id, {})
			if def.is_empty():
				errors.append("falta %s" % id)
				continue
			if int(def.get("tier", 0)) != tier or StringName(String(def.get("ship", ""))) != StringName(String(ship_id)):
				errors.append("%s: nave ou nível errado" % id)
			if String(def.get("name_key", "")) != "power.%s" % id or String(def.get("desc_key", "")) != "power.%s.desc" % id:
				errors.append("%s: chaves de texto fora do contrato" % id)
			if String(def.get("color", "")) != String((ships[ship_id] as Dictionary).get("tint", "")):
				errors.append("%s: cor diferente da nave" % id)
			var effects: Array = def.get("effects", [])
			if effects.is_empty():
				errors.append("%s: sem efeitos" % id)
			for fx: Variant in effects:
				if not StringName(String((fx as Dictionary).get("type", ""))) in TYPES:
					errors.append("%s: efeito desconhecido %s" % [id, (fx as Dictionary).get("type", "")])
	for id: Variant in powers:
		if not ships.has(StringName(String((powers[id] as Dictionary).get("ship", "")))):
			errors.append("%s: nave inexistente" % id)
	if powers.size() != ships.size() * 3:
		errors.append("%d poderes para %d naves" % [powers.size(), ships.size()])
	return errors


func active(sim: Sim) -> bool:
	return not sim.power_fx.is_empty()


func segments(sim: Sim) -> int:
	return whole(sim.player.power_charge)


## Segmentos cheios de uma carga (a folga absorve o arredondamento da soma de 840 passos de 1/840).
static func whole(charge: float) -> int:
	return floori(charge + 0.0001)


## Poder que sairia agora (HUD): "" sem segmento cheio.
func preview_id(sim: Sim) -> StringName:
	var tier := mini(3, segments(sim))
	if tier < 1:
		return &""
	return StringName("%s_%d" % [sim.player.ship.get("id", "falcon"), tier])


## Botão PODER neste passo (só a nave 1).
func press(sim: Sim, pressed: bool) -> void:
	if not pressed or not sim.player.alive or active(sim):
		return
	var tier := mini(3, segments(sim))
	if tier < 1:
		sim.emit(&"power_empty", {})
		return
	sim.player.power_charge = maxf(0.0, sim.player.power_charge - tier)
	cast(sim, StringName("%s_%d" % [sim.player.ship.get("id", "falcon"), tier]), tier)


## Lança um poder (sem gastar a Corrente: press() gasta). Testes chamam direto.
func cast(sim: Sim, id: StringName, tier: int) -> void:
	var def: Dictionary = (sim.tables.get("powers", {}) as Dictionary).get(id, {})
	if def.is_empty():
		return
	casts += 1
	_budget = BOSS_CAP[clampi(tier, 1, 3)]
	_dealt = 0.0
	var specs: Array = []
	var echo := ""
	for raw: Variant in def.get("effects", []):
		var spec: Dictionary = raw
		if StringName(String(spec.get("type", ""))) == &"echo":
			var kind: StringName = ShipTraits.ROTATION[sim.specials_used % ShipTraits.ROTATION.size()]
			echo = "%s_%d" % [ECHO_SHIPS.get(kind, &"falcon"), int(spec.get("tier", 1))]
			var echoed: Dictionary = (sim.tables.get("powers", {}) as Dictionary).get(StringName(echo), {})
			for inner: Variant in echoed.get("effects", []):
				if StringName(String((inner as Dictionary).get("type", ""))) != &"echo":
					specs.append(inner)
		else:
			specs.append(spec)
	var longest := 0
	for spec: Dictionary in specs:
		var e := {"id": String(id), "type": StringName(String(spec.get("type", ""))), "tier": tier,
				"color": String(def.get("color", "#ffffff")), "pos": sim.player.pos, "frames": 0,
				"total": PowerEffects.duration(spec), "wait": int(spec.get("delay", 0)), "_spec": spec}
		longest = maxi(longest, int(e["wait"]) + int(e["total"]))
		PowerEffects.prepare(sim, self, e)
		sim.power_fx.append(e)
	var invuln := EXIT_INVULN[clampi(tier, 1, 3)]
	if tier >= 3:
		invuln = clampi(longest, invuln, SUPREME_INVULN_MAX)
		sim.hitstop = maxi(sim.hitstop, SUPREME_HITSTOP)
	sim.player.invuln = maxi(sim.player.invuln, invuln)
	_recompute(sim)
	sim.emit(&"power", {"id": String(id), "tier": tier, "pos": sim.player.pos, "echo": echo})


## Um passo: mede o chefe, enche a Corrente (sem poder vivo) ou avança os efeitos, refaz os modificadores.
func step(sim: Sim) -> void:
	_spawned = 0
	_measure_boss(sim)
	if sim.power_fx.is_empty():
		if sim.player.alive:
			_fill(sim, 1.0 / TIME_FRAMES)
	else:
		var keep: Array[Dictionary] = []
		var last := ""
		for e: Dictionary in sim.power_fx:
			last = String(e["id"])
			if int(e["wait"]) > 0:
				e["wait"] = int(e["wait"]) - 1
				PowerEffects.waiting(sim, self, e)
				keep.append(e)
				continue
			var alive := PowerEffects.step(sim, self, e)
			e["frames"] = int(e["frames"]) + 1
			if alive and int(e["frames"]) < int(e["total"]):
				keep.append(e)
			else:
				PowerEffects.finish(sim, self, e)
		sim.power_fx = keep
		if keep.is_empty():
			sim.emit(&"power_end", {"id": last})
	_recompute(sim)
	_boss = sim.boss
	_boss_hp = sim.boss.hp if sim.boss != null else 0.0


## Abate: enche a Corrente pela classe do inimigo e, na Reação em Cadeia, explode em área.
func on_kill(sim: Sim, e: SimEnemy) -> void:
	if kill_blast_radius > 0.0 and _depth < KILL_BLAST_DEPTH:
		_depth += 1
		area(sim, e.pos, kill_blast_radius, kill_blast_damage, false, &"")
		_depth -= 1
	if e.max_hp >= ELITE_HP or e.radius >= 20.0 or e.id in TOWERS:
		_fill(sim, KILL_ELITE)
	else:
		_fill(sim, KILL_COMMON)


func on_graze(sim: Sim) -> void:
	_fill(sim, GRAZE)


## Chefe de meio de fase e elite (o chefe de ato enche pela vida tirada, em _measure_boss).
func on_boss_defeated(sim: Sim, b: SimBoss) -> void:
	if not b.is_final:
		_fill(sim, KILL_ELITE if String(b.id).begins_with("elite_") else KILL_MINIBOSS)


## Tiros que a arma principal acabou de criar: crítico e perfuração da sobrecarga e do manto.
func on_fire(sim: Sim, from: int) -> void:
	if crit <= 0.0 and pierce <= 0:
		return
	var pool := sim.player_bullets
	# Cada bala acerta cada alvo uma vez só (anel de alvos da BulletPool), então a perfuração extra vale
	# também contra o chefe: atravessa o corpo e pega as partes, sem repetir o mesmo alvo.
	for i: int in range(from, pool.count):
		pool.pierce[i] += pierce
		if crit > 0.0 and (crit >= 1.0 or sim.rng.stream(&"powers").randf() < crit):
			pool.damage[i] *= ShipTraits.CRIT_MULT
			pool.radius[i] += 1.0
			pool.grazed[i] = CRIT_MARK


# --- Ajudas das primitivas (PowerEffects) --------------------------------------------------------

## Dano num inimigo (já com o multiplicador da nave).
func hurt(sim: Sim, e: SimEnemy, amount: float) -> void:
	if e.active() and e.damage(amount * sim.damage_mult()):
		sim.kill_enemy(e)


## Dano no corpo do chefe, limitado ao teto do poder (fração da vida máxima, já descontada a armadura).
func hurt_boss(sim: Sim, amount: float) -> void:
	var b := sim.boss
	if b == null or not b.fighting():
		return
	_track(b)
	var left := _budget * b.max_hp - _dealt
	if left <= 0.0:
		return
	var armor := maxf(0.01, float(b.phase().get("armor", 1.0)))
	var before := b.hp
	b.damage_body(minf(amount * sim.damage_mult(), left / armor), sim)
	_dealt += maxf(0.0, before - b.hp)


## Teto alcançado? `share` < 1 deixa folga (a sobrecarga para antes: os tiros já no ar ainda acertam).
func boss_capped(sim: Sim, share: float = 1.0) -> bool:
	var b := sim.boss
	return b != null and b.fighting() and b == _boss and _dealt >= _budget * share * b.max_hp - 0.001


## Explosão de um poder: fere quem estiver no raio (e o chefe, com teto) e, se `cancel`, apaga as balas.
func area(sim: Sim, at: Vector2, radius: float, amount: float, cancel: bool, id: StringName) -> void:
	for e: SimEnemy in sim.enemies:
		if e.active() and at.distance_to(e.pos) <= radius + e.radius:
			hurt(sim, e, amount)
	if sim.boss != null and sim.boss.fighting() and at.distance_to(sim.boss.body_pos()) <= radius + sim.boss.body_radius():
		hurt_boss(sim, amount)
	if cancel:
		pearls(sim, sim.enemy_bullets.cancel_near(at, radius))
	if id != &"":
		sim.emit(&"power_blast", {"id": String(id), "pos": at, "radius": radius})


## Balas apagadas viram pérolas, até MAX_SPAWN por passo somando todos os efeitos (o resto só some).
func pearls(sim: Sim, points: PackedVector2Array) -> void:
	var room := MAX_SPAWN - _spawned
	if room <= 0:
		return
	if points.size() > room:
		points = points.slice(0, room)
	_spawned += points.size()
	sim.pearls_from(points)


## Reserva `n` objetos do orçamento do passo; devolve quantos cabem.
func reserve(n: int) -> int:
	var got := clampi(MAX_SPAWN - _spawned, 0, n)
	_spawned += got
	return got


## Apaga as balas que cumprirem a regra de forma (retângulo, faixa, segmento) e devolve as posições.
func cancel_rect(sim: Sim, rect: Rect2) -> PackedVector2Array:
	var pool := sim.enemy_bullets
	var out := PackedVector2Array()
	var i := pool.count - 1
	while i >= 0:
		if rect.has_point(pool.pos[i]):
			out.append(pool.pos[i])
			pool.kill(i)
		i -= 1
	return out


func cancel_ring(sim: Sim, center: Vector2, r0: float, r1: float) -> PackedVector2Array:
	var pool := sim.enemy_bullets
	var out := PackedVector2Array()
	var lo := maxf(0.0, r0) * maxf(0.0, r0)
	var hi := r1 * r1
	var i := pool.count - 1
	while i >= 0:
		var d2 := (pool.pos[i] as Vector2).distance_squared_to(center)
		if d2 >= lo and d2 <= hi:
			out.append(pool.pos[i])
			pool.kill(i)
		i -= 1
	return out


func cancel_segment(sim: Sim, a: Vector2, b: Vector2, dist: float) -> PackedVector2Array:
	var pool := sim.enemy_bullets
	var out := PackedVector2Array()
	var d2 := dist * dist
	var i := pool.count - 1
	while i >= 0:
		var p: Vector2 = pool.pos[i]
		if p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= d2:
			out.append(p)
			pool.kill(i)
		i -= 1
	return out


## Alvo de maior vida (Estrela Cadente): o chefe se estiver lutando, senão o inimigo mais forte na tela.
func strongest_target(sim: Sim) -> Vector2:
	if sim.boss != null and sim.boss.fighting():
		return sim.boss.body_pos()
	var best := Vector2.INF
	var best_hp := -INF
	for e: SimEnemy in sim.enemies:
		if e.active() and Rect2(Vector2.ZERO, Playfield.FIELD).has_point(e.pos) and e.hp > best_hp:
			best_hp = e.hp
			best = e.pos
	return best


# --- Medidor e modificadores -------------------------------------------------------------------

func _fill(sim: Sim, amount: float) -> void:
	if active(sim) or amount <= 0.0:
		return
	var before := whole(sim.player.power_charge)
	sim.player.power_charge = minf(SEGMENTS, sim.player.power_charge + amount)
	var now := whole(sim.player.power_charge)
	if now > before:
		sim.emit(&"power_charge", {"segments": now})


func _track(b: SimBoss) -> void:
	if b != _boss:
		_boss = b
		_boss_hp = b.hp
		_dealt = 0.0


## Vida que o chefe perdeu desde o fim do último passo (fora o dano direto dos poderes): enche a Corrente no
## chefe de ato e, com sobrecarga viva, a parte extra conta no teto do poder.
func _measure_boss(sim: Sim) -> void:
	var b := sim.boss
	if b == null:
		return
	if b != _boss:
		_track(b)
		return
	var drop := maxf(0.0, _boss_hp - b.hp)
	if drop <= 0.0:
		return
	if active(sim):
		var mult := rate * dmg * (1.0 + crit * (ShipTraits.CRIT_MULT - 1.0)) * _resonance_mult(sim)
		if mult > 1.0:
			_dealt += drop * (1.0 - 1.0 / mult)
	elif b.is_final:
		_fill(sim, drop / maxf(1.0, b.max_hp) * BOSS_FILL)


## Quanto a Ressonância multiplica a arma (DPS no nível de agora sobre o de antes).
func _resonance_mult(sim: Sim) -> float:
	if _level_restore < 0:
		return 1.0
	var def: Dictionary = (sim.tables["weapons"] as Dictionary).get(sim.player.weapon, {})
	return WeaponFire.dps(def, sim.player.level) / maxf(1.0, WeaponFire.dps(def, _level_restore))


func _recompute(sim: Sim) -> void:
	rate = 1.0
	dmg = 1.0
	crit = 0.0
	pierce = 0
	time_scale = 1.0
	frozen = false
	kill_blast_radius = 0.0
	kill_blast_damage = 0.0
	var capped := boss_capped(sim, OVERDRIVE_SHARE)
	if capped:
		_strip(sim)
	for e: Dictionary in sim.power_fx:
		if int(e["wait"]) > 0:
			continue
		var spec: Dictionary = e["_spec"]
		match e["type"]:
			&"slow":
				time_scale = minf(time_scale, float(spec.get("factor", 0.35)))
			&"eclipse":
				frozen = true
			&"cloak":
				pierce += int(spec.get("pierce", 0))
			&"overdrive":
				pierce += int(spec.get("pierce", 0))
				kill_blast_radius = maxf(kill_blast_radius, float(spec.get("blast_radius", 0.0)))
				kill_blast_damage = maxf(kill_blast_damage, float(spec.get("blast_damage", 0.0)))
				if not capped:
					rate *= float(spec.get("rate", 1.0))
					dmg *= float(spec.get("damage", 1.0))
					crit = maxf(crit, float(spec.get("crit", 0.0)))


## Teto do chefe alcançado: os tiros já no ar perdem o crítico do poder e a Ressonância acaba.
func _strip(sim: Sim) -> void:
	resonance_off(sim)
	var pool := sim.player_bullets
	for i: int in range(pool.count):
		if pool.grazed[i] == CRIT_MARK:
			pool.grazed[i] = 0
			pool.damage[i] /= ShipTraits.CRIT_MULT
			pool.radius[i] -= 1.0


## Ressonância (Ascensão): arma no nível máximo enquanto durar; ao fim volta ao nível de antes (ou menos, se
## a nave levou dano no meio).
func resonance_on(sim: Sim) -> void:
	if _level_restore < 0:
		_level_restore = sim.player.level
	sim.player.level = sim.player.max_level()


func resonance_off(sim: Sim) -> void:
	if _level_restore >= 0:
		sim.player.level = mini(sim.player.level, _level_restore)
		_level_restore = -1
