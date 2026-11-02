extends RefCounted
## Menus de comando, fase 2 (1.15): Loja (sub-abas, baú no cartão-destaque, grade de pinturas, painel de
## detalhe com Comprar e Equipar, preço sempre legível, tira discreta da versão de teste), Naves (palco da
## nave em foco, grade com aviso de nova, escolher) e Eventos (banners de modo, aviso do Diário, Prática).
## Só a apresentação mudou: as regras (Store, LiveOps, Notices, Modes) são as de antes e os testes
## conferem que o fluxo continua o mesmo. Chamado por tests/integration_tests.gd.

const LayoutTests := preload("res://tests/layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")


func run(check: Callable) -> void:
	check.call(ShopScreen.paint_rarity({"pearls": 40}) == CommandKit.COMMON
			and ShopScreen.paint_rarity({"pearls": 60}) == CommandKit.RARE
			and ShopScreen.paint_rarity({"pearls": 120}) == CommandKit.EPIC
			and ShopScreen.paint_rarity({"pearls": 0, "season": true}) == CommandKit.LEGENDARY,
			"Loja: raridade da pintura sobe com o preço; as de evento são lendárias")
	var ranks := {}
	for row: Variant in DB.rows("ships"):
		ranks[String((row as Dictionary)["id"])] = ShipsScreen.ship_rarity(row as Dictionary)
	check.call(ranks["falcon"] == CommandKit.COMMON and ranks["hydra"] == CommandKit.RARE
			and ranks["ram"] == CommandKit.EPIC and ranks["ascension"] == CommandKit.LEGENDARY,
			"Naves: raridade pela origem (primeira leva, fragmento caro, pós-lançamento, final verdadeiro)")
	var crisp := true
	for scale: float in [1.0, 2.0, 3.0, 4.0, 5.0]:
		var side := StoreBanner.pixel_side(100.0, scale)
		var physical := side * scale
		crisp = crisp and side <= 100.0 + 0.01 and is_equal_approx(fmod(physical, float(StoreBanner.PORTRAIT_SOURCE)), 0.0)
	check.call(crisp, "Destaque: retrato em múltiplo inteiro de pixel físico em toda escala")


func run_view(host: Node, check: Callable) -> void:
	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	LayoutTests.fit(app, Vector2(270, 480))
	await _shop(app, host, check)
	await _ships(app, host, check)
	await _events(app, host, check)
	app.queue_free()
	await host.get_tree().process_frame
	SaveManager.reset_profile()


