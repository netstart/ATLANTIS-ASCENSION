class_name SimObjectives
extends RefCounted
## Objetivos de fase (revisão 4 da Sim, SimRevision; plano mestre 5.6): 2 ou 3 metas curtas por missão, de 10 a 25 s,
## que aparecem no meio da fase com aviso, valem pontos, pérolas e oricalco e nunca reprovam a missão. Fora da Sim
## para ela caber no limite de linhas. O roteiro de cada missão vem de data/stages/<id>.json "objectives"
## (tools/gen_missions.py), por tempo de fase: o relógio da fase para com chefe na tela, então nenhum começa no meio
## de uma luta. Um de cada vez; o próximo espera o atual terminar.
##
## - rescue: a Jaula do Protocolo (no chão ou no fundo do mar; "pod": cápsula-prisão à deriva no céu e no espaço)
##   desce devagar levando atlantes. Destruída, solta `count` atlantes em bolhas que se espalham para os lados e sobem
##   para a superfície (vista de cima: descem devagar com o cenário, crescem e somem em SURVIVOR_LIFE): cada um que a
##   nave toca conta em `Sim.rescued` (objetivo "rescue" da missão, final e Cidade de Thalassa); o que sai do campo ou
##   chega à superfície antes se perde. Vale se salvar pelo menos metade. Se a jaula sair inteira do campo, falhou.
## - sabotage: `count` Faróis do Protocolo param no campo; derrubar todos antes de `seconds`. Senão chamam reforços:
##   a onda "reinforce" (a formação mais dura do capítulo) entra na hora.
## - intercept: um Mensageiro do Protocolo com uma relíquia roubada para no alto e foge pelo lado; abatido, solta a
##   relíquia, que voa até a nave (pontos extras).
##
## Replays de revisão anterior (e missões sem "objectives") ignoram tudo: `enabled` falso, nada muda no hash.
## Sorteios só no fluxo "objectives" da semente. A vista e o HUD só leem `current`, `survivors`, `relics`, `results`
## e os eventos (o tipo do objetivo vai em "kind"): &"objective_warn" {kind, total, pod}, &"objective_start"
## {kind, total}, &"objective_progress" {kind, done, total, pos}, &"objective_release" {pos, total},
## &"survivor" {pos, done, total}, &"survivor_lost" {pos}, &"relic" {pos},
## &"objective_end" {kind, ok, done, total, pos, released}, &"reinforcements" {}.

## Aviso antes de os alvos entrarem (1,5 s). O rádio do aviso fica no alto do campo exatamente esse tempo (Game
## usa WARN_FRAMES como duração dele): os alvos só entram quando ele já saiu da frente, em qualquer layout.
const WARN_FRAMES := 90
## Teto de segurança de um objetivo depois do aviso (alvo sumido por outro caminho): encerra como falha.
const MAX_FRAMES := 60 * 40
const SURVIVOR_RADIUS := 16.0
const SURVIVOR_LIFE := 60 * 12
const SURVIVOR_POINTS := 1000
## Relíquia: flutua um instante e voa até a nave, como as pérolas.
const RELIC_FLOAT := 24
const RELIC_SPEED := 220.0
const RELIC_RADIUS := 18.0
const RELIC_POINTS := 3000
const SUCCESS_POINTS := 5000
const SUCCESS_PEARLS := 12
const SUCCESS_ORICHALCUM := 2
## Resgate perfeito (todos salvos): oricalco extra.
const PERFECT_ORICHALCUM := 1
const TARGETS := {&"rescue": &"prison_barge", &"sabotage": &"protocol_beacon", &"intercept": &"relic_courier"}
const BEACON_X: Array[float] = [0.2, 0.5, 0.8]
const BEACON_Y: Array[float] = [110.0, 72.0, 130.0]

