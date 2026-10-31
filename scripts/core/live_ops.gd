class_name LiveOps
extends RefCounted
## Retorno diário sem servidor (plano mestre 4.9 e 19, pesquisa .ai/04): login de 7 dias com um escudo
## de proteção por semana, 3 tarefas diárias e 5 semanais sorteadas pela data, o Núcleo de Oricalco
## (enche com tarefas e abre um baú) e o baú grátis a cada 6 h. Regras puras sobre o perfil; a data
## vem de fora ("AAAA-MM-DD"), então os testes controlam o calendário.

const LOGIN_REWARDS: Array[Dictionary] = [
	{"credits": 200}, {"pearls": 10}, {"credits": 400}, {"orichalcum": 5}, {"pearls": 20}, {"credits": 800},
	{"orichalcum": 15, "pearls": 30},
]
## Modelos de tarefa: estatística do resultado somada, alvo diário e semanal.
const TASKS: Array[Dictionary] = [
	{"id": &"kills", "stat": "kills", "daily": 150, "weekly": 1200},
	{"id": &"grazes", "stat": "grazes", "daily": 60, "weekly": 500},
	{"id": &"medals", "stat": "medals", "daily": 15, "weekly": 120},
	{"id": &"clears", "stat": "cleared", "daily": 3, "weekly": 20},
	{"id": &"rescued", "stat": "rescued", "daily": 4, "weekly": 40},
	{"id": &"chain", "stat": "max_chain", "daily": 30, "weekly": 0},
	{"id": &"stars", "stat": "new_stars", "daily": 2, "weekly": 12},
	{"id": &"blessings", "stat": "blessings", "daily": 4, "weekly": 30},
]
const DAILY_COUNT := 3
const WEEKLY_COUNT := 5
const DAILY_REWARD := {"credits": 150, "core": 20}
const WEEKLY_REWARD := {"credits": 600, "pearls": 15, "core": 40}
const CORE_MAX := 100
const CORE_REWARD := {"orichalcum": 20, "pearls": 30}
const CHEST_SECONDS := 6 * 3600
const CHEST_REWARD := {"pearls": 5, "credits": 100}


static func state(profile: Dictionary) -> Dictionary:
	if not profile.has("live"):
		profile["live"] = {"daily_date": "", "daily": [], "week": "", "weekly": [], "core": 0, "chest_at": 0}
	return profile["live"]


# --- Login -----------------------------------------------------------------------------------------

## Registra a entrada do dia e devolve a recompensa ({} se já entrou hoje). Faltar um dia gasta o escudo
## (a sequência continua); faltar sem escudo zera. O escudo volta a cada nova semana.
static func login(profile: Dictionary, today: String) -> Dictionary:
	var lg: Dictionary = profile["login"]
	var last := String(lg.get("last_date", ""))
	if last == today:
		return {}
	var gap := days_between(last, today) if not last.is_empty() else 1
	if week_of(last) != week_of(today):
		lg["shields_left"] = 1
	if gap == 2 and int(lg.get("shields_left", 0)) > 0:
		lg["shields_left"] = int(lg["shields_left"]) - 1
	elif gap != 1:
		lg["streak"] = 0
	lg["streak"] = int(lg.get("streak", 0)) + 1
	lg["last_date"] = today
	var reward: Dictionary = LOGIN_REWARDS[(int(lg["streak"]) - 1) % LOGIN_REWARDS.size()].duplicate()
	grant(profile, reward)
	return reward


# --- Tarefas ---------------------------------------------------------------------------------------

## Garante as tarefas do dia e da semana (sorteadas pela data, iguais para todos).
static func refresh(profile: Dictionary, today: String) -> void:
	var live := state(profile)
	if String(live["daily_date"]) != today:
		live["daily_date"] = today
		live["daily"] = _pick(Modes.date_seed(today), DAILY_COUNT, "daily")
	var week := week_of(today)
	if String(live["week"]) != week:
		live["week"] = week
		live["weekly"] = _pick(Modes.date_seed("w" + week), WEEKLY_COUNT, "weekly")


