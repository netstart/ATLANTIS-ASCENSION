extends RefCounted
## Menus de comando (1.15): regras do Poder, do recomendado por capítulo, do nível da piloto e dos avisos
## (Notices), e a casca de navegação (NavShell) de ponta a ponta — abas sem histórico, voltar de uma aba
## para a Campanha e da Campanha ao título, LB/RB, Opções e moedas pela casca, área útil das telas-aba
## entre as barras e a bolinha de aviso que some quando o jogador age. Chamado por
## tests/integration_tests.gd (precisa do perfil padrão do SaveManager).

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const TODAY := "2026-11-02"
const NOW := 1_800_000_000


func run(check: Callable) -> void:
	_power(check)
	_pilot(check)
	_notices(check)


func _power(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	var ships := DB.rows("ships")
	var wings := DB.rows("wings")
	check.call(Economy.power(p, ships, wings) == 1000, "Poder: Falcon nível 1 sem nada = 1.000")
	check.call(Economy.power(p) == Economy.power(p, ships, wings), "Poder: sem as tabelas lê data/ e dá o mesmo")
	var last := Economy.power(p, ships, wings)
	for level: int in range(2, Economy.SHIP_MAX_LEVEL + 1):
		p["hangar"]["ship_levels"]["falcon"] = level
		var now := Economy.power(p, ships, wings)
		check.call(now > last, "Poder: nível %d da nave sobe o Poder (%d > %d)" % [level, now, last])
		last = now
	check.call(Economy.core_power(6) - Economy.core_power(5) == Economy.POWER_PER_LEVEL + Economy.POWER_HULL,
			"Poder: o casco extra do nível 6 conta")
	p["hangar"]["modules"]["missiles"] = 3
	check.call(Economy.power(p, ships, wings) == last, "Poder: secundária guardada não conta")
	p["selected"]["secondary"] = "missiles"
	var with_secondary := Economy.power(p, ships, wings)
	check.call(with_secondary == last + Economy.secondary_power(3), "Poder: secundária equipada soma o nível dela")
	p["selected"]["wings"] = ["wing_bubble"]
	check.call(Economy.power(p, ships, wings) == with_secondary + 400 + 25 * 6,
			"Poder: asa equipada soma 400 + 25 x estrelas")
	# Tudo no máximo: nave, secundária e as duas asas mais caras, na melhor aeronave.
	p["hangar"]["modules"]["missiles"] = Economy.SECONDARY_MAX_LEVEL
	p["selected"]["wings"] = ["wing_tide", "wing_slip"]
	var top := 0
	for row: Variant in ships:
		p["selected"]["ship"] = String((row as Dictionary)["id"])
		p["hangar"]["ship_levels"][String((row as Dictionary)["id"])] = Economy.SHIP_MAX_LEVEL
		top = maxi(top, Economy.power(p, ships, wings))
	check.call(top >= 17000 and top <= 23000, "Poder: tudo no máximo fica perto de 20.000 (%d)" % top)
	for row: Variant in ships:
		var f := Economy.ship_factor(row as Dictionary)
		check.call(f >= 0.9 and f <= 1.15, "Poder: fator da %s entre 0,9 e 1,15 (%.2f)" % [row["id"], f])
	check.call(is_equal_approx(Economy.ship_factor(DB.ship(&"falcon")), 1.0), "Poder: Falcon é a régua (fator 1,0)")
	var a := Economy.power(p, ships, wings)
	check.call(a == Economy.power(p, ships, wings), "Poder: determinístico")
	# Recomendado: começa em 1.000, nunca desce e sobe aos poucos (curva suave).
	check.call(Economy.recommended_power(1) == 1000, "Recomendado: capítulo 1 = 1.000")
	for c: int in range(2, 11):
		var step := Economy.recommended_power(c) - Economy.recommended_power(c - 1)
		check.call(step >= 0 and step <= 1500, "Recomendado: capítulo %d sobe suave (+%d)" % [c, step])
	check.call(Economy.mission_recommended_power(&"c4m2") == Economy.recommended_power(4),
			"Recomendado: missão usa o do capítulo")
	check.call(Economy.recommended_power(99) == Economy.recommended_power(10),
			"Recomendado: capítulo fora da faixa é limitado")


func _pilot(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	check.call(Economy.pilot(p) == {"level": 1, "xp": 0, "need": Economy.pilot_step(1)}, "Piloto: perfil novo no nível 1")
	p["missions"]["c1m1"] = {"stars": [true, true, true, true], "best_score": 1, "cleared": true, "route": ""}
	p["stats"]["missions_cleared"] = 1
	p["stats"]["kills"] = 95.0
	check.call(Economy.pilot_xp(p) == 400 + 40 + 9, "Piloto: XP = 100/estrela + 40/vitória + 1/10 abates")
	var info := Economy.pilot(p)
	check.call(int(info["level"]) == 2 and int(info["xp"]) == 449 - Economy.pilot_step(1),
			"Piloto: 449 de XP dá nível 2 com o resto na barra (%s)" % info)
	p["stats"]["kills"] = 1.0e9
	check.call(int(Economy.pilot(p)["level"]) == Economy.PILOT_MAX_LEVEL, "Piloto: para no nível 99")


func _notices(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	p["login"]["last_date"] = TODAY
	p["live"] = {"daily_date": TODAY, "daily": [], "week": "", "weekly": [], "core": 0, "chest_at": NOW + 60}
	p["story"]["seen"] = ["prologue"]
	for tab: StringName in NavShell.TABS:
		check.call(not Notices.for_tab(p, tab, TODAY, NOW), "Avisos: perfil em dia sem aviso em %s" % tab)
	# Loja: baú grátis.
	check.call(Notices.for_tab(p, &"shop", TODAY, NOW + 60), "Avisos: baú grátis pronto acende a Loja")
	# Oficina: créditos para subir a nave.
	p["wallet"]["credits"] = Economy.ship_level_cost(1)
	check.call(Notices.can_upgrade_ship(p) and Notices.for_tab(p, &"hangar", TODAY, NOW), "Avisos: dá para subir a nave")
	p["wallet"]["credits"] = 0
	p["hangar"]["ship_levels"]["falcon"] = Economy.SHIP_MAX_LEVEL
	p["wallet"]["credits"] = 999999
	check.call(not Notices.can_upgrade_ship(p), "Avisos: nave no máximo não acende")
	check.call(Notices.can_upgrade_secondary(p), "Avisos: secundária para comprar acende")
	p["wallet"]["credits"] = 0
	# Asa: aberta pelas estrelas e com encaixe livre.
	p["missions"]["c1m1"] = {"stars": [true, true, true, false], "best_score": 1, "cleared": true, "route": ""}
	check.call(Notices.wing_slot_open(p), "Avisos: asa nova com encaixe livre acende a Oficina")
	p["selected"]["wings"] = ["wing_magnet"]
	check.call(not Notices.wing_slot_open(p), "Avisos: asa já equipada apaga")
	# Campanha: cena de história esperando (fim do Ato depois da 1-3).
	check.call(not Notices.story_pending(p), "Avisos: sem cena nova")
	p["missions"]["c1m3"] = {"stars": [true, false, false, false], "best_score": 1, "cleared": true, "route": ""}
	check.call(Notices.for_tab(p, &"hub", TODAY, NOW), "Avisos: cena da história acende a Campanha")
	# Naves: aeronave aberta e ainda não vista; abrir a coleção apaga.
	(p["unlocked"]["ships"] as Array).append("manta")
	check.call(Notices.unseen_ships(p) == ["manta"] and Notices.for_tab(p, &"ships", TODAY, NOW),
			"Avisos: aeronave nova acende Naves")
	check.call(Notices.mark_ships_seen(p) and not Notices.for_tab(p, &"ships", TODAY, NOW),
			"Avisos: ver a coleção apaga o aviso")
	check.call(not Notices.mark_ships_seen(p), "Avisos: marcar de novo não muda nada")
	var old := SaveManager.migrate({"version": 1, "unlocked": {"ships": ["falcon"]}})
	check.call(Notices.unseen_ships(old).is_empty(), "Avisos: save antigo começa com a Falcon vista")
	# Eventos: login, tarefa pronta, Núcleo cheio, nível do passe e Desafio Diário.
	check.call(Notices.login_unclaimed(p, "2026-11-03"), "Avisos: dia novo sem entrada acende Eventos")
	p["live"]["daily"] = [{"id": "kills", "stat": "kills", "goal": 10, "progress": 10, "claimed": false}]
	check.call(Notices.tasks_claimable(p) and Notices.for_tab(p, &"events", TODAY, NOW), "Avisos: tarefa pronta")
	p["live"]["daily"][0]["claimed"] = true
	check.call(not Notices.tasks_claimable(p), "Avisos: tarefa resgatada apaga")
	p["live"]["core"] = LiveOps.CORE_MAX
	check.call(Notices.core_ready(p), "Avisos: Núcleo cheio")
	p["live"]["core"] = 0
	p["season"] = {"id": Season.id_for(TODAY), "xp": 250, "claimed": [1], "premium": false, "premium_claimed": []}
	check.call(Notices.season_reward_ready(p, TODAY), "Avisos: nível do passe para resgatar")
	p["season"]["claimed"] = [1, 2]
	check.call(not Notices.season_reward_ready(p, TODAY), "Avisos: passe em dia apaga")
	check.call(not Notices.season_reward_ready(p, "2027-02-01"), "Avisos: temporada passada não acende")
	check.call(not Notices.daily_event_open(p, TODAY), "Avisos: Desafio Diário fechado não acende")
	p["missions"]["c2m1"] = {"stars": [true, false, false, false], "best_score": 1, "cleared": true, "route": ""}
	check.call(Notices.daily_event_open(p, TODAY), "Avisos: Desafio Diário aberto e não jogado acende")
	p["daily"] = {"date": TODAY, "best_score": 10, "attempted": true}
	check.call(not Notices.daily_event_open(p, TODAY), "Avisos: Desafio Diário jogado hoje apaga")
	check.call(Notices.tabs(p, NavShell.TABS, TODAY, NOW) == [&"hub"], "Avisos: lista de abas com aviso")


## Casca de navegação no App, de ponta a ponta.
func run_view(host: Node, check: Callable) -> void:
	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)
	InputSetup.ensure_actions()
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	LayoutTests.fit(app, DeviceProfiles.main_view())
	var shell := app.shell()
	app.go(&"boot")
	await LayoutTests.settle(host)
	check.call(not shell.visible, "Casca: escondida no título")
	app.go(&"hub")
	await LayoutTests.settle(host)
	check.call(shell.visible and shell.current == &"hub", "Casca: aparece na Campanha")
	check.call(shell.get_index() == app.root().get_child_count() - 1, "Casca: por cima das telas")
	var hub := app.screen(&"hub")
	var insets := hub.shell_insets()
	check.call(insets.x > 0.0 and insets.y > 0.0 and is_equal_approx(hub.safe.position.y, insets.x),
			"Casca: a Campanha recebe a área útil já sem as barras (%s)" % insets)
	for tab: StringName in [&"shop", &"hangar", &"ships", &"events"]:
		shell.tab_button(tab).pressed.emit()
		await LayoutTests.settle(host)
		check.call(app.current == tab and shell.visible and shell.current == tab, "Casca: a aba %s abre" % tab)
		var screen := app.screen(tab) as ListScreen
		check.call(screen.in_shell() and not screen.find_child("Back", true, false).is_visible_in_tree(),
				"Casca: %s sem Voltar" % tab)
		check.call(not screen.find_child("Wallet", true, false).is_visible_in_tree(), "Casca: %s sem moedas próprias" % tab)
		# A Oficina abre direto no palco da nave (a aba de baixo já diz onde se está): sem faixa de título.
		check.call(screen.find_child("Ribbon", true, false).is_visible_in_tree() == (tab != &"hangar"),
				"Casca: %s com a faixa do título (Oficina sem)" % tab)
	app.back()
	await LayoutTests.settle(host)
	check.call(app.current == &"hub", "Casca: voltar numa aba leva à Campanha, sem passar pelas outras abas")
	app.back()
	await LayoutTests.settle(host)
	check.call(app.current == &"boot" and not shell.visible, "Casca: voltar na Campanha leva ao título")
	app.go(&"hub")
	await LayoutTests.settle(host)
	# LB/RB (Q/E): a aba da direita da Campanha é Naves; a da esquerda, Oficina.
	_press(&"tab_next")
	await LayoutTests.settle(host)
	check.call(app.current == &"ships", "Casca: RB vai para a aba da direita")
	_press(&"tab_prev")
	await LayoutTests.settle(host)
	_press(&"tab_prev")
	await LayoutTests.settle(host)
	check.call(app.current == &"hangar", "Casca: LB volta duas abas para a Oficina")
	# Opções pela engrenagem: tela comum, com Voltar e sem a casca; voltar retorna à aba.
	(shell.find_child("Options", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(app.current == &"options" and not shell.visible, "Casca: a engrenagem abre as Opções sem a casca")
	app.back()
	await LayoutTests.settle(host)
	check.call(app.current == &"hangar" and shell.visible, "Casca: voltar das Opções devolve a aba")
	# Moeda: tocar a pílula leva à Loja.
	(shell.find_child("Pill_pearls", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(app.current == &"shop", "Casca: a pílula da moeda leva à Loja")
	# Aviso: aeronave nova acende Naves; abrir a coleção apaga.
	SaveManager.unlock("ships", &"manta")
	SaveManager.save_profile()
	await LayoutTests.settle(host)
	var ships_tab := shell.tab_button(&"ships")
	check.call(bool(ships_tab.call("has_notice")), "Casca: aeronave nova acende a bolinha de Naves")
	ships_tab.pressed.emit()
	await LayoutTests.settle(host)
	app.go(&"hub")
	await LayoutTests.settle(host)
	check.call(not bool(ships_tab.call("has_notice")), "Casca: abrir Naves apaga a bolinha")
	app.queue_free()
	await host.get_tree().process_frame
	SaveManager.reset_profile()
	await _kit(host, check)


## Peças do CommandKit: tamanhos mínimos de toque, aviso que liga e desliga, cores do selo do Poder.
func _kit(host: Node, check: Callable) -> void:
	var box := Control.new()
	host.add_child(box)
	var tile := CommandKit.item_tile(ListScreen.icon(&"ship"), 7, CommandKit.LEGENDARY, true)
	var slot := CommandKit.slot()
	var ribbon := CommandKit.ribbon("Oficina")
	var chip := CommandKit.stat_chip(&"bolt", "Dano", "1.240")
	var low := CommandKit.power_badge(1000, 2400)
	var high := CommandKit.power_badge(3000, 2400)
	for node: Control in [tile, slot, ribbon, chip, low, high]:
		box.add_child(node)
	await host.get_tree().process_frame
	check.call(tile.get_combined_minimum_size().y >= UiTheme.TOUCH_MIN and slot.get_combined_minimum_size().y
			>= UiTheme.TOUCH_MIN, "Kit: ladrilho e encaixe com alvo de toque")
	var dot := tile.find_child("Notice", true, false) as Control
	check.call(dot != null and dot.visible, "Kit: ladrilho com aviso mostra a bolinha")
	tile.notice = false
	check.call(not dot.visible, "Kit: aviso desligado esconde a bolinha")
	check.call(CommandKit.rarity_color(CommandKit.LEGENDARY) == UiTheme.GOLD
			and CommandKit.rarity_color(CommandKit.EPIC) == UiTheme.VIOLET, "Kit: lendária dourada, épica violeta")
	check.call(ribbon.label().text == "OFICINA" and ribbon.get_combined_minimum_size().x
			> ribbon.label().get_minimum_size().x, "Kit: faixa cabe o título")
	var color_of := func(badge: Control) -> Color:
		return (badge.find_child("Value", true, false) as Label).get_theme_color("font_color")
	check.call(color_of.call(low) == UiTheme.CORAL and color_of.call(high) == UiTheme.MINT,
			"Kit: Poder abaixo do recomendado em coral, acima em menta")
	check.call(low.find_child("Recommended", true, false) != null, "Kit: selo mostra o recomendado")
	box.queue_free()
	await host.get_tree().process_frame


static func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
