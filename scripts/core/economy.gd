class_name Economy
extends RefCounted
## Progressão e economia (plano mestre 4.9 e 18.1), em regras puras sobre o perfil do save: o grafo
## da campanha, o que está aberto, custos do hangar, a carga levada para a missão e as recompensas
## de um resultado. Sem autoloads, para os testes unitários e a simulação de economia.

## Nós da campanha na Carta da Ascensão: missão, capítulo, pré-requisitos (basta um concluído),
## posição no mapa (x de 0 a 1, y no mundo) e tipo (mission, miniboss, boss, secret, route).
const CAMPAIGN: Array[Dictionary] = [
	{"id": &"c1m1", "chapter": 1, "after": [], "x": 0.35, "y": 880.0, "kind": &"mission"},
	{"id": &"c1m2", "chapter": 1, "after": [&"c1m1"], "x": 0.68, "y": 1110.0, "kind": &"miniboss"},
	{"id": &"c1m3", "chapter": 1, "after": [&"c1m2"], "x": 0.4, "y": 1340.0, "kind": &"mission"},
	{"id": &"c2m1", "chapter": 2, "after": [&"c1m3"], "x": 0.3, "y": 1640.0, "kind": &"mission"},
	{"id": &"s1", "chapter": 2, "after": [], "x": 0.84, "y": 1760.0, "kind": &"secret"},
	{"id": &"c2m2", "chapter": 2, "after": [&"c2m1"], "x": 0.6, "y": 1880.0, "kind": &"miniboss"},
	{"id": &"c2m3", "chapter": 2, "after": [&"c2m2"], "x": 0.4, "y": 2120.0, "kind": &"boss"},
	{"id": &"c3m1", "chapter": 3, "after": [&"c2m3"], "x": 0.62, "y": 2400.0, "kind": &"mission"},
	{"id": &"c3m2", "chapter": 3, "after": [&"c3m1"], "x": 0.38, "y": 2630.0, "kind": &"miniboss"},
	{"id": &"c3m3s", "chapter": 3, "after": [&"c3m2"], "x": 0.72, "y": 2880.0, "kind": &"route", "route": &"surface"},
	{"id": &"c3m3a", "chapter": 3, "after": [&"c3m2"], "x": 0.28, "y": 2860.0, "kind": &"route", "route": &"abyss"},
	{"id": &"c4m1", "chapter": 4, "after": [&"c3m3s", &"c3m3a"], "x": 0.62, "y": 3180.0, "kind": &"mission"},
	{"id": &"s2", "chapter": 4, "after": [], "x": 0.86, "y": 3290.0, "kind": &"secret"},
	{"id": &"c4m2", "chapter": 4, "after": [&"c4m1"], "x": 0.38, "y": 3410.0, "kind": &"miniboss"},
	{"id": &"c4m3s", "chapter": 4, "after": [&"c4m2"], "x": 0.72, "y": 3660.0, "kind": &"route", "route": &"surface"},
	{"id": &"c4m3a", "chapter": 4, "after": [&"c4m2"], "x": 0.28, "y": 3640.0, "kind": &"route", "route": &"abyss"},
	{"id": &"c5m1", "chapter": 5, "after": [&"c4m3s", &"c4m3a"], "x": 0.62, "y": 3940.0, "kind": &"mission"},
	{"id": &"c5m2", "chapter": 5, "after": [&"c5m1"], "x": 0.38, "y": 4170.0, "kind": &"miniboss"},
	{"id": &"c5m3s", "chapter": 5, "after": [&"c5m2"], "x": 0.72, "y": 4420.0, "kind": &"boss", "route": &"surface"},
	{"id": &"c5m3a", "chapter": 5, "after": [&"c5m2"], "x": 0.28, "y": 4400.0, "kind": &"boss", "route": &"abyss"},
	{"id": &"c6m1", "chapter": 6, "after": [&"c5m3s", &"c5m3a"], "x": 0.62, "y": 4700.0, "kind": &"mission"},
	{"id": &"s3", "chapter": 6, "after": [], "x": 0.86, "y": 4810.0, "kind": &"secret"},
	{"id": &"c6m2", "chapter": 6, "after": [&"c6m1"], "x": 0.38, "y": 4930.0, "kind": &"miniboss"},
	{"id": &"c6m3s", "chapter": 6, "after": [&"c6m2"], "x": 0.72, "y": 5180.0, "kind": &"route", "route": &"surface"},
	{"id": &"c6m3a", "chapter": 6, "after": [&"c6m2"], "x": 0.28, "y": 5160.0, "kind": &"route", "route": &"abyss"},
	{"id": &"c7m1", "chapter": 7, "after": [&"c6m3s", &"c6m3a"], "x": 0.62, "y": 5460.0, "kind": &"mission"},
	{"id": &"c7m2", "chapter": 7, "after": [&"c7m1"], "x": 0.38, "y": 5690.0, "kind": &"miniboss"},
	{"id": &"c7m3s", "chapter": 7, "after": [&"c7m2"], "x": 0.72, "y": 5940.0, "kind": &"boss", "route": &"surface"},
	{"id": &"c7m3a", "chapter": 7, "after": [&"c7m2"], "x": 0.28, "y": 5920.0, "kind": &"boss", "route": &"abyss"},
	{"id": &"c8m1", "chapter": 8, "after": [&"c7m3s", &"c7m3a"], "x": 0.62, "y": 6220.0, "kind": &"mission"},
	{"id": &"s4", "chapter": 8, "after": [], "x": 0.86, "y": 6330.0, "kind": &"secret"},
	{"id": &"c8m2", "chapter": 8, "after": [&"c8m1"], "x": 0.38, "y": 6450.0, "kind": &"miniboss"},
	{"id": &"c8m3s", "chapter": 8, "after": [&"c8m2"], "x": 0.72, "y": 6700.0, "kind": &"route", "route": &"surface"},
	{"id": &"c8m3a", "chapter": 8, "after": [&"c8m2"], "x": 0.28, "y": 6680.0, "kind": &"route", "route": &"abyss"},
	{"id": &"c9m1", "chapter": 9, "after": [&"c8m3s", &"c8m3a"], "x": 0.62, "y": 6980.0, "kind": &"mission"},
	{"id": &"c9m2", "chapter": 9, "after": [&"c9m1"], "x": 0.38, "y": 7210.0, "kind": &"mission"},
	{"id": &"c9m3", "chapter": 9, "after": [&"c9m2"], "x": 0.5, "y": 7460.0, "kind": &"boss"},
]
## Fases já lançadas: naves e asas de fases futuras ficam fora das listas.
const RELEASES: Array[String] = ["alpha", "beta", "post"]
## Missões secretas (Registros Abissais): as 4 concluídas levam ao final verdadeiro.
const SECRETS: Array[StringName] = [&"s1", &"s2", &"s3", &"s4"]
## Distritos da Cidade de Thalassa (plano mestre 7.2), abertos por atlantes resgatados, com o bônus de cada um.
const DISTRICTS: Array[Dictionary] = [
	{"id": &"docks", "rescued": 10, "bonus": &"credits", "value": 0.1},
	{"id": &"gardens", "rescued": 30, "bonus": &"pearls", "value": 0.2},
	{"id": &"forge", "rescued": 60, "bonus": &"discount", "value": 0.1},
	{"id": &"temple", "rescued": 100, "bonus": &"bombs", "value": 1.0},
	{"id": &"observatory", "rescued": 150, "bonus": &"orichalcum", "value": 0.25},
]
const SHIP_MAX_LEVEL := 10
const SECONDARY_MAX_LEVEL := 5
const SECONDARIES: Array[StringName] = [&"missiles", &"drones"]
const SECONDARY_UNLOCK := 600
const DIFFICULTIES: Array[StringName] = [&"brisa", &"normal", &"veteran", &"abyssal"]
const MAX_WINGS := 2
## Créditos por missão: base + pontuação / 2.000 + 25 por estrela nova.
const CREDITS_BASE := 50
const CREDITS_PER_SCORE := 2000
const CREDITS_PER_STAR := 25
## Fragmentos de aeronave: primeira conclusão de uma missão-fonte e cada repetição.
const FRAGMENTS_FIRST := 15
const FRAGMENTS_REPEAT := 3
## Pérolas recolhidas na missão viram Pérolas de Maré da carteira nesta razão.
const PEARLS_PER_WALLET := 10


