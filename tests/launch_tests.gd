extends RefCounted
## Sistemas da 1.0 (plano mestre Fase 4): replay determinístico (gravar, salvar, ler e reproduzir dá o
## mesmo hash), placar local top 10, Segunda Maré com o Kraken remendado, Correntes da semana, passe de
## temporada e conquistas. Chamado por tests/integration_tests.gd.

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")


func run(host: Node, check: Callable) -> void:
	_replay(check)
	_boards(check)
	_second_tide(check)
	_currents(check)
	_season(check)
	_achievements(check)
	await _photo(host, check)


func _replay(check: Callable) -> void:
	var mission := Sim.load_mission(&"c1m1")
	var loadout := Sim.default_loadout(&"falcon")
	var sim := Sim.new()
	sim.setup(mission, Sim.load_tables(), loadout, 11)
	var rec := Replay.new(mission, 11, loadout)
	var bot := BotPilot.new()
	while not sim.finished and sim.frame < 60 * 60 * 10:
		var input := bot.decide(sim)
		rec.record(input)
		sim.step(input)
	rec.score = sim.scoring.score
	check.call(rec.blocks.size() < rec.frames(), "Replay: blocos comprimem (%d blocos, %d passos)" % [rec.blocks.size(),
			rec.frames()])
	var path := rec.save("test_c1m1")
	var loaded := Replay.load_key("test_c1m1")
	check.call(loaded != null and loaded.frames() == rec.frames(), "Replay: salvo e lido de %s" % path)
	var again := loaded.make_sim()
	var input: SimInput = loaded.next_input()
	while input != null and not again.finished:
		again.step(input)
		input = loaded.next_input()
	check.call(again.state_hash() == sim.state_hash() and again.scoring.score == sim.scoring.score,
			"Replay: reproduzir dá o mesmo estado (%d pontos)" % again.scoring.score)
	DirAccess.remove_absolute(path)


func _boards(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	for s: int in [500, 900, 100, 700]:
		Replay.submit(p, "c1m1", s, "2026-11-01", "falcon")
	var board: Array = p["boards"]["c1m1"]
	check.call(int(board[0]["score"]) == 900 and int(board[3]["score"]) == 100, "Placar: ordenado do maior para o menor")
	for k: int in range(20):
		Replay.submit(p, "c1m1", 1000 + k, "2026-11-01", "falcon")
	check.call((p["boards"]["c1m1"] as Array).size() == Replay.BOARD_SIZE, "Placar: guarda só o top 10")
	check.call(Replay.submit(p, "c1m1", 1, "2026-11-01", "falcon") == -1, "Placar: pontuação baixa não entra")


func _second_tide(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	check.call(not Modes.unlocked(p, &"second_tide"), "Segunda Maré: fechada antes do primeiro final")
	p["missions"]["c9m3"] = {"cleared": true, "stars": [true, false, false, false], "best_score": 1}
	check.call(Modes.unlocked(p, &"second_tide"), "Segunda Maré: abre com o primeiro final")
	var run := Modes.run(&"second_tide", p, "2026-11-01", 7)
	check.call(run.size() == Modes.SECOND_TIDE.size(), "Segunda Maré: %d missões em fila" % run.size())
	var loadout := Modes.loadout_for(&"second_tide", p, "2026-11-01")
	loadout["damage"] = 0.36
	var sim := Sim.new()
	sim.setup(Sim.load_mission(&"c2m3"), Sim.load_tables(), loadout, 7)
	var bot := BotPilot.new()
	var patched := false
	while not sim.finished and sim.frame < 60 * 60 * 10:
		sim.step(bot.decide(sim))
		for ev: Dictionary in sim.take_events():
			patched = patched or (ev["type"] == &"boss_intro" and ev["id"] == &"kraken_engine_patched")
	check.call(patched, "Segunda Maré: o Kraken volta remendado")
	check.call(sim.cleared, "Segunda Maré: o bot vence a 2-3 com o hangar no máximo (%.0f s)" % (sim.frame / 60.0))


func _currents(check: Callable) -> void:
	var a := Modes.currents("2026-11-02", 9)
	var b := Modes.currents("2026-11-02", 9)
	check.call(JSON.stringify(a) == JSON.stringify(b), "Correntes: a mesma semana dá a mesma missão")
	var seen := {}
	for w: int in range(8):
		seen[Modes.current_mutator(LiveOps.week_of(Time.get_date_string_from_unix_time(1_793_000_000 + w * 604800)))] = true
	check.call(seen.size() >= 3, "Correntes: o modificador muda com as semanas (%d em 8)" % seen.size())
	var sim := Sim.new()
	var loadout := Sim.default_loadout(&"falcon")
	loadout["mutators"] = ["glass"]
	sim.setup(Sim.load_mission(&"c1m1"), Sim.load_tables(), loadout, 7)
	check.call(sim.player.max_hull == 1, "Correntes: casco de vidro deixa 1 de casco")


func _season(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	check.call(Season.id_for("2026-11-01") == "2026-T4" and Season.id_for("2027-02-10") == "2027-T1",
			"Passe: um por trimestre")
	Season.add_result(p, "2026-11-01", {"score": 60000, "cleared": true})
	check.call(Season.tier(p, "2026-11-01") == 1,
			"Passe: 100 XP sobem um nível (%d XP)" % Season.state(p, "2026-11-01")["xp"])
	var credits := int(p["wallet"]["credits"])
	check.call(not Season.claim(p, "2026-11-01", 1).is_empty() and int(p["wallet"]["credits"]) == credits + 200,
			"Passe: resgata o nível 1")
	check.call(Season.claim(p, "2026-11-01", 2).is_empty(), "Passe: nível não alcançado não paga")
	Season.state(p, "2026-11-01")["xp"] = 1000
	check.call(Season.buy_premium(p, "2026-11-01") and Season.claim_premium(p, "2026-11-01") == ["tint_season_a"],
			"Passe: trilha dourada (simulada) dá a pintura do nível 10")
	Season.state(p, "2027-01-05")
	check.call(Season.tier(p, "2027-01-05") == 0, "Passe: temporada nova começa do zero")


func _achievements(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	check.call(Achievements.all().size() >= 20, "Conquistas: %d definidas" % Achievements.all().size())
	p["missions"]["c1m1"] = {"cleared": true, "stars": [true, true, true, true], "best_score": 1}
	var got := Achievements.check(p, {"cleared": true, "max_chain": 90})
	check.call("first_dive" in got and "chain_80" in got, "Conquistas: primeiro mergulho e corrente de 80")
	check.call(Achievements.check(p, {}).is_empty(), "Conquistas: não repetem")
	p["missions"]["c5m3a"] = {"cleared": true, "stars": [true, false, false, false], "best_score": 1}
	check.call("sky_leviathan" in Achievements.check(p, {}), "Conquistas: qualquer rota conta (5-3 Abismo)")


func _photo(host: Node, check: Callable) -> void:
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	app.go(&"map")
	await host.get_tree().process_frame
	var map := app.screen(&"map") as MapScreen
	map.set_photo_mode(true)
	check.call(not (map.find_child("Back", true, false) as Control).visible, "Modo foto: esconde a interface")
	map.set_photo_mode(false)
	check.call((map.find_child("Back", true, false) as Control).visible, "Modo foto: volta a interface")
	app.queue_free()
	await host.get_tree().process_frame
