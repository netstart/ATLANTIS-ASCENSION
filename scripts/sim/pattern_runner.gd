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

const MAX_OPS_PER_STEP := 32

var steps: Array = []
var loop: bool = true
var bullet: int = 1
var pc: int = 0
var wait: int = 0
var angle: float = 0.0
var done: bool = false
var _counters: Dictionary = {}


func _init(pattern: Dictionary = {}, delay_frames: int = 0) -> void:
	steps = pattern.get("steps", [])
	loop = bool(pattern.get("loop", true))
	bullet = BulletKinds.enemy_index(StringName(String(pattern.get("bullet", "orb_cyan_m"))))
	wait = delay_frames


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
				wait = maxi(0, int(s.get("frames", 1)) - 1)
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
	match StringName(String(s.get("op", ""))):
		&"ring":
			var base := float(s.get("offset_deg", 0.0)) + angle
			for k: int in range(count):
				sim.fire_enemy(origin, base + 360.0 * k / count, speed, kind, turn, accel)
		&"fan", &"aimed_fan":
			var center := to_player if s.get("op") == "aimed_fan" else float(s.get("angle_deg", 90.0)) + angle
			var spread := float(s.get("spread_deg", 30.0))
			for k: int in range(count):
				var u := 0.5 if count == 1 else float(k) / (count - 1)
				sim.fire_enemy(origin, center - spread * 0.5 + spread * u, speed, kind, turn, accel)
		&"aimed":
			sim.fire_enemy(origin, to_player + angle, speed, kind, turn, accel)
		&"line":
			var dir := float(s.get("angle_deg", 90.0)) + angle
			if bool(s.get("aim", false)):
				dir = to_player
			var step_speed := float(s.get("speed_step", 12.0)) * sim.bullet_speed_mult()
			for k: int in range(count):
				sim.fire_enemy(origin, dir, speed + step_speed * k, kind, turn, accel)
