class_name TideChest
extends RefCounted
## Arca da Maré (pesquisa em .ai/07-pesquisa-diversao-e-surpresa.md, seção 3.3): toda vitória na
## campanha abre uma arca com recompensa variável, revelada como um carretel que gira e para. A nota
## escolhe o metal da arca (C/B bronze, A prata, S/SS ouro): jogar melhor rende arcas melhores, e a
## sorte só decide quanto dentro da faixa e se sai o "Tesouro de Atlântida" (x3 créditos e +1 de
## oricalco). Sem dinheiro real, sem anúncio, sem custo: é bônus de quem joga.
##
## Determinística: a semente vem da missão, da semente da partida e do número de partidas do perfil.
## Regras puras; App.record_result grava o que sair.

const BRONZE := 0
const SILVER := 1
const GOLD := 2
const TIERS: Array[String] = ["bronze", "silver", "gold"]
## Créditos [mín, máx] por metal.
const CREDITS: Array[Vector2i] = [Vector2i(10, 30), Vector2i(25, 60), Vector2i(50, 110)]
## Pérolas [mín, máx] por metal.
const PEARLS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 2), Vector2i(2, 4)]
## Chance do Tesouro de Atlântida por metal (o SS dobra a do ouro).
const JACKPOT: Array[float] = [0.0, 0.04, 0.1]
const JACKPOT_CREDITS_MULT := 3
## Símbolos do carretel (a ordem é a do desenho na tela de resultado).
const SYMBOLS: Array[StringName] = [&"credits", &"pearls", &"orichalcum", &"jackpot"]
const REEL_LENGTH := 14


static func tier_for(grade: int) -> int:
	if grade >= Grade.S:
		return GOLD
	return SILVER if grade == Grade.A else BRONZE


## Abre a arca: {tier, credits, pearls, orichalcum, jackpot, reel}. Vazia se a nota é NONE.
static func roll(mission_id: String, seed_value: int, plays: int, grade: int) -> Dictionary:
	if grade == Grade.NONE:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d:chest" % [mission_id, seed_value, plays])
	var tier := tier_for(grade)
	var credits := rng.randi_range(CREDITS[tier].x, CREDITS[tier].y)
	var pearls := rng.randi_range(PEARLS[tier].x, PEARLS[tier].y)
	var orichalcum := 0
	if tier == GOLD:
		orichalcum = 2 if grade == Grade.SS else 1
	var chance := JACKPOT[tier] * (2.0 if grade == Grade.SS else 1.0)
	var jackpot := rng.randf() < chance
	if jackpot:
		credits *= JACKPOT_CREDITS_MULT
		orichalcum += 1
	# Carretel: símbolos sorteados que passam pela janela; o último é o que sai.
	var reel: Array[StringName] = []
	for i: int in range(REEL_LENGTH - 1):
		reel.append(SYMBOLS[rng.randi_range(0, SYMBOLS.size() - 1)])
	reel.append(&"jackpot" if jackpot else (&"orichalcum" if orichalcum > 0 else (&"pearls" if pearls > 0
			else &"credits")))
	return {"tier": tier, "credits": credits, "pearls": pearls, "orichalcum": orichalcum, "jackpot": jackpot,
			"reel": reel}


## Credita o que saiu da arca na carteira (e no total ganho).
static func grant(profile: Dictionary, chest: Dictionary) -> void:
	for kind: String in ["credits", "pearls", "orichalcum"]:
		var amount := int(chest.get(kind, 0))
		if amount <= 0:
			continue
		profile["wallet"][kind] = int(profile["wallet"].get(kind, 0)) + amount
		profile["earned"][kind] = int(profile["earned"].get(kind, 0)) + amount
	if bool(chest.get("jackpot", false)):
		profile["jackpots"] = int(profile.get("jackpots", 0)) + 1


## Vitória na campanha: nota, melhor nota e arca, tudo gravado no perfil. Devolve os campos para o
## resultado: grade, grade_new (melhorou a melhor nota da missão) e chest.
static func settle(profile: Dictionary, result: Dictionary) -> Dictionary:
	var grade := Grade.compute(result)
	if grade == Grade.NONE:
		return {"grade": grade}
	var mission := String(result.get("mission", ""))
	var had := Grade.best(profile, mission)
	var improved := Grade.record(profile, mission, grade)
	var plays := int((profile.get("stats", {}) as Dictionary).get("missions_played", 0))
	var chest := roll(mission, int(result.get("seed", 0)), plays, grade)
	grant(profile, chest)
	return {"grade": grade, "grade_new": improved and had != Grade.NONE, "grade_first": had == Grade.NONE,
			"chest": chest}
