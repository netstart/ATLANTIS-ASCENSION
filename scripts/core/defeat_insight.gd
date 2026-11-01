class_name DefeatInsight
extends RefCounted
## "Quase lá" (pesquisa em .ai/07-pesquisa-diversao-e-surpresa.md, seção 3.4): a derrota mostra o quanto
## o jogador chegou perto (porcentagem da missão e casco que restou ao chefe) e uma dica tirada da
## própria partida — a bomba guardada, o raio que avisou, o choque com o inimigo. Quem vê que faltou
## pouco e sabe o que mudar aperta "Tentar de novo". Regras puras, sem nós.

## Abaixo disto o chefe "estava quase caindo" e a dica vira incentivo.
const BOSS_CLOSE := 0.25
## Dicas gerais, em rodízio pela semente quando a partida não aponta uma causa.
const GENERAL: Array[String] = ["tip.precise", "tip.tide", "tip.hangar", "tip.blessing", "tip.graze"]


## {progress (0..100), boss (0..100 ou -1), close (bool), tip (chave), tip_arg (int)}. Vazio na vitória.
static func analyze(result: Dictionary) -> Dictionary:
	if bool(result.get("cleared", false)):
		return {}
	var progress := roundi(clampf(float(result.get("progress", 0.0)), 0.0, 1.0) * 100.0)
	var boss_left := float(result.get("boss_left", -1.0))
	var boss := roundi(clampf(boss_left, 0.0, 1.0) * 100.0) if boss_left >= 0.0 else -1
	var out := {"progress": progress, "boss": boss, "close": progress >= 75 or (boss >= 0 and boss_left <= BOSS_CLOSE),
			"tip": "", "tip_arg": 0}
	var bombs := int(result.get("bombs_left", 0))
	var cause := String(result.get("cause", ""))
	if boss >= 0 and boss_left <= BOSS_CLOSE:
		out["tip"] = "tip.boss_close"
		out["tip_arg"] = maxi(1, boss)
	elif bombs > 0:
		out["tip"] = "tip.bombs_left"
		out["tip_arg"] = bombs
	elif cause == "beam":
		out["tip"] = "tip.beam"
	elif cause == "contact":
		out["tip"] = "tip.contact"
	else:
		out["tip"] = GENERAL[absi(int(result.get("seed", 0))) % GENERAL.size()]
	return out
