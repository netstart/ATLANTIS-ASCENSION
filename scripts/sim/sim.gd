class_name Sim
extends RefCounted
## A partida inteira, sem nós (plano mestre 10.3): passo fixo de 1/60 s, determinística pela semente.
## A cena (Game) só lê o estado e os eventos e desenha; o bot e os testes rodam a Sim direto.
##
## Ordem de um passo: hitstop → jogador → tiro → roteiro → inimigos e chefe → balas → colisões →
## coletáveis → limpeza → rank → fim de missão. Eventos para a visualização e o áudio se acumulam em
## `events` até alguém chamar take_events().

const STEP := 1.0 / 60.0
const BOUNDS := Rect2(-32, -64, 334, 546)
const GRAZE_RANGE := 8.0
const CONTACT_FACTOR := 0.6
const COLUMNS := 10
const PICKUP_RADIUS := 18.0
const PEARL_RADIUS := 16.0
const PEARL_FLOAT := 20
const PEARL_SPEED := 300.0
const ORB_FALL := 42.0
const MEDAL_FALL := 70.0
const ORB_CYCLE := 90
const BOMB_DAMAGE := 80.0
const SPECIAL_DAMAGE := 40.0
const FINISH_DELAY := 90
const MERCY_RADIUS := 64.0
const RANK_START := 0.3
const ORB_WEAPONS: Array[StringName] = [&"pulsar", &"laser"]

var mission_id: StringName
var mission: Dictionary = {}
var tables: Dictionary = {}
var rng: SimRng
var frame: int = 0
var player := SimPlayer.new()
var scoring := Scoring.new()
var enemy_bullets := BulletPool.new(2048)
var player_bullets := BulletPool.new(512)
var enemies: Array[SimEnemy] = []
var boss: SimBoss
var pickups: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var stage := StageScript.new()
var events: Array[Dictionary] = []
var hitstop: int = 0
var no_fire: int = 0
var gravity := Vector2.ZERO
var scroll: float = 0.0
var scroll_speed: float = 22.0
var rank: float = RANK_START
var laser_active: bool = false
var laser_to_y: float = 0.0
var finished: bool = false
var cleared: bool = false
var miniboss_seconds: float = -1.0
var _finish_timer: int = -1
var _miniboss_start: int = -1
var _columns: Array = []


## Lê as tabelas de data/ sem depender do autoload DB (roda nos testes sem autoloads).
static func load_tables() -> Dictionary:
	var out := {}
	for name: String in ["enemies", "patterns", "bosses", "weapons", "ships"]:
		var table := {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))
		if typeof(parsed) == TYPE_ARRAY:
			for row: Variant in parsed:
				table[StringName(String((row as Dictionary).get("id", "")))] = row
		out[name] = table
	return out


static func load_mission(id: StringName) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/stages/%s.json" % id))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func setup(p_mission: Dictionary, p_tables: Dictionary, ship_id: StringName, seed: int,
		sensitivity: float = 1.0) -> void:
	mission = p_mission
	mission_id = StringName(String(mission.get("id", "")))
	tables = p_tables
	rng = SimRng.new(seed + int(mission.get("seed_salt", 0)))
	player.setup((tables["ships"] as Dictionary).get(ship_id, {}), sensitivity)
	scroll_speed = float(mission.get("scroll_speed", 22.0))
	stage.setup(mission)
	for c: int in range(COLUMNS):
		_columns.append([])


func take_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


func emit(type: StringName, data: Dictionary = {}) -> void:
	var event := data.duplicate()
	event["type"] = type
	event["frame"] = frame
	events.append(event)


func can_fire() -> bool:
	return no_fire <= 0 and not finished


func bullet_speed_mult() -> float:
	var mult := 1.0 + 0.12 * (rank - 0.5) * 2.0
	if boss != null and boss.desperate:
		mult *= 1.15
	return mult


# --- Passo -------------------------------------------------------------------------------------

