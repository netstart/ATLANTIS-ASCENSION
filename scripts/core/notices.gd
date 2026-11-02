class_name Notices
extends RefCounted
## Avisos dos menus (a bolinha vermelha "!" das abas e dos atalhos): regras puras sobre o perfil que
## dizem onde há algo para fazer agora. Cada aviso é uma pergunta de sim ou não com motivo claro e que
## some quando o jogador age — nada de urgência falsa, nada de aviso que só some pagando.
##
## Abas (NavShell.TABS): Loja (baú grátis pronto), Oficina (dá para subir a nave ou a secundária, ou há
## asa aberta com encaixe livre), Campanha (cena da história esperando), Naves (aeronave aberta que o
## jogador ainda não viu) e Eventos (tarefa pronta, Núcleo cheio, nível do passe para resgatar, Desafio
## Diário ainda não jogado hoje).
##
## `today` é "AAAA-MM-DD" e `now` é o relógio Unix (segundos); os testes fixam os dois. Nada aqui grava
## no perfil, exceto mark_ships_seen.


## Há algo a fazer na aba? `now` < 0 usa o relógio do sistema.
static func for_tab(profile: Dictionary, tab: StringName, today: String, now: int = -1) -> bool:
	var clock := now if now >= 0 else int(Time.get_unix_time_from_system())
	match tab:
		&"shop":
			return free_chest_ready(profile, clock)
		&"hangar":
			return can_upgrade_ship(profile) or can_upgrade_secondary(profile) or wing_slot_open(profile)
		&"hub":
			return story_pending(profile)
		&"ships":
			return not unseen_ships(profile).is_empty()
		&"events":
			return (login_unclaimed(profile, today) or tasks_claimable(profile) or core_ready(profile)
					or season_reward_ready(profile, today) or daily_event_open(profile, today))
	return false


## Abas com aviso, na ordem pedida.
static func tabs(profile: Dictionary, list: Array[StringName], today: String, now: int = -1) -> Array[StringName]:
	var out: Array[StringName] = []
	for tab: StringName in list:
		if for_tab(profile, tab, today, now):
			out.append(tab)
	return out


# --- Oficina ---------------------------------------------------------------------------------------

## A aeronave escolhida sobe de nível com os créditos que o jogador tem.
static func can_upgrade_ship(profile: Dictionary) -> bool:
	var ship := StringName(String(profile["selected"].get("ship", "falcon")))
	var level := Economy.ship_level(profile, ship)
	return level < Economy.SHIP_MAX_LEVEL and Economy.can_pay(profile,
			{"credits": Economy.ship_level_cost(level, profile)})


## Alguma arma secundária pode ser comprada ou subir de nível agora.
static func can_upgrade_secondary(profile: Dictionary) -> bool:
	for kind: StringName in Economy.SECONDARIES:
		var level := Economy.secondary_level(profile, kind)
		if level >= Economy.SECONDARY_MAX_LEVEL:
			continue
		var cost := {"credits": Economy.SECONDARY_UNLOCK} if level == 0 else Economy.secondary_cost(level)
		if Economy.can_pay(profile, cost):
			return true
	return false


## Há asa aberta pelas estrelas que não está equipada, e encaixe livre para ela.
static func wing_slot_open(profile: Dictionary) -> bool:
	var chosen: Array = profile["selected"].get("wings", [])
	if chosen.size() >= Economy.MAX_WINGS:
		return false
	for wing: StringName in Economy.wings_available(profile, Economy.data_rows("wings")):
		if not chosen.has(String(wing)):
			return true
	return false


# --- Loja ------------------------------------------------------------------------------------------

static func free_chest_ready(profile: Dictionary, now: int) -> bool:
	var live: Dictionary = profile.get("live", {})
	return int(live.get("chest_at", 0)) <= now


# --- Campanha --------------------------------------------------------------------------------------

## Cena da história esperando (prólogo, fim de ato, final).
static func story_pending(profile: Dictionary) -> bool:
	return not StoryScreen.pending(profile).is_empty()


# --- Naves -----------------------------------------------------------------------------------------

## Aeronaves abertas que o jogador ainda não viu na coleção.
static func unseen_ships(profile: Dictionary) -> Array[String]:
	var seen: Array = (profile.get("seen", {}) as Dictionary).get("ships", [])
	var out: Array[String] = []
	for ship: Variant in profile["unlocked"]["ships"]:
		if not seen.has(String(ship)):
			out.append(String(ship))
	return out


## A coleção abriu: todas as aeronaves abertas passam a vistas. Devolve se mudou algo.
static func mark_ships_seen(profile: Dictionary) -> bool:
	var fresh := unseen_ships(profile)
	if fresh.is_empty():
		return false
	if not profile.has("seen"):
		profile["seen"] = {}
	var seen: Array = (profile["seen"] as Dictionary).get("ships", [])
	seen.append_array(fresh)
	profile["seen"]["ships"] = seen
	return true


# --- Eventos ---------------------------------------------------------------------------------------

## A entrada de hoje ainda não foi registrada (o hub entrega a recompensa ao abrir).
static func login_unclaimed(profile: Dictionary, today: String) -> bool:
	return String((profile.get("login", {}) as Dictionary).get("last_date", "")) != today


## Alguma tarefa diária ou semanal pronta para resgatar.
static func tasks_claimable(profile: Dictionary) -> bool:
	var live: Dictionary = profile.get("live", {})
	for kind: String in ["daily", "weekly"]:
		for task: Variant in live.get(kind, []):
			var t := task as Dictionary
			if not bool(t.get("claimed", false)) and LiveOps.done(t):
				return true
	return false


static func core_ready(profile: Dictionary) -> bool:
	return int((profile.get("live", {}) as Dictionary).get("core", 0)) >= LiveOps.CORE_MAX


## Nível do passe alcançado com a recompensa grátis por resgatar (só a temporada de `today`).
static func season_reward_ready(profile: Dictionary, today: String) -> bool:
	var s: Dictionary = profile.get("season", {})
	if String(s.get("id", "")) != Season.id_for(today):
		return false
	var tier := mini(Season.TIERS, int(s.get("xp", 0)) / Season.XP_PER_TIER)
	return (s.get("claimed", []) as Array).size() < tier


## O Desafio Diário está aberto e ainda não foi tentado hoje.
static func daily_event_open(profile: Dictionary, today: String) -> bool:
	if not Modes.unlocked(profile, &"daily"):
		return false
	var daily: Dictionary = profile.get("daily", {})
	return not (String(daily.get("date", "")) == today and bool(daily.get("attempted", false)))
