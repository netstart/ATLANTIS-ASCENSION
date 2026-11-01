class_name Sim
extends RefCounted
## A partida inteira, sem nós (plano mestre 10.3): passo fixo de 1/60 s, determinística pela semente.
## A cena (Game) só lê o estado e os eventos e desenha; o bot e os testes rodam a Sim direto.
##
## Ordem de um passo: escolha de bênção pendente → hitstop → jogador → tiro, secundárias e especial →
## roteiro → inimigos e chefe → balas → colisões → coletáveis → limpeza → rank → fim de missão.
## Eventos para a visualização e o áudio se acumulam em `events` até alguém chamar take_events().

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
const ORB_WEAPONS: Array[StringName] = [&"pulsar", &"laser", &"plasma", &"railgun"]
const TIDE_FRAMES := 480
const TIDE_RADIUS := 20.0
const TIDE_CANCEL := 48.0
## Co-op local (PC): as duas naves dividem o casco; perto uma da outra, o Elo de Maré entre elas apaga balas.
const LINK_RANGE := 64.0
const LINK_CANCEL := 12.0
const COOP_OFFSET := 36.0
const DIFFICULTY := {
	&"brisa": {"hull": 2, "bullet": 0.8, "rank": false, "score": 0.5},
	&"normal": {"hull": 0, "bullet": 1.0, "rank": true, "score": 1.0},
	&"veteran": {"hull": 0, "bullet": 1.1, "rank": true, "score": 1.3},
	&"abyssal": {"hull": -2, "bullet": 1.15, "rank": true, "score": 1.6},
}
const TABLES: Array[String] = ["enemies", "patterns", "bosses", "weapons", "ships", "blessings", "wings"]

var mission_id: StringName
var mission: Dictionary = {}
var tables: Dictionary = {}
var loadout: Dictionary = {}
var difficulty: StringName = &"normal"
var rng: SimRng
var frame: int = 0
var player := SimPlayer.new()
var scoring := Scoring.new()
var mods := SimMods.new()
var enemy_bullets := BulletPool.new(2048)
var player_bullets := BulletPool.new(512)
var enemies: Array[SimEnemy] = []
var boss: SimBoss
var pickups: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var missiles: Array[Dictionary] = []
var drones: Array[Vector2] = []
var stage := StageScript.new()
var events: Array[Dictionary] = []
var hitstop: int = 0
var no_fire: int = 0
## Vento e corrente (capítulos 2 e 3) e, depois, Gravity Breach: aceleração das balas inimigas.
var gravity := Vector2.ZERO
## Deriva da nave (u/s) sob corrente ou vento, e quantos passos ainda dura.
var drift := Vector2.ZERO
var drift_frames: int = 0
var scroll: float = 0.0
var scroll_speed: float = 22.0
var rank: float = RANK_START
var laser_active: bool = false
var laser_width: float = 0.0
var laser_to_y: float = 0.0
var finished: bool = false
var cleared: bool = false
var miniboss_seconds: float = -1.0
## Tempo do chefe de ato (da entrada ao golpe final), para o objetivo "boss_time".
var boss_seconds: float = -1.0
var secondary: StringName = &""
var secondary_level: int = 1
var special_kind: StringName = &""
var special_frames: int = 0
var special_point := Vector2.ZERO
var tide_frames: int = 0
## Bênçãos oferecidas e ainda não escolhidas: a Sim espera (sem avançar o tempo) até a escolha.
var offer: Array[StringName] = []
var log_found: bool = false
var glyph_progress: int = 0
var secret_found: StringName = &""
var bosses_killed: int = 0
var fury_stacks: int = 0
## Beta (Hazards): Gravity Breach, prédios de cobertura, cápsulas, faixas do jogador e final.
var breach_dir := Vector2.ZERO
var breach_frames: int = 0
var breach_flip: bool = false
var covers: Array[Dictionary] = []
var rescued: int = 0
var capsule_combo: int = 0
var max_capsule_combo: int = 0
var lanes := PackedInt32Array([0, 0, 0])
var ending: StringName = &""
var revives: int = 0
## Segunda Maré (loop 2): balas 15% mais rápidas, bala de vingança em cada abate, chefes remendados.
var second_tide: bool = false
## Modificadores das Correntes semanais (fast_bullets, glass...).
var mutators: Array = []
var bosses_met: int = 0
## Pós-lançamento: escolta capturada (ShipTraits), quantos inimigos foram dominados e especiais usadas.
var escorts: Array[Dictionary] = []
var captured: int = 0
var specials_used: int = 0
## Abismo Infinito: profundidade atual (0 fora do modo); acelera as balas e multiplica os pontos.
var abyss_depth: int = 0
## Segunda nave do co-op local (null no jogo solo) e se o Elo de Maré está ligado neste passo.
var wing: SimPlayer
var linked: bool = false
## Causa do último dano (bullet, contact, beam, boss): a tela de derrota tira a dica daqui.
var last_cause: StringName = &""
var _coral_grazes: int = 0
var _bubble_timer: int = 0
var _finish_timer: int = -1
var _miniboss_start: int = -1
var _boss_start: int = -1
var _columns: Array = []
var _abyss_points: float = 1.0