func _shop(app: App, host: Node, check: Callable) -> void:
	var p := SaveManager.data
	p["live"] = {"daily_date": "", "daily": [], "week": "", "weekly": [], "core": 0, "chest_at": 0}
	app.go(&"shop")
	await LayoutTests.settle(host)
	var shop := app.screen(&"shop") as ShopScreen
	var tabs := shop.find_child("SubTabs", true, false) as PillTabs
	check.call(tabs != null and tabs.has(&"chest") and tabs.has(&"paints") and tabs.has(&"support") == Store.simulated(),
			"Loja: sub-abas Baú, Pinturas e (com compra) Apoio")
	var dot := tabs.button(&"chest").find_child("Notice", true, false) as Control
	check.call(dot != null and dot.visible, "Loja: baú pronto acende a bolinha da sub-aba Baú")
	var strip := shop.find_child("TestStrip", true, false) as Control
	check.call(strip == null or strip.size.y <= 30.0, "Loja: versão de teste é uma tira discreta")
	check.call(shop.find_child("Banner", true, false) != null, "Loja: o baú é o cartão-destaque com retrato")
	var credits := int(p["wallet"]["credits"])
	var pearls := int(p["wallet"]["pearls"])
	(shop.find_child("Chest", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(int(p["wallet"]["credits"]) == credits + 100 and int(p["wallet"]["pearls"]) == pearls + 5,
			"Loja: abrir o baú grátis paga como antes")
	check.call(shop.find_child("Chest", true, false) == null and not dot.visible,
			"Loja: baú aberto some o botão e apaga a bolinha")
	tabs.button(&"paints").pressed.emit()
	await LayoutTests.settle(host)
	var shelf := shop.find_child("Paints", true, false) as GridContainer
	check.call(shelf != null and shelf.columns >= 3, "Loja: pinturas em grade de ladrilhos (%d colunas)" % (
			shelf.columns if shelf != null else 0))
	# Sem pérolas: o preço continua claro (nada de escuro sobre escuro).
	p["wallet"]["pearls"] = 0
	shop.refill()
	await LayoutTests.settle(host)
	var state := shop.find_child("Paint_tint_storm", true, false).get_parent().find_child("StateText", true, false)
	check.call(_light((state as Label).get_theme_color("font_color")), "Loja: preço que não dá segue legível")
	(shop.find_child("Paint_tint_storm", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	var buy := shop.find_child("Buy_tint_storm", true, false) as Button
	check.call(buy != null and buy.disabled, "Loja: sem pérolas, Comprar desabilitado")
	var ink := buy.find_children("*", "Label", true, false)
	check.call(not ink.is_empty() and _light((ink[0] as Label).get_theme_color("font_color")),
			"Loja: Comprar desabilitado com texto claro")
	var safe := DeviceProfiles.safe_rect(Vector2(270, 480), Vector4.ZERO)
	var controls: Array[Control] = shop.layout_controls()
	LayoutTests.check_screen_controls(controls, safe, check, "Loja: painel de detalhe em 270x480")
	check.call(shop.back(), "Loja: voltar com o painel aberto é tratado pela tela")
	await LayoutTests.settle(host)
	check.call(app.current == &"shop" and not (shop.find_child("Sheet", true, false) as Control).visible,
			"Loja: voltar fecha o painel e fica na Loja")
	p["wallet"]["pearls"] = 100
	shop.refill()
	(shop.find_child("Paint_tint_kelp", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	(shop.find_child("Buy_tint_kelp", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(Store.owned(p, "tint_kelp") and int(p["wallet"]["pearls"]) == 40, "Loja: Comprar no painel compra")
	var equip := shop.find_child("Equip_tint_kelp", true, false) as Button
	check.call(equip != null, "Loja: depois de comprar, o painel oferece Equipar")
	if equip != null:
		equip.pressed.emit()
		await LayoutTests.settle(host)
	check.call(String(p["selected"].get("cosmetic", "")) == "tint_kelp", "Loja: Equipar no painel veste a pintura")
	check.call((shop.find_child("Paint_tint_kelp", true, false) as CommandKit.ItemTile).selected,
			"Loja: ladrilho da pintura equipada aceso")
	shop.back()
	await LayoutTests.settle(host)
	check.call(not (shop.find_child("Sheet", true, false) as Control).visible, "Loja: voltar fecha o painel")


func _ships(app: App, host: Node, check: Callable) -> void:
	SaveManager.unlock("ships", &"manta")
	app.go(&"ships")
	await LayoutTests.settle(host)
	var ships := app.screen(&"ships") as ShipsScreen
	var manta := ships.find_child("Ship_manta", true, false) as CommandKit.ItemTile
	check.call(manta != null and manta.notice, "Naves: ladrilho da aeronave nova com a bolinha")
	check.call(Notices.unseen_ships(SaveManager.data).is_empty(), "Naves: abrir a coleção marca as novas como vistas")
	var stage := ships.find_child("Stage", true, false)
	check.call(stage != null and stage.find_child("Stats", true, false) != null, "Naves: palco com os atributos")
	(ships.find_child("Ship_tempest", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	stage = ships.find_child("Stage", true, false)
	check.call(stage.find_child("Requirement", true, false) != null and stage.find_child("Select_tempest", true, false)
			== null, "Naves: fechada mostra o requisito, sem Escolher")
	(ships.find_child("Ship_manta", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	var pick := ships.find_child("Select_manta", true, false) as Button
	check.call(pick != null, "Naves: aberta e fora da missão mostra Escolher")
	if pick != null:
		pick.pressed.emit()
		await LayoutTests.settle(host)
	check.call(String(SaveManager.data["selected"]["ship"]) == "manta", "Naves: Escolher troca a nave da missão")
	SaveManager.data["selected"]["ship"] = "falcon"


func _events(app: App, host: Node, check: Callable) -> void:
	var p := SaveManager.data
	app.go(&"events")
	await LayoutTests.settle(host)
	var events := app.screen(&"events")
	var practice := events.find_child("ModeCard_practice", true, false)
	check.call(practice != null and practice.find_child("Mode_practice", true, false) == null,
			"Eventos: modo fechado é banner apagado, sem botão")
	for id: String in ["c1m1", "c2m1"]:
		p["missions"][id] = {"stars": [true, false, false, false], "best_score": 1000, "cleared": true, "route": ""}
	p["daily"]["date"] = ""
	events.call("refill")
	await LayoutTests.settle(host)
	var daily := events.find_child("ModeCard_daily", true, false)
	var dot := daily.find_child("Notice", true, false) as Control if daily != null else null
	check.call(dot != null and dot.visible, "Eventos: Desafio Diário não jogado acende a bolinha do banner")
	(events.find_child("Mode_practice", true, false) as Button).pressed.emit()
	await LayoutTests.settle(host)
	check.call(app.current == &"practice", "Eventos: o banner da Prática leva à escolha de missão")


static func _light(color: Color) -> bool:
	return color.get_luminance() >= 0.45