var enabled: bool = false
var schedule: Array = []
## Próximo item de `schedule`.
var next: int = 0
## Objetivo em curso (vazio = nenhum): type, total, done, frames (desde o aviso), limit (passos do prazo, -1 sem),
## spec (a entrada do roteiro), targets (SimEnemy), released (a jaula abriu), pos (último lugar do alvo).
var current: Dictionary = {}
## Atlantes soltos no campo: {pos, vel, frames, phase}.
var survivors: Array[Dictionary] = []
## Relíquias a caminho da nave: {pos, vel, frames}.
var relics: Array[Dictionary] = []
## Objetivos encerrados: {type, done, total, ok} (resultado da missão).
var results: Array[Dictionary] = []
## Oricalco ganho nos objetivos (somado ao da missão em Sim.result).
var orichalcum: int = 0


func setup(sim: Sim) -> void:
	enabled = SimRevision.of(sim.loadout) >= 4
	schedule = (sim.mission.get("objectives", []) as Array).duplicate(true) if enabled else []


## Um passo (logo depois do roteiro): atlantes e relíquias, começo do próximo objetivo e o andamento do atual.
func step(sim: Sim) -> void:
	if not enabled:
		return
	_survivors_step(sim)
	_relics_step(sim)
	if current.is_empty():
		if next < schedule.size() and sim.boss == null \
				and sim.stage.frame >= roundi(float((schedule[next] as Dictionary).get("t", 0.0)) * 60.0):
			_announce(sim, schedule[next])
			next += 1
		return
	current["frames"] = int(current["frames"]) + 1
	var frames := int(current["frames"])
	if frames == WARN_FRAMES:
		_spawn(sim)
	elif frames > WARN_FRAMES:
		_track(sim, frames - WARN_FRAMES)


## Abate de um inimigo (Sim._kill_enemy): conta se for alvo do objetivo em curso.
func on_kill(sim: Sim, e: SimEnemy) -> void:
	if e.objective == &"" or current.is_empty() or not e in (current["targets"] as Array):
		return
	current["pos"] = e.pos
	match e.objective:
		&"rescue":
			current["released"] = true
			var stream := sim.rng.stream(&"objectives")
			# Abatida ainda entrando: os atlantes saem já dentro do campo (senão se perderiam na hora).
			var from := Vector2(e.pos.x, maxf(e.pos.y, 12.0))
			for k: int in range(int(current["total"])):
				var spread := (k - (int(current["total"]) - 1) * 0.5) * 7.0
				survivors.append({"pos": from + Vector2(spread, stream.randf_range(-4.0, 4.0)),
						"vel": Vector2(spread * 2.6 + stream.randf_range(-8.0, 8.0), stream.randf_range(14.0, 22.0)),
						"frames": 0, "phase": stream.randf_range(0.0, TAU)})
			sim.emit(&"objective_release", {"pos": e.pos, "total": int(current["total"])})
		&"sabotage":
			current["done"] = int(current["done"]) + 1
			sim.emit(&"objective_progress", {"kind": e.objective, "done": current["done"], "total": current["total"],
					"pos": e.pos})
		&"intercept":
			current["done"] = 1
			relics.append({"pos": e.pos, "vel": Vector2(0, -20), "frames": 0})
			sim.emit(&"objective_progress", {"kind": e.objective, "done": 1, "total": 1, "pos": e.pos})


## Saída da fase (SimOutro): os atlantes e a relíquia no campo vêm até a nave e contam; o objetivo em curso fecha.
func abort(sim: Sim) -> void:
	if not enabled:
		return
	for s: Dictionary in survivors:
		_save(sim, s["pos"])
	survivors.clear()
	for r: Dictionary in relics:
		_relic(sim, r["pos"])
	relics.clear()
	if not current.is_empty():
		_end(sim, _ok(), false)