static func node(id: StringName) -> Dictionary:
	for n: Dictionary in CAMPAIGN:
		if n["id"] == id:
			return n
	return {}


static func cleared(profile: Dictionary, id: StringName) -> bool:
	var rec: Variant = (profile.get("missions", {}) as Dictionary).get(String(id))
	return rec != null and bool((rec as Dictionary).get("cleared", false))


## Uma missão abre quando um dos pré-requisitos foi concluído; a secreta, quando os glifos a abrem.
static func mission_unlocked(profile: Dictionary, id: StringName) -> bool:
	var n := node(id)
	if n.is_empty():
		return false
	if n["kind"] == &"secret":
		return (profile["unlocked"].get("missions", []) as Array).has(String(id))
	var after: Array = n["after"]
	if after.is_empty():
		return true
	for prev: Variant in after:
		if cleared(profile, prev):
			return true
	return false


## Próxima missão a jogar: a primeira aberta sem conclusão (ou a última aberta).
static func next_mission(profile: Dictionary) -> StringName:
	var last: StringName = CAMPAIGN[0]["id"]
	for n: Dictionary in CAMPAIGN:
		if n["kind"] == &"secret" or not mission_unlocked(profile, n["id"]):
			continue
		last = n["id"]
		if not cleared(profile, n["id"]):
			return last
	return last


