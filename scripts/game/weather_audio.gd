class_name WeatherAudio
extends RefCounted
## Som do clima (1.13): mistura as camadas de ambiente pelo estado da Sim e toca o trovão atrasado
## pela distância do relâmpago (o som anda ~340 m/s; aqui, até 2,4 s no horizonte). Sob a água a
## música e o ambiente chegam abafados, mais ainda na água turva e funda; no vácuo não há som de
## vento nenhum (só a trilha). Só lê a Sim: nada aqui muda a partida.
##
## Camadas: chuva fina (rubberduck), base da tempestade (kindland, chuva forte), vento (rubberduck),
## água correndo (rubberduck) e o pad grave da água funda (isaiah658). Os laços saem de
## tools/cut_weather_audio.py com o mesmo RMS; o volume de cada camada fica aqui. A regra da mistura
## (sem autoloads, testada) fica em scripts/game/weather_mix.gd.

const RAIN := WeatherMix.RAIN
const STORM := WeatherMix.STORM
const WIND := WeatherMix.WIND
const WATER := WeatherMix.WATER
const DEEP := WeatherMix.DEEP
const THUNDERS: Array[String] = ["kindland_thunder_1", "kindland_thunder_2", "kindland_thunder_3"]
## Volume de cada camada no nível 1 (dB, sobre o barramento Ambience).
const DB := {RAIN: -8.0, STORM: -12.0, WIND: -16.0, WATER: -18.0, DEEP: -14.0}
## Atraso máximo do trovão (distância 1) e o volume perto e longe.
const THUNDER_DELAY := 2.4
const THUNDER_NEAR_DB := -2.0
const THUNDER_FAR_DB := -16.0
## Na pausa o ambiente fica neste nível.
const PAUSED_LEVEL := 0.35

var paused: bool = false
## Trovões a caminho: {t, distance, strike}.
var pending: Array[Dictionary] = []
var _count: int = 0


## Um quadro: níveis das camadas, abafamento e trovões que chegaram.
func update(w: Weather, delta: float) -> void:
	var levels := WeatherMix.levels_for(w)
	var k := PAUSED_LEVEL if paused else 1.0
	for id: String in levels:
		AudioManager.set_ambience(id, float(levels[id]) * k, float(DB[id]))
	AudioManager.set_muffle(WeatherMix.muffle_for(w))
	var i := pending.size() - 1
	while i >= 0:
		var t: Dictionary = pending[i]
		t["t"] = float(t["t"]) - delta
		if float(t["t"]) <= 0.0:
			_play(t)
			pending.remove_at(i)
		i -= 1


## Relâmpago visto: o trovão vem depois, pela distância (raio no campo: na hora).
func on_thunder(distance: float, strike: bool) -> void:
	pending.append({"t": 0.0 if strike else 0.12 + distance * THUNDER_DELAY, "distance": distance,
			"strike": strike})


## Fim da missão: o ambiente desce e os trovões a caminho não tocam.
func stop() -> void:
	pending.clear()
	AudioManager.stop_ambience()


func _play(t: Dictionary) -> void:
	_count += 1
	var distance := float(t["distance"])
	var db := lerpf(THUNDER_NEAR_DB, THUNDER_FAR_DB, distance)
	var pitch := lerpf(1.0, 0.72, distance)
	AudioManager.play(THUNDERS[_count % THUNDERS.size()], pitch, 0.04, db, AudioManager.AMBIENCE_BUS)
	if bool(t["strike"]) or distance < 0.4:
		Settings.vibrate(40 if bool(t["strike"]) else 20, 0.35, 0)
