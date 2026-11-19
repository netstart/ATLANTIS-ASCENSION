class_name SimOutro
extends RefCounted
## Saída da missão vencida (fora da Sim para ela caber no limite de linhas): quando o chefe que encerra a fase
## cai (ou, nas fases sem chefe no fim, quando a última onda some), o campo fica limpo de vez e a nave sai voando
## pelo topo. Só então a missão termina (`finished` e `cleared`), no lugar do antigo Sim.FINISH_DELAY.
##
## Limpeza (no fim do passo da morte, para não mexer nas listas no meio das colisões): inimigos restantes somem
## sem pontos e sem coletáveis, balas inimigas viram pérolas, balas do jogador, feixes, mísseis, perigos, escolta,
## poderes, especial, laser e Maré Alta acabam. Os coletáveis no campo (e as medalhas do chefe) vêm todos até a
## nave e contam como de costume; o que ainda faltar é recolhido quando ela some.
## Voo: a nave (e a ala no co-op) ignora a entrada, não leva dano (a Sim não colide mais nada) e não atira.
## Enquanto o chefe explode ela vai ao centro devagar; depois sobe com aceleração (ease-in com um recuo leve
## no começo) e sai por cima do campo, sem o keep_inside prender.
## Replays antigos (sem "outro" na carga, ver Replay.from_dict) seguem o fim antigo: `enabled` false.
##
## Eventos: &"outro" {} quando a limpeza começa (a vista apaga os efeitos que restarem) e &"outro_rise" {"pos"}
## quando a nave arranca.

## Passos de espera nas fases sem chefe no fim (coletáveis chegando) antes de arrancar.
const SETTLE_FRAMES := 30
## A nave arranca quando a explosão do chefe passa disto (de SimBoss.DYING_FRAMES).
const BOSS_WAIT := 96
const RISE_FRAMES := 54
## Fora do campo por inteiro: meia nave (24) mais a chama do motor.
const EXIT_Y := -56.0
const CENTER_EASE := 0.05
## Recuo antes da arrancada: progresso = t² · (1 + DIP) · t − t² · DIP (negativo bem no começo).
const DIP := 0.6
const PICKUP_SPEED := 300.0
const PICKUP_ACCEL := 14.0
const PICKUP_REACH := 10.0

var enabled: bool = true
## Passos desde o começo da saída (-1 = fora dela).
var frames: int = -1
## Passos de subida (-1 = ainda esperando).
var rise: int = -1
var _pending: bool = false
var _from := PackedVector2Array()


func setup(loadout: Dictionary) -> void:
	enabled = bool(loadout.get("outro", true))


func active() -> bool:
	return frames >= 0


## O chefe caiu: se nada mais nasce depois dele no roteiro, a saída começa no fim deste passo. O aviso à vista
## sai já, antes do &"boss_dead", para a explosão do chefe ficar e o resto dos efeitos sumir.
func on_boss_defeated(sim: Sim) -> void:
	if not enabled or active() or _pending or not _last_spawn(sim.stage):
		return
	_pending = true
	sim.emit(&"outro", {})


## Fim de passo (Sim._check_finish): começa a saída quando for a hora. Devolve se o fim novo vale aqui (o
## antigo, com FINISH_DELAY, só roda nos replays antigos).
func check(sim: Sim) -> bool:
	if not enabled:
		return false
	if not active() and (_pending or sim.stage.ended and sim.boss == null and sim.enemies.is_empty()):
		_begin(sim)
	return true