func step(input: SimInput) -> void:
	if finished:
		return
	frame += 1
	if hitstop > 0:
		hitstop -= 1
		return
	player.tick()
	scoring.tick()
	if no_fire > 0:
		no_fire -= 1
	scroll += scroll_speed * STEP
	if player.alive:
		player.move(input)
		_player_actions(input)
	stage.step(self)
	for e: SimEnemy in enemies:
		e.step(self)
	if boss != null:
		if boss.state == SimBoss.State.DUEL:
			boss.add_taps(input.taps)
		boss.step(self)
		if boss.state == SimBoss.State.DEAD:
			boss = null
	enemy_bullets.step(STEP, BOUNDS, gravity)
	player_bullets.step(STEP, BOUNDS)
	_beams_step()
	_collide_player_bullets()
	_laser_step(input)
	_collide_player()
	_pickups_step()
	_cleanup()
	rank = clampf(rank + 0.002 * STEP + (0.0003 if player.level >= 3 else 0.0), 0.0, 1.0)
	_check_finish()


func _player_actions(input: SimInput) -> void:
	var weapon_def: Dictionary = (tables["weapons"] as Dictionary).get(player.weapon, {})
	laser_active = false
	if input.fire:
		if player.weapon == &"laser":
			laser_active = true
		elif WeaponFire.fire_pulsar(player, player_bullets, weapon_def, frame) > 0:
			emit(&"shot", {"weapon": player.weapon})
	if input.bomb and player.bombs > 0:
		player.bombs -= 1
		scoring.bombs_used += 1
		scoring.break_chain()
		player.invuln = maxi(player.invuln, SimPlayer.BOMB_INVULN)
		_area_blast(BOMB_DAMAGE)
		emit(&"bomb", {"pos": player.pos})
	elif input.special and player.special_charge >= 1.0:
		player.special_charge = 0.0
		player.invuln = maxi(player.invuln, SimPlayer.SPECIAL_INVULN)
		_area_blast(SPECIAL_DAMAGE)
		emit(&"special", {"pos": player.pos, "kind": String(player.ship.get("special", ""))})


## Bomba e especial: todas as balas viram pérolas e todo inimigo na tela leva dano.
func _area_blast(amount: float) -> void:
	_pearls_from(enemy_bullets.cancel_all())
	for e: SimEnemy in enemies:
		if e.active() and e.damage(amount):
			_kill_enemy(e)
	if boss != null:
		boss.damage_body(amount, self)
	beams.clear()


# --- Inimigos e chefes ---------------------------------------------------------------------------

func spawn_enemy(spec: Dictionary, member: int) -> void:
	var def: Dictionary = (tables["enemies"] as Dictionary).get(StringName(String(spec.get("enemy", ""))), {})
	if def.is_empty():
		return
	var count := maxi(1, int(spec.get("count", 1)))
	var spacing := float(spec.get("spacing", 36.0))
	var x := float(spec.get("x", 0.5)) * Playfield.FIELD.x
	var y := float(spec.get("y", -24.0))
	var center := (count - 1) * 0.5
	match StringName(String(spec.get("formation", "single"))):
		&"line":
			x += (member - center) * spacing
		&"v":
			x += (member - center) * spacing
			y -= absf(member - center) * 16.0
		&"column", &"single":
			pass
	var e := SimEnemy.new()
	var params: Dictionary = (spec.get("params", {}) as Dictionary).duplicate()
	if StringName(String(spec.get("path", ""))) == &"dive" and bool(spec.get("mirror", false)) and member % 2 == 1:
		params["side"] = -float(params.get("side", 1.0))
	e.setup(def, Vector2(x, y), StringName(String(spec.get("path", "straight"))), params,
			tables["patterns"], bool(spec.get("from_depth", false)))
	e.marked = bool(spec.get("marked", def.get("marked", false)))
	if e.marked:
		scoring.marked_total += 1
	e.drop = StringName(String(def.get("drop", "")))
	if member == count - 1 and spec.has("drop_last"):
		e.drop = StringName(String(spec["drop_last"]))
	enemies.append(e)


