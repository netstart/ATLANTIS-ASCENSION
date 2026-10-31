class_name Achievements
extends RefCounted
## Conquistas locais (plano mestre 11.2): as mesmas ids viram as conquistas da Steam quando o GodotSteam
## entrar. Regras puras: cada uma olha o perfil depois de gravar um resultado. Dados em
## data/achievements.json (id, tipo, alvo).

const PATH := "res://data/achievements.json"


static func all() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


## Desbloqueia o que o perfil já cumpre e devolve as ids novas.
static func check(profile: Dictionary, result: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var have: Dictionary = profile["achievements"]
	for raw: Variant in all():
		var a := raw as Dictionary
		var id := String(a["id"])
		if have.has(id):
			continue
		if _met(profile, result, a):
			have[id] = Time.get_date_string_from_system()
			out.append(id)
	return out


static func _met(profile: Dictionary, result: Dictionary, a: Dictionary) -> bool:
	var target := int(a.get("target", 1))
	var stats: Dictionary = profile["stats"]
	match String(a["type"]):
		"cleared":
			for option: String in String(a["mission"]).split("|"):
				if Economy.cleared(profile, StringName(option)):
					return true
			return false
		"stars":
			return Economy.total_stars(profile) >= target
		"kills":
			return float(stats.get("kills", 0)) >= target
		"grazes":
			return float(stats.get("grazes", 0)) >= target
		"ships":
			return (profile["unlocked"]["ships"] as Array).size() >= target
		"secrets":
			return Economy.abyss_records(profile) >= target
		"rescued":
			return int(profile.get("rescued_total", 0)) >= target
		"ending":
			return (profile["story"]["endings"] as Array).has(String(a["ending"]))
		"endings":
			return (profile["story"]["endings"] as Array).size() >= target
		"no_damage_boss":
			return bool(result.get("cleared", false)) and int(result.get("hull_lost", 1)) == 0 \
					and int(result.get("bosses_met", 0)) > 0
		"chain":
			return int(result.get("max_chain", 0)) >= target
		"blessings_deity":
			return (result.get("blessings", []) as Array).size() >= target
		"level":
			return Economy.ship_level(profile, StringName(String(profile["selected"]["ship"]))) >= target
		"mode":
			return int((profile.get("mode_best", {}) as Dictionary).get(String(a["mode"]), 0)) > 0
		"abyss_depth":
			return int(profile.get("abyss_depth", 0)) >= target
	return false
