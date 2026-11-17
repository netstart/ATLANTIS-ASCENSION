extends RefCounted
## Sistemas do Beta (plano mestre 4.11, 17 e 19): modos montados por semente (Diário igual para todos
## no mesmo dia, Boss Rush com os 12 chefes, Sobrevivência), login de 7 dias com escudo, tarefas
## diárias e semanais, Núcleo, baú de 6 h, loja de cosméticos, apoio simulado, distritos e finais.
## Chamado por tests/integration_tests.gd.

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")
const SimTests := preload("res://tests/sim_tests.gd")


func run(check: Callable) -> void:
	_modes(check)
	_live_ops(check)
	_store(check)
	_city_and_endings(check)


func _modes(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	check.call(not Modes.unlocked(p, &"arcade") and not Modes.unlocked(p, &"daily"), "Modos: fechados no começo")
	p["missions"]["c2m1"] = {"cleared": true, "stars": [true, false, false, false], "best_score": 1}
	check.call(Modes.unlocked(p, &"daily") and not Modes.unlocked(p, &"boss_rush"), "Modos: Diário abre na 2-1")
	var a := Modes.daily("2026-11-01", 3)
	var b := Modes.daily("2026-11-01", 3)
	var c := Modes.daily("2026-11-02", 3)
	check.call(JSON.stringify(a) == JSON.stringify(b), "Diário: mesma data, mesmo roteiro")
	check.call(JSON.stringify(a) != JSON.stringify(c), "Diário: outro dia, outro roteiro")
	var tables := Sim.load_tables()
	var daily_run := _bot(a, tables)
	check.call(bool(daily_run["result"]["cleared"]),
			"Diário: o bot vence o desafio de hoje (%.0f s)" % daily_run["result"]["seconds"])
	var rush := Modes.run(&"boss_rush", p, "2026-11-01", 7)
	check.call(rush.size() == 12, "Boss Rush: 12 chefes em fila (%d)" % rush.size())
	for i: int in [0, 6]:
		var r := _bot(rush[i], tables)
		check.call(bool(r["result"]["cleared"]), "Boss Rush: o bot vence %s" % rush[i]["name_key"])
	var surv := Modes.survival(7)
	check.call(float(surv["length_s"]) >= Modes.SURVIVAL_STAGES * Modes.SURVIVAL_STAGE_SECONDS,
			"Sobrevivência: %d estágios" % Modes.SURVIVAL_STAGES)
	var sim := Sim.new()
	sim.setup(surv, tables, &"falcon", 7)
	var bot := BotPilot.new()
	var empty := 0
	var worst := 0
	while not sim.finished and sim.frame < 60 * 90:
		sim.step(bot.decide(sim))
		empty = empty + 1 if sim.enemies.is_empty() else 0
		worst = maxi(worst, empty)
	check.call(sim.player.alive and worst < 10 * 60, "Sobrevivência: 90 s sem buraco de 10 s (%.1f s)" % (worst / 60.0))
	var out := Modes.apply_result(p, &"daily", {"score": 30000, "daily": "2026-11-01", "cleared": true})
	check.call(int(out["pearls_gain"]) == 10 and bool(p["daily"]["attempted"]), "Diário: 1ª tentativa paga 10 pérolas")
	var again := Modes.apply_result(p, &"daily", {"score": 90000, "daily": "2026-11-01", "cleared": true})
	check.call(not again.has("pearls_gain") and int(p["daily"]["best_score"]) == 30000,
			"Diário: só a 1ª tentativa do dia conta")
	check.call(int((p["mode_best"] as Dictionary)["daily"]) == 90000, "Modos: recorde guarda o melhor")
	check.call(int(Modes.apply_result(p, &"practice", {"score": 50000})["credits"]) == 0, "Prática: sem recompensa")
	_daily_real_path(check, tables)


## Diário pelo caminho do jogo (Sim.result -> App.record_result, como em App._on_mission_finished): o resultado
## leva a data do Diário jogado, o dia seguinte reinicia e paga de novo, e o save antigo com data vazia
## (1.18.0 e antes) volta a funcionar sem perder nada.
func _daily_real_path(check: Callable, tables: Dictionary) -> void:
	var saved_data := SaveManager.data
	var saved_today := App.today_override
	SaveManager.data = SaveManagerScript.default_profile()
	# Save antigo: data nunca gravada, Diário "feito" e Pérolas "dobradas" para sempre.
	SaveManager.data["daily"] = {"date": "", "best_score": 500, "attempted": true, "pearls_doubled": true}
	SaveManager.data["wallet"]["pearls"] = 7
	# Partida começada em 03/11 e terminada depois da meia-noite: conta no dia em que começou.
	App.today_override = "2026-11-04"
	var first := _daily_record(Modes.daily("2026-11-03", 3), tables)
	var daily: Dictionary = SaveManager.data["daily"]
	check.call(String(first.get("daily", "")) == "2026-11-03" and String(daily["date"]) == "2026-11-03",
			"Diário (jogo): o resultado leva a data do Diário jogado (%s)" % daily["date"])
	check.call(int(first.get("pearls_gain", 0)) == 10 and int(SaveManager.data["wallet"]["pearls"]) == 17,
			"Diário (jogo): save antigo com data vazia volta a pagar, sem perder Pérolas")
	check.call(Modes.daily_pearls_doublable(SaveManager.data, first), "Diário (jogo): o save antigo volta a dobrar")
	var again := _daily_record(Modes.daily("2026-11-03", 3), tables)
	check.call(not again.has("pearls_gain"), "Diário (jogo): 2ª tentativa do mesmo dia não paga")
	var next := _daily_record(Modes.daily("2026-11-04", 3), tables)
	check.call(int(next.get("pearls_gain", 0)) == 10 and String(SaveManager.data["daily"]["date"]) == "2026-11-04"
			and Modes.daily_pearls_doublable(SaveManager.data, next),
			"Diário (jogo): o dia seguinte reinicia, paga e dobra de novo")
	check.call(String(_sim_result(Sim.load_mission(&"c1m1"), tables).get("daily", "?")).is_empty(),
			"Diário (jogo): fora do Diário o resultado não tem data")
	App.today_override = saved_today
	SaveManager.data = saved_data


func _sim_result(mission: Dictionary, tables: Dictionary) -> Dictionary:
	var sim := Sim.new()
	sim.setup(mission, tables, &"falcon", 7)
	return sim.result()


## O que App._on_mission_finished faz com o resultado de um modo antes de gravar.
func _daily_record(mission: Dictionary, tables: Dictionary) -> Dictionary:
	var result := _sim_result(mission, tables)
	result["mode"] = "daily"
	result["run_score"] = int(result["score"])
	return App.record_result(result, &"daily")


func _bot(mission: Dictionary, tables: Dictionary) -> Dictionary:
	return SimTests.run_bot(mission, tables, 7)


func _live_ops(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	var r1 := LiveOps.login(p, "2026-11-02")
	check.call(int(r1.get("credits", 0)) == 200 and int(p["login"]["streak"]) == 1, "Login: dia 1 paga 200 créditos")
	check.call(LiveOps.login(p, "2026-11-02").is_empty(), "Login: mesmo dia não paga de novo")
	LiveOps.login(p, "2026-11-03")
	LiveOps.login(p, "2026-11-05")
	check.call(int(p["login"]["streak"]) == 3 and int(p["login"]["shields_left"]) == 0,
			"Login: faltar 1 dia gasta o escudo e mantém a sequência")
	LiveOps.login(p, "2026-11-07")
	check.call(int(p["login"]["streak"]) == 1, "Login: faltar sem escudo zera a sequência")
	LiveOps.login(p, "2026-11-10")
	check.call(int(p["login"]["shields_left"]) >= 0 and LiveOps.week_of("2026-11-10") == "2026-11-09",
			"Login: semana começa na segunda (%s)" % LiveOps.week_of("2026-11-10"))
	LiveOps.refresh(p, "2026-11-10")
	var live := LiveOps.state(p)
	check.call((live["daily"] as Array).size() == 3 and (live["weekly"] as Array).size() == 5,
			"Tarefas: 3 diárias e 5 semanais")
	var q := SaveManagerScript.default_profile()
	LiveOps.refresh(q, "2026-11-10")
	check.call(JSON.stringify(LiveOps.state(q)["daily"]) == JSON.stringify(live["daily"]),
			"Tarefas: iguais para todos no dia")
	for k: int in range(20):
		LiveOps.track(p, {"kills": 100, "grazes": 50, "medals": 10, "cleared": true, "rescued": 3, "max_chain": 40,
				"new_stars": 1, "blessings": ["a", "b"]})
	var credits := int(p["wallet"]["credits"])
	var reward := LiveOps.claim(p, "daily", 0)
	check.call(not reward.is_empty() and int(p["wallet"]["credits"]) == credits + 150, "Tarefas: resgatar paga")
	check.call(LiveOps.claim(p, "daily", 0).is_empty(), "Tarefas: não paga duas vezes")
	for i: int in range(1, 3):
		LiveOps.claim(p, "daily", i)
	for i: int in range(5):
		LiveOps.claim(p, "weekly", i)
	check.call(LiveOps.core_ready(p), "Núcleo: enche com as tarefas (%d)" % LiveOps.state(p)["core"])
	var oricalco := int(p["wallet"]["orichalcum"])
	check.call(not LiveOps.open_core(p).is_empty() and int(p["wallet"]["orichalcum"]) == oricalco + 20,
			"Núcleo: abre e paga")
	var now := 1_800_000_000
	check.call(not LiveOps.open_chest(p, now).is_empty() and LiveOps.chest_wait(p, now + 60) > 0, "Baú: abre e espera 6 h")
	check.call(LiveOps.open_chest(p, now + LiveOps.CHEST_SECONDS, 2)["pearls"] == 10, "Baú: dobra com o anúncio")


func _store(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	check.call(not Store.buy(p, "tint_coral"), "Loja: sem pérolas não compra")
	p["wallet"]["pearls"] = 100
	check.call(Store.buy(p, "tint_coral") and int(p["wallet"]["pearls"]) == 60, "Loja: compra com pérolas")
	check.call(not Store.buy(p, "tint_supporter"), "Loja: a pintura do apoiador não se compra")
	Store.equip(p, "tint_coral")
	check.call(Economy.loadout(p)["cosmetic"] == "tint_coral", "Loja: pintura vai para a missão")
	check.call(Store.simulated() == (OS.is_debug_build() and not Engine.has_singleton("GodotGooglePlayBilling")),
			"Loja: só simula a compra em build de desenvolvimento sem o Play Billing")
	check.call(Ads.mode() == "mock" and Store.purchases_enabled() and Store.ads_allowed(p) and Ads.can_show(p),
			"Loja: compra e anúncio visíveis no modo simulado")
	_daily_pearls(check, p)
	check.call(Store.simulated() and Store.support(p) and not Store.ads_allowed(p) and not Ads.can_show(p),
			"Apoiar (simulado): tira os anúncios")
	var q := SaveManagerScript.default_profile()
	q["purchases"]["supporter"] = true
	_daily_pearls(check, q)
	check.call(Store.owned(p, "tint_supporter"), "Apoiar: dá a pintura dourada")
	_admob_rules(check)


## Dobrar as Pérolas do Diário: só no resultado do Diário que pagou, 1 vez por dia, com ou sem anúncio.
func _daily_pearls(check: Callable, p: Dictionary) -> void:
	var tag := "anúncio" if Store.ads_allowed(p) else "apoiador"
	var pearls := int(p["wallet"]["pearls"])
	var out := Modes.apply_result(p, &"daily", {"score": 100, "daily": "2026-11-03", "cleared": true})
	out["mode"] = "daily"
	check.call(not Modes.daily_pearls_doublable(p, {"mode": "", "pearls_gain": 10}),
			"Diário (%s): campanha não dobra Pérolas" % tag)
	check.call(Modes.double_daily_pearls(p, out) and int(out["pearls_gain"]) == 20
			and int(p["wallet"]["pearls"]) == pearls + 20, "Diário (%s): dobra as 10 Pérolas" % tag)
	check.call(not Modes.double_daily_pearls(p, out) and int(p["wallet"]["pearls"]) == pearls + 20,
			"Diário (%s): só 1 vez" % tag)
	var again := Modes.apply_result(p, &"daily", {"score": 200, "daily": "2026-11-03", "cleared": true})
	again["mode"] = "daily"
	check.call(not Modes.daily_pearls_doublable(p, again), "Diário (%s): 2ª tentativa do dia não dobra" % tag)
	var next := Modes.apply_result(p, &"daily", {"score": 100, "daily": "2026-11-04", "cleared": true})
	next["mode"] = "daily"
	check.call(Modes.daily_pearls_doublable(p, next), "Diário (%s): outro dia, dobra de novo" % tag)
	# Apoiador (e Steam, modo "off"): nenhum anúncio, o botão mostra o texto sem anúncio.
	check.call(Ads.can_show(p) == Store.ads_allowed(p), "Diário (%s): anúncio só quando permitido" % tag)


## Regras puras do provedor real (AdMobProvider): IDs reais e o modo de partida.
func _admob_rules(check: Callable) -> void:
	var test_app := "ca-app-pub-3940256099942544~3347511713"
	var real_app := "ca-app-pub-1234567890123456~1234567890"
	var real_unit := {"rewarded": "ca-app-pub-1234567890123456/1234567890"}
	check.call(not AdMobProvider.ids_configured({}, real_app), "AdMob: sem bloco não tem IDs reais")
	check.call(not AdMobProvider.ids_configured(AdMobProvider.TEST_UNITS, test_app), "AdMob: IDs de teste não valem")
	check.call(not AdMobProvider.ids_configured(real_unit, test_app), "AdMob: app de teste não vale")
	check.call(not AdMobProvider.ids_configured({"rewarded": ""}, real_app), "AdMob: bloco vazio não vale")
	check.call(AdMobProvider.ids_configured(real_unit, real_app), "AdMob: bloco e app reais valem")
	check.call(AdMobProvider.has_release_ids(), "AdMob: este jogo tem IDs reais (release liga o anúncio)")
	check.call(String(ProjectSettings.get_setting(AdMobProvider.APP_ID_SETTING, "")) \
			== "ca-app-pub-6552169828297838~1447443371", "AdMob: project.godot tem o ID real do app")
	check.call(AdMobProvider.startup_provider(true, false, true) == "admob", "AdMob: debug com o SDK usa IDs de teste")
	check.call(AdMobProvider.startup_provider(false, true, true) == "admob", "AdMob: release com IDs reais e SDK")
	check.call(AdMobProvider.startup_provider(false, false, true) == "off", "AdMob: release sem IDs reais fica off")
	check.call(AdMobProvider.startup_provider(false, true, false) == "off", "AdMob: release sem o SDK fica off")
	check.call(AdMobProvider.startup_provider(true, false, false) == "mock", "AdMob: debug sem o SDK simula")
	check.call(AdMobProvider.unit("rewarded") == AdMobProvider.TEST_UNITS["rewarded"], "AdMob: debug usa o bloco de teste")
	# Consentimento (UMP): SDK e anúncio só com o consentimento obtido ou dispensado.
	check.call(AdMobProvider.consent_allows_ads(ConsentInformation.ConsentStatus.OBTAINED)
			and AdMobProvider.consent_allows_ads(ConsentInformation.ConsentStatus.NOT_REQUIRED),
			"AdMob: consentimento obtido ou dispensado libera o anúncio")
	check.call(not AdMobProvider.consent_allows_ads(ConsentInformation.ConsentStatus.REQUIRED)
			and not AdMobProvider.consent_allows_ads(ConsentInformation.ConsentStatus.UNKNOWN),
			"AdMob: consentimento exigido e não obtido (ou UMP sem resposta) fica sem anúncio")
	# Desfecho do anúncio real: só a recusa do jogador nega; falha técnica vale como "sem anúncio".
	check.call(Ads.rewarded_granted(Ads.EARNED, true) and Ads.rewarded_granted(Ads.EARNED, false),
			"Anúncio: assistido até o fim recompensa")
	check.call(not Ads.rewarded_granted(Ads.DECLINED, true), "Anúncio: fechado antes do fim não recompensa")
	check.call(Ads.rewarded_granted(Ads.FAILED, true), "Anúncio: falha ao abrir (ou sem anúncio) recompensa de presente")
	check.call(not Ads.rewarded_granted(Ads.FAILED, false),
			"Anúncio: recompensa já recusada não sai de graça enquanto o próximo anúncio não carrega")
	check.call(not Ads.rewarded_granted(Ads.LOST, true), "Anúncio: preso sem callback libera sem recompensa")
	# "consent" do save nunca foi lido (o UMP guarda a escolha): sai do perfil novo e do save antigo.
	var old := SaveManagerScript.default_profile()
	old["consent"] = {"asked": true, "personalized": false}
	check.call(not SaveManagerScript.default_profile().has("consent")
			and not SaveManagerScript.migrate(old).has("consent"), "Save: sem a chave 'consent' sem uso")


func _city_and_endings(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	var ships := DB.rows("ships")
	var wings := DB.rows("wings")
	var r := Economy.apply_result(p, {"mission": "c1m1", "cleared": true, "score": 0, "stars": [true, false, false, false],
			"rescued": 12}, ships, wings)
	check.call(&"docks" in r["new_districts"], "Cidade: 10 resgatados reerguem as Docas")
	check.call(is_equal_approx(Economy.district_bonus(p, &"credits"), 0.1), "Cidade: Docas dão +10% de créditos")
	p["rescued_total"] = 100
	check.call(int(Economy.loadout(p)["bombs"]) == 1, "Cidade: Templo dá +1 bomba")
	check.call(Economy.ship_level_cost(1, p) < Economy.ship_level_cost(1), "Cidade: Forja dá desconto na oficina")
	Economy.apply_result(p, {"mission": "c9m3", "cleared": true, "score": 0, "stars": [true, false, false, false],
			"ending": "return"}, ships, wings)
	p["story"]["seen"] = ["prologue", "act1_atlantis", "act1_end", "act2_end", "act3_end"]
	var story := StoryScreen.pending(p)
	check.call(String(story.get("id", "")) == "ending_return",
			"Finais: o final escolhido abre a cena (%s)" % story.get("id"))
	var tables := Sim.load_tables()
	var fin := _bot(Sim.load_mission(&"c9m3"), tables)
	check.call(String(fin["result"]["ending"]) in ["return", "shattered"], "Finais: o voo do bot escolhe um final")
	var loadout := Sim.default_loadout(&"falcon")
	loadout["abyss_records"] = 4
	var sim := Sim.new()
	sim.setup(Sim.load_mission(&"c9m3"), tables, loadout, 7)
	var bot := BotPilot.new()
	while not sim.finished and sim.frame < 60 * 60 * 10:
		sim.step(bot.decide(sim))
	check.call(sim.ending == &"high_tide", "Finais: os 4 Registros Abissais levam ao final verdadeiro")