func spawn_boss(boss_id: StringName, final: bool) -> void:
	var def: Dictionary = (tables["bosses"] as Dictionary).get(boss_id, {})
	if def.is_empty():
		return
	boss = SimBoss.new()
	boss.setup(def, tables["patterns"])
	if not final:
		_miniboss_start = frame
	emit(&"boss_intro", {"id": boss_id, "name_key": String(def.get("name_key", "")), "final": final})


func on_boss_phase(b: SimBoss, ph: Dictionary, transition: bool) -> void:
	if transition:
		hitstop = maxi(hitstop, int((ph.get("intro", {}) as Dictionary).get("hitstop", 8)))
		_pearls_from(enemy_bullets.cancel_all())
		beams.clear()
	no_fire = maxi(no_fire, SimBoss.PHASE_QUIET)
	var intro: Dictionary = ph.get("intro", {})
	emit(&"boss_phase", {"id": b.id, "phase": String(ph.get("id", "")), "index": b.phase_index,
			"dialogue": String(intro.get("dialogue", "")), "event": String(intro.get("event", ""))})
	if String(intro.get("event", "")) == "ocean_shift_reverse":
		emit(&"ocean_shift", {"to": "flood", "duration": 4.0, "warn": 0.0})


func on_boss_part_destroyed(b: SimBoss, part: Dictionary) -> void:
	scoring.add_bonus(int(part.get("points", 2000)))
	hitstop = maxi(hitstop, 3)
	emit(&"boss_part", {"id": b.id, "part": String(part["id"]), "pos": b.part_pos(part)})
	_spawn_pickup(&"medal", b.part_pos(part))


func on_boss_duel_start(b: SimBoss) -> void:
	_pearls_from(enemy_bullets.cancel_all())
	beams.clear()
	hitstop = maxi(hitstop, 12)
	emit(&"duel_start", {"id": b.id, "pos": b.body_pos()})


func on_boss_defeated(b: SimBoss) -> void:
	_pearls_from(enemy_bullets.cancel_all())
	beams.clear()
	scoring.add_bonus(b.bonus + int(b.def.get("points", 20000)) + int(b.duel_power * 10000.0))
	hitstop = maxi(hitstop, 10)
	if _miniboss_start >= 0 and not b.is_final:
		miniboss_seconds = (frame - _miniboss_start) * STEP
		_miniboss_start = -1
	for k: int in range(int(b.def.get("medals", 6))):
		_spawn_pickup(&"medal", b.body_pos() + Vector2(rng.randf_in(&"drops", -60.0, 60.0),
				rng.randf_in(&"drops", -30.0, 30.0)))
	emit(&"boss_dead", {"id": b.id, "pos": b.body_pos(), "final": b.is_final})


func on_stage_event(ev: Dictionary) -> void:
	match StringName(String(ev.get("op", ""))):
		&"ocean_shift":
			# Aviso e 1,5 s sem balas novas durante a troca (plano mestre 4.8).
			no_fire = maxi(no_fire, int((float(ev.get("warn", 2.0)) + 1.5) * 60.0))
			emit(&"ocean_shift", {"to": String(ev.get("to", "")), "duration": float(ev.get("duration", 8.0)),
					"warn": float(ev.get("warn", 2.0))})
		&"scroll_speed":
			scroll_speed = float(ev.get("value", scroll_speed))
		_:
			var data := ev.duplicate()
			emit(StringName(String(ev.get("op", "event"))), data)


func add_beam(origin: Vector2, width: float, warn_frames: int, frames: int) -> void:
	beams.append({"x": origin.x, "y": origin.y, "width": width, "warn": warn_frames, "frames": frames, "age": 0})
	emit(&"beam_warn", {"pos": origin, "width": width})


func fire_enemy(origin: Vector2, angle_deg: float, speed: float, kind: int, turn: float, accel: float) -> void:
	enemy_bullets.spawn(origin, Vector2.from_angle(deg_to_rad(angle_deg)) * speed, BulletKinds.enemy_radius(kind),
			kind, 1.0, turn, accel)