## Andamento para o HUD: {type, done, total, left (s do prazo, -1 sem), warn (ainda no aviso)}; vazio sem objetivo.
func progress() -> Dictionary:
	if current.is_empty():
		return {}
	var frames := int(current["frames"])
	var limit := int(current["limit"])
	var left := -1.0
	if limit > 0:
		left = clampf((limit - maxi(0, frames - WARN_FRAMES)) / 60.0, 0.0, limit / 60.0)
	return {"type": current["type"], "done": current["done"], "total": current["total"], "left": left,
			"limit": limit / 60.0, "warn": frames < WARN_FRAMES, "pod": bool((current["spec"] as Dictionary).get("pod",
			false)), "released": bool(current["released"])}


func _announce(sim: Sim, spec: Dictionary) -> void:
	var kind := StringName(String(spec.get("type", "")))
	if not TARGETS.has(kind):
		return
	var total := 1 if kind == &"intercept" else maxi(1, int(spec.get("count", 3)))
	if kind == &"sabotage":
		total = mini(total, BEACON_X.size())
	current = {"type": kind, "total": total, "done": 0, "frames": 0, "spec": spec, "targets": [], "released": false,
			"pos": Vector2(float(spec.get("x", 0.5)) * Playfield.FIELD.x, 0.0),
			"limit": roundi(float(spec.get("seconds", 14.0)) * 60.0) if kind == &"sabotage" else -1}
	sim.emit(&"objective_warn", {"kind": kind, "total": total, "pod": bool(spec.get("pod", false))})


func _spawn(sim: Sim) -> void:
	var spec: Dictionary = current["spec"]
	var kind: StringName = current["type"]
	var x := float(spec.get("x", 0.5))
	match kind:
		&"rescue":
			var enemy := "prison_pod" if bool(spec.get("pod", false)) else "prison_barge"
			_add(sim, kind, {"enemy": enemy, "x": x, "y": -26.0, "path": "sine", "params": {"amp": 16.0, "freq": 0.12,
					"speed": float(spec.get("speed", 30.0))}})
		&"sabotage":
			for k: int in range(int(current["total"])):
				_add(sim, kind, {"enemy": String(TARGETS[kind]), "x": BEACON_X[k], "y": -20.0 - 14.0 * k,
						"path": "stop_go", "params": {"speed": 60.0, "stop_y": BEACON_Y[k],
						"hold": float(spec.get("seconds", 14.0))}})
		&"intercept":
			_add(sim, kind, {"enemy": String(TARGETS[kind]), "x": x, "y": -20.0, "path": "stop_go",
					"params": {"speed": float(spec.get("speed", 80.0)), "stop_y": 78.0,
					"hold": float(spec.get("hold", 3.0)), "exit": "left" if x > 0.5 else "right"}})
	sim.emit(&"objective_start", {"kind": kind, "total": current["total"]})


func _add(sim: Sim, kind: StringName, spec: Dictionary) -> void:
	var before := sim.enemies.size()
	sim.spawn_enemy(spec, 0)
	if sim.enemies.size() > before:
		var e: SimEnemy = sim.enemies[-1]
		e.objective = kind
		(current["targets"] as Array).append(e)


func _track(sim: Sim, frames: int) -> void:
	var targets: Array = current["targets"]
	var gone := true
	for e: SimEnemy in targets:
		if e.alive:
			gone = false
			current["pos"] = e.pos
	match StringName(current["type"]):
		&"rescue":
			if bool(current["released"]):
				if survivors.is_empty():
					_end(sim, _ok(), false)
				return
			if gone:
				_end(sim, false, false)
				return
		&"sabotage":
			if int(current["done"]) >= int(current["total"]):
				_end(sim, true, false)
				return
			if frames >= int(current["limit"]):
				_end(sim, false, true)
				return
		&"intercept":
			if int(current["done"]) > 0:
				_end(sim, true, false)
				return
			if gone:
				_end(sim, false, false)
				return
	if frames >= MAX_FRAMES:
		_end(sim, false, false)


## Deu certo: no resgate, metade ou mais salvos; nos outros, todos os alvos abatidos.
func _ok() -> bool:
	if StringName(current["type"]) == &"rescue":
		return int(current["done"]) * 2 >= int(current["total"])
	return int(current["done"]) >= int(current["total"])


