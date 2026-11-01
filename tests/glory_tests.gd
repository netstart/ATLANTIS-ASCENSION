extends RefCounted
## Maré de Glória (1.12, pesquisa em .ai/07-pesquisa-diversao-e-surpresa.md): Ecos de Estilo, nota da
## missão, Arca da Maré, "Quase lá" na derrota, vibração em camadas e câmera lenta do golpe final.
## Regras puras em run(); telas e HUD em run_view(). Chamado por tests/integration_tests.gd.

const LayoutTests := preload("res://tests/layout_tests.gd")


func run(check: Callable) -> void:
	_grade(check)
	_chest(check)
	_settle(check)
	_insight(check)
	_sim_result(check)
	_style(check)
	_achievements(check)
	_vibration(check)
	_texts(check)


static func _won(stars: int, extra: Dictionary = {}) -> Dictionary:
	var got: Array = []
	for i: int in range(4):
		got.append(i < stars)
	var r := {"mission": "c1m1", "cleared": true, "stars": got, "max_chain": 0, "bombs_used": 1, "hull_lost": 1,
			"revives": 0, "seed": 7}
	r.merge(extra, true)
	return r


func _grade(check: Callable) -> void:
	check.call(Grade.compute({"cleared": false}) == Grade.NONE, "Nota: derrota não tem nota")
	check.call(Grade.compute(_won(1)) == Grade.C, "Nota: só vencer é C")
	check.call(Grade.compute(_won(3)) == Grade.B, "Nota: 3 estrelas é B")
	check.call(Grade.compute(_won(4)) == Grade.A, "Nota: 4 estrelas com bomba é A")
	check.call(Grade.compute(_won(4, {"bombs_used": 0, "max_chain": 40})) == Grade.S, "Nota: 4 estrelas sem bomba é S")
	var perfect := _won(4, {"bombs_used": 0, "hull_lost": 0, "max_chain": Grade.SS_CHAIN})
	check.call(Grade.compute(perfect) == Grade.SS and Grade.perfect(perfect), "Nota: partida perfeita é SS")
	perfect["max_chain"] = Grade.SS_CHAIN - 1
	check.call(Grade.compute(perfect) == Grade.S, "Nota: SS exige a corrente mínima")
	check.call(Grade.compute(_won(4, {"bombs_used": 0, "max_chain": 80, "revives": 1})) == Grade.A,
			"Nota: reviver custa uma letra")
	check.call(Grade.points(_won(4, {"bombs_used": 0, "max_chain": 999})) == 100, "Nota: pontos com teto de 100")
	check.call(Grade.letter(Grade.SS) == "SS" and Grade.letter(Grade.NONE) == "—", "Nota: letras")
	var profile := {"missions": {}}
	check.call(Grade.record(profile, "c1m1", Grade.B), "Nota: primeira nota grava")
	check.call(not Grade.record(profile, "c1m1", Grade.C), "Nota: nota pior não substitui")
	check.call(Grade.record(profile, "c1m1", Grade.S) and Grade.best(profile, "c1m1") == Grade.S,
			"Nota: nota melhor substitui")
	Grade.record(profile, "c1m2", Grade.SS)
	check.call(Grade.count_at_least(profile, Grade.S) == 2 and Grade.count_at_least(profile, Grade.SS) == 1,
			"Nota: contagem por letra")