# --- Colisões ----------------------------------------------------------------------------------

func _collide_player_bullets() -> void:
	for c: Array in _columns:
		c.clear()
	var width := Playfield.FIELD.x / COLUMNS
	for e: SimEnemy in enemies:
		if not e.active():
			continue
		var c0 := clampi(floori((e.pos.x - e.radius) / width), 0, COLUMNS - 1)
		var c1 := clampi(floori((e.pos.x + e.radius) / width), 0, COLUMNS - 1)
		for c: int in range(c0, c1 + 1):
			(_columns[c] as Array).append(e)
	var i := player_bullets.count - 1
	while i >= 0:
		var p: Vector2 = player_bullets.pos[i]
		var r: float = player_bullets.radius[i]
		var dmg: float = player_bullets.damage[i]
		var hit := false
		for e: SimEnemy in _columns[clampi(floori(p.x / width), 0, COLUMNS - 1)]:
			if e.alive and p.distance_squared_to(e.pos) <= (r + e.radius) * (r + e.radius):
				hit = true
				if e.damage(dmg):
					_kill_enemy(e)
				break
		if not hit and boss != null and boss.fighting():
			hit = _hit_boss(p, r, dmg)
		if hit:
			emit(&"hit", {"pos": p})
			player_bullets.kill(i)
		i -= 1


func _hit_boss(p: Vector2, r: float, dmg: float) -> bool:
	for part: Dictionary in boss.parts:
		var pr := float(part.get("radius", 10.0))
		if boss.part_active(part) and p.distance_squared_to(boss.part_pos(part)) <= (r + pr) * (r + pr):
			boss.damage_part(part, dmg, self)
			return true
	var br := boss.body_radius()
	if p.distance_squared_to(boss.body_pos()) <= (r + br) * (r + br):
		boss.damage_body(dmg, self)
		return true
	return false


## Laser: feixe vertical que acerta o alvo mais próximo acima da nave.
func _laser_step(_input: SimInput) -> void:
	if not laser_active or not player.alive:
		return
	var half := WeaponFire.laser_width(player.level) * 0.5
	var weapon_def: Dictionary = (tables["weapons"] as Dictionary).get(&"laser", {})
	var dmg := WeaponFire.dps(weapon_def, player.level) * STEP
	var best_y := -BOUNDS.size.y
	var target: SimEnemy = null
	for e: SimEnemy in enemies:
		if e.active() and absf(e.pos.x - player.pos.x) <= half + e.radius and e.pos.y < player.pos.y and e.pos.y > best_y:
			best_y = e.pos.y
			target = e
	var boss_part: Dictionary = {}
	var boss_body := false
	if boss != null and boss.fighting():
		for part: Dictionary in boss.parts:
			var pp := boss.part_pos(part)
			if boss.part_active(part) and absf(pp.x - player.pos.x) <= half + float(part.get("radius", 10.0)) \
					and pp.y < player.pos.y and pp.y > best_y:
				best_y = pp.y
				boss_part = part
				target = null
		var bp := boss.body_pos()
		if absf(bp.x - player.pos.x) <= half + boss.body_radius() and bp.y < player.pos.y and bp.y > best_y:
			best_y = bp.y
			boss_body = true
			boss_part = {}
			target = null
	laser_to_y = best_y
	if target != null:
		if target.damage(dmg):
			_kill_enemy(target)
	elif not boss_part.is_empty():
		boss.damage_part(boss_part, dmg, self)
	elif boss_body:
		boss.damage_body(dmg, self)