func _end(sim: Sim, ok: bool, reinforce: bool) -> void:
	var kind: StringName = current["type"]
	var done := int(current["done"])
	var total := int(current["total"])
	var at: Vector2 = current["pos"]
	var released := bool(current["released"])
	var wave: Dictionary = (current["spec"] as Dictionary).get("reinforce", {}) if reinforce else {}
	for e: SimEnemy in current["targets"] as Array:
		# Alvo que sobrou vira inimigo comum (o farol sai sozinho; abatê-lo depois não conta mais).
		e.objective = &""
	if ok:
		sim.scoring.add_bonus(roundi(SUCCESS_POINTS * sim.scoring.point_mult))
		orichalcum += SUCCESS_ORICHALCUM + (PERFECT_ORICHALCUM if kind == &"rescue" and done == total else 0)
		var ring := PackedVector2Array()
		for k: int in range(SUCCESS_PEARLS):
			ring.append(at + Vector2.from_angle(TAU * k / SUCCESS_PEARLS) * 14.0)
		sim.pearls_from(ring)
	results.append({"type": String(kind), "done": done, "total": total, "ok": ok})
	current = {}
	sim.emit(&"objective_end", {"kind": kind, "ok": ok, "done": done, "total": total, "pos": at, "released": released})
	if reinforce:
		for m: int in range(int(wave.get("count", 0))):
			sim.spawn_enemy(wave, m)
		sim.emit(&"reinforcements", {})


func _survivors_step(sim: Sim) -> void:
	var i := survivors.size() - 1
	while i >= 0:
		var s := survivors[i]
		var frames := int(s["frames"]) + 1
		s["frames"] = frames
		# Bolha subindo para a superfície: o empurrão da jaula se acalma e sobra o balanço lateral.
		var vel: Vector2 = s["vel"]
		vel.x *= 0.985
		s["vel"] = vel
		var p: Vector2 = s["pos"] + (vel + Vector2(sin(frames * 0.07 + float(s["phase"])) * 10.0, 0.0)) * Sim.STEP
		s["pos"] = p
		if _touches(sim, p, SURVIVOR_RADIUS):
			_save(sim, p)
			survivors.remove_at(i)
		elif frames > SURVIVOR_LIFE or not Rect2(Vector2.ZERO, sim.field).grow(10.0).has_point(p):
			survivors.remove_at(i)
			sim.emit(&"survivor_lost", {"pos": p})
		i -= 1


func _save(sim: Sim, at: Vector2) -> void:
	sim.rescued += 1
	if not current.is_empty():
		current["done"] = int(current["done"]) + 1
	sim.scoring.add_bonus(roundi(SURVIVOR_POINTS * sim.scoring.point_mult))
	sim.emit(&"survivor", {"pos": at, "done": int(current.get("done", 0)), "total": int(current.get("total", 0))})


func _relics_step(sim: Sim) -> void:
	var i := relics.size() - 1
	while i >= 0:
		var r := relics[i]
		var frames := int(r["frames"]) + 1
		r["frames"] = frames
		var p: Vector2 = r["pos"]
		if frames > RELIC_FLOAT and sim.player.alive:
			r["vel"] = (sim.player.pos - p).normalized() * RELIC_SPEED
		p += (r["vel"] as Vector2) * Sim.STEP
		r["pos"] = p
		if _touches(sim, p, RELIC_RADIUS):
			_relic(sim, p)
			relics.remove_at(i)
		i -= 1


func _relic(sim: Sim, at: Vector2) -> void:
	sim.scoring.add_bonus(roundi(RELIC_POINTS * sim.scoring.point_mult))
	sim.emit(&"relic", {"pos": at})


static func _touches(sim: Sim, p: Vector2, radius: float) -> bool:
	if sim.player.alive and p.distance_to(sim.player.pos) <= radius:
		return true
	return sim.wing != null and sim.wing.alive and p.distance_to(sim.wing.pos) <= radius