## Lê as tabelas de data/ sem depender do autoload DB (roda nos testes sem autoloads).
static func load_tables() -> Dictionary:
	var out := {}
	for name: String in TABLES:
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


## Carga padrão (sem hangar): só a aeronave.
static func default_loadout(ship_id: StringName) -> Dictionary:
	return {"ship": String(ship_id), "secondary": "", "secondary_level": 1, "wings": [], "damage": 0.0, "hull": 0,
			"speed": 0.0, "difficulty": "normal"}


## `p_loadout`: id da aeronave (StringName) ou a carga completa do hangar (Dictionary).
func setup(p_mission: Dictionary, p_tables: Dictionary, p_loadout: Variant, seed: int,
		sensitivity: float = 1.0) -> void:
	mission = p_mission
	mission_id = StringName(String(mission.get("id", "")))
	tables = p_tables
	loadout = default_loadout(p_loadout) if typeof(p_loadout) != TYPE_DICTIONARY else p_loadout
	difficulty = StringName(String(loadout.get("difficulty", "normal")))
	second_tide = bool(loadout.get("second_tide", false))
	mutators = (loadout.get("mutators", []) as Array).duplicate()
	if not DIFFICULTY.has(difficulty):
		difficulty = &"normal"
	rng = SimRng.new(seed + int(mission.get("seed_salt", 0)))
	mods.apply(&"damage", float(loadout.get("damage", 0.0)))
	mods.apply(&"hull", float(loadout.get("hull", 0)))
	mods.apply(&"speed", float(loadout.get("speed", 0.0)))
	for wing_id: Variant in loadout.get("wings", []):
		var wing: Dictionary = (tables.get("wings", {}) as Dictionary).get(StringName(String(wing_id)), {})
		if not wing.is_empty():
			mods.apply(StringName(String(wing.get("effect", ""))), float(wing.get("value", 0.0)))
	var ship_id := StringName(String(loadout.get("ship", "falcon")))
	player.setup((tables["ships"] as Dictionary).get(ship_id, {}), sensitivity * mods.speed_mult)
	var diff: Dictionary = DIFFICULTY[difficulty]
	player.max_hull = maxi(1, player.max_hull + mods.extra_hull + int(diff["hull"]))
	player.hull = player.max_hull
	player.bombs += int(loadout.get("bombs", 0))
	if "glass" in mutators:
		player.max_hull = 1
		player.hull = 1
	player.hitbox *= mods.hitbox_mult
	player.precise_mult = 0.5 * mods.precise_mult
	player.invuln_bonus = mods.invuln_bonus
	var lock := String(mission.get("weapon_lock", ""))
	if not lock.is_empty():
		player.weapon_lock = StringName(lock)
		player.weapon = player.weapon_lock
	if bool(loadout.get("coop", false)):
		_setup_wing(StringName(String(loadout.get("coop_ship", "manta"))))
	secondary = StringName(String(loadout.get("secondary", "")))
	secondary_level = clampi(int(loadout.get("secondary_level", 1)), 1, 5)
	scroll_speed = float(mission.get("scroll_speed", 22.0))
	scoring.window = Scoring.CHAIN_WINDOW + mods.chain_window
	scoring.point_mult = float(diff["score"]) * float(mission.get("score_mult", 1.0))
	_bubble_timer = mods.bubble_recharge
	_abyss_points = scoring.point_mult
	stage.setup(mission)
	for c: int in range(COLUMNS):
		_columns.append([])


func _setup_wing(ship_id: StringName) -> void:
	wing = SimPlayer.new()
	wing.setup((tables["ships"] as Dictionary).get(ship_id, {}), player.speed_mult / maxf(0.01,
			float(player.ship.get("speed", 1.0))))
	# O feixe do Laser é resolvido só para a nave 1; a ala usa Pulsar no lugar.
	if wing.signature == &"laser":
		wing.signature = &"pulsar"
		wing.weapon = &"pulsar"
	player.pos.x -= COOP_OFFSET
	wing.pos = SimPlayer.START + Vector2(COOP_OFFSET, 0)
	if player.weapon_lock != &"" and player.weapon_lock != &"laser":
		wing.weapon_lock = player.weapon_lock
		wing.weapon = player.weapon_lock


## Reviver (anúncio recompensado ou grátis na Steam): volta com 1 de casco, balas apagadas e 3 s de
## invulnerabilidade. Só depois de uma derrota e uma vez por missão (o App controla).
func revive() -> void:
	if not finished or cleared:
		return
	finished = false
	player.alive = true
	player.hull = 1
	player.invuln = 180
	_finish_timer = -1
	revives += 1
	pearls_from(enemy_bullets.cancel_all())
	beams.clear()
	emit(&"revive", {"pos": player.pos})


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
	return no_fire <= 0 and not finished and not Specials.frozen(self)


