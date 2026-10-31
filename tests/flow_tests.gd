extends RefCounted
## Fluxo de ponta a ponta no Godot (docs/policies/testes.md, E2E): título → hub → prólogo → mapa →
## missão jogada pelo bot até o fim → resultado gravado no save → Tentar de novo → sair pela pausa →
## oficina do hangar (subir nível) → naves → opções → diário. Também confere o contraste das balas
## inimigas contra a água de todos os cenários (≥ 4,5:1).
## Chamado por tests/integration_tests.gd.

const LayoutTests := preload("res://tests/layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")


func run(host: Node, check: Callable) -> void:
	_contrast(check)
	for i: int in range(HangarStage.FACTORS.size() - 1):
		check.call(HangarStage.FACTORS[i] < HangarStage.FACTORS[i + 1], "Parallax: camadas do hub em ordem de profundidade")
	for i: int in range(MapScreen.FACTORS.size() - 1):
		check.call(MapScreen.FACTORS[i] < MapScreen.FACTORS[i + 1], "Parallax: camadas do mapa em ordem de profundidade")

	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	LayoutTests.fit(app, DeviceProfiles.main_view())
	check.call(app.current == &"boot", "Fluxo: começa no título")
	(app.screen(&"boot").find_child("Play", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(app.current == &"hub", "Fluxo: Jogar abre o hub")
	(app.screen(&"hub").find_child("Play", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(app.current == &"story", "Fluxo: JOGAR do hub abre o prólogo na primeira vez")
	var story := app.screen(&"story") as StoryScreen
	var panels := (story.scene.get("panels", []) as Array).size()
	check.call(panels >= 3, "Fluxo: o prólogo tem %d quadros" % panels)
	for i: int in range(panels):
		(story.find_child("Next", true, false) as Button).pressed.emit()
		await LayoutTests.settle(host)
	check.call(app.current == &"map", "Fluxo: o fim do prólogo abre o mapa")
	check.call(StoryScreen.pending(SaveManager.data).is_empty(), "Fluxo: o prólogo não volta a aparecer")
	var map := app.screen(&"map") as MapScreen
	check.call(map.selected == &"c1m1", "Fluxo: o mapa foca a missão 1-1")
	var credits_before := SaveManager.currency("credits")
	app.play(&"c1m1", true, 7, Sim.default_loadout(&"falcon"))
	await host.get_tree().process_frame
	check.call(app.game != null, "Fluxo: a missão começou")
	var bot := BotPilot.new()
	var sim := app.game.sim
	while not sim.finished and sim.frame < 60 * 60 * 10:
		sim.step(bot.decide(sim))
	check.call(sim.cleared, "Fluxo: o bot venceu a missão pela cena")
	var deadline := Time.get_ticks_msec() + 8000
	while app.current != &"results" and Time.get_ticks_msec() < deadline:
		await host.get_tree().process_frame
	check.call(app.current == &"results", "Fluxo: o fim da missão abre o resultado")
	var record := SaveManager.mission_record(&"c1m1")
	check.call(bool(record["cleared"]) and int(record["best_score"]) > 0, "Fluxo: resultado gravado no save")
	check.call(SaveManager.currency("credits") > 0, "Fluxo: créditos ganhos (%d)" % SaveManager.currency("credits"))
	check.call(int(app.last_result.get("credits", 0)) == SaveManager.currency("credits") - credits_before,
			"Fluxo: créditos do resultado = save")
	(app.screen(&"results").find_child("Retry", true, false) as Button).pressed.emit()
	await host.get_tree().process_frame
	check.call(app.game != null, "Fluxo: Tentar de novo começa outra missão")
	app.game.set_paused(true)
	app.game.hud().quit_pressed.emit()
	await LayoutTests.settle(host)
	check.call(app.game == null and app.current == &"map", "Fluxo: sair pela pausa volta ao mapa")
	check.call(Economy.mission_unlocked(SaveManager.data, &"c1m2"), "Fluxo: a 1-2 abriu no mapa")
	app.go(&"hub")
	await LayoutTests.settle(host)
	(app.screen(&"hub").find_child("Tab_hangar", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(app.current == &"hangar", "Fluxo: a aba Hangar abre a oficina")
	SaveManager.add_currency("credits", 5000)
	(app.screen(&"hangar") as ListScreen).refill()
	(app.screen(&"hangar").find_child("UpgradeShip", true, false) as Button).pressed.emit()
	check.call(Economy.ship_level(SaveManager.data, &"falcon") == 2, "Fluxo: subir o nível da Falcon na oficina")
	app.go(&"back")
	await LayoutTests.settle(host)
	(app.screen(&"hub").find_child("Tab_ships", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(app.current == &"ships", "Fluxo: a aba Naves abre a coleção")
	for screen_name: StringName in [&"options", &"logbook"]:
		app.go(&"hub")
		await LayoutTests.settle(host)
		(app.screen(&"hub").find_child(String(screen_name).capitalize(), true, false) as Button).pressed.emit()
		await LayoutTests.settle(host)
		check.call(app.current == screen_name, "Fluxo: o hub abre %s" % screen_name)
	app.queue_free()
	await host.get_tree().process_frame
	SaveManager.reset_profile()


## Contraste WCAG da cor clara de cada bala inimiga contra cada cor da água (≥ 4,5:1).
func _contrast(check: Callable) -> void:
	for k: Dictionary in BulletKinds.ENEMY:
		var tex := SpriteBank.texture(String(k["texture"]))
		check.call(tex != null, "Leitura: textura de %s existe" % k["id"])
		if tex == null:
			continue
		var img := tex.get_image()
		var c := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
		var waters: Array[Color] = []
		for palette: Dictionary in OceanBackdrop.PALETTES.values():
			for key: String in ["deep", "mid", "shoal", "lit"]:
				waters.append(palette[key])
		for palette: String in ["off"] + BulletRenderer.COLORBLIND.keys():
			var tint: Color = (BulletRenderer.COLORBLIND.get(palette, {}) as Dictionary).get(k["id"], Color(1, 1, 1))
			for water: Color in waters:
				var ratio := contrast(c * tint, water)
				check.call(ratio >= 4.5, "Leitura: %s (%s) sobre a água %s com contraste %.1f:1" % [k["id"], palette,
						water.to_html(false), ratio])


static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	var lin: Array[float] = []
	for v: float in ch:
		lin.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