static func _pick(seed: int, count: int, kind: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool: Array[Dictionary] = []
	for t: Dictionary in TASKS:
		if int(t[kind]) > 0:
			pool.append(t)
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var t := pool.pop_at(rng.randi_range(0, pool.size() - 1)) as Dictionary
		out.append({"id": String(t["id"]), "stat": t["stat"], "goal": int(t[kind]), "progress": 0, "claimed": false})
	return out


## Soma um resultado de missão às tarefas abertas.
static func track(profile: Dictionary, result: Dictionary) -> void:
	var live := state(profile)
	for list: Variant in [live["daily"], live["weekly"]]:
		for task: Variant in list:
			var t := task as Dictionary
			var gain := _stat(result, String(t["stat"]))
			if String(t["stat"]) == "max_chain":
				t["progress"] = maxi(int(t["progress"]), gain)
			else:
				t["progress"] = int(t["progress"]) + gain


static func _stat(result: Dictionary, stat: String) -> int:
	match stat:
		"cleared":
			return 1 if bool(result.get("cleared", false)) else 0
		"blessings":
			return (result.get("blessings", []) as Array).size()
	return int(result.get(stat, 0))


static func done(task: Dictionary) -> bool:
	return int(task["progress"]) >= int(task["goal"])


## Resgata uma tarefa pronta (lista "daily" ou "weekly"). Devolve a recompensa ou {}.
static func claim(profile: Dictionary, kind: String, index: int) -> Dictionary:
	var list: Array = state(profile)[kind]
	if index < 0 or index >= list.size():
		return {}
	var t := list[index] as Dictionary
	if bool(t["claimed"]) or not done(t):
		return {}
	t["claimed"] = true
	var reward: Dictionary = (DAILY_REWARD if kind == "daily" else WEEKLY_REWARD).duplicate()
	grant(profile, reward)
	return reward


# --- Núcleo e baú -----------------------------------------------------------------------------------

static func core_ready(profile: Dictionary) -> bool:
	return int(state(profile)["core"]) >= CORE_MAX


static func open_core(profile: Dictionary) -> Dictionary:
	if not core_ready(profile):
		return {}
	state(profile)["core"] = int(state(profile)["core"]) - CORE_MAX
	grant(profile, CORE_REWARD.duplicate())
	return CORE_REWARD


## Segundos até o baú grátis (0 = pronto). `now` em segundos Unix.
static func chest_wait(profile: Dictionary, now: int) -> int:
	return maxi(0, int(state(profile)["chest_at"]) - now)


## Abre o baú (multiplicador 2 quando o jogador viu o anúncio recompensado).
static func open_chest(profile: Dictionary, now: int, mult: int = 1) -> Dictionary:
	if chest_wait(profile, now) > 0:
		return {}
	state(profile)["chest_at"] = now + CHEST_SECONDS
	var reward := {}
	for k: String in CHEST_REWARD:
		reward[k] = int(CHEST_REWARD[k]) * mult
	grant(profile, reward)
	return reward


## Credita uma recompensa: moedas na carteira, "core" no Núcleo.
static func grant(profile: Dictionary, reward: Dictionary) -> void:
	for k: String in reward:
		if k == "core":
			state(profile)["core"] = int(state(profile)["core"]) + int(reward[k])
		elif (profile["wallet"] as Dictionary).has(k):
			profile["wallet"][k] = int(profile["wallet"][k]) + int(reward[k])
			profile["earned"][k] = int(profile["earned"].get(k, 0)) + int(reward[k])


# --- Calendário ------------------------------------------------------------------------------------

static func days_between(a: String, b: String) -> int:
	return roundi((_unix(b) - _unix(a)) / 86400.0)


## Semana do ano ISO aproximada pela segunda-feira ("AAAA-MM-DD" da segunda da semana).
static func week_of(date: String) -> String:
	if date.is_empty():
		return ""
	var unix := _unix(date)
	var weekday := (int(floorf(unix / 86400.0)) + 3) % 7
	return Time.get_date_string_from_unix_time(unix - weekday * 86400)


static func _unix(date: String) -> int:
	return Time.get_unix_time_from_datetime_string(date + "T12:00:00")
