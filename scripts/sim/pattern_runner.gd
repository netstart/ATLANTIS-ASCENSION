class_name PatternRunner
extends RefCounted
## Interpreta a DSL de padrões de tiro (plano mestre 10.5; padrões em data/patterns.json). Cada
## emissor (inimigo, parte de chefe) tem o seu runner. Sem código por padrão: o JSON descreve.
##
## Operações:
##   ring      {count, speed, offset_deg}           anel em volta do emissor
##   fan       {count, spread_deg, speed, angle_deg} leque numa direção (90 = para baixo)
##   aimed     {speed}                              uma bala no jogador
##   aimed_fan {count, spread_deg, speed}           leque centrado no jogador
##   line      {count, speed, speed_step, angle_deg} fila de balas na mesma direção, velocidades crescentes
##   beam      {warn_frames, frames, width}         feixe vertical; avisa antes de ferir
##   wait      {frames}
##   rotate    {deg}                                gira as próximas emissões (espirais)
##   repeat    {from, times}                        volta à operação `from` mais `times` vezes
## Campos comuns de emissão: bullet, turn (graus/s), accel (u/s²), ox, oy (deslocamento da origem).
##
## Boca (revisão 2 da Sim, SimRevision): cada bala nasce em origem + direção × `muzzle`, na borda do emissor, e não no
## centro dele. Sem isso, anéis, leques e espirais lentas saíam como um bolo de balas sobrepostas em cima do
## sprite até se espalharem. As vizinhas de uma mesma emissão nascem a pelo menos SPAWN_GAP × raio da bala uma
## da outra: o anel abre o raio se precisar; o leque estreito, cujo arco na boca é curto, abre também de lado,
## como uma boca larga (a bala do meio continua na direção exata, e as outras andam paralelas à rota que teriam,
## a poucas unidades); a fila (`line`) nasce escalonada ao longo da direção, em vez de empilhada no mesmo ponto à
## espera da diferença de velocidade. Replays de revisão 1 nascem no centro, como antes.

const MAX_OPS_PER_STEP := 32
## Fração do raio de colisão do emissor usada como boca (1 = a borda dele) e o teto em unidades (chefes
## grandes não jogam a bala para longe do casco).
const MUZZLE_FRAC := 1.0
const MUZZLE_MAX := 30.0
## Distância mínima entre balas vizinhas de uma emissão, em raios de colisão da bala (o desenho tem ≈ 1,7 × o
## raio, então 2,6 deixa as vizinhas quase encostadas, sem sobrepor; ver tests/sim_tests.gd _spawn_spread).
const SPAWN_GAP := 2.6

var steps: Array = []
var loop: bool = true
var bullet: int = 1
var pc: int = 0
var wait: int = 0
var angle: float = 0.0
var done: bool = false
## Raio da boca (ver muzzle_for); 0 = nasce no centro.
var muzzle: float = 0.0
var _counters: Dictionary = {}


func _init(pattern: Dictionary = {}, delay_frames: int = 0, emitter_radius: float = 0.0) -> void:
	steps = pattern.get("steps", [])
	loop = bool(pattern.get("loop", true))
	bullet = BulletKinds.enemy_index(StringName(String(pattern.get("bullet", "orb_cyan_m"))))
	wait = delay_frames
	muzzle = muzzle_for(emitter_radius)


## Boca de um emissor com este raio de colisão (inimigo, corpo ou parte do chefe).
static func muzzle_for(emitter_radius: float) -> float:
	return minf(MUZZLE_MAX, maxf(0.0, emitter_radius) * MUZZLE_FRAC)