func _collide_player() -> void:
	if not player.alive:
		return
	var pp := player.pos
	var hb := player.hitbox
	var hit := false
	var cause := &"bullet"
	for i: int in range(enemy_bullets.count):
		var p: Vector2 = enemy_bullets.pos[i]
		var r: float = enemy_bullets.radius[i]
		var d2 := pp.distance_squared_to(p)
		if d2 <= (hb + r) * (hb + r):
			hit = true
			break
		if enemy_bullets.grazed[i] == 0 and d2 <= (hb + r + GRAZE_RANGE) * (hb + r + GRAZE_RANGE):
			enemy_bullets.grazed[i] = 1
			scoring.on_graze()
			player.special_charge = minf(1.0, player.special_charge + SimPlayer.GRAZE_CHARGE)
			emit(&"graze", {"pos": p})
	if not hit:
		for e: SimEnemy in enemies:
			if e.active() and pp.distance_to(e.pos) <= e.radius * CONTACT_FACTOR + hb:
				hit = true
				cause = &"contact"
				break
	if not hit:
		for b: Dictionary in beams:
			if int(b["age"]) >= int(b["warn"]) and pp.y > float(b["y"]) \
					and absf(pp.x - float(b["x"])) <= float(b["width"]) * 0.5 + hb:
				hit = true
				cause = &"beam"
				break
	if not hit and boss != null and boss.fighting():
		hit = pp.distance_to(boss.body_pos()) <= boss.body_radius() * CONTACT_FACTOR + hb
		if hit:
			cause = &"boss"
	if hit and player.vulnerable():
		_player_hit(cause)


func _player_hit(cause: StringName) -> void:
	scoring.hull_lost += 1
	scoring.break_chain()
	var down := player.take_hit()
	enemy_bullets.cancel_near(player.pos, MERCY_RADIUS)
	rank = maxf(0.0, rank - 0.25)
	hitstop = maxi(hitstop, 6)
	emit(&"player_hit", {"pos": player.pos, "hull": player.hull, "down": down, "cause": cause})


func _kill_enemy(e: SimEnemy) -> void:
	if not e.alive:
		return
	e.alive = false
	var gained := scoring.on_kill(e.points, e.pos.distance_to(player.pos), e.marked)
	emit(&"kill", {"pos": e.pos, "id": e.id, "sprite": e.sprite, "points": gained, "big": e.radius >= 20.0})
	if e.radius >= 20.0:
		hitstop = maxi(hitstop, 3)
	if e.drop != &"":
		_spawn_pickup(e.drop, e.pos)


# --- Feixes inimigos, coletáveis e limpeza ------------------------------------------------------------

func _beams_step() -> void:
	var i := beams.size() - 1
	while i >= 0:
		var b := beams[i]
		b["age"] = int(b["age"]) + 1
		if int(b["age"]) >= int(b["warn"]) + int(b["frames"]):
			beams.remove_at(i)
		i -= 1


func _spawn_pickup(kind: StringName, at: Vector2) -> void:
	var vel := Vector2(0, MEDAL_FALL if kind == &"medal" else ORB_FALL)
	pickups.append({"kind": kind, "pos": at, "vel": vel, "frames": 0})


func _pearls_from(points: PackedVector2Array) -> void:
	for p: Vector2 in points:
		pickups.append({"kind": &"pearl", "pos": p, "vel": Vector2(0, -30), "frames": 0})


## Cor atual de um orbe de arma: troca a cada ORB_CYCLE passos (o jogador escolhe a hora de pegar).
static func orb_weapon(frames: int) -> StringName:
	return ORB_WEAPONS[floori(frames / float(ORB_CYCLE)) % ORB_WEAPONS.size()]


func _pickups_step() -> void:
	var i := pickups.size() - 1
	while i >= 0:
		var pk := pickups[i]
		var frames := int(pk["frames"]) + 1
		pk["frames"] = frames
		var p: Vector2 = pk["pos"]
		var kind: StringName = pk["kind"]
		if kind == &"pearl" and frames > PEARL_FLOAT and player.alive:
			pk["vel"] = (player.pos - p).normalized() * PEARL_SPEED
		elif kind == &"orb":
			pk["vel"] = Vector2(sin(frames * 0.05) * 20.0, ORB_FALL)
		p += (pk["vel"] as Vector2) * STEP
		pk["pos"] = p
		var radius := PEARL_RADIUS if kind == &"pearl" else PICKUP_RADIUS
		if player.alive and p.distance_to(player.pos) <= radius:
			_collect(kind, frames)
			pickups.remove_at(i)
		elif p.y > Playfield.FIELD.y + 24.0 or (kind == &"pearl" and frames > 600):
			if kind == &"medal":
				scoring.on_medal_missed()
				emit(&"medal_missed", {})
			pickups.remove_at(i)
		i -= 1