func bullet_speed_mult() -> float:
	var diff: Dictionary = DIFFICULTY[difficulty]
	var mult := float(diff["bullet"])
	if bool(diff["rank"]):
		mult *= 1.0 + 0.12 * (rank - 0.5) * 2.0
	if boss != null and boss.desperate:
		mult *= 1.15
	if second_tide:
		mult *= 1.15
	if "fast_bullets" in mutators:
		mult *= 1.2
	if abyss_depth > 1:
		mult *= 1.0 + minf(0.45, 0.01 * (abyss_depth - 1))
	return mult


## Multiplicador de dano do jogador agora (hangar, bênçãos, Fúria e Maré Alta).
func damage_mult() -> float:
	var m := mods.dmg_mult * (1.0 + 0.02 * fury_stacks)
	if tide_frames > 0:
		m *= 1.25
	return m


# --- Passo -------------------------------------------------------------------------------------

## `input2`: entrada da segunda nave no co-op local (ignorada no solo).
func step(input: SimInput, input2: SimInput = null) -> void:
	if finished:
		return
	if not offer.is_empty():
		if input.choice < 0 or input.choice >= offer.size():
			return
		choose_blessing(offer[input.choice])
	frame += 1
	if hitstop > 0:
		hitstop -= 1
		return
	player.tick()
	scoring.tick()
	if no_fire > 0:
		no_fire -= 1
	_timers()
	scroll += scroll_speed * STEP
	if player.alive:
		player.move(input)
		if drift_frames > 0:
			player.pos += drift * STEP
			player.pos = player.pos.clamp(SimPlayer.MARGIN, Playfield.FIELD - SimPlayer.MARGIN)
		_player_actions(input)
		if wing != null:
			_wing_actions(input2 if input2 != null else SimInput.new())
	SecondaryFire.step(self)
	ShipTraits.step(self)
	Specials.step(self)
	stage.step(self)
	Hazards.step(self)
	for e: SimEnemy in enemies:
		e.step(self)
	if boss != null:
		if boss.state == SimBoss.State.DUEL:
			boss.add_taps(input.taps)
		boss.step(self)
		if boss.state == SimBoss.State.DEAD:
			boss = null
	enemy_bullets.step(STEP, BOUNDS, gravity + breach_dir, Specials.frozen(self))
	player_bullets.step(STEP, BOUNDS, breach_dir * Hazards.BREACH_PLAYER_SHARE)
	if tide_frames > 0:
		pearls_from(enemy_bullets.cancel_near(player.pos, TIDE_RADIUS))
	_beams_step()
	_collide_player_bullets()
	if laser_active:
		_beam_attack(WeaponFire.laser_width(player.level), WeaponFire.dps(
				(tables["weapons"] as Dictionary).get(&"laser", {}), player.level) * damage_mult())
	_collide_ship(player)
	if wing != null:
		_collide_ship(wing)
	_pickups_step()
	_cleanup()
	if bool((DIFFICULTY[difficulty] as Dictionary)["rank"]):
		rank = clampf(rank + 0.002 * STEP + (0.0003 if player.level >= 3 else 0.0), 0.0, 1.0)
	_check_finish()


func _timers() -> void:
	if tide_frames > 0:
		tide_frames -= 1
		if tide_frames == 0:
			scoring.tide_mult = 1.0
	if drift_frames > 0:
		drift_frames -= 1
		if drift_frames == 0:
			gravity = Vector2.ZERO
	if mods.bubble_recharge > 0:
		_bubble_timer -= 1
		if _bubble_timer <= 0:
			_bubble_timer = mods.bubble_recharge
			if mods.bubbles < 1:
				mods.bubbles = 1
				emit(&"bubble", {})


func _player_actions(input: SimInput) -> void:
	var weapon_def: Dictionary = (tables["weapons"] as Dictionary).get(player.weapon, {})
	laser_active = false
	if input.fire:
		if player.weapon == &"laser":
			laser_active = true
		else:
			var before := player_bullets.count
			if WeaponFire.fire(player, player_bullets, weapon_def, frame, damage_mult(), mods.fire_rate) > 0:
				ShipTraits.on_fire(self, before)
				emit(&"shot", {"weapon": player.weapon})
	if input.bomb and player.bombs > 0:
		player.bombs -= 1
		scoring.bombs_used += 1
		scoring.break_chain()
		player.invuln = maxi(player.invuln, SimPlayer.BOMB_INVULN)
		area_blast(BOMB_DAMAGE)
		emit(&"bomb", {"pos": player.pos})
	elif input.special and player.special_charge >= 1.0:
		player.special_charge = 0.0
		Specials.activate(self, ShipTraits.special_for(self))
	if input.tide and scoring.pressure >= Scoring.PRESSURE_MAX and tide_frames == 0:
		tide_frames = TIDE_FRAMES + mods.tide_bonus
		scoring.pressure = 0.0
		scoring.tide_mult = 2.0
		pearls_from(enemy_bullets.cancel_near(player.pos, TIDE_CANCEL))
		rank = minf(1.0, rank + 0.1)
		emit(&"tide", {"pos": player.pos})