func _chest(check: Callable) -> void:
	check.call(TideChest.roll("c1m1", 7, 3, Grade.NONE).is_empty(), "Arca: derrota não abre arca")
	var first := TideChest.roll("c1m1", 7, 3, Grade.S)
	var second := TideChest.roll("c1m1", 7, 3, Grade.S)
	check.call(first == second, "Arca: mesma partida, mesma arca (determinística)")
	check.call(TideChest.tier_for(Grade.C) == TideChest.BRONZE and TideChest.tier_for(Grade.B) == TideChest.BRONZE
			and TideChest.tier_for(Grade.A) == TideChest.SILVER and TideChest.tier_for(Grade.SS) == TideChest.GOLD,
			"Arca: a nota escolhe o metal")
	var jackpots := [0, 0, 0, 0, 0]
	var sums := [0, 0, 0, 0, 0]
	var ranges_ok := true
	var reel_ok := true
	const N := 2000
	for grade: int in range(Grade.C, Grade.SS + 1):
		for i: int in range(N):
			var c := TideChest.roll("c%dm1" % (i % 9 + 1), i * 31, i, grade)
			var tier := int(c["tier"])
			var credits := roundi(int(c["credits"]) / float(TideChest.JACKPOT_CREDITS_MULT if bool(c["jackpot"]) else 1))
			ranges_ok = ranges_ok and credits >= TideChest.CREDITS[tier].x and credits <= TideChest.CREDITS[tier].y \
					and int(c["pearls"]) >= TideChest.PEARLS[tier].x and int(c["pearls"]) <= TideChest.PEARLS[tier].y
			var reel: Array = c["reel"]
			reel_ok = reel_ok and reel.size() == TideChest.REEL_LENGTH \
					and (reel[-1] == &"jackpot") == bool(c["jackpot"])
			if tier == TideChest.GOLD:
				ranges_ok = ranges_ok and int(c["orichalcum"]) >= (2 if grade == Grade.SS else 1)
			jackpots[grade] += 1 if bool(c["jackpot"]) else 0
			sums[grade] += int(c["credits"])
	check.call(ranges_ok, "Arca: créditos, pérolas e oricalco dentro da faixa de cada metal")
	check.call(reel_ok, "Arca: o carretel para no prêmio que saiu")
	check.call(jackpots[Grade.C] == 0, "Arca: bronze nunca dá o Tesouro")
	var gold_rate: float = jackpots[Grade.S] / float(N)
	var ss_rate: float = jackpots[Grade.SS] / float(N)
	check.call(absf(gold_rate - TideChest.JACKPOT[TideChest.GOLD]) < 0.025,
			"Arca: Tesouro do ouro ~10%% (%.3f)" % gold_rate)
	check.call(ss_rate > gold_rate * 1.5, "Arca: SS dobra a chance do Tesouro (%.3f)" % ss_rate)
	check.call(sums[Grade.C] < sums[Grade.A] and sums[Grade.A] < sums[Grade.S],
			"Arca: nota melhor rende mais em média")
	# Economia: a arca é bônus, não substitui o pagamento da missão (média ≤ 130 créditos no ouro).
	check.call(sums[Grade.S] / float(N) <= 130.0, "Arca: média do ouro %.0f ≤ 130 créditos" % (sums[Grade.S] / float(N)))


func _settle(check: Callable) -> void:
	var profile := {"missions": {}, "wallet": {"credits": 0, "pearls": 0, "orichalcum": 0}, "earned": {},
			"stats": {"missions_played": 4}}
	var out := TideChest.settle(profile, _won(4, {"bombs_used": 0, "max_chain": 40}))
	var chest: Dictionary = out["chest"]
	check.call(int(out["grade"]) == Grade.S and bool(out["grade_first"]) and not bool(out["grade_new"]),
			"Arca: primeira vitória grava a nota S")
	check.call(int(profile["wallet"]["credits"]) == int(chest["credits"])
			and int(profile["wallet"]["orichalcum"]) == int(chest["orichalcum"])
			and int(profile["earned"]["credits"]) == int(chest["credits"]), "Arca: o prêmio vai para a carteira")
	var again := TideChest.settle(profile, _won(4, {"bombs_used": 0, "hull_lost": 0, "max_chain": 60}))
	check.call(int(again["grade"]) == Grade.SS and bool(again["grade_new"]), "Arca: SS supera a melhor nota")
	var lost := TideChest.settle(profile, {"mission": "c1m1", "cleared": false})
	check.call(not lost.has("chest") and Grade.best(profile, "c1m1") == Grade.SS, "Arca: derrota não mexe na nota")


