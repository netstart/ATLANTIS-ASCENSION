class_name SimBoss
extends RefCounted
## Chefe e mini-chefe (plano mestre 6.3, 6.4; dados em data/bosses.json): máquina de estados por
## etapa, partes destrutíveis, pontos fracos, entrada com nome em tela, duelo de raio no golpe final.
##
## Estados: ENTER (desce até a posição, invulnerável) → FIGHT (etapas por HP) → DUEL (feixe contra
## feixe, toques do jogador empurram) → DYING (explosões) → DEAD.
## Toda troca de etapa tem hitstop, cancela as balas (viram pérolas) e dá 1 s sem balas novas.

enum State { ENTER, FIGHT, DUEL, DYING, DEAD }

const ENTER_FRAMES := 180
const DUEL_FRAMES := 240
const DYING_FRAMES := 120
const PHASE_QUIET := 60
const DUEL_PUSH := 0.0035
const DUEL_TAP := 0.05

var id: StringName
var def: Dictionary = {}
var is_final: bool = false
var hp: float = 1.0
var max_hp: float = 1.0
var pos := Vector2.ZERO
var home := Vector2.ZERO
var state: State = State.ENTER
var state_frames: int = 0
var frames: int = 0
var phase_index: int = -1
var phase_frames: int = 0
var parts: Array[Dictionary] = []
var desperate: bool = false
var flash: int = 0
## 0..1: o feixe do jogador avança no duelo; 1 vence antes do tempo.
var duel_power: float = 0.5
var bonus: int = 0
var _runners: Array[Dictionary] = []
var _patterns: Dictionary = {}
var _start := Vector2.ZERO


func setup(p_def: Dictionary, patterns: Dictionary) -> void:
	def = p_def
	id = StringName(String(def.get("id", "")))
	is_final = bool(def.get("duel", false))
	max_hp = float(def.get("hp", 1000.0))
	hp = max_hp
	_patterns = patterns
	home = Vector2(float(def.get("home_x", 135.0)), float(def.get("home_y", 110.0)))
	_start = Vector2(home.x, -float(def.get("enter_from", 120.0)))
	pos = _start
	for raw: Variant in def.get("parts", []):
		var p: Dictionary = (raw as Dictionary).duplicate(true)
		p["id"] = StringName(String(p.get("id", "")))
		p["base"] = Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
		p["offset"] = p["base"]
		p["max_hp"] = float(p.get("hp", 0.0))
		p["hp"] = p["max_hp"]
		p["alive"] = true
		p["flash"] = 0
		parts.append(p)


func phase() -> Dictionary:
	var phases: Array = def.get("phases", [])
	if phase_index < 0 or phase_index >= phases.size():
		return {}
	return phases[phase_index]


func phase_id() -> StringName:
	return StringName(String(phase().get("id", "")))


func fighting() -> bool:
	return state == State.FIGHT


func body_pos() -> Vector2:
	return pos + Vector2(float(def.get("body_x", 0.0)), float(def.get("body_y", 0.0)))


func body_radius() -> float:
	return float(def.get("body_radius", 30.0))


func part_pos(part: Dictionary) -> Vector2:
	return pos + (part["offset"] as Vector2)


## Parte que pode ser atingida agora (viva e ativa na etapa atual).
func part_active(part: Dictionary) -> bool:
	if not bool(part["alive"]):
		return false
	var only: Array = part.get("active_in", [])
	return only.is_empty() or String(phase_id()) in only


func step(sim: Sim) -> void:
	frames += 1
	state_frames += 1
	if flash > 0:
		flash -= 1
	match state:
		State.ENTER:
			var u := minf(1.0, float(state_frames) / ENTER_FRAMES)
			pos = _start.lerp(home, 1.0 - (1.0 - u) * (1.0 - u))
			if state_frames >= ENTER_FRAMES:
				_set_state(State.FIGHT)
				_enter_phase(0, sim)
		State.FIGHT:
			phase_frames += 1
			_move()
			var after := float(phase().get("desperation_after_s", 0.0))
			desperate = after > 0.0 and phase_frames > after * 60.0
			for r: Dictionary in _runners:
				var anchor := StringName(String(r["anchor"]))
				var origin := body_pos()
				var ok := true
				if anchor != &"body":
					var part := _part(anchor)
					ok = not part.is_empty() and part_active(part)
					if ok:
						origin = part_pos(part)
				if ok:
					(r["runner"] as PatternRunner).step(sim, origin, sim.can_fire())
		State.DUEL:
			duel_power = clampf(duel_power - DUEL_PUSH, 0.0, 1.0)
			if duel_power >= 1.0 or state_frames >= DUEL_FRAMES:
				sim.on_boss_defeated(self)
				_set_state(State.DYING)
		State.DYING:
			if state_frames >= DYING_FRAMES:
				_set_state(State.DEAD)
	for part: Dictionary in parts:
		if int(part["flash"]) > 0:
			part["flash"] = int(part["flash"]) - 1