## Ala do co-op: move, atira com a própria arma, usa as bombas do par e liga o Elo de Maré quando perto.
func _wing_actions(input: SimInput) -> void:
	wing.tick()
	wing.move(input)
	if input.fire:
		var before := player_bullets.count
		var def: Dictionary = (tables["weapons"] as Dictionary).get(wing.weapon, {})
		if WeaponFire.fire(wing, player_bullets, def, frame, damage_mult(), mods.fire_rate) > 0:
			ShipTraits.on_fire(self, before)
	if input.bomb and player.bombs > 0:
		player.bombs -= 1
		scoring.bombs_used += 1
		scoring.break_chain()
		wing.invuln = maxi(wing.invuln, SimPlayer.BOMB_INVULN)
		area_blast(BOMB_DAMAGE)
		emit(&"bomb", {"pos": wing.pos})
	var was := linked
	linked = wing.pos.distance_to(player.pos) <= LINK_RANGE
	if linked:
		pearls_from(enemy_bullets.cancel_near((wing.pos + player.pos) * 0.5, LINK_CANCEL))
	if linked != was:
		emit(&"link", {"on": linked})


## Bomba e especial: todas as balas viram pérolas e todo inimigo na tela leva dano.
func area_blast(amount: float) -> void:
	pearls_from(enemy_bullets.cancel_all())
	for e: SimEnemy in enemies:
		if e.active() and e.damage(amount):
			_kill_enemy(e)
	if boss != null:
		boss.damage_body(amount, self)
	beams.clear()


## Rajada concentrada (Manta): feixe largo com dano multiplicado, mesmo com outra arma.
func burst_beam(width: float, mult: float) -> void:
	laser_active = true
	laser_width = width
	var weapon_def: Dictionary = (tables["weapons"] as Dictionary).get(player.weapon, {})
	_beam_attack(width, WeaponFire.dps(weapon_def, player.level) * mult * damage_mult())


# --- Bênçãos -----------------------------------------------------------------------------------

## Sorteia 3 bênçãos ainda não escolhidas (fluxo "blessings" da semente) e espera a escolha. `kind` &"module"
## oferece os módulos do Abismo Infinito (mesma tabela, marcados com "abyss") no lugar das bênçãos.
func offer_blessings(kind: StringName = &"blessing") -> void:
	var pool: Array[StringName] = []
	var table: Dictionary = tables.get("blessings", {})
	for id: StringName in table:
		if not id in mods.taken and bool((table[id] as Dictionary).get("abyss", false)) == (kind == &"module"):
			pool.append(id)
	offer.clear()
	var stream := rng.stream(&"blessings")
	while offer.size() < 3 and not pool.is_empty():
		offer.append(pool.pop_at(stream.randi_range(0, pool.size() - 1)))
	if not offer.is_empty():
		emit(&"blessing_offer", {"ids": offer.duplicate()})


func choose_blessing(id: StringName) -> void:
	var def: Dictionary = (tables.get("blessings", {}) as Dictionary).get(id, {})
	offer.clear()
	if def.is_empty():
		return
	var synergy := mods.apply_blessing(def)
	match StringName(String(def.get("effect", ""))):
		&"hull":
			player.max_hull += int(def.get("value", 1))
			player.hull += int(def.get("value", 1))
		&"hitbox":
			player.hitbox = maxf(1.5, player.hitbox * (1.0 - float(def.get("value", 0.2))))
		&"precise":
			player.precise_mult = 0.5 * mods.precise_mult
		&"invuln":
			player.invuln_bonus = mods.invuln_bonus
		&"chain_window":
			scoring.window = Scoring.CHAIN_WINDOW + mods.chain_window
		&"shield_timer":
			_bubble_timer = mods.bubble_recharge
		&"missiles", &"drones":
			# Módulo de secundária: instala a arma ou sobe 2 níveis se já for a mesma.
			var kind := StringName(String(def["effect"]))
			secondary_level = mini(5, secondary_level + 2) if secondary == kind else maxi(2, secondary_level)
			secondary = kind
		&"bombs":
			player.bombs = mini(player.bombs + int(def.get("value", 1)), 6)
	player.cap_bonus = mods.weapon_cap_bonus
	scoring.base_chain = mods.base_chain
	scoring.chain = maxi(scoring.chain, scoring.base_chain)
	emit(&"blessing", {"id": id, "synergy": String(synergy)})


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
	if spec.has("glyph"):
		e.glyph = int(spec["glyph"])
	enemies.append(e)


