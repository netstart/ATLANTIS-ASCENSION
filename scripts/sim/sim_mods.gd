class_name SimMods
extends RefCounted
## Modificadores da partida (plano mestre 4.9, 4.10 e 19.3): progressão do hangar, alas de apoio e
## Bênçãos das Marés aplicam efeitos aqui, por nome (data/blessings.json, data/wings.json). A Sim só
## lê estes valores; nenhum efeito tem código espalhado pelos sistemas.
##
## Sinergias (2 bênçãos do mesmo deus): Proteu = arma +1 nível de teto; Tétis = bolha a cada 45 s;
## Nereu = corrente começa em x2. Três do mesmo deus = Avatar (+10% de dano, nave dourada).

const DEITIES: Array[StringName] = [&"proteus", &"tethys", &"nereus"]

var dmg_mult: float = 1.0
var fire_rate: float = 1.0
var speed_mult: float = 1.0
var extra_hull: int = 0
var hitbox_mult: float = 1.0
var precise_mult: float = 1.0
var invuln_bonus: int = 0
var magnet_radius: float = 0.0
var chain_window: int = 0
var base_chain: int = 0
var medal_net: bool = false
var orb_luck: float = 0.0
var bubbles: int = 0
var bubble_recharge: int = 0
var reflux: bool = false
var coral_heal: int = 0
var tide_bonus: int = 0
var undertow: bool = false
var harpoon: bool = false
var fury: bool = false
var weapon_cap_bonus: int = 0
var chart: bool = false
var oracle: bool = false
var avatar: bool = false
var rear_cover: bool = false
var graze_bonus: float = 0.0
var log_finder: bool = false
var taken: Array[StringName] = []
var _deity_count: Dictionary = {}


## Aplica um efeito pelo nome (bênção, ala ou hangar).
func apply(effect: StringName, value: float) -> void:
	match effect:
		&"damage":
			dmg_mult += value
		&"fire_rate":
			fire_rate += value
		&"speed":
			speed_mult += value
		&"hull":
			extra_hull += int(value)
		&"hitbox":
			hitbox_mult = maxf(0.5, hitbox_mult - value)
		&"precise":
			precise_mult = maxf(0.3, precise_mult - value)
		&"invuln":
			invuln_bonus += int(value)
		&"magnet":
			magnet_radius = maxf(magnet_radius, value)
		&"chain_window":
			chain_window += int(value)
		&"medal_net":
			medal_net = true
		&"orb_luck":
			orb_luck += value
		&"bubble":
			bubbles += int(value)
		&"reflux":
			reflux = true
		&"coral_heal":
			coral_heal = int(value)
		&"tide_bonus":
			tide_bonus += int(value)
		&"undertow":
			undertow = true
		&"harpoon":
			harpoon = true
		&"fury":
			fury = true
		&"chart":
			chart = true
		&"oracle":
			oracle = true
		&"rear_cover":
			rear_cover = true
		&"graze_bonus":
			graze_bonus += value
		&"log_finder":
			log_finder = true
		&"weapon_cap":
			weapon_cap_bonus += int(value)
		&"shield_timer":
			bubble_recharge = int(value)


## Aplica uma bênção (definição de data/blessings.json) e devolve a sinergia ativada ("" se nenhuma).
func apply_blessing(def: Dictionary) -> StringName:
	var id := StringName(String(def.get("id", "")))
	if id in taken:
		return &""
	taken.append(id)
	apply(StringName(String(def.get("effect", ""))), float(def.get("value", 0.0)))
	var deity := StringName(String(def.get("deity", "")))
	if deity == &"abyss":
		# Módulos do Abismo Infinito não contam para sinergia de deus.
		return &""
	var n := int(_deity_count.get(deity, 0)) + 1
	_deity_count[deity] = n
	if n == 2:
		match deity:
			&"proteus":
				weapon_cap_bonus += 1
			&"tethys":
				bubble_recharge = 45 * 60 if bubble_recharge == 0 else mini(bubble_recharge, 45 * 60)
				bubbles += 1
			&"nereus":
				base_chain = maxi(base_chain, Scoring.CHAIN_PER_MULT)
		return deity
	if n == 3:
		avatar = true
		dmg_mult += 0.1
		return &"avatar"
	return &""


func deity_count(deity: StringName) -> int:
	return int(_deity_count.get(deity, 0))
