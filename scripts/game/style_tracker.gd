class_name StyleTracker
extends RefCounted
## Ecos de Estilo (pesquisa em .ai/07-pesquisa-diversao-e-surpresa.md, seção 3.1): reconhece na hora a
## jogada bonita — corrente que sobe de degrau, raspões em série, abates à queima-roupa, medalha máxima,
## chuva de pérolas, chefe final vencido sem dano ou por um fio — e devolve frases curtas para o HUD.
## Só lê a Sim e os eventos dela (o tempo vem de `sim.frame`): não muda a partida, o hash nem o replay.
##
## Cada frase é {key, arg, tier}; tier 0 a 3 escolhe cor, tamanho, som e vibração (StyleCallouts).

## Degraus do multiplicador que merecem frase (o último é a corrente máxima).
const CHAIN_STEPS: Array[int] = [4, 8, 12, 16]
## Raspões na janela para a "Dança das balas".
const GRAZE_STREAK := 12
const GRAZE_WINDOW := 90
## Abates à queima-roupa na janela.
const BLANK_STREAK := 3
const BLANK_WINDOW := 90
## Pérolas na janela para a "Chuva de pérolas".
const PEARL_STREAK := 15
const PEARL_WINDOW := 60
## Intervalo mínimo entre duas frases do mesmo tipo (passos).
const COOLDOWN := 240

var _last_mult: int = 1
var _grazes: Array[int] = []
var _blanks: Array[int] = []
var _pearls: Array[int] = []
var _last: Dictionary = {}


## Uma vez por quadro, depois dos eventos: degraus da corrente.
func tick(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mult := sim.scoring.multiplier()
	if mult > _last_mult:
		for step: int in CHAIN_STEPS:
			if _last_mult < step and mult >= step:
				if step == CHAIN_STEPS[-1]:
					out.append({"key": "style.chain_max", "arg": step, "tier": 3})
				else:
					out.append({"key": "style.chain", "arg": step, "tier": CHAIN_STEPS.find(step)})
	_last_mult = mult
	# Vários degraus no mesmo quadro (bomba de pontos): só o mais alto aparece.
	if out.size() > 1:
		var top: Dictionary = out[-1]
		out.clear()
		out.append(top)
	return out


## Cada evento da Sim; devolve as frases que ele dispara.
func observe(ev: Dictionary, sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var now := sim.frame
	match StringName(ev.get("type", "")):
		&"graze":
			if _streak(_grazes, now, GRAZE_WINDOW, GRAZE_STREAK):
				_add(out, "style.graze_dance", 0, 1, now)
		&"kill":
			var at: Vector2 = ev.get("pos", Vector2.INF)
			if at.distance_to(sim.player.pos) <= Scoring.POINT_BLANK \
					and _streak(_blanks, now, BLANK_WINDOW, BLANK_STREAK):
				_add(out, "style.point_blank", 0, 1, now)
		&"pearl":
			if _streak(_pearls, now, PEARL_WINDOW, PEARL_STREAK):
				_add(out, "style.pearl_rain", 0, 1, now)
		&"medal":
			if int(ev.get("value", 0)) >= Scoring.MEDAL_VALUES[-1]:
				_add(out, "style.medal_max", 0, 2, now)
		&"boss_dead":
			if bool(ev.get("final", false)):
				if sim.scoring.hull_lost == 0:
					_add(out, "style.flawless", 0, 3, now)
				elif sim.player.hull == 1:
					_add(out, "style.close_call", 0, 3, now)
		&"player_hit":
			_grazes.clear()
			_blanks.clear()
	return out


## Registra o instante e diz se a série completou (e zera a série para não repetir no passo seguinte).
func _streak(list: Array[int], now: int, window: int, need: int) -> bool:
	list.append(now)
	while not list.is_empty() and now - list[0] > window:
		list.pop_front()
	if list.size() >= need:
		list.clear()
		return true
	return false


func _add(out: Array[Dictionary], key: String, arg: int, tier: int, now: int) -> void:
	if now - int(_last.get(key, -COOLDOWN)) < COOLDOWN:
		return
	_last[key] = now
	out.append({"key": key, "arg": arg, "tier": tier})