func _insight(check: Callable) -> void:
	check.call(DefeatInsight.analyze({"cleared": true}).is_empty(), "Quase lá: só na derrota")
	var close := DefeatInsight.analyze({"cleared": false, "progress": 0.97, "boss_left": 0.12, "bombs_left": 2})
	check.call(close["tip"] == "tip.boss_close" and int(close["tip_arg"]) == 12 and bool(close["close"])
			and int(close["progress"]) == 97, "Quase lá: chefe quase caindo vira incentivo")
	var bombs := DefeatInsight.analyze({"cleared": false, "progress": 0.4, "boss_left": -1.0, "bombs_left": 2})
	check.call(bombs["tip"] == "tip.bombs_left" and int(bombs["tip_arg"]) == 2 and int(bombs["boss"]) == -1
			and not bool(bombs["close"]), "Quase lá: bomba guardada vira dica")
	check.call(DefeatInsight.analyze({"cleared": false, "cause": "beam"})["tip"] == "tip.beam", "Quase lá: dica do raio")
	check.call(DefeatInsight.analyze({"cleared": false, "cause": "contact"})["tip"] == "tip.contact",
			"Quase lá: dica do choque")
	var general := DefeatInsight.analyze({"cleared": false, "cause": "bullet", "seed": 3})
	check.call(general["tip"] in DefeatInsight.GENERAL, "Quase lá: dica geral pela semente")


## A Sim conta até onde o jogador chegou e do que caiu, sem mudar a partida.
func _sim_result(check: Callable) -> void:
	var tables := Sim.load_tables()
	var sim := Sim.new()
	sim.setup(Sim.load_mission(&"c1m1"), tables, Sim.default_loadout(&"falcon"), 7)
	var idle := SimInput.new()
	while not sim.finished and sim.frame < 60 * 240:
		sim.step(idle)
	var r := sim.result()
	check.call(not bool(r["cleared"]), "Quase lá: parado no lugar a nave cai na 1-1")
	check.call(float(r["progress"]) > 0.0 and float(r["progress"]) < 1.0,
			"Quase lá: progresso da derrota entre 0 e 1 (%.2f)" % float(r["progress"]))
	check.call(String(r["cause"]) in ["bullet", "contact", "beam", "boss"], "Quase lá: causa da queda (%s)" % r["cause"])
	check.call(r.has("bombs_left") and r.has("boss_left"), "Quase lá: bombas e chefe no resultado")
	var won := Sim.new()
	won.setup(Sim.load_mission(&"c1m1"), tables, Sim.default_loadout(&"falcon"), 7)
	var bot := BotPilot.new()
	while not won.finished and won.frame < 60 * 600:
		won.step(bot.decide(won))
	check.call(won.cleared and float(won.result()["progress"]) == 1.0, "Quase lá: vitória é 100%")


