extends RefCounted
## Aba Campanha (1.15): regras da trilha do capítulo (CampaignTrail: capítulos abertos, nós sem as
## secretas, linhas, marco com prêmio que já existe) e a tela de ponta a ponta — tocar num nó abre o
## cartão, voltar fecha, Jogar começa a missão, setas e deslize trocam de capítulo (só os abertos),
## atalhos e marco levam às telas certas, foco do controle, "reduzir movimento" e o layout de TODOS os
## capítulos (rotas lado a lado incluídas) nas telas mais apertadas e no desktop.
## Chamado por tests/integration_tests.gd.

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
## Telas do layout por capítulo: a mais baixa em retrato (com a câmera em cima), a larga baixa e o desktop.
const LAYOUT_VIEWS: Array[String] = ["270x480", "453x544", "960x540"]


func run(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	check.call(CampaignTrail.open_chapters(p) == [1], "Campanha: perfil novo só com o capítulo 1")
	check.call(CampaignTrail.current_chapter(p) == 1, "Campanha: perfil novo começa no capítulo 1")
	var ids: Array = CampaignTrail.nodes(p, 1).map(func(n: Dictionary) -> StringName: return n["id"])
	check.call(ids == [&"c1m1", &"c1m2", &"c1m3"], "Campanha: trilha do capítulo 1 com as 3 missões (%s)" % [ids])
	var first: Dictionary = CampaignTrail.nodes(p, 1)[0]
	check.call(first["open"] and first["next"] and not CampaignTrail.nodes(p, 1)[1]["open"],
			"Campanha: 1-1 aberta e próxima, 1-2 trancada")
	var two: Array = CampaignTrail.nodes(p, 2).map(func(n: Dictionary) -> StringName: return n["id"])
	check.call(not two.has(&"s1") and two.size() == 3, "Campanha: a secreta fica fora da trilha (%s)" % [two])
	var three: Array = CampaignTrail.nodes(p, 3)
	check.call(three.size() == 4 and CampaignTrail.row_of(&"c3m3s") == 2 and CampaignTrail.row_of(&"c3m3a") == 2,
			"Campanha: as duas rotas do capítulo 3 dividem a linha de cima")
	check.call(CampaignParts.short_label(&"c10m1") == "10-1" and CampaignParts.short_label(&"c3m3s") == "3-3",
			"Campanha: rótulo curto do nó (10-1, 3-3)")
	check.call(MapScreen.node_label(Economy.node(&"c10m2")) == "10-2 ◆", "Mapa: o capítulo 10 tem rótulo certo")
	var ms := CampaignTrail.milestone(p, 1)
	check.call(ms["kind"] == &"ship" and ms["id"] == &"manta" and ms["mission"] == &"c1m3",
			"Campanha: marco do capítulo 1 é a Manta ao vencer a 1-3 (%s)" % [ms])
	var ms4 := CampaignTrail.milestone(p, 4)
	check.call(ms4["kind"] == &"wing" and int(ms4["need"]) == 3 and int(ms4["have"]) == 0,
			"Campanha: sem aeronave no capítulo 4, o marco é a próxima asa pelas estrelas (%s)" % [ms4])
	# Capítulos 1 e 2 vencidos com todas as estrelas: abre o 3, a Manta e a Hydra saem do marco.
	for id: StringName in [&"c1m1", &"c1m2", &"c1m3", &"c2m1", &"c2m2", &"c2m3"]:
		p["missions"][String(id)] = {"stars": [true, true, true, true], "best_score": 1000, "cleared": true, "route": ""}
	p["unlocked"]["ships"] = ["falcon", "manta", "hydra"]
	check.call(CampaignTrail.open_chapters(p) == [1, 2, 3] and CampaignTrail.current_chapter(p) == 3,
			"Campanha: vencer os capítulos 1 e 2 abre o 3 e vai para ele")
	check.call(CampaignTrail.neighbor(p, 3, 1) == 3 and CampaignTrail.neighbor(p, 3, -1) == 2
			and CampaignTrail.neighbor(p, 1, -1) == 1, "Campanha: trocar capítulo só entre os abertos")
	check.call(CampaignTrail.chapter_stars(p, 1) == Vector2i(12, 12), "Campanha: estrelas do capítulo 12/12")
	check.call(CampaignTrail.nodes(p, 1)[2]["stars"] == 4, "Campanha: o nó guarda as estrelas ganhas")
	var ms1 := CampaignTrail.milestone(p, 1)
	check.call(ms1["kind"] == &"wing" and int(ms1["have"]) == 24 and int(ms1["need"]) == 30,
			"Campanha: Manta já aberta, o marco passa à próxima asa (%s)" % [ms1])
	check.call(CampaignTrail.milestone(p, 3)["id"] == &"tempest", "Campanha: marco do capítulo 3 é a Tempest")
	var few := [{"id": "wing_magnet", "stars": 3, "release": "alpha"}]
	check.call(CampaignTrail.milestone(p, 4, [], few)["kind"] == &"done",
			"Campanha: com todas as asas abertas o marco mostra o capítulo completo")
	# Zigue-zague: rotas nas pontas, a linha abaixo delas no meio e a de baixo desta numa ponta.
	var rows := {0: [1], 1: [1], 2: [1, 2]}
	var xs := HubScreen.row_positions(rows, 3, 3)
	check.call(xs[2] == [0.0, 1.0] and xs[1] == [0.5] and float(xs[0][0]) in [0.0, 1.0],
			"Campanha: posições da trilha com rotas (%s)" % [xs])
	var plain := HubScreen.row_positions({0: [1], 1: [1], 2: [1]}, 3, 1)
	check.call(absf(float(plain[0][0]) - float(plain[1][0])) > 0.8, "Campanha: zigue-zague de um lado ao outro")


func run_view(host: Node, check: Callable) -> void:
	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)
	InputSetup.ensure_actions()
	FocusNav.pad = false
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	LayoutTests.fit(app, DeviceProfiles.main_view())
	app.go(&"hub")
	await LayoutTests.settle(host)
	var hub := app.screen(&"hub") as HubScreen
	check.call(hub.chapter == 1 and hub.trail_nodes().size() == 3, "Campanha: abre no capítulo 1 com 3 nós")
	check.call(hub.node_button(&"c1m2").disabled, "Campanha: nó trancado não abre cartão")
	hub.node_button(&"c1m1").pressed.emit()
	await LayoutTests.settle(host)
	var card := hub.card()
	check.call(hub.card_open() and card.mission == &"c1m1", "Campanha: tocar no nó abre o cartão da missão")
	check.call(card.find_child("PowerBadge", true, false) != null, "Campanha: o cartão mostra o Poder recomendado")
	check.call(hub.safe.grow(0.5).encloses(card.get_global_rect()), "Campanha: cartão dentro da área útil")
	app.back()
	await LayoutTests.settle(host)
	check.call(not hub.card_open() and app.current == &"hub", "Campanha: voltar fecha o cartão e fica na aba")
	hub.node_button(&"c1m1").pressed.emit()
	await LayoutTests.settle(host)
	card.play_button().pressed.emit()
	await host.get_tree().process_frame
	check.call(app.game != null, "Campanha: Jogar do cartão começa a missão")
	if app.game != null:
		app.game.set_paused(true)
		app.game.hud().quit_pressed.emit()
		await LayoutTests.settle(host)
	# JOGAR com a história pendente abre a história; sem ela, começa a próxima missão direto.
	app.go(&"hub")
	await LayoutTests.settle(host)
	(hub.find_child("Play", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(app.current == &"story", "Campanha: JOGAR abre a cena pendente antes")
	_see_all_story(SaveManager.data)
	app.go(&"hub")
	await LayoutTests.settle(host)
	(hub.find_child("Play", true, false) as Button).pressed.emit()
	await host.get_tree().process_frame
	check.call(app.game != null and app.game.sim.mission_id == &"c1m1",
			"Campanha: sem história pendente, JOGAR começa a próxima missão")
	if app.game != null:
		app.game.set_paused(true)
		app.game.hud().quit_pressed.emit()
		await LayoutTests.settle(host)
	# Atalhos e marco.
	for pair: Array in [["Logbook", &"logbook"], ["City", &"city"], ["Season", &"season"], ["Records", &"records"],
			["Practice", &"practice"], ["Credits", &"credits"], ["FullMap", &"map"], ["Daily", &"events"],
			["Milestone", &"ships"]]:
		app.go(&"hub")
		await LayoutTests.settle(host)
		(hub.find_child(pair[0], true, false) as Button).pressed.emit()
		await LayoutTests.settle(host)
		check.call(app.current == pair[1], "Campanha: o atalho %s abre %s" % pair)
	# Trocar de capítulo: setas e deslize, só entre os abertos.
	for id: String in ["c1m1", "c1m2", "c1m3", "c2m1", "c2m2", "c2m3"]:
		SaveManager.data["missions"][id] = {"stars": [true, false, true, false], "best_score": 900, "cleared": true,
				"route": ""}
	_see_all_story(SaveManager.data)
	app.go(&"hub")
	await LayoutTests.settle(host)
	check.call(hub.chapter == 3 and hub.node_button(&"c3m3s") != null and hub.node_button(&"c3m3a") != null,
			"Campanha: abre no capítulo da próxima missão, com as duas rotas")
	check.call((hub.find_child("NextChapter", true, false) as Button).disabled,
			"Campanha: sem capítulo 4 aberto, a seta apaga")
	(hub.find_child("PrevChapter", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(hub.chapter == 2 and hub.node_button(&"c2m3").cleared and hub.node_button(&"c2m3").stars == 2,
			"Campanha: a seta volta ao capítulo 2, com as estrelas ganhas")
	(hub.find_child("Trail", true, false) as CampaignParts.TrailView).swiped.emit(1)
	await LayoutTests.settle(host)
	check.call(hub.chapter == 3, "Campanha: deslizar para o lado avança o capítulo")
	hub.show_chapter(5)
	check.call(hub.chapter == 3, "Campanha: capítulo fechado não abre")
	# Controle: JOGAR é o foco padrão; para cima chega à trilha ou aos atalhos.
	FocusNav.pad = true
	app.go(&"credits")
	await LayoutTests.settle(host)
	app.back()
	await LayoutTests.settle(host)
	var viewport := host.get_viewport()
	check.call(viewport.gui_get_focus_owner() == hub.find_child("Play", true, false), "Campanha: o controle abre no JOGAR")
	_press(&"ui_up")
	await LayoutTests.settle(host)
	var focused := viewport.gui_get_focus_owner()
	check.call(focused != null and hub.is_ancestor_of(focused) and focused.name != "Play",
			"Campanha: para cima o foco sobe do JOGAR (%s)" % [focused.name if focused != null else "nenhum"])
	hub.node_button(&"c3m1").grab_focus()
	_press(&"ui_accept")
	await LayoutTests.settle(host)
	check.call(hub.card_open() and viewport.gui_get_focus_owner() == hub.card().play_button(),
			"Campanha: A no nó abre o cartão com foco no Jogar")
	app.back()
	await LayoutTests.settle(host)
	check.call(not hub.card_open() and viewport.gui_get_focus_owner() == hub.node_button(&"c3m1"),
			"Campanha: B fecha o cartão e o foco volta ao nó")
	FocusNav.pad = false
	# Reduzir movimento: o sonar fica parado.
	Settings.set_value("reduce_motion", true)
	hub.relayout()
	var pulse := hub.find_child("Pulse", true, false) as Control
	for i: int in range(10):
		await host.get_tree().process_frame
	check.call(pulse.scale == Vector2.ONE, "Campanha: reduzir movimento para o sonar")
	Settings.set_value("reduce_motion", false)
	app.queue_free()
	await host.get_tree().process_frame
	await _layout_all_chapters(host, check)
	SaveManager.reset_profile()


## Todos os capítulos abertos, cada um nas telas apertadas e no desktop, nos idiomas mais longos.
func _layout_all_chapters(host: Node, check: Callable) -> void:
	SaveManager.reset_profile()
	for n: Dictionary in Economy.CAMPAIGN:
		if n["kind"] != &"secret" and not String(n["id"]).begins_with("c10"):
			SaveManager.data["missions"][String(n["id"])] = {"stars": [true, true, false, true], "best_score": 1,
					"cleared": true, "route": ""}
	_see_all_story(SaveManager.data)
	for c: Dictionary in DeviceProfiles.layout_cases():
		var label := String(c["label"])
		if not LAYOUT_VIEWS.has(label.get_slice(" ", 0)) or label.contains("embaixo"):
			continue
		var view: Vector2 = c["view"]
		var safe := DeviceProfiles.safe_rect(view, c["insets"])
		DeviceProfiles.simulate_insets(c["insets"])
		for lang: String in Languages.INSET_LANGS:
			Locale.set_language(lang, false)
			var app := App.new()
			host.add_child(app)
			await host.get_tree().process_frame
			LayoutTests.fit(app, view)
			app.go(&"hub")
			await LayoutTests.settle(host)
			var hub := app.screen(&"hub") as HubScreen
			check.call(CampaignTrail.open_chapters(SaveManager.data).size() == 10, "Campanha: os 10 capítulos abertos")
			for chapter: int in range(1, 11):
				hub.show_chapter(chapter)
				await host.get_tree().process_frame
				LayoutTests.check_screen(hub, safe, check, "Layout Campanha cap. %d %s [%s]" % [chapter, lang, label],
						app.shell())
			app.queue_free()
			await host.get_tree().process_frame
	DeviceProfiles.clear_insets()
	Locale.set_language("pt_BR", false)


static func _see_all_story(profile: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	var seen: Array = profile["story"].get("seen", [])
	for row: Variant in parsed:
		if not seen.has(String((row as Dictionary)["id"])):
			seen.append(String((row as Dictionary)["id"]))
	profile["story"]["seen"] = seen


static func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