func add_taps(count: int) -> void:
	if state == State.DUEL:
		duel_power = clampf(duel_power + DUEL_TAP * count, 0.0, 1.0)


## Dano no corpo (armadura da etapa reduz). Devolve o dano aplicado ao HP.
func damage_body(amount: float, sim: Sim) -> float:
	if state != State.FIGHT:
		return 0.0
	var applied := amount * float(phase().get("armor", 1.0))
	flash = 3
	_apply(applied, sim)
	return applied


## Dano numa parte: destrutível (tem HP; ao morrer tira `share` do HP total) ou ponto fraco
## (`weak` multiplica o dano no HP total).
func damage_part(part: Dictionary, amount: float, sim: Sim) -> void:
	if state != State.FIGHT or not part_active(part):
		return
	part["flash"] = 3
	var weak := float(part.get("weak", 0.0))
	if weak > 0.0:
		_apply(amount * weak, sim)
		return
	part["hp"] = float(part["hp"]) - amount
	_apply(amount * float(part.get("leak", 0.25)), sim)
	if float(part["hp"]) <= 0.0 and bool(part["alive"]):
		part["alive"] = false
		sim.on_boss_part_destroyed(self, part)
		_apply(float(part.get("share", 0.0)) * max_hp, sim)


func _apply(amount: float, sim: Sim) -> void:
	if state != State.FIGHT:
		return
	hp = maxf(0.0, hp - amount)
	var phases: Array = def.get("phases", [])
	var limit := float(phase().get("until_hp", 0.0)) * max_hp
	if hp > limit:
		return
	bonus += maxi(0, int((float(phase().get("par_s", 60.0)) * 60.0 - phase_frames) / 60.0 * 100.0))
	if phase_index + 1 < phases.size() and hp > 0.0:
		_enter_phase(phase_index + 1, sim)
		return
	hp = 0.0
	if is_final:
		_set_state(State.DUEL)
		sim.on_boss_duel_start(self)
	else:
		sim.on_boss_defeated(self)
		_set_state(State.DYING)


func _enter_phase(index: int, sim: Sim) -> void:
	phase_index = index
	phase_frames = 0
	desperate = false
	_runners.clear()
	var ph := phase()
	for raw: Variant in ph.get("patterns", []):
		var entry: Dictionary = raw
		var pattern_id := StringName(String(entry.get("pattern", "")))
		if _patterns.has(pattern_id):
			_runners.append({"anchor": String(entry.get("anchor", "body")),
					"runner": PatternRunner.new(_patterns[pattern_id], int(entry.get("delay", PHASE_QUIET)))})
	sim.on_boss_phase(self, ph, index > 0)


func _move() -> void:
	var t := frames * Sim.STEP
	var move: Dictionary = phase().get("move", {})
	var amp := float(move.get("amp", 20.0))
	var freq := float(move.get("freq", 0.12))
	pos = home + Vector2(amp * sin(t * freq * TAU), amp * 0.25 * sin(t * freq * 2.0 * TAU))
	for part: Dictionary in parts:
		var sway := float(part.get("sway", 0.0))
		if sway > 0.0:
			var f := float(part.get("freq", 0.3))
			var ph := float(part.get("phase", 0.0))
			part["offset"] = (part["base"] as Vector2) + Vector2(sway * sin((t * f + ph) * TAU),
					sway * 0.5 * cos((t * f * 1.3 + ph) * TAU))


func _part(part_id: StringName) -> Dictionary:
	for part: Dictionary in parts:
		if part["id"] == part_id:
			return part
	return {}


func _set_state(value: State) -> void:
	state = value
	state_frames = 0