## Fonte de eventos falsa para o StyleTracker (só lê a Sim).
func _style(check: Callable) -> void:
	var sim := Sim.new()
	sim.setup(Sim.load_mission(&"c1m1"), Sim.load_tables(), Sim.default_loadout(&"falcon"), 7)
	var tracker := StyleTracker.new()
	var seen: Array[int] = []
	for chain: int in range(0, 140):
		sim.scoring.chain = chain
		for c: Dictionary in tracker.tick(sim):
			seen.append(int(c["arg"]))
			if c["key"] == "style.chain_max":
				check.call(int(c["tier"]) == 3, "Estilo: corrente máxima no destaque mais alto")
	check.call(seen == [4, 8, 12, 16], "Estilo: um eco por degrau da corrente (%s)" % [seen])
	sim.scoring.chain = 0
	tracker.tick(sim)
	sim.scoring.chain = 200
	var jump := tracker.tick(sim)
	check.call(jump.size() == 1 and jump[0]["key"] == "style.chain_max", "Estilo: salto de degraus mostra só o maior")
	var dance := 0
	for i: int in range(StyleTracker.GRAZE_STREAK * 2):
		sim.frame = 1000 + i
		dance += tracker.observe({"type": "graze"}, sim).size()
	check.call(dance == 1, "Estilo: Dança das balas uma vez e espera o intervalo (%d)" % dance)
	var blank := 0
	for i: int in range(StyleTracker.BLANK_STREAK):
		sim.frame = 2000 + i * 10
		blank += tracker.observe({"type": "kill", "pos": sim.player.pos + Vector2(10, 0)}, sim).size()
	check.call(blank == 1, "Estilo: 3 abates à queima-roupa")
	var far := 0
	for i: int in range(StyleTracker.BLANK_STREAK * 2):
		sim.frame = 5000 + i
		far += tracker.observe({"type": "kill", "pos": sim.player.pos + Vector2(0, -200)}, sim).size()
	check.call(far == 0, "Estilo: abate de longe não é queima-roupa")
	sim.frame = 6000
	var medal := tracker.observe({"type": "medal", "value": Scoring.MEDAL_VALUES[-1]}, sim)
	check.call(medal.size() == 1 and medal[0]["key"] == "style.medal_max", "Estilo: medalha máxima")
	sim.scoring.hull_lost = 0
	var flawless := tracker.observe({"type": "boss_dead", "final": true}, sim)
	check.call(flawless.size() == 1 and flawless[0]["key"] == "style.flawless", "Estilo: chefe final sem dano")
	check.call(tracker.observe({"type": "boss_dead", "final": false}, sim).is_empty(), "Estilo: mini-chefe não conta")
	var other := StyleTracker.new()
	sim.scoring.hull_lost = 2
	sim.player.hull = 1
	var thread := other.observe({"type": "boss_dead", "final": true}, sim)
	check.call(thread.size() == 1 and thread[0]["key"] == "style.close_call", "Estilo: chefe final por um fio")


func _achievements(check: Callable) -> void:
	var ids: Array[String] = []
	for a: Variant in Achievements.all():
		ids.append(String((a as Dictionary)["id"]))
	check.call("grade_s" in ids and "atlantean_legend" in ids and "atlantis_treasure" in ids,
			"Conquistas: Maestria, Lenda Atlante e Tesouro de Atlântida")
	var profile := {"achievements": {}, "missions": {"c1m1": {"grade": Grade.SS}}, "stats": {}, "jackpots": 1,
			"unlocked": {"ships": []}, "story": {"endings": []}, "selected": {"ship": "falcon"},
			"hangar": {"ship_levels": {"falcon": 1}}}
	var got := Achievements.check(profile, {})
	check.call("atlantean_legend" in got and "atlantis_treasure" in got and not "grade_s" in got,
			"Conquistas: SS e Tesouro desbloqueiam; Maestria pede 10 missões S")


func _vibration(check: Callable) -> void:
	Settings.set_value("vibration", true)
	Settings.set("_last_vibration_ms", -100000)
	Settings.vibrate(80, -1.0, 2)
	Settings.vibrate(8, 0.25, 0)
	check.call(int(Settings.get("_last_vibration_priority")) == 2, "Vibração: raspão não abafa o dano")
	Settings.set("_last_vibration_ms", -100000)
	Settings.vibrate(8, 0.25, 0)
	Settings.vibrate(150, -1.0, 2)
	check.call(int(Settings.get("_last_vibration_priority")) == 2, "Vibração: dano passa por cima do raspão")
	GameClock.time_scale = 0.3
	GameClock.reset()
	check.call(GameClock.time_scale == 1.0, "Câmera lenta: reset volta à velocidade normal")
	GameClock.paused = true


func _texts(check: Callable) -> void:
	for key: String in ["style.chain", "style.chain_max", "style.graze_dance", "style.point_blank", "style.pearl_rain",
			"style.medal_max", "style.flawless", "style.close_call", "chest.title", "chest.jackpot", "defeat.close",
			"tip.boss_close", "tip.bombs_left", "results.grade", "map.grade", "options.style_callouts"]:
		check.call(Locale.keys.has(key), "Textos: %s traduzido" % key)


