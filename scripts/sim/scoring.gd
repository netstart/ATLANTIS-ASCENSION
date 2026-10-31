class_name Scoring
extends RefCounted
## Pontuação (plano mestre 4.4): Corrente de Maré, medalhas de oricalco, graze, queima-roupa,
## pérolas e o medidor de Pressão. Regras puras, sem nós.

const CHAIN_WINDOW := 48
const CHAIN_PER_MULT := 8
const MAX_MULT := 16
const MEDAL_VALUES: Array[int] = [100, 200, 500, 1000, 2000, 5000, 10000]
const GRAZE_POINTS := 10
const PEARL_BASE := 10
const POINT_BLANK := 40.0
const POINT_BLANK_BONUS := 1.5
const PRESSURE_MAX := 100.0

var score: int = 0
var chain: int = 0
var max_chain: int = 0
var chain_timer: int = 0
var medal_index: int = 0
var medals: int = 0
var max_medal: int = 0
var grazes: int = 0
var pearls: int = 0
var kills: int = 0
var marked_total: int = 0
var marked_killed: int = 0
var pressure: float = 0.0
var bombs_used: int = 0
var hull_lost: int = 0
## Janela da corrente (passos): bênção do Velho Marinheiro aumenta.
var window: int = CHAIN_WINDOW
## Corrente mínima depois de quebrar (sinergia de Nereu começa em x2).
var base_chain: int = 0
## Multiplicador da dificuldade e da rota de Abismo; a Maré Alta soma tide_mult.
var point_mult: float = 1.0
var tide_mult: float = 1.0


func multiplier() -> int:
	return mini(MAX_MULT, 1 + floori(chain / float(CHAIN_PER_MULT)))


func tick() -> void:
	if chain_timer > 0:
		chain_timer -= 1
		if chain_timer == 0:
			chain = base_chain


## Abate: soma corrente e pontos. Devolve os pontos dados.
func on_kill(base_points: int, distance_to_player: float, marked: bool) -> int:
	chain += 1
	max_chain = maxi(max_chain, chain)
	chain_timer = window
	kills += 1
	if marked:
		marked_killed += 1
	var gained := int(base_points * multiplier() * point_mult * tide_mult)
	if distance_to_player <= POINT_BLANK:
		gained = int(gained * POINT_BLANK_BONUS)
		add_pressure(3.0)
	score += gained
	return gained


func on_graze() -> void:
	grazes += 1
	score += int(GRAZE_POINTS * point_mult)
	add_pressure(1.0)


## Medalha coletada: vale o degrau atual e sobe um degrau.
func on_medal() -> int:
	var value: int = MEDAL_VALUES[medal_index]
	score += int(value * point_mult)
	medals += 1
	max_medal = maxi(max_medal, value)
	medal_index = mini(medal_index + 1, MEDAL_VALUES.size() - 1)
	return value


## Medalha perdida (saiu da tela): volta ao primeiro degrau.
func on_medal_missed() -> void:
	medal_index = 0


func on_pearl() -> int:
	var value := int(PEARL_BASE * multiplier() * point_mult * tide_mult)
	pearls += 1
	score += value
	return value


func add_pressure(amount: float) -> void:
	pressure = minf(PRESSURE_MAX, pressure + amount)


## Dano ou bomba quebram a corrente.
func break_chain() -> void:
	chain = base_chain
	chain_timer = 0


func add_bonus(points: int) -> void:
	score += points
