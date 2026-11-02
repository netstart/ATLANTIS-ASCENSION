extends RefCounted
## Montagem das telas (1.14.5): cada abertura monta a lista uma vez só (antes, o _ready e o on_show
## montavam duas vezes na primeira abertura); reabrir com dado novo mostra o dado novo; trocar de idioma
## com a tela escondida não remonta nada até ela abrir de novo, e com a tela aberta remonta uma vez.
## Chamado por tests/integration_tests.gd.

const LayoutTests := preload("res://tests/layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const LISTS: Array[StringName] = [&"hangar", &"ships", &"options", &"logbook", &"events", &"shop", &"city",
		&"practice", &"season", &"records"]


func run(host: Node, check: Callable) -> void:
	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	LayoutTests.fit(app, DeviceProfiles.main_view())

	for screen_name: StringName in LISTS:
		app.go(screen_name)
		await LayoutTests.settle(host)
		check.call(_fills(app, screen_name) == 1,
				"Montagem: %s monta a lista uma vez na primeira abertura (%d)" % [screen_name, _fills(app, screen_name)])
		app.go(&"hub")
		await LayoutTests.settle(host)
		app.go(screen_name)
		await LayoutTests.settle(host)
		check.call(_fills(app, screen_name) == 2,
				"Montagem: %s monta uma vez a cada abertura (%d em 2)" % [screen_name, _fills(app, screen_name)])

	# Dado novo com a tela escondida: a reabertura mostra o nível e o saldo de agora.
	app.go(&"hub")
	await LayoutTests.settle(host)
	SaveManager.data["hangar"]["ship_levels"]["falcon"] = 3
	SaveManager.add_currency("credits", Economy.ship_level_cost(3))
	app.go(&"hangar")
	await LayoutTests.settle(host)
	var hangar := app.screen(&"hangar")
	var hero := hangar.find_child("HeroShip", true, false)
	var upgrade := hangar.find_child("UpgradeShip", true, false) as Button
	check.call(hero != null and int(hero.get("level")) == 3, "Montagem: o hangar reaberto mostra o nível novo da nave")
	check.call(upgrade != null and not upgrade.disabled, "Montagem: o hangar reaberto vê os créditos novos")
	var wallet := (hangar.get("_wallet_values") as Dictionary)["credits"] as Label
	check.call(wallet.text == Locale.format_number(SaveManager.currency("credits")),
			"Montagem: as moedas do hangar reaberto mostram o saldo novo")

	# Resultado novo: a tela de resultados reaberta mostra o desfecho da última partida.
	app.last_result = {"mission": "c1m1", "cleared": true, "score": 1000, "stars": [true, false, false, false]}
	app.go(&"results")
	await LayoutTests.settle(host)
	var results := app.screen(&"results")
	check.call(results.default_focus().name == "Continue", "Montagem: resultado da vitória abre no Continuar")
	app.go(&"hub")
	await LayoutTests.settle(host)
	app.last_result = {"mission": "c1m2", "cleared": false, "score": 10, "stars": [false, false, false, false]}
	app.go(&"results")
	await LayoutTests.settle(host)
	var failed := (results.get("_title") as Label).text == tr_in("results.failed")
	check.call(results.default_focus().name == "Retry" and failed,
			"Montagem: os resultados reabertos mostram a derrota nova")

	# Idioma trocado com as listas escondidas: nada remonta agora; cada uma remonta uma vez ao abrir.
	app.go(&"hub")
	await LayoutTests.settle(host)
	var before := {}
	for screen_name: StringName in LISTS:
		before[screen_name] = _fills(app, screen_name)
	Locale.set_language("en", false)
	await LayoutTests.settle(host)
	var still := true
	for screen_name: StringName in LISTS:
		still = still and _fills(app, screen_name) == int(before[screen_name])
	check.call(still, "Montagem: trocar de idioma não remonta as listas escondidas")
	check.call((app.screen(&"hub").find_child("Logbook", true, false) as Button).text == tr_in("logbook.title"),
			"Montagem: a tela aberta troca de idioma na hora")
	app.go(&"hangar")
	await LayoutTests.settle(host)
	check.call(_fills(app, &"hangar") == int(before[&"hangar"]) + 1,
			"Montagem: a lista escondida remonta uma vez ao abrir depois da troca de idioma")
	check.call((hangar.get("_title") as Label).text == tr_in("hangar.title"),
			"Montagem: a lista reaberta já no idioma novo")
	app.go(&"credits")
	await LayoutTests.settle(host)
	var credits_back := app.screen(&"credits").find_child("Back", true, false) as Button
	check.call(credits_back != null and credits_back.text == tr_in("credits.back"),
			"Montagem: os créditos reabertos já no idioma novo")
	app.go(&"results")
	await LayoutTests.settle(host)
	check.call((results.get("_title") as Label).text == tr_in("results.failed"),
			"Montagem: os resultados reabertos já no idioma novo")

	# Idioma trocado com a lista aberta: remonta uma vez, na hora.
	app.go(&"options")
	await LayoutTests.settle(host)
	var opened := _fills(app, &"options")
	Locale.set_language("pt_BR", false)
	await LayoutTests.settle(host)
	check.call(_fills(app, &"options") == opened + 1, "Montagem: a lista aberta remonta uma vez ao trocar de idioma")
	check.call((app.screen(&"options").get("_title") as Label).text == tr_in("options.title"),
			"Montagem: a lista aberta mostra o idioma novo")
	app.queue_free()
	await host.get_tree().process_frame
	SaveManager.reset_profile()


static func tr_in(key: String) -> String:
	return TranslationServer.translate(key)


static func _fills(app: App, screen_name: StringName) -> int:
	var screen := app.screen(screen_name)
	return int(screen.get("fills")) if screen != null else -1
