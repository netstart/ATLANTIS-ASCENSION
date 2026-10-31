class_name Season
extends RefCounted
## Passe de temporada (plano mestre Fase 4): uma temporada por trimestre, 30 níveis de 100 XP. A trilha
## grátis paga moedas; a trilha "Maré Dourada" (compra simulada até a Fase 4) paga pinturas a cada 10
## níveis. Nada de poder. XP: 1 por 1.000 pontos + 40 por missão vencida.

const TIERS := 30
const XP_PER_TIER := 100
const XP_PER_CLEAR := 40
const FREE_REWARDS: Array[Dictionary] = [{"credits": 200}, {"pearls": 8}, {"orichalcum": 4}]
const PREMIUM_COSMETICS := {10: "tint_season_a", 20: "tint_season_b", 30: "tint_season_c"}


## "2026-T4": ano e trimestre da data "AAAA-MM-DD".
static func id_for(date: String) -> String:
	var month := int(date.substr(5, 2))
	return "%s-T%d" % [date.substr(0, 4), (month - 1) / 3 + 1]


static func state(profile: Dictionary, date: String) -> Dictionary:
	var sid := id_for(date)
	if not profile.has("season") or String((profile["season"] as Dictionary).get("id", "")) != sid:
		var premium := profile.has("season") and bool((profile["season"] as Dictionary).get("premium_forever", false))
		profile["season"] = {"id": sid, "xp": 0, "claimed": [], "premium": premium, "premium_claimed": [],
				"premium_forever": premium}
	return profile["season"]


static func tier(profile: Dictionary, date: String) -> int:
	return mini(TIERS, int(state(profile, date)["xp"]) / XP_PER_TIER)


static func add_result(profile: Dictionary, date: String, result: Dictionary) -> int:
	var gain := int(result.get("run_score", result.get("score", 0))) / 1000
	if bool(result.get("cleared", false)):
		gain += XP_PER_CLEAR
	var s := state(profile, date)
	s["xp"] = mini(TIERS * XP_PER_TIER, int(s["xp"]) + gain)
	return gain


static func free_reward(level: int) -> Dictionary:
	return FREE_REWARDS[(level - 1) % FREE_REWARDS.size()]


## Resgata a recompensa grátis de um nível alcançado. Devolve a recompensa ou {}.
static func claim(profile: Dictionary, date: String, level: int) -> Dictionary:
	var s := state(profile, date)
	if level < 1 or level > tier(profile, date) or (s["claimed"] as Array).has(level):
		return {}
	(s["claimed"] as Array).append(level)
	var reward := free_reward(level)
	LiveOps.grant(profile, reward)
	return reward


## Pinturas da trilha dourada já alcançadas (com a trilha comprada).
static func claim_premium(profile: Dictionary, date: String) -> Array[String]:
	var s := state(profile, date)
	var out: Array[String] = []
	if not bool(s["premium"]):
		return out
	for level: int in PREMIUM_COSMETICS:
		var id: String = PREMIUM_COSMETICS[level]
		if level <= tier(profile, date) and not (s["premium_claimed"] as Array).has(level):
			(s["premium_claimed"] as Array).append(level)
			if not (profile["unlocked"]["cosmetics"] as Array).has(id):
				(profile["unlocked"]["cosmetics"] as Array).append(id)
			out.append(id)
	return out


## Compra simulada da trilha dourada (sem plugin de pagamento, Store.simulated).
static func buy_premium(profile: Dictionary, date: String) -> bool:
	var s := state(profile, date)
	if bool(s["premium"]) or not Store.simulated():
		return false
	s["premium"] = true
	return true
