class_name Modes
extends RefCounted
## Modos além da campanha (plano mestre 4.11), em regras puras: quando cada um abre e como montar as
## missões. Nada é escrito à mão aqui: o Desafio Diário e a Sobrevivência remixam ondas das missões
## autorais por semente (a mesma semente dá o mesmo roteiro em qualquer aparelho); Arcade e Boss Rush
## são sequências (uma "corrida" que o App joga em fila, somando a pontuação).

## Modo, condição de abertura (missões das quais basta UMA concluída; vazio = sempre) e se paga recompensas.
const MODES: Array[Dictionary] = [
	{"id": &"arcade", "after_all": [&"c2m3"], "rewards": true},
	{"id": &"daily", "after_all": [&"c2m1"], "rewards": true},
	{"id": &"survival", "after_all": [&"c4m1"], "rewards": true},
	{"id": &"boss_rush", "after_all": [&"c2m3", &"c5m3s|c5m3a", &"c7m3s|c7m3a", &"c9m3"], "rewards": true},
	{"id": &"practice", "after_all": [&"c1m1"], "rewards": false},
]
## Arcade: um trecho de cada capítulo em sequência, sem hangar.
const ARCADE: Array[StringName] = [&"c1m1", &"c2m3", &"c3m2", &"c4m2", &"c5m3s", &"c6m2", &"c7m3s", &"c8m2", &"c9m3"]
const BOSS_RUSH: Array[StringName] = [&"tidebreaker", &"kraken_engine", &"coral_guardian", &"storm_eye", &"forge",
		&"architect", &"sky_leviathan", &"ice_queen", &"steel_albatross", &"poseidon_prime", &"orbital_gate",
		&"leviathan_protocol"]
## Chefes de ato (duelo no fim) no Boss Rush.
const ACT_BOSSES: Array[StringName] = [&"kraken_engine", &"sky_leviathan", &"poseidon_prime", &"leviathan_protocol"]
const DAILY_SECONDS := 150.0
const SURVIVAL_STAGE_SECONDS := 40.0
const SURVIVAL_STAGES := 15
const BACKDROPS: Array[String] = ["ocean", "atlantis", "storm", "volcanic", "city", "ice", "stratosphere", "orbit",
		"core"]


static func unlocked(profile: Dictionary, mode: StringName) -> bool:
	for m: Dictionary in MODES:
		if m["id"] != mode:
			continue
		for need: Variant in m["after_all"]:
			var any := false
			for option: String in String(need).split("|"):
				any = any or Economy.cleared(profile, StringName(option))
			if not any:
				return false
		return true
	return false


static func pays_rewards(mode: StringName) -> bool:
	for m: Dictionary in MODES:
		if m["id"] == mode:
			return bool(m["rewards"])
	return true


## Semente estável de uma data "AAAA-MM-DD" (igual para todos os jogadores no mesmo dia).
static func date_seed(date: String) -> int:
	var h := 2166136261
	for i: int in range(date.length()):
		h = ((h ^ date.unicode_at(i)) * 16777619) & 0x7fffffff
	return h


