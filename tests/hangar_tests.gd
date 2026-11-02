extends RefCounted
## Oficina dos menus de comando (1.15, HangarScreen): o palco com os seis encaixes, as sub-abas, a grade
## e o cartão de detalhe em todas as resoluções (com o furo da câmera, nos idiomas mais longos), e o
## fluxo pela interface nova — evoluir a nave, comprar, equipar e evoluir a secundária, equipar e tirar
## asas (com o limite), escolher dificuldade e pintura, encaixe que abre a sub-aba, B que fecha o
## cartão. Chamado por tests/integration_tests.gd.

const LayoutTests := preload("res://tests/layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")


func run_view(host: Node, check: Callable) -> void:
	for c: Dictionary in DeviceProfiles.layout_cases():
		await run_layout_case(host, check, c)
	await run_flow(host, check)


## Um caso de tests/device_profiles.gd nos idiomas longos dele. Unidade das fatias de
## tests/integration_tests.gd (cada caso começa do mesmo perfil e deixa o estado global limpo).
func run_layout_case(host: Node, check: Callable, c: Dictionary) -> void:
	SaveManager.reset_profile()
	mid_profile(SaveManager.data)
	await _layout_case(host, check, c)
	DeviceProfiles.clear_insets()
	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)


## O fluxo pela interface nova (evoluir, comprar, equipar...). Unidade das fatias.
func run_flow(host: Node, check: Callable) -> void:
	await _flow(host, check)
	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)


## Jogador no meio do caminho: nave 6, mísseis 3 equipados, duas asas, 12 estrelas e uma pintura.
static func mid_profile(p: Dictionary) -> void:
	for i: int in range(3):
		p["missions"]["c1m%d" % (i + 1)] = {"stars": [true, true, true, true], "best_score": 50_000, "cleared": true,
				"route": ""}
	p["wallet"] = {"credits": 3_200, "orichalcum": 20, "pearls": 90}
	p["hangar"]["ship_levels"]["falcon"] = 6
	p["hangar"]["modules"]["missiles"] = 3
	p["selected"]["secondary"] = "missiles"
	p["selected"]["wings"] = ["wing_magnet", "wing_bubble"]
	(p["unlocked"]["cosmetics"] as Array).append("tint_coral")


func _layout_case(host: Node, check: Callable, c: Dictionary) -> void:
	var view: Vector2 = c["view"]
	var safe := DeviceProfiles.safe_rect(view, c["insets"])
	DeviceProfiles.simulate_insets(c["insets"])
	for lang: String in Languages.INSET_LANGS:
		if not lang in c["langs"]:
			continue
		Locale.set_language(lang, false)
		var app := App.new()
		host.add_child(app)
		await host.get_tree().process_frame
		LayoutTests.fit(app, view)
		app.go(&"hangar")
		await LayoutTests.settle(host)
		var hangar := app.screen(&"hangar") as HangarScreen
		var tag := "Oficina %s [%s]" % [lang, c["label"]]
		var slots := hangar.find_children("Slot_*", "Button", true, false)
		check.call(slots.size() == 6, "%s: seis encaixes no palco" % tag)
		for s: Node in slots:
			check.call(safe.grow(0.5).encloses((s as Control).get_global_rect()),
					"%s: encaixe %s inteiro na área segura" % [tag, s.name])
		var grid := hangar.find_child("Items", true, false) as GridContainer
		var cols := grid.columns
		var narrow := view.x <= 300.0
		check.call(cols >= 4 and (not narrow or cols == 4), "%s: grade com %d colunas" % [tag, cols])
		# Cada sub-aba com o primeiro ladrilho aberto no cartão: tudo dentro da área, nada cortado.
		for tab: StringName in HangarScreen.TABS:
			(hangar.find_child("Tab_" + String(tab), true, false) as Button).pressed.emit()
			var first := hangar.find_child("Items", true, false).get_child(0).get_child(0) as Button
			first.pressed.emit()
			await LayoutTests.settle(host)
			var panel := hangar.find_child("Detail", false, false) as PanelContainer
			check.call(panel.visible, "%s %s: o ladrilho abre o cartão" % [tag, tab])
			check.call(safe.grow(0.5).encloses(panel.get_global_rect()),
					"%s %s: cartão inteiro na área segura (%s)" % [tag, tab, panel.get_global_rect()])
			check.call(panel.get_global_rect().end.y <= hangar.safe.end.y + 0.5,
					"%s %s: cartão acima da barra de abas" % [tag, tab])
			for node: Node in panel.find_children("*", "Button", true, false):
				var b := node as Button
				check.call(b.size.y >= UiTheme.TOUCH_MIN - 0.5, "%s %s: %s com alvo de toque" % [tag, tab, b.name])
				var line := b.find_child("Title", true, false) as Label
				if line != null:
					check.call((line.get_parent() as Control).get_combined_minimum_size().x <= b.size.x + 0.5,
							"%s %s: texto e preço de %s cabem" % [tag, tab, b.name])
			hangar.back()
			await LayoutTests.settle(host)
			check.call(not panel.visible, "%s %s: B fecha o cartão" % [tag, tab])
		for b: Node in hangar.find_children("Tab_*", "Button", true, false):
			check.call((b as Button).size.y >= UiTheme.TOUCH_MIN - 0.5, "%s: sub-aba %s com alvo" % [tag, b.name])
		app.queue_free()
		await host.get_tree().process_frame


