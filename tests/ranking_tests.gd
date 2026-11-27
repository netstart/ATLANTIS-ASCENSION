extends RefCounted
## Ranking mundial de abates (Google Play Games): regras puras do KillRanking (chamado por tests/run_tests.gd,
## sem autoloads): ida e volta da pontuação, ordem, tempo jogado e campos de uma linha. A tela fica em
## tests/ranking_view_tests.gd.


## Pontuação do placar sem o plugin (os campos que KillRanking.entry lê).
class FakeScore:
	extends RefCounted
	var rank: int = 0
	var raw_score: int = 0
	var score_holder_display_name: String = ""
	var score_holder: RefCounted


class FakePlayer:
	extends RefCounted
	var player_id: String = ""


func run_unit(check: Callable) -> void:
	var cap := KillRanking.TIME_CAP
	for pair: Array in [[0, 0], [1, 59], [15_000, 3600 * 12 + 300], [2_000_000_000, cap], [900_000_000_000, 1]]:
		var back := KillRanking.decode(KillRanking.encode(pair[0], float(pair[1])))
		check.call(int(back["kills"]) == pair[0] and int(back["seconds"]) == pair[1],
				"Ranking: ida e volta de %d abates em %d s (%s)" % [pair[0], pair[1], back])
	check.call(KillRanking.decode(KillRanking.encode(7, cap * 3.0)) == {"kills": 7, "seconds": cap},
			"Ranking: tempo acima do teto fica no teto, sem mexer nos abates")
	check.call(KillRanking.decode(KillRanking.encode(-5, -9.0)) == {"kills": 0, "seconds": 0},
			"Ranking: valores negativos viram zero")
	check.call(KillRanking.encode(11, cap * 2.0) > KillRanking.encode(10, 0.0),
			"Ranking: mais abates vence qualquer tempo")
	check.call(KillRanking.encode(10, 100.0) > KillRanking.encode(10, 101.0), "Ranking: no empate vence o menor tempo")
	check.call(KillRanking.score_of({"stats": {"kills": 321.0, "time_played": 754.6}}) == KillRanking.encode(321, 755.0)
			and KillRanking.score_of({}) == KillRanking.encode(0, 0.0), "Ranking: pontuação a partir das estatísticas do save")
	for pair: Array in [[0, "0m"], [59, "0m"], [60, "1m"], [3599, "59m"], [3600, "1h 00m"], [43500, "12h 05m"],
			[cap, "2777h 46m"], [-4, "0m"]]:
		check.call(KillRanking.format_time(pair[0]) == pair[1],
				"Ranking: tempo de %d s = %s (%s)" % [pair[0], pair[1], KillRanking.format_time(pair[0])])
	check.call(KillRanking.format_time(43500, "%d時間%02d分", "%d分") == "12時間05分"
			and KillRanking.format_time(120, "%d時間%02d分", "%d分") == "2分", "Ranking: tempo no formato do idioma")
	var score := FakeScore.new()
	score.rank = 3
	score.raw_score = KillRanking.encode(4321, 43500.0)
	score.score_holder_display_name = "Maré"
	check.call(KillRanking.entry(score, "p1") == {"rank": 3, "name": "Maré", "kills": 4321, "seconds": 43500, "me": false},
			"Ranking: linha a partir da pontuação (%s)" % KillRanking.entry(score, "p1"))
	score.score_holder = FakePlayer.new()
	score.score_holder.set("player_id", "p1")
	check.call(bool(KillRanking.entry(score, "p1")["me"]) and not bool(KillRanking.entry(score, "p2")["me"])
			and not bool(KillRanking.entry(score)["me"]), "Ranking: a linha do próprio jogador é marcada pelo ID")