static func total_stars(profile: Dictionary) -> int:
	var total := 0
	for rec: Variant in (profile.get("missions", {}) as Dictionary).values():
		for got: Variant in (rec as Dictionary).get("stars", []):
			total += 1 if bool(got) else 0
	return total


static func released(def: Dictionary) -> bool:
	return String(def.get("release", "alpha")) in RELEASES


# --- Hangar ----------------------------------------------------------------------------------------

## Custo em créditos para subir a aeronave do nível `level` para o seguinte (a Forja da cidade dá desconto).
static func ship_level_cost(level: int, profile: Dictionary = {}) -> int:
	var cost := 150 * level + 40 * level * level
	return roundi(cost * (1.0 - district_bonus(profile, &"discount"))) if not profile.is_empty() else cost


## Bônus do nível da aeronave: +4% de dano por nível; +1 de casco a partir do 6.
static func ship_bonus(level: int) -> Dictionary:
	return {"damage": 0.04 * float(level - 1), "hull": 1 if level >= 6 else 0}


## Custo para subir a secundária do nível `level` (créditos e oricalco).
static func secondary_cost(level: int) -> Dictionary:
	return {"credits": 350 * level, "orichalcum": 3 * level}


static func ship_level(profile: Dictionary, ship: StringName) -> int:
	return int((profile["hangar"]["ship_levels"] as Dictionary).get(String(ship), 1))


static func secondary_level(profile: Dictionary, kind: StringName) -> int:
	return int((profile["hangar"]["modules"] as Dictionary).get(String(kind), 0))


static func can_pay(profile: Dictionary, cost: Dictionary) -> bool:
	for kind: String in cost:
		if int((profile["wallet"] as Dictionary).get(kind, 0)) < int(cost[kind]):
			return false
	return true


static func pay(profile: Dictionary, cost: Dictionary) -> bool:
	if not can_pay(profile, cost):
		return false
	for kind: String in cost:
		profile["wallet"][kind] = int(profile["wallet"][kind]) - int(cost[kind])
	return true


## Sobe o nível da aeronave se houver créditos. Devolve se subiu.
static func upgrade_ship(profile: Dictionary, ship: StringName) -> bool:
	var level := ship_level(profile, ship)
	if level >= SHIP_MAX_LEVEL or not pay(profile, {"credits": ship_level_cost(level, profile)}):
		return false
	profile["hangar"]["ship_levels"][String(ship)] = level + 1
	return true


## Compra (nível 0 para 1) ou sobe a secundária. Devolve se mudou.
static func upgrade_secondary(profile: Dictionary, kind: StringName) -> bool:
	var level := secondary_level(profile, kind)
	if level >= SECONDARY_MAX_LEVEL:
		return false
	var cost := {"credits": SECONDARY_UNLOCK} if level == 0 else secondary_cost(level)
	if not pay(profile, cost):
		return false
	profile["hangar"]["modules"][String(kind)] = level + 1
	return true