## Um passo de simulação. `can_fire` falso (Ocean Shift, entrada do fundo) avança sem atirar.
func step(sim: Sim, origin: Vector2, can_fire: bool) -> void:
	if done or steps.is_empty():
		return
	if wait > 0:
		wait -= 1
		return
	var ops := 0
	while ops < MAX_OPS_PER_STEP:
		ops += 1
		if pc >= steps.size():
			if not loop:
				done = true
				return
			pc = 0
			_counters.clear()
		var s: Dictionary = steps[pc]
		pc += 1
		match StringName(String(s.get("op", ""))):
			&"wait":
				var frames := int(s.get("frames", 1))
				if SimRevision.of(sim.loadout) >= 3:
					frames = maxi(1, roundi(frames * SimCurve.wait_for(sim)))
				wait = maxi(0, frames - 1)
				return
			&"rotate":
				angle += float(s.get("deg", 0.0))
			&"repeat":
				var key := pc - 1
				var left := int(_counters.get(key, int(s.get("times", 1))))
				if left > 0:
					_counters[key] = left - 1
					pc = int(s.get("from", 0))
				else:
					_counters.erase(key)
			&"beam":
				if can_fire:
					sim.add_beam(origin + _offset(s), float(s.get("width", 16.0)), int(s.get("warn_frames", 30)),
							int(s.get("frames", 60)))
			_:
				if can_fire:
					_emit(sim, origin + _offset(s), s)


func _offset(s: Dictionary) -> Vector2:
	return Vector2(float(s.get("ox", 0.0)), float(s.get("oy", 0.0)))


func _emit(sim: Sim, origin: Vector2, s: Dictionary) -> void:
	var kind := bullet
	if s.has("bullet"):
		kind = BulletKinds.enemy_index(StringName(String(s["bullet"])))
	var speed := float(s.get("speed", 80.0)) * sim.bullet_speed_mult()
	var turn := deg_to_rad(float(s.get("turn", 0.0)))
	var accel := float(s.get("accel", 0.0))
	var count := maxi(1, int(s.get("count", 1)))
	var to_player := rad_to_deg((sim.player.pos - origin).angle())
	var rev2 := SimRevision.of(sim.loadout) >= 2
	var mz := muzzle if rev2 else 0.0
	var gap := BulletKinds.enemy_radius(kind) * SPAWN_GAP if rev2 else 0.0
	match StringName(String(s.get("op", ""))):
		&"ring":
			var base := float(s.get("offset_deg", 0.0)) + angle
			# Corda entre vizinhas = 2 r sen(π/n): abre o raio até a corda caber `gap`.
			var r := mz
			if rev2 and count > 1:
				r = maxf(mz, gap / (2.0 * sin(PI / count)))
			for k: int in range(count):
				_fire(sim, origin, r, base + 360.0 * k / count, speed, kind, turn, accel)
		&"fan", &"aimed_fan":
			var center := to_player if s.get("op") == "aimed_fan" else float(s.get("angle_deg", 90.0)) + angle
			var spread := float(s.get("spread_deg", 30.0))
			# Arco entre vizinhas na boca = mz × passo; o que faltar até `gap` vira afastamento de lado.
			var side := 0.0
			if rev2 and count > 1:
				side = maxf(0.0, gap - mz * deg_to_rad(spread / (count - 1)))
			# Para o lado em que o ângulo cresce (o mesmo do arco), senão um desconta o outro.
			var perp := Vector2.from_angle(deg_to_rad(center + 90.0))
			for k: int in range(count):
				var u := 0.5 if count == 1 else float(k) / (count - 1)
				var o := origin + perp * (side * (k - (count - 1) * 0.5))
				_fire(sim, o, mz, center - spread * 0.5 + spread * u, speed, kind, turn, accel)
		&"aimed":
			_fire(sim, origin, mz, to_player + angle, speed, kind, turn, accel)
		&"line":
			var dir := float(s.get("angle_deg", 90.0)) + angle
			if bool(s.get("aim", false)):
				dir = to_player
			var step_speed := float(s.get("speed_step", 12.0)) * sim.bullet_speed_mult()
			for k: int in range(count):
				_fire(sim, origin, mz + gap * k, dir, speed + step_speed * k, kind, turn, accel)


## Uma bala a `dist` da origem na direção em que sai (revisão 1: dist 0, no centro).
func _fire(sim: Sim, origin: Vector2, dist: float, angle_deg: float, speed: float, kind: int, turn: float,
		accel: float) -> void:
	var p := origin
	if dist > 0.0:
		p += Vector2.from_angle(deg_to_rad(angle_deg)) * dist
	sim.fire_enemy(p, angle_deg, speed, kind, turn, accel)