func _begin(sim: Sim) -> void:
	if not _pending:
		sim.emit(&"outro", {})
	_pending = false
	frames = 0
	for e: SimEnemy in sim.enemies:
		e.alive = false
	sim.enemies.clear()
	sim.pearls_from(sim.enemy_bullets.cancel_all())
	sim.player_bullets.clear()
	sim.beams.clear()
	sim.missiles.clear()
	sim.drones.clear()
	sim.covers.clear()
	sim.escorts.clear()
	sim.breach_frames = 0
	sim.breach_dir = Vector2.ZERO
	sim.gravity = Vector2.ZERO
	sim.drift_frames = 0
	sim.laser_active = false
	sim.special_frames = 0
	sim.special_kind = &""
	sim.tide_frames = 0
	sim.scoring.tide_mult = 1.0
	sim.no_fire = 0
	sim.powers.stop(sim)
	for ship: SimPlayer in _ships(sim):
		ship.invuln = 0


## Um passo da saída (no lugar do passo normal): explosão do chefe, coletáveis até a nave e o voo.
func step(sim: Sim) -> void:
	frames += 1
	sim.scroll += sim.scroll_speed * Sim.STEP
	if sim.boss != null:
		sim.boss.step(sim)
		if sim.boss.state == SimBoss.State.DEAD:
			sim.boss = null
	if rise < 0 and _ready_to_rise(sim):
		rise = 0
		_from.clear()
		for ship: SimPlayer in _ships(sim):
			_from.append(ship.pos)
		sim.emit(&"outro_rise", {"pos": sim.player.pos})
	var ships := _ships(sim)
	for k: int in range(ships.size()):
		_fly(sim, ships[k], k, ships.size())
	if rise >= 0:
		rise += 1
	_pull_pickups(sim)
	if rise >= RISE_FRAMES and sim.boss == null:
		for pk: Dictionary in sim.pickups:
			sim.collect(pk["kind"], int(pk["frames"]), sim.player)
		sim.pickups.clear()
		frames = -1
		sim.finished = true
		sim.cleared = true
		sim.emit(&"finished", {"cleared": true})


## Progresso da subida (0 a 1), com o recuo leve antes da arrancada.
static func rise_curve(t: float) -> float:
	return t * t * ((1.0 + DIP) * t - DIP)


func _ready_to_rise(sim: Sim) -> bool:
	if sim.boss != null:
		return sim.boss.state == SimBoss.State.DYING and sim.boss.state_frames >= BOSS_WAIT
	return frames >= SETTLE_FRAMES


func _fly(sim: Sim, ship: SimPlayer, index: int, count: int) -> void:
	var before := ship.pos
	var center := sim.field.x * 0.5 + (index - (count - 1) * 0.5) * Sim.COOP_OFFSET
	ship.pos.x += (center - ship.pos.x) * CENTER_EASE
	if rise >= 0:
		var from: Vector2 = _from[index]
		ship.pos.y = lerpf(from.y, EXIT_Y, rise_curve(minf(1.0, (rise + 1) / float(RISE_FRAMES))))
	ship.last_move = ship.pos - before


func _pull_pickups(sim: Sim) -> void:
	var speed := PICKUP_SPEED + PICKUP_ACCEL * frames
	var target := sim.player.pos
	var i := sim.pickups.size() - 1
	while i >= 0:
		var pk := sim.pickups[i]
		pk["frames"] = int(pk["frames"]) + 1
		var p: Vector2 = pk["pos"]
		if p.distance_to(target) <= speed * Sim.STEP + PICKUP_REACH:
			sim.collect(pk["kind"], int(pk["frames"]), sim.player)
			sim.pickups.remove_at(i)
		else:
			pk["pos"] = p + (target - p).normalized() * speed * Sim.STEP
		i -= 1


static func _ships(sim: Sim) -> Array[SimPlayer]:
	var out: Array[SimPlayer] = [sim.player]
	if sim.wing != null:
		out.append(sim.wing)
	return out


## Nada mais nasce no roteiro depois do evento atual (só sobram falas, música e o "end").
static func _last_spawn(stage: StageScript) -> bool:
	if stage.has_pending_spawns():
		return false
	for k: int in range(stage.index, stage.events.size()):
		if String((stage.events[k] as Dictionary).get("op", "")) in ["wave", "miniboss", "boss", "capsule", "log",
				"blessing", "module"]:
			return false
	return true