func _flow(host: Node, check: Callable) -> void:
	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)
	var p := SaveManager.data
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	LayoutTests.fit(app, DeviceProfiles.main_view())
	app.go(&"hangar")
	await LayoutTests.settle(host)
	var hangar := app.screen(&"hangar") as HangarScreen
	var press := func(button_name: String) -> bool:
		var b := hangar.find_child(button_name, true, false) as Button
		if b == null or b.disabled:
			return false
		b.pressed.emit()
		return true
	# Sem dinheiro: o botão dourado existe, desabilitado, e o preço continua claro (não escuro no escuro).
	var upgrade := hangar.find_child("UpgradeShip", true, false) as Button
	check.call(upgrade != null and upgrade.disabled, "Oficina: sem créditos, Evoluir fica desabilitado")
	var price := upgrade.find_child("Price_credits", true, false) as Label
	check.call(price != null and price.get_theme_color("font_color").get_luminance() > 0.5,
			"Oficina: preço sem dinheiro continua claro")
	SaveManager.add_currency("credits", 20_000)
	SaveManager.add_currency("orichalcum", 40)
	hangar.refill()
	check.call(hangar.find_child("Notice", true, false) != null, "Oficina: aviso quando dá para evoluir")
	check.call(press.call("UpgradeShip") and Economy.ship_level(p, &"falcon") == 2,
			"Oficina: Evoluir nave sobe a Falcon")
	check.call(hangar.find_child("NewPart", true, false) != null, "Oficina: a subida mostra o selo da peça")
	# Peça da evolução: a próxima abre no cartão com o botão de evoluir.
	(hangar.find_child("Item_nav_lights", true, false) as Button).pressed.emit()
	check.call(press.call("UpgradePart") and Economy.ship_level(p, &"falcon") == 3,
			"Oficina: Evoluir pelo cartão da peça")
	# Arma: o encaixe abre a sub-aba Armas; comprar equipa; tirar e pôr; evoluir.
	(hangar.find_child("Slot_weapon", true, false) as Button).pressed.emit()
	check.call(hangar.find_child("Item_missiles", true, false) != null, "Oficina: encaixe da arma abre Armas")
	(hangar.find_child("Item_missiles", true, false) as Button).pressed.emit()
	check.call(press.call("BuySecondary") and Economy.secondary_level(p, &"missiles") == 1
			and String(p["selected"]["secondary"]) == "missiles", "Oficina: comprar mísseis equipa")
	check.call(press.call("EquipSecondary") and String(p["selected"]["secondary"]).is_empty(),
			"Oficina: Remover desequipa a secundária")
	check.call(press.call("EquipSecondary") and String(p["selected"]["secondary"]) == "missiles",
			"Oficina: Equipar devolve a secundária")
	check.call(press.call("UpgradeSecondary") and Economy.secondary_level(p, &"missiles") == 2,
			"Oficina: Evoluir a secundária com créditos e oricalco")
	check.call((hangar.find_child("Slot_weapon", true, false) as Node).find_child("SlotMark", true, false) != null,
			"Oficina: encaixe da arma mostra a moldura")
	# Asas: trancadas sem estrelas; com estrelas, duas cabem e a terceira espera.
	(hangar.find_child("Tab_wings", true, false) as Button).pressed.emit()
	(hangar.find_child("Item_wing_magnet", true, false) as Button).pressed.emit()
	check.call(hangar.find_child("EquipWing", true, false) == null, "Oficina: asa trancada não equipa")
	for i: int in range(3):
		p["missions"]["c1m%d" % (i + 1)] = {"stars": [true, true, true, true], "cleared": true, "best_score": 1,
				"route": ""}
	hangar.refill()
	check.call(press.call("EquipWing") and (p["selected"]["wings"] as Array).has("wing_magnet"),
			"Oficina: equipar a asa do ímã")
	(hangar.find_child("Item_wing_bubble", true, false) as Button).pressed.emit()
	check.call(press.call("EquipWing") and (p["selected"]["wings"] as Array).size() == 2, "Oficina: segunda asa")
	(hangar.find_child("Item_wing_rear", true, false) as Button).pressed.emit()
	check.call(not press.call("EquipWing") and (p["selected"]["wings"] as Array).size() == Economy.MAX_WINGS,
			"Oficina: terceira asa espera um encaixe livre")
	(hangar.find_child("Item_wing_magnet", true, false) as Button).pressed.emit()
	check.call(press.call("EquipWing") and not (p["selected"]["wings"] as Array).has("wing_magnet"),
			"Oficina: Remover tira a asa")
	# Dificuldade e pintura.
	(hangar.find_child("Slot_mode", true, false) as Button).pressed.emit()
	(hangar.find_child("Item_veteran", true, false) as Button).pressed.emit()
	check.call(press.call("PickDifficulty") and String(p["selected"]["difficulty"]) == "veteran",
			"Oficina: escolher Veterano")
	(p["unlocked"]["cosmetics"] as Array).append("tint_coral")
	(hangar.find_child("Slot_paint", true, false) as Button).pressed.emit()
	(hangar.find_child("Item_tint_coral", true, false) as Button).pressed.emit()
	check.call(press.call("EquipPaint") and String(p["selected"]["cosmetic"]) == "tint_coral",
			"Oficina: equipar pintura possuída")
	if not Store.is_steam():
		(hangar.find_child("Item_tint_kelp", true, false) as Button).pressed.emit()
		check.call(hangar.find_child("GoShop", true, false) != null, "Oficina: pintura nova leva à Loja")
	check.call(hangar.back() and not (hangar.find_child("Detail", false, false) as Control).visible,
			"Oficina: Voltar fecha o cartão")
	# Controle: abrir um ladrilho leva o foco à ação do cartão; B devolve ao ladrilho.
	var was_pad := FocusNav.pad
	FocusNav.pad = true
	(hangar.find_child("Tab_mode", true, false) as Button).pressed.emit()
	var normal := hangar.find_child("Item_normal", true, false) as Button
	normal.grab_focus()
	normal.pressed.emit()
	await LayoutTests.settle(host)
	var owner := hangar.get_viewport().gui_get_focus_owner()
	check.call(owner != null and String(owner.get_meta(&"focus_key", "")) == "detail:first",
			"Oficina: com o controle, o cartão recebe o foco")
	hangar.back()
	await LayoutTests.settle(host)
	owner = hangar.get_viewport().gui_get_focus_owner()
	check.call(owner != null and owner.name == "Item_normal", "Oficina: B devolve o foco ao ladrilho")
	FocusNav.pad = was_pad
	app.queue_free()
	await host.get_tree().process_frame