func spawn_boss(boss_id: StringName, final: bool) -> void:
	var patched := StringName(String(boss_id) + "_patched")
	if second_tide and (tables["bosses"] as Dictionary).has(patched):
		boss_id = patched
	var def: Dictionary = (tables["bosses"] as Dictionary).get(boss_id, {})
	if def.is_empty():
		return
	boss = SimBoss.new()
	boss.setup(def, tables["patterns"])
	if not final:
		_miniboss_start = frame
	else:
		_boss_start = frame
		bosses_met += 1
	emit(&"boss_intro", {"id": boss_id, "name_key": String(def.get("name_key", "")), "final": final})


func on_boss_phase(b: SimBoss, ph: Dictionary, transition: bool) -> void:
	if transition:
		hitstop = maxi(hitstop, int((ph.get("intro", {}) as Dictionary).get("hitstop", 8)))
		pearls_from(enemy_bullets.cancel_all())
		beams.clear()
	no_fire = maxi(no_fire, SimBoss.PHASE_QUIET)
	var intro: Dictionary = ph.get("intro", {})
	emit(&"boss_phase", {"id": b.id, "phase": String(ph.get("id", "")), "index": b.phase_index,
			"dialogue": String(intro.get("dialogue", "")), "event": String(intro.get("event", ""))})
	match String(intro.get("event", "")):
		"ocean_shift_reverse":
			emit(&"ocean_shift", {"to": "flood", "duration": 4.0, "warn": 0.0})
		"gravity_breach":
			Hazards.breach(self, Vector2(0, 1), 36.0, 10.0, false)
		"gravity_flip":
			Hazards.breach(self, Vector2(1, 0), 34.0, 60.0, true)
	var memory := int(loadout.get("memory_lane", -1))
	if b.is_final and not transition and memory >= 0:
		# Chefe que lembra: já viu o jogador antes e começa puxado para a faixa preferida dele.
		var lane_x := (memory + 0.5) * Playfield.FIELD.x / Hazards.LANES
		b.home.x = lerpf(b.home.x, lane_x, 0.4)
		emit(&"boss_remember", {"lane": memory})
	if bool(ph.get("learn", false)):
		# O Protocolo aprendeu onde o jogador gosta de voar e se posiciona ali.
		b.home.x = Hazards.favorite_lane_x(self)
		emit(&"boss_learn", {"x": b.home.x})


func on_boss_part_destroyed(b: SimBoss, part: Dictionary) -> void:
	scoring.add_bonus(int(int(part.get("points", 2000)) * scoring.point_mult))
	hitstop = maxi(hitstop, 3)
	emit(&"boss_part", {"id": b.id, "part": String(part["id"]), "pos": b.part_pos(part)})
	_spawn_pickup(&"medal", b.part_pos(part))


func on_boss_duel_start(b: SimBoss) -> void:
	pearls_from(enemy_bullets.cancel_all())
	beams.clear()
	hitstop = maxi(hitstop, 12)
	emit(&"duel_start", {"id": b.id, "pos": b.body_pos()})


func on_boss_defeated(b: SimBoss) -> void:
	pearls_from(enemy_bullets.cancel_all())
	beams.clear()
	bosses_killed += 1
	scoring.add_bonus(int((b.bonus + int(b.def.get("points", 20000)) + int(b.duel_power * 10000.0)) * scoring.point_mult))
	hitstop = maxi(hitstop, 10)
	if _miniboss_start >= 0 and not b.is_final:
		miniboss_seconds = (frame - _miniboss_start) * STEP
		_miniboss_start = -1
	if _boss_start >= 0 and b.is_final:
		boss_seconds = (frame - _boss_start) * STEP
		_boss_start = -1
	if bool(b.def.get("ending", false)):
		ending = Hazards.ending_for(self, b)
	for k: int in range(int(b.def.get("medals", 6))):
		_spawn_pickup(&"medal", b.body_pos() + Vector2(rng.randf_in(&"drops", -60.0, 60.0),
				rng.randf_in(&"drops", -30.0, 30.0)))
	# Recompensa dos chefes de meio de fase (data/bosses.json "drops"): núcleo de força e bomba para a luta seguinte.
	for kind: Variant in b.def.get("drops", []):
		var drop := StringName(String(kind))
		if drop != &"power" or player.weapon_lock == &"":
			_spawn_pickup(drop, b.body_pos() + Vector2(rng.randf_in(&"drops", -24.0, 24.0), 10.0))
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
		&"current", &"wind":
			var strength := float(ev.get("strength", 30.0))
			var dir := Vector2(float(ev.get("dx", 1.0)), float(ev.get("dy", 0.0))).normalized()
			gravity = dir * strength
			drift = dir * strength * float(ev.get("drift", 0.6))
			drift_frames = int(float(ev.get("duration", 8.0)) * 60.0)
			emit(StringName(String(ev["op"])), {"dir": dir, "duration": float(ev.get("duration", 8.0))})
		&"lightning":
			var x := float(ev.get("x", 0.5)) * Playfield.FIELD.x
			beams.append({"x": x, "y": -20.0, "width": float(ev.get("width", 26.0)), "warn": int(ev.get("warn", 45)),
					"frames": int(ev.get("frames", 24)), "age": 0, "kind": String(ev.get("kind", "lightning"))})
			emit(&"beam_warn", {"pos": Vector2(x, 0), "width": float(ev.get("width", 26.0)),
					"kind": String(ev.get("kind", "lightning"))})
		&"blessing":
			offer_blessings()
		&"module":
			offer_blessings(&"module")
		&"abyss":
			abyss_depth = int(ev.get("depth", abyss_depth + 1))
			scoring.point_mult = _abyss_points * (1.0 + 0.05 * (abyss_depth - 1))
			emit(&"abyss", {"depth": abyss_depth})
		&"gravity_breach", &"cover", &"capsule":
			Hazards.on_event(self, ev)
		&"log":
			pickups.append({"kind": &"log", "pos": Vector2(float(ev.get("x", 0.5)) * Playfield.FIELD.x, -12.0),
					"vel": Vector2(0, 34), "frames": 0})
			emit(&"log_spawn", {})
		_:
			emit(StringName(String(ev.get("op", "event"))), ev.duplicate())