func _collect(kind: StringName, frames: int) -> void:
	match kind:
		&"orb":
			var weapon := orb_weapon(frames)
			var up := player.collect_orb(weapon)
			emit(&"orb", {"weapon": weapon, "level": player.level, "up": up})
		&"medal":
			emit(&"medal", {"value": scoring.on_medal()})
		&"pearl":
			scoring.on_pearl()
			emit(&"pearl", {})
		&"bomb":
			player.bombs = mini(player.bombs + 1, 4)
			emit(&"bomb_pickup", {})


func _cleanup() -> void:
	var i := enemies.size() - 1
	while i >= 0:
		if not enemies[i].alive:
			enemies.remove_at(i)
		i -= 1


func _check_finish() -> void:
	if not player.alive:
		finished = true
		cleared = false
		emit(&"finished", {"cleared": false})
		return
	if _finish_timer < 0 and stage.ended and boss == null and enemies.is_empty():
		_finish_timer = FINISH_DELAY
	if _finish_timer > 0:
		_finish_timer -= 1
		if _finish_timer == 0:
			finished = true
			cleared = true
			emit(&"finished", {"cleared": true})


# --- Resultado e verificação ---------------------------------------------------------------------

## Estrelas da missão (plano mestre 4.5): concluir, sem perder casco, 100% dos marcados, objetivo.
func stars() -> Array[bool]:
	var objective := false
	var obj: Dictionary = mission.get("objective", {})
	match StringName(String(obj.get("type", ""))):
		&"miniboss_time":
			objective = miniboss_seconds >= 0.0 and miniboss_seconds <= float(obj.get("seconds", 30.0))
		&"no_bomb":
			objective = scoring.bombs_used == 0
	var all_marked := scoring.marked_killed >= scoring.marked_total
	return [cleared, cleared and scoring.hull_lost == 0, cleared and all_marked, cleared and objective]


func result() -> Dictionary:
	return {
		"mission": String(mission_id), "cleared": cleared, "score": scoring.score, "stars": stars(),
		"kills": scoring.kills, "marked": [scoring.marked_killed, scoring.marked_total], "grazes": scoring.grazes,
		"max_chain": scoring.max_chain, "medals": scoring.medals, "max_medal": scoring.max_medal,
		"pearls": scoring.pearls, "hull_lost": scoring.hull_lost, "bombs_used": scoring.bombs_used,
		"seconds": frame * STEP, "miniboss_seconds": miniboss_seconds,
	}


## Hash do estado (teste de determinismo em 1x, 2x, 3x e em qualquer qualidade gráfica).
func state_hash() -> String:
	var parts := PackedStringArray([str(frame), str(scoring.score), str(scoring.grazes), str(player.hull),
			"%.3f,%.3f" % [player.pos.x, player.pos.y], str(enemy_bullets.count), str(player_bullets.count),
			str(enemies.size()), str(pickups.size()), "%.4f" % rank])
	for e: SimEnemy in enemies:
		parts.append("%s:%.2f,%.2f:%.2f" % [e.id, e.pos.x, e.pos.y, e.hp])
	var sum := Vector2.ZERO
	for i: int in range(enemy_bullets.count):
		sum += enemy_bullets.pos[i]
	parts.append("%.2f,%.2f" % [sum.x, sum.y])
	if boss != null:
		parts.append("%s:%d:%.2f" % [boss.id, boss.phase_index, boss.hp])
	return ",".join(parts).md5_text()
