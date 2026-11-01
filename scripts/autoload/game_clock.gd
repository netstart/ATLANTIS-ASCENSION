extends Node
## Tempo da partida em passo fixo de 1/60 s (plano mestre 10.3). Em 2x roda 2 passos de simulação
## por quadro; em 3x, 3. A mesma semente produz a mesma partida em qualquer velocidade, e projéteis
## não atravessam alvos por causa de passos maiores. 2x e 3x servem aos testes (`-- --speed=N`) e à
## acessibilidade em Brisa; não contam para placar.
##
## Origem: game_clock.gd do projeto hyakki (mesmo autor, MIT), sem a trava de compra.

signal ticked(dt: float)

const STEP := 1.0 / 60.0
const SPEEDS: Array[int] = [1, 2, 3]
## Teto de passos por quadro (por velocidade): o jogo nunca entra em espiral de lentidão.
const MAX_STEPS_PER_SPEED := 3

## Passos simulados desde reset(). O tempo de jogo deriva daqui (inteiro, sem erro acumulado).
var steps: int = 0
var speed: int = 1
var paused: bool = true
## Câmera lenta do golpe final (Game): menos passos por segundo real, a mesma partida passo a passo.
## Só muda quando os passos acontecem, nunca o que cada passo faz (o hash não muda).
var time_scale: float = 1.0
## Fração entre o último passo e o próximo; usada para interpolar o desenho.
var alpha: float = 0.0
var last_frame_steps: int = 0
var last_sim_ms: float = 0.0

var _accumulator: float = 0.0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):
			set_speed(int(arg.trim_prefix("--speed=")))


## Tempo de jogo em segundos.
func game_time() -> float:
	return steps * STEP


func reset() -> void:
	steps = 0
	_accumulator = 0.0
	alpha = 0.0
	time_scale = 1.0
	paused = false


func set_speed(value: int) -> void:
	speed = clampi(value, SPEEDS[0], SPEEDS[-1])


## Avança `count` passos na hora, sem esperar quadros (testes, replays e varrer missões).
func advance(count: int) -> void:
	for i: int in range(count):
		steps += 1
		ticked.emit(STEP)


func _process(delta: float) -> void:
	last_frame_steps = 0
	if paused:
		return
	_accumulator += minf(delta, 0.1) * speed * clampf(time_scale, 0.05, 1.0)
	var max_steps := speed * MAX_STEPS_PER_SPEED
	var start := Time.get_ticks_usec()
	while _accumulator >= STEP and last_frame_steps < max_steps:
		_accumulator -= STEP
		steps += 1
		last_frame_steps += 1
		ticked.emit(STEP)
		if paused:
			break
	if last_frame_steps >= max_steps:
		_accumulator = minf(_accumulator, STEP)
	alpha = clampf(_accumulator / STEP, 0.0, 1.0)
	last_sim_ms = (Time.get_ticks_usec() - start) / 1000.0
