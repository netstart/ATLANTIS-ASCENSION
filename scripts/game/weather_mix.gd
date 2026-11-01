class_name WeatherMix
extends RefCounted
## Regra pura da mistura do som do clima (1.13): o nível de cada camada de ambiente e o abafamento
## sob a água para o clima de agora. Sem autoloads, para os testes de regras
## (tests/weather_tests.gd); quem toca é scripts/game/weather_audio.gd.

const RAIN := "rubberduck_rain"
const STORM := "kindland_storm_bed"
const WIND := "rubberduck_wind"
const WATER := "rubberduck_water"
const DEEP := "isaiah658_underwater_pad"


## Níveis (0..1) de cada camada para o clima de agora.
static func levels_for(w: Weather) -> Dictionary:
	var out := {RAIN: 0.0, STORM: 0.0, WIND: 0.0, WATER: 0.0, DEEP: 0.0}
	var speed := w.wind.length()
	if w.medium == &"air":
		var rain := w.fx("rain")
		var storm := clampf((rain - 0.6) / 0.4, 0.0, 1.0)
		out[RAIN] = clampf(rain * 1.6, 0.0, 1.0) * (1.0 - storm)
		out[STORM] = storm
		out[WIND] = clampf(speed / 30.0 + w.turbulence * 0.15, 0.0, 1.0)
	elif w.medium == &"water":
		out[WATER] = clampf(speed / 22.0, 0.0, 1.0) * 0.85
		out[DEEP] = clampf(w.fx("haze") + w.fx("dim") * 1.5, 0.0, 1.0)
		# Tempestade na superfície: a chuva forte lá em cima chega abafada.
		out[STORM] = clampf(w.fx("flashes") / 8.0, 0.0, 1.0) * 0.6
	return out


## Abafamento da música e do ambiente (0..1).
static func muffle_for(w: Weather) -> float:
	if w.medium != &"water":
		return 0.0
	return clampf(0.3 + w.fx("haze") * 0.45 + w.fx("dim") * 0.6, 0.0, 0.9)
