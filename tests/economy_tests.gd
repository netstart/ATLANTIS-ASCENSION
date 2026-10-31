extends RefCounted
## Economia e progressão (Economy, plano mestre 4.9): regras do grafo da campanha, custos, fragmentos,
## asas, segredo e a simulação da economia — o bot joga a campanha inteira do Alpha com a carga do
## hangar, gastando os créditos como um jogador faria, e o ritmo das recompensas tem de ficar na faixa
## planejada. Chamado por tests/integration_tests.gd (precisa do perfil padrão do SaveManager).

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")


func run(check: Callable) -> void:
	_rules(check)
	_campaign(check)


func _rules(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	var ships := DB.rows("ships")
	var wings := DB.rows("wings")
	check.call(Economy.mission_unlocked(p, &"c1m1") and not Economy.mission_unlocked(p, &"c1m2"),
			"Economia: só a 1-1 aberta no começo")
	check.call(not Economy.mission_unlocked(p, &"s1"), "Economia: missão secreta fechada no começo")
	check.call(Economy.next_mission(p) == &"c1m1", "Economia: próxima missão é a 1-1")
	var r := Economy.apply_result(p, {"mission": "c1m1", "cleared": true, "score": 20000,
			"stars": [true, true, true, true], "pearls": 25, "orichalcum": 2, "log_found": true}, ships, wings)
	check.call(int(r["credits"]) == 50 + 10 + 100, "Economia: créditos = base + pontos + estrelas (%d)" % r["credits"])
	check.call(int(r["new_stars"]) == 4 and bool(r["record"]), "Economia: 4 estrelas novas e recorde")
	check.call(&"c1m2" in r["new_missions"], "Economia: concluir a 1-1 abre a 1-2")
	check.call(bool(r["log"]) and (p["story"]["logs"] as Array).has("c1m1"), "Economia: registro vai para o diário")
	check.call(int(r["pearls_gain"]) == 2, "Economia: 25 pérolas recolhidas viram 2 na carteira")
	check.call(&"wing_magnet" in r["new_wings"], "Economia: 3 estrelas liberam a primeira asa")
	var again := Economy.apply_result(p, {"mission": "c1m1", "cleared": true, "score": 100,
			"stars": [true, true, true, true]}, ships, wings)
	check.call(int(again["new_stars"]) == 0 and not bool(again["record"]), "Economia: repetir não paga estrelas de novo")
	for m: String in ["c1m2", "c1m3"]:
		Economy.apply_result(p, {"mission": m, "cleared": true, "score": 1000, "stars": [true, false, false, false]},
				ships, wings)
	check.call((p["unlocked"]["ships"] as Array).has("manta"), "Economia: fragmentos da 1-2 e 1-3 abrem a Manta")
	check.call(Economy.next_mission(p) == &"c2m1", "Economia: próxima missão é a 2-1")
	Economy.apply_result(p, {"mission": "c2m1", "cleared": true, "score": 1000, "stars": [true, false, false, true],
			"secret": "s1"}, ships, wings)
	check.call(Economy.mission_unlocked(p, &"s1"), "Economia: glifos na ordem abrem a missão secreta")
	p["wallet"]["credits"] = 0
	check.call(not Economy.upgrade_ship(p, &"falcon"), "Economia: sem créditos não sobe nível")
	p["wallet"]["credits"] = Economy.ship_level_cost(1)
	check.call(Economy.upgrade_ship(p, &"falcon") and Economy.ship_level(p, &"falcon") == 2
			and int(p["wallet"]["credits"]) == 0, "Economia: subir nível cobra o custo exato")
	p["wallet"]["credits"] = 10000
	p["wallet"]["orichalcum"] = 100
	check.call(Economy.upgrade_secondary(p, &"missiles") and Economy.secondary_level(p, &"missiles") == 1,
			"Economia: comprar mísseis")
	p["selected"]["secondary"] = "missiles"
	check.call(Economy.toggle_wing(p, &"wing_magnet", wings), "Economia: equipar asa liberada")
	check.call(not Economy.toggle_wing(p, &"wing_tide", wings), "Economia: asa do Beta não aparece no Alpha")
	var load := Economy.loadout(p)
	check.call(load["secondary"] == "missiles" and (load["wings"] as Array).has("wing_magnet")
			and is_equal_approx(float(load["damage"]), 0.04), "Economia: carga leva nível, secundária e asa")
	for i: int in range(Economy.SHIP_MAX_LEVEL + 2):
		p["wallet"]["credits"] = 100000
		Economy.upgrade_ship(p, &"falcon")
	check.call(Economy.ship_level(p, &"falcon") == Economy.SHIP_MAX_LEVEL, "Economia: nível para no máximo")


## Campanha do Alpha jogada pelo bot com a carga do hangar: depois de cada missão o "jogador" sobe
## a aeronave sempre que puder. Faixa planejada (plano mestre 18.1): ao fim do Alpha a aeronave
## está entre o nível 3 e o 7 — dá para sentir o progresso sem zerar a oficina.
func _campaign(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	var tables := Sim.load_tables()
	var order: Array[StringName] = [&"c1m1", &"c1m2", &"c1m3", &"c2m1", &"s1", &"c2m2", &"c2m3", &"c3m1", &"c3m2",
			&"c3m3a"]
	for id: StringName in order:
		check.call(Economy.mission_unlocked(p, id), "Economia: %s aberta na hora certa" % id)
		var sim := Sim.new()
		sim.setup(Sim.load_mission(id), tables, Economy.loadout(p), 7)
		var bot := BotPilot.new()
		while not sim.finished and sim.frame < 60 * 60 * 10:
			sim.step(bot.decide(sim))
		check.call(sim.cleared, "Economia: o bot vence %s com a carga do hangar" % id)
		Economy.apply_result(p, sim.result(), DB.rows("ships"), DB.rows("wings"))
		while Economy.upgrade_ship(p, &"falcon"):
			pass
	var level := Economy.ship_level(p, &"falcon")
	if "--verbose" in OS.get_cmdline_user_args():
		print("Economia: nível %d, carteira %s, estrelas %d" % [level, p["wallet"], Economy.total_stars(p)])
	check.call(level >= 3 and level <= 7, "Economia: aeronave no nível 3 a 7 ao fim do Alpha (%d)" % level)
	check.call(Economy.total_stars(p) >= 20, "Economia: o bot junta ≥ 20 estrelas (%d)" % Economy.total_stars(p))
	check.call((p["unlocked"]["ships"] as Array).size() >= 3, "Economia: ≥ 3 aeronaves abertas no Alpha")
