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
	{"id": &"c3m3s", "chapter": 3, "after": [&"c3m2"], "x": 0.72, "y": 2880.0, "kind": &"route"},
	{"id": &"c3m3a", "chapter": 3, "after": [&"c3m2"], "x": 0.28, "y": 2860.0, "kind": &"route"},
]
## Fases já lançadas: naves e asas de fases futuras ficam fora das listas.
const RELEASES: Array[String] = ["alpha"]
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

## Custo em créditos para subir a aeronave do nível `level` para o seguinte.
static func ship_level_cost(level: int) -> int:
	return 200 * level + 60 * level * level


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
	if level >= SHIP_MAX_LEVEL or not pay(profile, {"credits": ship_level_cost(level)}):
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
			"speed": 0.0, "difficulty": String(sel.get("difficulty", "normal"))}


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
	var orichalcum := int(result.get("orichalcum", 0)) if won else 0
	var pearls := floori(int(result.get("pearls", 0)) / float(PEARLS_PER_WALLET))
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
	return out


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