## Asas liberadas pelas estrelas somadas (só das fases lançadas).
static func wings_available(profile: Dictionary, wings: Array) -> Array[StringName]:
	var stars := total_stars(profile)
	var out: Array[StringName] = []
	for w: Variant in wings:
		var def := w as Dictionary
		if released(def) and stars >= int(def.get("stars", 0)):
			out.append(StringName(String(def["id"])))
	return out


## Liga ou desliga uma asa (no máximo MAX_WINGS). Devolve se mudou.
static func toggle_wing(profile: Dictionary, wing: StringName, wings: Array) -> bool:
	var list: Array = profile["selected"]["wings"]
	if list.has(String(wing)):
		list.erase(String(wing))
		return true
	if list.size() >= MAX_WINGS or not wing in wings_available(profile, wings):
		return false
	list.append(String(wing))
	return true


## Carga levada para a missão (Sim.setup): aeronave escolhida, nível, secundária, asas, dificuldade.
static func loadout(profile: Dictionary) -> Dictionary:
	var sel: Dictionary = profile["selected"]
	var ship := StringName(String(sel.get("ship", "falcon")))
	var bonus := ship_bonus(ship_level(profile, ship))
	var secondary := StringName(String(sel.get("secondary", "")))
	var level := secondary_level(profile, secondary)
	return {"ship": String(ship), "secondary": String(secondary) if level > 0 else "", "secondary_level": maxi(1, level),
			"wings": (sel.get("wings", []) as Array).duplicate(), "damage": bonus["damage"], "hull": bonus["hull"],
			"speed": 0.0, "difficulty": String(sel.get("difficulty", "normal")),
			"bombs": int(district_bonus(profile, &"bombs")), "abyss_records": abyss_records(profile),
			"memory_lane": int((profile.get("boss_memory", {}) as Dictionary).get("lane", -1)),
			"cosmetic": String(sel.get("cosmetic", ""))}


## Registros Abissais: missões secretas já concluídas.
static func abyss_records(profile: Dictionary) -> int:
	var n := 0
	for s: StringName in SECRETS:
		n += 1 if cleared(profile, s) else 0
	return n


## Soma dos bônus dos distritos abertos de um tipo.
static func district_bonus(profile: Dictionary, bonus: StringName) -> float:
	var total := 0.0
	var rescued := int(profile.get("rescued_total", 0))
	for d: Dictionary in DISTRICTS:
		if d["bonus"] == bonus and rescued >= int(d["rescued"]):
			total += float(d["value"])
	return total


# --- Recompensas -----------------------------------------------------------------------------------

