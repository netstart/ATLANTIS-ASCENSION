extends RefCounted
## Clima e mar (1.13 "Céu e Mar Vivos", scripts/sim/weather.gd). Regras puras em run_unit() (chamado por
## tests/run_tests.gd, sem autoloads): tabela, coerência do clima com o cenário, aviso das frentes,
## mistura, vento e corrente, turbulência, resistência do meio, empurrão nas balas, maestria e as
## camadas de som. A tela fica em tests/weather_view_tests.gd.

const MEDIA: Array[StringName] = [&"air", &"water", &"void"]
## Limites de pilotagem (a nave sempre responde; o desafio cresce, nunca trava).
const MAX_WIND := 35.0
const MAX_TURBULENCE := 2.0
const MIN_DRAG := 0.85
const MAX_PUSH := 0.4
const MAX_FLASHES := 12
## Aviso mínimo (s) das frentes severas (docs/policies/qualidade.md: nada sem aviso).
const SEVERE_WARN := 3.0


func run_unit(check: Callable) -> void:
	var tables := Sim.load_tables()
	_table(check, tables["weather"])
	_missions(check, tables["weather"])
	_front(check, tables)
	_forces(check, tables)
	_turbulence(check, tables)
	_resist(check)
	_mastery(check, tables)
	_neutral(check, tables)
	_audio(check, tables)


func _table(check: Callable, table: Dictionary) -> void:
	check.call(table.size() >= 19, "Clima: %d estados na tabela" % table.size())
	for medium: StringName in MEDIA:
		var id: StringName = Weather.DEFAULT_OF[medium]
		var row: Dictionary = table.get(id, {})
		check.call(not row.is_empty() and float(row["wind"]) == 0.0 and float(row["turbulence"]) == 0.0
				and float(row["drag"]) == 1.0, "Clima: o padrão de %s (%s) não mexe na nave" % [medium, id])
	for id: StringName in table:
		var row: Dictionary = table[id]
		var tag := "Clima %s" % id
		check.call(StringName(String(row.get("medium", ""))) in MEDIA, "%s: meio válido" % tag)
		check.call(String(row.get("name_key", "")) == "weather." + String(id), "%s: nome traduzível" % tag)
		check.call(float(row.get("wind", 0.0)) <= MAX_WIND, "%s: vento até %d" % [tag, MAX_WIND])
		check.call(float(row.get("turbulence", 0.0)) <= MAX_TURBULENCE, "%s: turbulência limitada" % tag)
		check.call(float(row.get("drag", 1.0)) >= MIN_DRAG and float(row.get("drag", 1.0)) <= 1.0,
				"%s: resistência entre %.2f e 1" % [tag, MIN_DRAG])
		check.call(float(row.get("push", 0.0)) <= MAX_PUSH, "%s: empurrão nas balas limitado" % tag)
		check.call(float(row.get("period", 10.0)) >= 4.0, "%s: a corrente muda devagar (período ≥ 4 s)" % tag)
		var fx: Dictionary = row.get("fx", {})
		check.call(fx.has("grade") and Color.html_is_valid(String(fx["grade"])), "%s: cor da água ou do céu" % tag)
		for key: String in fx:
			if key in ["grade", "haze_color"]:
				continue
			if key == "flashes":
				# Relâmpagos por minuto, longe uns dos outros (fotossensibilidade).
				check.call(float(fx[key]) <= MAX_FLASHES, "%s: até %d relâmpagos por minuto" % [tag, MAX_FLASHES])
				continue
			var v := float(fx[key])
			check.call(v >= -0.2 and v <= 2.0, "%s: efeito %s em faixa sã (%.2f)" % [tag, key, v])
		if bool(row.get("severe", false)):
			check.call(float(row["wind"]) > 0.0 or float(row["turbulence"]) > 0.0 or float(row["drag"]) < 1.0,
					"%s: severo mexe na pilotagem" % tag)


## Todo clima de missão existe, é do meio do cenário e toda frente severa vem com aviso.
func _missions(check: Callable, table: Dictionary) -> void:
	var with_weather := 0
	var media_seen := {}
	for id: StringName in SimTestsIds.ids():
		var m := Sim.load_mission(id)
		var medium: StringName = Weather.MEDIUM_OF.get(StringName(String(m.get("backdrop", ""))), &"")
		check.call(medium != &"", "Clima %s: cenário com meio conhecido" % id)
		var states: Array[String] = []
		if m.has("weather"):
			states.append(String(m["weather"]))
		var fronts := 0
		for ev: Dictionary in m.get("events", []):
			if String(ev.get("op", "")) != "weather":
				continue
			fronts += 1
			var to := String(ev.get("to", ""))
			states.append(to)
			var row: Dictionary = table.get(StringName(to), {})
			if bool(row.get("severe", false)):
				check.call(float(ev.get("warn", 0.0)) >= SEVERE_WARN,
						"Clima %s: %s severo avisa %.0f s antes" % [id, to, SEVERE_WARN])
			check.call(float(ev.get("ramp", 0.0)) >= 3.0, "Clima %s: %s entra aos poucos" % [id, to])
		for s: String in states:
			var row: Dictionary = table.get(StringName(s), {})
			check.call(not row.is_empty() and StringName(String(row["medium"])) == medium,
					"Clima %s: %s combina com o cenário (%s)" % [id, s, medium])
			media_seen[medium] = true
		if fronts > 0:
			with_weather += 1
	check.call(with_weather >= 30, "Clima: %d missões com frentes" % with_weather)
	check.call(media_seen.size() == 3, "Clima: há frentes no céu, no mar e na órbita")