func add_beam(origin: Vector2, width: float, warn_frames: int, frames: int) -> void:
	# Oráculo de Nereu: avisos de feixe 50% mais longos.
	var warn := roundi(warn_frames * 1.5) if mods.oracle else warn_frames
	beams.append({"x": origin.x, "y": origin.y, "width": width, "warn": warn, "frames": frames, "age": 0})
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
			var area: float = player_bullets.splash[i]
			if area > 0.0:
				splash(p, area, dmg)
			if player_bullets.pierce[i] > 0:
				player_bullets.pierce[i] -= 1
			else:
				player_bullets.kill(i)
		i -= 1


## Dano em área (Plasma, Ressaca): metade do dano em quem estiver no raio.
func splash(at: Vector2, radius: float, dmg: float) -> void:
	for e: SimEnemy in enemies:
		if e.active() and at.distance_to(e.pos) <= radius + e.radius and e.damage(dmg * 0.5):
			_kill_enemy(e)
	if boss != null and boss.fighting() and at.distance_to(boss.body_pos()) <= radius + boss.body_radius():
		boss.damage_body(dmg * 0.5, self)
	emit(&"splash", {"pos": at, "radius": radius})


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


## Golpe genérico num ponto (mísseis): devolve se acertou algo.
func hit_at(p: Vector2, r: float, dmg: float) -> bool:
	for e: SimEnemy in enemies:
		if e.active() and p.distance_squared_to(e.pos) <= (r + e.radius) * (r + e.radius):
			if e.damage(dmg):
				_kill_enemy(e)
			return true
	return boss != null and boss.fighting() and _hit_boss(p, r, dmg)


