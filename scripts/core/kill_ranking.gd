class_name KillRanking
extends RefCounted
## Regras puras do ranking de abates (Google Play Games, PlayRanking): o placar guarda um inteiro só, então
## os abates da carreira e o tempo jogado viajam juntos nele. Mais abates primeiro; no empate, menos tempo.
## As missões têm número fixo de inimigos: abates por partida empatariam todo mundo, por isso vale a carreira.

## Teto do tempo no desempate (segundos, ~115 dias de jogo); acima dele o tempo para de desempatar.
const TIME_CAP := 9_999_999
const FACTOR := TIME_CAP + 1


static func encode(kills: int, seconds: float) -> int:
	return maxi(0, kills) * FACTOR + TIME_CAP - clampi(roundi(seconds), 0, TIME_CAP)


static func decode(score: int) -> Dictionary:
	@warning_ignore("integer_division")
	return {"kills": score / FACTOR, "seconds": TIME_CAP - score % FACTOR}


## Pontuação atual do perfil (stats.kills e stats.time_played, em segundos).
static func score_of(profile: Dictionary) -> int:
	var stats: Dictionary = profile.get("stats", {})
	return encode(int(stats.get("kills", 0)), float(stats.get("time_played", 0.0)))


## "12h 05m" a partir de uma hora; antes disso só os minutos ("45m"). Os formatos vêm traduzidos da tela.
static func format_time(seconds: int, hours_format: String = "%dh %02dm", minutes_format: String = "%dm") -> String:
	@warning_ignore("integer_division")
	var minutes := maxi(0, seconds) / 60
	if minutes < 60:
		return minutes_format % minutes
	@warning_ignore("integer_division")
	return hours_format % [minutes / 60, minutes % 60]


## Campos de uma linha a partir de uma pontuação do placar (PlayGamesLeaderboardScore): posição, nome do
## jogador no Play Games, abates, segundos e se é o próprio jogador (`player_id`).
static func entry(score: Object, player_id: String = "") -> Dictionary:
	var out := decode(int(score.get("raw_score")))
	var holder: Object = score.get("score_holder")
	out["rank"] = int(score.get("rank"))
	out["name"] = String(score.get("score_holder_display_name"))
	out["me"] = not player_id.is_empty() and holder != null and String(holder.get("player_id")) == player_id
	return out