## Aplica um resultado de missão ao perfil e devolve o resultado com as recompensas: credits,
## orichalcum, pearls, new_stars, record, fragments {nave: n}, new_ships, new_wings, new_missions, log.
static func apply_result(profile: Dictionary, result: Dictionary, ships: Array, wings: Array) -> Dictionary:
	var out := result.duplicate(true)
	var id := StringName(String(result.get("mission", "")))
	var all: Dictionary = profile["missions"]
	if not all.has(String(id)):
		all[String(id)] = {"stars": [false, false, false, false], "best_score": 0, "cleared": false, "route": ""}
	var record: Dictionary = all[String(id)]
	var was_cleared := bool(record["cleared"])
	var wings_before := wings_available(profile, wings)
	var opened_before := _open_ids(profile)
	var stars: Array = record["stars"]
	var got: Array = result.get("stars", [false, false, false, false])
	var fresh := 0
	for i: int in range(mini(stars.size(), got.size())):
		if bool(got[i]) and not bool(stars[i]):
			stars[i] = true
			fresh += 1
	var score := int(result.get("score", 0))
	out["record"] = score > int(record["best_score"])
	record["best_score"] = maxi(int(record["best_score"]), score)
	var won := bool(result.get("cleared", false))
	var credits := CREDITS_BASE + floori(score / float(CREDITS_PER_SCORE)) + CREDITS_PER_STAR * fresh
	credits = roundi(credits * (1.0 + district_bonus(profile, &"credits")))
	var orichalcum := int(result.get("orichalcum", 0)) if won else 0
	orichalcum = roundi(orichalcum * (1.0 + district_bonus(profile, &"orichalcum")))
	var pearls := floori(int(result.get("pearls", 0)) / float(PEARLS_PER_WALLET))
	pearls = roundi(pearls * (1.0 + district_bonus(profile, &"pearls")))
	var districts_before := int(profile.get("rescued_total", 0))
	profile["rescued_total"] = districts_before + int(result.get("rescued", 0))
	if int(result.get("bosses_met", 0)) > 0:
		# Chefe que lembra: a faixa preferida do jogador diante de um chefe de ato fica no perfil.
		profile["boss_memory"] = {"lane": int(result.get("lane", 1))}
	var ending := String(result.get("ending", ""))
	if won and not ending.is_empty() and not (profile["story"]["endings"] as Array).has(ending):
		(profile["story"]["endings"] as Array).append(ending)
	_earn(profile, "credits", credits)
	_earn(profile, "orichalcum", orichalcum)
	_earn(profile, "pearls", pearls)
	var fragments := {}
	var new_ships: Array[StringName] = []
	if won:
		record["cleared"] = true
		for s: Variant in ships:
			var def := s as Dictionary
			var ship := String(def["id"])
			if not released(def) or (profile["unlocked"]["ships"] as Array).has(ship):
				continue
			if _unlock_by_ending(profile, def):
				new_ships.append(StringName(ship))
				continue
			if not (def.get("sources", []) as Array).has(String(id)):
				continue
			var gain := FRAGMENTS_REPEAT if was_cleared else FRAGMENTS_FIRST
			var have := int((profile["hangar"]["fragments"] as Dictionary).get(ship, 0)) + gain
			profile["hangar"]["fragments"][ship] = have
			fragments[ship] = gain
			if have >= int(def.get("fragments", 0)):
				(profile["unlocked"]["ships"] as Array).append(ship)
				profile["hangar"]["ship_levels"][ship] = 1
				new_ships.append(StringName(ship))
	var secret := String(result.get("secret", ""))
	if not secret.is_empty() and not (profile["unlocked"]["missions"] as Array).has(secret):
		(profile["unlocked"]["missions"] as Array).append(secret)
		(profile["story"]["glyphs"] as Array).append(String(id))
	var log_new := bool(result.get("log_found", false)) and not (profile["story"]["logs"] as Array).has(String(id))
	if log_new:
		(profile["story"]["logs"] as Array).append(String(id))
	var new_wings: Array[StringName] = []
	for w: StringName in wings_available(profile, wings):
		if not w in wings_before:
			new_wings.append(w)
	var new_missions: Array[StringName] = []
	for m: StringName in _open_ids(profile):
		if not m in opened_before:
			new_missions.append(m)
	out["credits"] = credits
	out["orichalcum_gain"] = orichalcum
	out["pearls_gain"] = pearls
	out["new_stars"] = fresh
	out["fragments"] = fragments
	out["new_ships"] = new_ships
	out["new_wings"] = new_wings
	out["new_missions"] = new_missions
	out["log"] = log_new
	var new_districts: Array[StringName] = []
	for d: Dictionary in DISTRICTS:
		if districts_before < int(d["rescued"]) and int(profile["rescued_total"]) >= int(d["rescued"]):
			new_districts.append(d["id"])
	out["new_districts"] = new_districts
	return out


## Aeronave que vem de um final (Ascension: final verdadeiro). Abre na primeira vitória depois dele.
static func _unlock_by_ending(profile: Dictionary, def: Dictionary) -> bool:
	var ending := String(def.get("ending", ""))
	if ending.is_empty() or not (profile["story"]["endings"] as Array).has(ending):
		return false
	(profile["unlocked"]["ships"] as Array).append(String(def["id"]))
	profile["hangar"]["ship_levels"][String(def["id"])] = 1
	return true


static func _earn(profile: Dictionary, kind: String, amount: int) -> void:
	if amount <= 0:
		return
	profile["wallet"][kind] = int(profile["wallet"].get(kind, 0)) + amount
	profile["earned"][kind] = int(profile["earned"].get(kind, 0)) + amount


static func _open_ids(profile: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for n: Dictionary in CAMPAIGN:
		if mission_unlocked(profile, n["id"]):
			out.append(n["id"])
	return out