# --- Telas ----------------------------------------------------------------------------------------

func run_view(host: Node, check: Callable) -> void:
	await _results_view(host, check)
	await _hud_view(host, check)


func _results_view(host: Node, check: Callable) -> void:
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	LayoutTests.fit(app, Vector2(360, 640))
	var win := _won(4, {"bombs_used": 0, "hull_lost": 0, "max_chain": 60, "score": 12345})
	win["grade"] = Grade.SS
	win["grade_new"] = true
	win["chest"] = TideChest.roll("c1m1", 7, 1, Grade.SS)
	win["credits"] = 80
	app.last_result = win
	app.go(&"results")
	await LayoutTests.settle(host)
	var screen := app.screen(&"results")
	var seal := screen.find_child("GradeSeal", true, false) as GradeSeal
	var chest := screen.find_child("TideChest", true, false) as TideChestPanel
	var defeat := screen.find_child("Defeat", true, false) as DefeatPanel
	check.call(seal != null and seal.visible and seal.grade == Grade.SS, "Resultado: selo SS na vitória perfeita")
	check.call(chest != null and chest.visible, "Resultado: Arca da Maré na vitória")
	check.call(defeat != null and not defeat.visible, "Resultado: sem 'Quase lá' na vitória")
	var deadline := Time.get_ticks_msec() + 9000
	while bool(screen.get("_revealing")) and Time.get_ticks_msec() < deadline:
		await host.get_tree().process_frame
	check.call(not bool(screen.get("_revealing")), "Resultado: a revelação com a arca termina sozinha")
	var reel := (chest.get("_reel") as Label).text
	check.call(reel == TideChestPanel.symbol_text(StringName(String((win["chest"]["reel"] as Array)[-1]))),
			"Resultado: o carretel para no prêmio (%s)" % reel)
	LayoutTests.check_screen(screen, Rect2(Vector2.ZERO, Vector2(360, 640)), check, "Resultado com arca")
	var lost := {"mission": "c1m1", "cleared": false, "progress": 0.95, "boss_left": 0.1, "bombs_left": 1,
			"stars": [false, false, false, false], "seed": 7}
	app.last_result = lost
	app.go(&"map")
	await LayoutTests.settle(host)
	app.go(&"results")
	await LayoutTests.settle(host)
	screen = app.screen(&"results")
	defeat = screen.find_child("Defeat", true, false) as DefeatPanel
	check.call(defeat.visible and defeat.insight["tip"] == "tip.boss_close", "Resultado: 'Quase lá' na derrota")
	screen.call("_finish_reveal")
	check.call(is_equal_approx(defeat.fill, 0.95), "Resultado: a barra para em 95%")
	check.call(not (screen.find_child("TideChest", true, false) as Control).visible, "Resultado: derrota sem arca")
	app.queue_free()
	await host.get_tree().process_frame


func _hud_view(host: Node, check: Callable) -> void:
	var game := (load("res://scenes/game/Game.tscn") as PackedScene).instantiate() as Game
	game.configure(&"c1m1", &"falcon", 7, true)
	host.add_child(game)
	await host.get_tree().process_frame
	game.relayout_for(Vector2(360, 640))
	var layer := game.callouts()
	check.call(layer.size == (game.hud().layout["field"] as Rect2).size, "Estilo: frases ocupam o campo")
	for i: int in range(5):
		layer.pop("x", i % 4)
	check.call(layer.live_count() == StyleCallouts.MAX_LIVE, "Estilo: no máximo 3 frases ao mesmo tempo")
	var deadline := Time.get_ticks_msec() + 3000
	while layer.live_count() > 0 and Time.get_ticks_msec() < deadline:
		await host.get_tree().process_frame
	check.call(layer.live_count() == 0, "Estilo: as frases somem sozinhas")
	game.queue_free()
	await host.get_tree().process_frame