## Alvo mais próximo para os mísseis (Vector2.INF se não houver).
func nearest_target(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for e: SimEnemy in enemies:
		if e.active() and Rect2(Vector2.ZERO, Playfield.FIELD).has_point(e.pos):
			var d := from.distance_squared_to(e.pos)
			if d < best_d:
				best_d = d
				best = e.pos
	if boss != null and boss.fighting():
		var d := from.distance_squared_to(boss.body_pos())
		if d < best_d:
			best = boss.body_pos()
	return best


## Feixe vertical (Laser e Rajada): acerta o alvo mais próximo acima da nave.
func _beam_attack(width: float, dps_value: float) -> void:
	if not player.alive:
		return
	laser_width = width
	var half := width * 0.5
	var dmg := dps_value * STEP
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


func _collide_ship(ship: SimPlayer) -> void:
	if not player.alive:
		return
	var pp := ship.pos
	var hb := ship.hitbox
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
			_graze(p, ship)
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
	if hit and ship.vulnerable():
		_player_hit(cause, ship)


func _graze(p: Vector2, ship: SimPlayer = null) -> void:
	scoring.on_graze()
	if linked:
		# Elo de Maré: raspão perto do par vale dobrado.
		scoring.on_graze()
	scoring.add_pressure(mods.graze_bonus)
	player.special_charge = minf(1.0, player.special_charge + SimPlayer.GRAZE_CHARGE * (1.0 + mods.graze_bonus))
	if ship != null and ship != player:
		ship.special_charge = player.special_charge
	emit(&"graze", {"pos": p})
	if breach_frames > 0:
		# Redemoinho: durante a Gravity Breach cada raspão conta duas vezes.
		scoring.on_graze()
	if mods.coral_heal > 0:
		_coral_grazes += 1
		if _coral_grazes >= mods.coral_heal:
			_coral_grazes = 0
			if player.hull < player.max_hull:
				player.hull += 1
				emit(&"heal", {"pos": player.pos})


## `ship`: a nave atingida (no co-op, a ala divide o casco da nave 1).
func _player_hit(cause: StringName, ship: SimPlayer = null) -> void:
	if ship == null:
		ship = player
	fury_stacks = 0
	capsule_combo = 0
	if mods.bubbles > 0:
		mods.bubbles -= 1
		ship.invuln = maxi(ship.invuln, 60)
		pearls_from(enemy_bullets.cancel_near(ship.pos, MERCY_RADIUS))
		emit(&"bubble_pop", {"pos": ship.pos})
		return
	scoring.hull_lost += 1
	scoring.break_chain()
	last_cause = cause
	var keep_level := player.level
	var down := player.take_hit()
	if ship != player:
		# O casco é do par; o nível de arma perdido é o da nave atingida.
		player.level = keep_level
		ship.level = maxi(1, ship.level - 1)
	if wing != null:
		wing.invuln = player.invuln
		wing.alive = player.alive
	enemy_bullets.cancel_near(ship.pos, 120.0 if mods.reflux else MERCY_RADIUS)
	rank = maxf(0.0, rank - 0.25)
	hitstop = maxi(hitstop, 6)
	emit(&"player_hit", {"pos": ship.pos, "hull": player.hull, "down": down, "cause": cause})


func _kill_enemy(e: SimEnemy) -> void:
	if not e.alive:
		return
	e.alive = false
	# Carta de Nereu: marcados valem +50%.
	var points := roundi(e.points * 1.5) if mods.chart and e.marked else e.points
	var gained := scoring.on_kill(points, e.pos.distance_to(player.pos), e.marked)
	emit(&"kill", {"pos": e.pos, "id": e.id, "sprite": e.sprite, "points": gained, "big": e.radius >= 20.0})
	if e.radius >= 20.0:
		hitstop = maxi(hitstop, 3)
	if mods.fury:
		fury_stacks = mini(10, fury_stacks + 1)
	if second_tide and can_fire() and player.alive and e.pos.distance_to(player.pos) > 70.0:
		# Bala de vingança: lenta, mirada, nunca à queima-roupa (Segunda Maré).
		fire_enemy(e.pos, rad_to_deg((player.pos - e.pos).angle()), 62.0, BulletKinds.enemy_index(&"orb_gold_m"),
				0.0, 0.0)
	if mods.undertow:
		splash(e.pos, 30.0, 8.0 * damage_mult())
	ShipTraits.on_kill(self, e)
	if e.glyph >= 0:
		_glyph(e.glyph)
	var drop := e.drop
	if drop == &"" and mods.orb_luck > 0.0 and rng.stream(&"drops").randf() < mods.orb_luck:
		drop = &"orb"
	if drop != &"" and (player.weapon_lock == &"" or drop != &"orb"):
		_spawn_pickup(drop, e.pos)


## Glifos atlantes: destruídos na ordem certa abrem a missão secreta (plano mestre 5.4).
func _glyph(index: int) -> void:
	var secret: Dictionary = mission.get("secret", {})
	if secret.is_empty():
		return
	if index == glyph_progress:
		glyph_progress += 1
		emit(&"glyph", {"index": index, "of": int(secret.get("glyphs", 3))})
		if glyph_progress >= int(secret.get("glyphs", 3)):
			secret_found = StringName(String(secret.get("mission", "")))
			emit(&"secret", {"mission": String(secret_found)})
	else:
		glyph_progress = 0
		emit(&"glyph_reset", {})


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


func pearls_from(points: PackedVector2Array) -> void:
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
		elif mods.magnet_radius > 0.0 and player.alive and kind != &"log" \
				and p.distance_to(player.pos) <= mods.magnet_radius:
			pk["vel"] = (player.pos - p).normalized() * 160.0
		elif kind == &"log" and mods.log_finder and player.alive and p.y > 40.0:
			# Localizador: o registro vem até a nave assim que entra no campo.
			pk["vel"] = (player.pos - p).normalized() * 120.0
		elif kind == &"orb" or kind == &"power":
			pk["vel"] = Vector2(sin(frames * 0.05) * 20.0, ORB_FALL)
		p += (pk["vel"] as Vector2) * STEP
		pk["pos"] = p
		var radius := PEARL_RADIUS if kind == &"pearl" else PICKUP_RADIUS
		var who: SimPlayer = null
		if player.alive and p.distance_to(player.pos) <= radius:
			who = player
		elif wing != null and wing.alive and p.distance_to(wing.pos) <= radius:
			who = wing
		if who != null:
			_collect(kind, frames, who)
			pickups.remove_at(i)
		elif p.y > Playfield.FIELD.y + 24.0 or (kind == &"pearl" and frames > 600):
			if kind == &"medal" and mods.medal_net and not pk.has("bounced"):
				pk["bounced"] = true
				pk["vel"] = Vector2(0, -MEDAL_FALL * 1.6)
			else:
				if kind == &"medal":
					scoring.on_medal_missed()
				elif kind == &"capsule":
					capsule_combo = 0
					emit(&"medal_missed", {})
				pickups.remove_at(i)
		i -= 1


func _collect(kind: StringName, frames: int, who: SimPlayer = null) -> void:
	if who == null:
		who = player
	match kind:
		&"orb":
			var weapon := orb_weapon(frames)
			if who == wing and weapon == &"laser":
				weapon = &"pulsar"
			var up := who.collect_orb(weapon)
			emit(&"orb", {"weapon": who.weapon, "level": who.level, "up": up, "pos": who.pos})
		&"power":
			# Núcleo de força (chefes de meio de fase): +1 nível na arma atual, sem trocar de arma.
			var up := who.collect_orb(who.weapon)
			emit(&"orb", {"weapon": who.weapon, "level": who.level, "up": up, "pos": who.pos})
		&"medal":
			emit(&"medal", {"value": scoring.on_medal(), "pos": who.pos})
		&"pearl":
			scoring.on_pearl()
			emit(&"pearl", {"pos": who.pos})
		&"bomb":
			player.bombs = mini(player.bombs + 1, 4)
			emit(&"bomb_pickup", {"pos": who.pos})
		&"log":
			log_found = true
			emit(&"log", {"pos": who.pos})
		&"capsule":
			Hazards.collect_capsule(self)


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
		&"log":
			objective = log_found
		&"grazes":
			objective = scoring.grazes >= int(obj.get("count", 100))
		&"chain":
			objective = scoring.max_chain >= int(obj.get("count", 40))
		&"secret":
			objective = secret_found != &""
		&"score":
			objective = scoring.score >= int(obj.get("count", 100000))
		&"rescue":
			objective = rescued >= int(obj.get("count", 10))
		&"capsule_combo":
			objective = max_capsule_combo >= int(obj.get("count", 5))
		&"boss_time":
			objective = boss_seconds >= 0.0 and boss_seconds <= float(obj.get("seconds", 90.0))
	var all_marked := scoring.marked_killed >= scoring.marked_total
	return [cleared, cleared and scoring.hull_lost == 0, cleared and all_marked, cleared and objective]


func result() -> Dictionary:
	return {
		"mission": String(mission_id), "cleared": cleared, "score": scoring.score, "stars": stars(),
		"kills": scoring.kills, "marked": [scoring.marked_killed, scoring.marked_total], "grazes": scoring.grazes,
		"max_chain": scoring.max_chain, "medals": scoring.medals, "max_medal": scoring.max_medal,
		"pearls": scoring.pearls, "hull_lost": scoring.hull_lost, "bombs_used": scoring.bombs_used,
		"seconds": frame * STEP, "miniboss_seconds": miniboss_seconds, "log_found": log_found,
		"secret": String(secret_found), "blessings": mods.taken.duplicate(), "difficulty": String(difficulty),
		"orichalcum": floori(scoring.medals / 2.0) + bosses_killed * 5, "bosses": bosses_killed,
		"rescued": rescued, "max_capsule_combo": max_capsule_combo, "ending": String(ending), "revives": revives,
		"lane": Hazards.favorite_lane(self), "bosses_met": bosses_met, "captured": captured, "depth": abyss_depth,
		"progress": progress(), "boss_left": boss.hp / maxf(1.0, boss.max_hp) if boss != null and boss.is_final
				else -1.0, "bombs_left": player.bombs, "cause": String(last_cause),
	}


## Quanto da missão já passou (0 a 1): tempo de fase sobre a duração; o chefe final conta o resto.
func progress() -> float:
	if cleared:
		return 1.0
	var length := float(mission.get("length_s", 0.0)) * 60.0
	var base := clampf(stage.frame / length, 0.0, 1.0) if length > 0.0 else 0.0
	if boss != null and boss.is_final:
		base = maxf(base, 0.9 + 0.1 * (1.0 - boss.hp / maxf(1.0, boss.max_hp)))
	return base


## Hash do estado (teste de determinismo em 1x, 2x, 3x e em qualquer qualidade gráfica).
func state_hash() -> String:
	var parts := PackedStringArray([str(frame), str(scoring.score), str(scoring.grazes), str(player.hull),
			"%.3f,%.3f" % [player.pos.x, player.pos.y], str(enemy_bullets.count), str(player_bullets.count),
			str(enemies.size()), str(pickups.size()), "%.4f" % rank, str(missiles.size()), ",".join(mods.taken),
			str(rescued), str(breach_frames), str(captured)])
	if wing != null:
		parts.append("w%.3f,%.3f:%d" % [wing.pos.x, wing.pos.y, wing.level])
	for e: SimEnemy in enemies:
		parts.append("%s:%.2f,%.2f:%.2f" % [e.id, e.pos.x, e.pos.y, e.hp])
	var sum := Vector2.ZERO
	for i: int in range(enemy_bullets.count):
		sum += enemy_bullets.pos[i]
	parts.append("%.2f,%.2f" % [sum.x, sum.y])
	if boss != null:
		parts.append("%s:%d:%.2f" % [boss.id, boss.phase_index, boss.hp])
	return ",".join(parts).md5_text()