func _sim(tables: Dictionary, backdrop: String, weather: String = "") -> Sim:
	var m := {"id": "teste", "backdrop": backdrop, "events": [], "length_s": 600.0}
	if not weather.is_empty():
		m["weather"] = weather
	var sim := Sim.new()
	sim.setup(m, tables, &"falcon", 7)
	return sim


## Aviso, mistura e troca de rótulo; estado errado para o meio cai no padrão.
func _front(check: Callable, tables: Dictionary) -> void:
	var sim := _sim(tables, "storm")
	check.call(sim.weather.medium == &"air" and sim.weather.state == &"clear", "Clima: céu começa limpo")
	check.call(sim.weather.valid(&"surge") == &"clear", "Clima: corrente do mar não entra no céu")
	sim.weather.start(sim, {"to": "storm", "warn": 1.0, "ramp": 2.0})
	var announced := sim.take_events().filter(func(e: Dictionary) -> bool: return e["type"] == &"weather")
	check.call(announced.size() == 1 and bool(announced[0]["severe"]), "Clima: frente anunciada como severa")
	var idle := SimInput.new()
	idle.fire = false
	for i: int in range(59):
		sim.step(idle)
	check.call(sim.weather.state == &"clear" and sim.weather.wind == Vector2.ZERO,
			"Clima: nada muda durante o aviso")
	sim.step(idle)
	sim.step(idle)
	check.call(sim.weather.state == &"storm" and sim.weather.blend > 0.0 and sim.weather.blend < 0.05,
			"Clima: a frente começa a entrar depois do aviso (%.3f)" % sim.weather.blend)
	check.call(sim.weather.label() == &"clear", "Clima: o nome troca só na metade da entrada")
	for i: int in range(120):
		sim.step(idle)
	check.call(is_equal_approx(sim.weather.blend, 1.0) and sim.weather.label() == &"storm",
			"Clima: a frente entra inteira em 2 s")
	check.call(sim.weather.severe(), "Clima: tempestade é severa")


## Vento ou corrente com rajada e direção que oscila; empurrão nas balas.
func _forces(check: Callable, tables: Dictionary) -> void:
	var sim := _sim(tables, "ocean", "surge")
	var row: Dictionary = tables["weather"][&"surge"]
	var strength := float(row["wind"])
	var top := strength * (1.0 + float(row["gust"]))
	var angles: Array[float] = []
	var idle := SimInput.new()
	idle.fire = false
	var max_len := 0.0
	for i: int in range(60 * 12):
		sim.step(idle)
		max_len = maxf(max_len, sim.weather.wind.length())
		if i % 60 == 0:
			angles.append(sim.weather.wind.angle())
	check.call(max_len <= top + 0.01, "Corrente: rajada até %.0f (%.1f)" % [top, max_len])
	var spread: float = angles.max() - angles.min()
	check.call(spread > 0.8, "Corrente: a direção muda com o tempo (%.2f rad)" % spread)
	check.call(sim.weather.bullet_accel().is_equal_approx(sim.weather.wind * float(row["push"])),
			"Corrente: as balas recebem a fração do vento")
	var a := _sim(tables, "ocean", "surge")
	var b := _sim(tables, "ocean", "surge")
	for i: int in range(300):
		a.step(idle)
		b.step(idle)
	check.call(a.state_hash() == b.state_hash() and a.weather.wind == b.weather.wind,
			"Corrente: mesma semente, mesma corrente")
	var drifted := _sim(tables, "storm", "jetstream")
	var start := drifted.player.pos
	for i: int in range(60):
		drifted.step(idle)
	check.call(absf(drifted.player.pos.x - start.x) > 8.0, "Corrente de jato: a nave parada é levada de lado")