## Ondas de uma missão autoral, com os tempos relativos ao começo da primeira onda.
static func waves_of(mission: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Variant in mission.get("events", []):
		var e := ev as Dictionary
		if String(e.get("op", "")) == "wave" and String(e.get("enemy", "")) != "glyph":
			out.append(e)
	return out


## Roteiro remixado: ondas sorteadas dos capítulos dados, uma a cada `gap` s, com bênção, cápsulas e,
## no meio, um mini-chefe. Determinístico pela semente.
static func remix(id: String, chapters: Array, seed: int, seconds: float, gap: float,
		miniboss: StringName) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool: Array[Dictionary] = []
	for ch: Variant in chapters:
		for n: Dictionary in Economy.CAMPAIGN:
			if int(n["chapter"]) == int(ch) and n["kind"] != &"secret":
				pool.append_array(waves_of(_load(n["id"])))
	var events: Array = []
	var t := 1.0
	var half_done := false
	while t < seconds and not pool.is_empty():
		var w := (pool[rng.randi_range(0, pool.size() - 1)] as Dictionary).duplicate(true)
		w["t"] = snappedf(t, 0.01)
		events.append(w)
		t += gap * rng.randf_range(0.8, 1.2)
		if not half_done and t > seconds * 0.5:
			half_done = true
			events.append({"op": "blessing", "t": snappedf(t, 0.01)})
			events.append({"op": "capsule", "x": 0.3, "t": snappedf(t + 3.0, 0.01)})
			if miniboss != &"":
				events.append({"op": "miniboss", "id": String(miniboss), "t": snappedf(t + 4.0, 0.01)})
			t += 6.0
	events.append({"op": "end", "t": snappedf(t + 2.0, 0.01)})
	var first := int(chapters[0]) if not chapters.is_empty() else 1
	return {"id": id, "chapter": first, "name_key": "mode." + id.get_slice(":", 0), "music": "hydrogene_space_shooter",
			"scroll_speed": 24, "backdrop": BACKDROPS[clampi(first - 1, 0, BACKDROPS.size() - 1)], "seed_salt": seed % 9973,
			"objective": {"type": "score", "count": 50000, "text_key": "objective.score"}, "length_s": t, "events": events}


## Desafio Diário: capítulo, ritmo e mini-chefe sorteados pela data, entre os capítulos já abertos.
static func daily(date: String, max_chapter: int) -> Dictionary:
	var seed := date_seed(date)
	var ch := 1 + seed % maxi(1, mini(max_chapter, 9))
	var minis: Array[StringName] = [&"tidebreaker", &"coral_guardian", &"storm_eye", &"forge", &"architect",
			&"ice_queen", &"steel_albatross", &"orbital_gate", &"orbital_gate"]
	var m := remix("daily:" + date, [ch, mini(9, ch + 1)], seed, DAILY_SECONDS, 3.4, minis[ch - 1])
	m["daily"] = date
	return m


## Sobrevivência das Marés: estágios de 40 s cada vez mais densos, do capítulo 1 ao 9, com bênção a cada
## estágio. Termina ao cair (ou ao vencer o último estágio).
static func survival(seed: int) -> Dictionary:
	var events: Array = []
	var t := 0.0
	for stage: int in range(SURVIVAL_STAGES):
		var ch := 1 + mini(8, floori(stage * 9.0 / SURVIVAL_STAGES))
		var part := remix("survival", [ch], seed + stage * 7919, SURVIVAL_STAGE_SECONDS, maxf(1.6, 3.6 - stage * 0.14),
				&"")
		for ev: Variant in part["events"]:
			var e := (ev as Dictionary).duplicate(true)
			if String(e.get("op", "")) == "end":
				continue
			e["t"] = snappedf(float(e["t"]) + t, 0.01)
			events.append(e)
		t += SURVIVAL_STAGE_SECONDS
		events.append({"op": "blessing", "t": snappedf(t, 0.01)})
		t += 3.0
	events.append({"op": "end", "t": t + 2.0})
	return {"id": "survival", "chapter": 1, "name_key": "mode.survival", "music": "hydrogene_space_shooter",
			"scroll_speed": 26, "backdrop": "storm", "seed_salt": seed % 9973, "survival": true,
			"objective": {"type": "score", "count": 150000, "text_key": "objective.score"}, "length_s": t, "events": events}


## Missão de um chefe só (Boss Rush e Prática de chefe).
static func boss_only(boss_id: StringName, index: int) -> Dictionary:
	var op := "boss" if boss_id in ACT_BOSSES else "miniboss"
	return {"id": "boss_rush:%d" % index, "chapter": 1, "name_key": "boss." + String(boss_id),
			"music": "junkala_epic_boss_battle", "scroll_speed": 18,
			"backdrop": BACKDROPS[index % BACKDROPS.size()], "seed_salt": index * 31,
			"objective": {"type": "score", "count": 20000, "text_key": "objective.score"}, "length_s": 4.0,
			"events": [{"op": op, "id": String(boss_id), "t": 1.0}, {"op": "end", "t": 2.0}]}


## Corrida de um modo: lista de missões (dicionários) jogadas em fila.
static func run(mode: StringName, profile: Dictionary, date: String, seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mode:
		&"arcade":
			for id: StringName in ARCADE:
				out.append(_load(id))
		&"boss_rush":
			for i: int in range(BOSS_RUSH.size()):
				out.append(boss_only(BOSS_RUSH[i], i))
		&"daily":
			out.append(daily(date, max_chapter(profile)))
		&"survival":
			out.append(survival(seed))
	return out


## Maior capítulo com alguma missão concluída (o diário não sorteia capítulo que o jogador não viu).
static func max_chapter(profile: Dictionary) -> int:
	var best := 1
	for n: Dictionary in Economy.CAMPAIGN:
		if Economy.cleared(profile, n["id"]):
			best = maxi(best, int(n["chapter"]))
	return best


## Grava o fim de uma corrida de modo: recorde, diário do dia e créditos pela pontuação total.
## Devolve o resultado com "credits" e "record".
static func apply_result(profile: Dictionary, mode: StringName, result: Dictionary) -> Dictionary:
	var out := result.duplicate(true)
	var score := int(result.get("run_score", result.get("score", 0)))
	if not profile.has("mode_best"):
		profile["mode_best"] = {}
	var best := int((profile["mode_best"] as Dictionary).get(String(mode), 0))
	out["record"] = score > best
	profile["mode_best"][String(mode)] = maxi(best, score)
	var credits := 0
	if pays_rewards(mode):
		credits = Economy.CREDITS_BASE + floori(score / float(Economy.CREDITS_PER_SCORE))
		profile["wallet"]["credits"] = int(profile["wallet"]["credits"]) + credits
		profile["earned"]["credits"] = int(profile["earned"]["credits"]) + credits
	if mode == &"daily":
		var daily: Dictionary = profile["daily"]
		var date := String(result.get("daily", ""))
		if String(daily.get("date", "")) != date:
			daily["date"] = date
			daily["best_score"] = 0
			daily["attempted"] = false
		if not bool(daily["attempted"]):
			daily["attempted"] = true
			daily["best_score"] = score
			profile["wallet"]["pearls"] = int(profile["wallet"]["pearls"]) + 10
			out["pearls_gain"] = 10
	out["credits"] = credits
	return out


static func _load(id: StringName) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/stages/%s.json" % id))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