## Turbulência limitada (média zero) e cortada pela metade no modo preciso.
func _turbulence(check: Callable, tables: Dictionary) -> void:
	var calm := _sim(tables, "storm", "eye")
	var rough := _sim(tables, "storm", "storm")
	var precise := _sim(tables, "storm", "storm")
	var row: Dictionary = tables["weather"][&"storm"]
	var amp := float(row["turbulence"])
	var idle := SimInput.new()
	idle.fire = false
	var steady := SimInput.new()
	steady.fire = false
	steady.precise = true
	var peak := 0.0
	var peak_precise := 0.0
	for i: int in range(600):
		rough.step(idle)
		precise.step(steady)
		calm.step(idle)
		peak = maxf(peak, rough.weather.shake.length())
		peak_precise = maxf(peak_precise, precise.weather.shake.length())
	# O alvo é (x, 0,6·y) vezes a amplitude, com |x|, |y| ≤ 1: no máximo √1,36 ≈ 1,17 da amplitude.
	check.call(peak > 0.3 and peak <= amp * 1.17, "Turbulência: balança até %.1f (%.2f)" % [amp, peak])
	check.call(peak_precise <= peak * Weather.TURB_PRECISE + 0.05, "Turbulência: modo preciso segura o manche (%.2f)"
			% peak_precise)
	check.call(calm.weather.shake.length() < 0.25, "Turbulência: quase nada no olho da tempestade")


## A resistência do meio age no mesmo passo (latência de 1 passo mantida), só encurta o passo.
func _resist(check: Callable) -> void:
	var p := SimPlayer.new()
	p.setup({"speed": 1.0}, 1.0)
	var input := SimInput.new()
	input.axis = Vector2(1, 0)
	var x0 := p.pos.x
	p.move(input)
	var free := p.pos.x - x0
	p.resist = 0.9
	x0 = p.pos.x
	p.move(input)
	check.call(is_equal_approx(p.pos.x - x0, free * 0.9), "Resistência: 90%% do passo, no mesmo passo (%.2f)"
			% (p.pos.x - x0))


## Atravessar a frente severa sem dano dá o bônus; com dano, não.
func _mastery(check: Callable, tables: Dictionary) -> void:
	for hurt: bool in [false, true]:
		var sim := _sim(tables, "storm")
		sim.player.invuln = 100000
		var idle := SimInput.new()
		idle.fire = false
		sim.weather.start(sim, {"to": "storm", "warn": 0.0, "ramp": 1.0})
		for i: int in range(60 * 10):
			sim.step(idle)
		if hurt:
			sim.scoring.hull_lost += 1
		var before := sim.scoring.score
		sim.weather.start(sim, {"to": "clear", "warn": 0.0, "ramp": 1.0})
		var got := false
		for i: int in range(90):
			sim.step(idle)
			for ev: Dictionary in sim.take_events():
				got = got or ev["type"] == &"weather_mastered"
		if hurt:
			check.call(not got and sim.weather.mastered == 0, "Maestria: com dano não há bônus")
		else:
			check.call(got and sim.weather.mastered == 1 and sim.scoring.score > before,
					"Maestria: tempestade atravessada sem dano dá bônus (+%d)" % (sim.scoring.score - before))


## Missão sem clima (replays antigos): nada muda na nave nem nas balas.
func _neutral(check: Callable, tables: Dictionary) -> void:
	for backdrop: String in ["ocean", "storm", "orbit"]:
		var sim := _sim(tables, backdrop)
		var idle := SimInput.new()
		idle.fire = false
		var still := true
		for i: int in range(300):
			sim.step(idle)
			still = still and sim.weather.wind == Vector2.ZERO and sim.weather.shake == Vector2.ZERO \
					and sim.player.resist == 1.0 and sim.weather.bullet_accel() == Vector2.ZERO
		check.call(still and sim.player.pos == SimPlayer.START, "Clima: %s sem clima não mexe em nada" % backdrop)


## Som: no vácuo nada de vento; tempestade no céu toca a base da chuva forte; sob a água a música abafa.
func _audio(check: Callable, tables: Dictionary) -> void:
	var orbit := _sim(tables, "orbit", "solar")
	var silent := true
	for v: Variant in WeatherMix.levels_for(orbit.weather).values():
		silent = silent and float(v) == 0.0
	check.call(silent and WeatherMix.muffle_for(orbit.weather) == 0.0, "Som: no vácuo não há vento nem chuva")
	var storm := _sim(tables, "storm", "storm")
	var levels := WeatherMix.levels_for(storm.weather)
	check.call(float(levels[WeatherMix.STORM]) == 1.0 and float(levels[WeatherMix.RAIN]) == 0.0,
			"Som: tempestade troca a chuva fina pela forte")
	check.call(float(levels[WeatherMix.WIND]) > 0.3, "Som: vento na tempestade")
	var silt := _sim(tables, "ocean", "silt")
	var calm := _sim(tables, "ocean")
	check.call(WeatherMix.muffle_for(silt.weather) > WeatherMix.muffle_for(calm.weather)
			and WeatherMix.muffle_for(calm.weather) > 0.0, "Som: sob a água abafa, mais ainda no sedimento")
	check.call(float(WeatherMix.levels_for(silt.weather)[WeatherMix.DEEP]) > 0.5, "Som: pad grave na água turva")


## Ids das missões (o mesmo de tests/sim_tests.gd, sem depender dele).
class SimTestsIds:
	static func ids() -> Array[StringName]:
		var out: Array[StringName] = []
		for file: String in DirAccess.get_files_at("res://data/stages"):
			if file.ends_with(".json"):
				out.append(StringName(file.get_basename()))
		out.sort()
		return out
