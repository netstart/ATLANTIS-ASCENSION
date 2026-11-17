extends RefCounted
## Turbo (scripts/core/turbo.gd) e a compra real pela Google Play (PlayBillingProvider), com o
## BillingClient falso (tests/fake_billing_client.gd), que só responde quando o teste manda:
## - regras puras: sem compra fica em 1x; o ciclo 1x → 1,5x → 2x → 1x grava no perfil; Steam incluída;
##   save antigo ganha 1x e "sem compra"; valor estranho no save volta a 1x;
## - modos: release sem o plugin ("off") não finge cobrança nem mostra o cartão; o simulado libera na
##   hora; "Apoiar" e o passe continuam só simulados (nunca cobráveis com o plugin);
## - estados da compra: concluída libera e confirma (acknowledge); PENDENTE não libera nem confirma e
##   libera quando a Play conclui; cancelada não libera; reembolso tira e volta a 1x; a consulta ao
##   abrir restaura quem reinstalou; ITEM_ALREADY_OWNED restaura pela consulta;
## - Loja: cartão com o preço da Play, "Abrindo a Google Play…" com a compra desativada, pendente,
##   Restaurar compras e, no simulado, Comprar → Ativo.
## Chamado por tests/integration_tests.gd.

const FakeBillingClient := preload("res://tests/fake_billing_client.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const CODE := BillingClient.BillingResponseCode
const STATE := BillingClient.PurchaseState

var _host: Node
var _check: Callable


func run(check: Callable) -> void:
	_rules(check)
	_modes(check)


func run_view(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	SaveManager.reset_profile()
	_test_restore_on_open()
	_test_pending()
	_test_cancel_refund()
	_test_already_owned()
	await _test_shop_play()
	await _test_shop_simulated()
	Turbo.use_provider(null)
	Turbo.forced_mode = ""
	SaveManager.reset_profile()


# --- Regras puras ------------------------------------------------------------------------------

func _rules(check: Callable) -> void:
	var p := SaveManager.default_profile()
	check.call(not Turbo.owned_in(p, false) and (Turbo.speed(p) == 1.0 or Store.is_steam()),
			"Turbo: perfil novo sem compra fica em 1x")
	if not Store.is_steam():
		check.call(Turbo.cycle(p) == 1.0 and float(p["selected"]["turbo"]) == 1.0,
				"Turbo: sem compra o ciclo não muda nada e devolve 1x")
	check.call(Turbo.owned_in(p, true), "Turbo: na Steam vem incluído, sem compra")
	p["purchases"]["turbo"] = true
	var seen: Array = []
	for i: int in range(4):
		seen.append(Turbo.cycle(p))
	check.call(seen == [1.5, 2.0, 1.0, 1.5] and Turbo.speed(p) == 1.5 and float(p["selected"]["turbo"]) == 1.5,
			"Turbo: ciclo 1x → 1,5x → 2x → 1x, guardado no perfil")
	p["selected"]["turbo"] = 3.0
	check.call(Turbo.speed(p) == 1.0, "Turbo: velocidade estranha no save volta a 1x")
	var old := SaveManager.default_profile()
	(old["selected"] as Dictionary).erase("turbo")
	(old["purchases"] as Dictionary).erase("turbo")
	old["version"] = 1
	var migrated := SaveManager.migrate(old)
	check.call(float(migrated["selected"]["turbo"]) == 1.0 and not bool(migrated["purchases"]["turbo"])
			and Turbo.speed(migrated) == 1.0, "Turbo: save antigo ganha 1x e sem compra")
	# Estados da Play aplicados ao perfil (regra pura).
	var q := SaveManager.default_profile()
	check.call(not Turbo.apply_state(q, "pending") and not Turbo.owned_in(q, false) and Turbo.status() == "pending",
			"Turbo: compra pendente não libera")
	check.call(Turbo.apply_state(q, "purchased") and Turbo.owned_in(q, false) and Turbo.status().is_empty(),
			"Turbo: compra concluída libera")
	check.call(not Turbo.apply_state(q, "purchased"), "Turbo: a mesma compra de novo não muda o perfil")
	q["selected"]["turbo"] = 2.0
	check.call(Turbo.apply_state(q, "refunded") and not Turbo.owned_in(q, false) and float(q["selected"]["turbo"]) == 1.0,
			"Turbo: reembolso tira o Turbo e volta a 1x")
	check.call(not Turbo.apply_state(q, "canceled") and not Turbo.owned_in(q, false) and Turbo.status() == "canceled",
			"Turbo: compra cancelada não libera")
	Turbo.apply_state(q, "refunded")


func _modes(check: Callable) -> void:
	check.call(Turbo.mode_for(true, true, true) == "steam" and Turbo.mode_for(false, true, false) == "play"
			and Turbo.mode_for(false, false, true) == "simulated" and Turbo.mode_for(false, false, false) == "off",
			"Turbo: modos Steam, Play, simulado e off (release sem o plugin)")
	var p := SaveManager.default_profile()
	check.call(not Turbo.buy(p, "off") and not bool(p["purchases"]["turbo"]) and not Turbo.shop_visible(p, "off"),
			"Turbo: release sem o plugin não finge cobrança e não mostra o cartão")
	check.call(not Turbo.buy(p, "steam") and not Turbo.shop_visible(p, "steam"), "Turbo: na Steam não há o que comprar")
	check.call(Turbo.shop_visible(p, "play") and Turbo.shop_visible(p, "simulated"), "Turbo: cartão com Play ou simulado")
	check.call(Turbo.buy(p, "simulated") and bool(p["purchases"]["turbo"]), "Turbo: simulado libera na hora")
	check.call(Store.purchases_enabled() == (Store.simulated() and not Store.is_steam()),
			"Apoiar e passe: só simulados, nunca cobráveis pelo plugin de Billing")


# --- Compra pela Play (BillingClient falso) ---------------------------------------------------

## Provedor na árvore com o cliente falso, ligado ao Turbo (como o Turbo.start faz no Android).
func _provider(fake: FakeBillingClient) -> PlayBillingProvider:
	var play := PlayBillingProvider.new()
	_host.add_child(play)
	Turbo.use_provider(play)
	play.setup(PackedStringArray([Turbo.PRODUCT]), fake)
	return play


func _done(play: PlayBillingProvider) -> void:
	Turbo.use_provider(null)
	play.get_parent().remove_child(play)
	play.free()
	SaveManager.reset_profile()


func _owned() -> bool:
	return bool(SaveManager.data["purchases"]["turbo"])


func _test_restore_on_open() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	var calls := [0]
	var listener := func() -> void: calls[0] += 1
	Turbo.on_changed(listener)
	fake.connect_now()
	_check.call(fake.count("query_product_details") == 1 and fake.count("query_purchases") == 1,
			"Play: ao abrir, consulta o preço e as compras (restauração)")
	fake.answer_details([Turbo.PRODUCT])
	_check.call(Turbo.price() == "R$ 10,99" and calls[0] >= 1, "Play: o preço chega e a Loja é avisada")
	fake.answer_purchases([FakeBillingClient.make_purchase(Turbo.PRODUCT, STATE.PURCHASED, true)])
	_check.call(_owned() and fake.count("acknowledge_purchase") == 0,
			"Play: quem reinstalou recupera o Turbo (compra já confirmada não é confirmada de novo)")
	Turbo.off_changed(listener)
	_done(play)


func _test_pending() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details([Turbo.PRODUCT])
	fake.answer_purchases([])
	_check.call(not Turbo.buy(SaveManager.data, "play") and fake.count("purchase") == 1 and Turbo.status() == "busy",
			"Play: Comprar abre a tela de pagamento (sem liberar na hora)")
	Turbo.buy(SaveManager.data, "play")
	_check.call(fake.count("purchase") == 1, "Play: toque duplo não pede a compra de novo")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(Turbo.PRODUCT, STATE.PENDING)])
	_check.call(not _owned() and Turbo.status() == "pending" and fake.count("acknowledge_purchase") == 0,
			"Play: compra pendente não libera nem é confirmada")
	fake.answer_purchases([FakeBillingClient.make_purchase(Turbo.PRODUCT, STATE.PENDING)])
	_check.call(not _owned() and Turbo.status() == "pending", "Play: pendente continua pendente na consulta")
	fake.answer_purchases([FakeBillingClient.make_purchase(Turbo.PRODUCT)])
	_check.call(_owned() and Turbo.status().is_empty() and fake.calls[-1] == ["acknowledge_purchase", "token_turbo"],
			"Play: pendente concluída libera e é confirmada (acknowledge)")
	_done(play)


func _test_cancel_refund() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details([Turbo.PRODUCT])
	Turbo.buy(SaveManager.data, "play")
	fake.purchase_update(CODE.USER_CANCELED)
	_check.call(not _owned() and Turbo.status() == "canceled" and play.busy_product().is_empty(),
			"Play: cancelar não libera e encerra o pedido")
	Turbo.buy(SaveManager.data, "play")
	fake.purchase_update(CODE.SERVICE_UNAVAILABLE)
	_check.call(not _owned() and Turbo.status() == "unavailable", "Play: Play fora do ar vira \"indisponível\"")
	Turbo.buy(SaveManager.data, "play")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(Turbo.PRODUCT)])
	_check.call(_owned() and fake.count("acknowledge_purchase") == 1, "Play: compra concluída libera e é confirmada")
	SaveManager.data["selected"]["turbo"] = 2.0
	fake.answer_purchases([])
	_check.call(not _owned() and Turbo.speed(SaveManager.data) == 1.0, "Play: reembolso tira o Turbo e volta a 1x")
	fake.answer_purchases([], CODE.SERVICE_UNAVAILABLE)
	_check.call(not _owned(), "Play: consulta com erro não muda nada")
	_done(play)


func _test_already_owned() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details([Turbo.PRODUCT])
	fake.launch_results.append({"response_code": CODE.ITEM_ALREADY_OWNED, "debug_message": "owned"})
	var queries := fake.count("query_purchases")
	Turbo.buy(SaveManager.data, "play")
	_check.call(fake.count("query_purchases") == queries + 1 and not _owned(),
			"Play: \"já é seu\" consulta as compras em vez de cobrar de novo")
	fake.answer_purchases([FakeBillingClient.make_purchase(Turbo.PRODUCT, STATE.PURCHASED, true)])
	_check.call(_owned() and play.busy_product().is_empty(), "Play: \"já é seu\" restaura o Turbo")
	_done(play)


# --- Loja --------------------------------------------------------------------------------------

func _shop() -> Array:
	var app := App.new()
	_host.add_child(app)
	await _host.get_tree().process_frame
	LayoutTests.fit(app, Vector2(270, 480))
	app.go(&"shop")
	await LayoutTests.settle(_host)
	return [app, app.screen(&"shop") as ShopScreen]


func _close(app: App) -> void:
	app.queue_free()
	await _host.get_tree().process_frame


func _test_shop_play() -> void:
	Locale.set_language("pt_BR", false)
	Turbo.forced_mode = "play"
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details([Turbo.PRODUCT])
	fake.answer_purchases([])
	var opened: Array = await _shop()
	var app: App = opened[0]
	var shop: ShopScreen = opened[1]
	var buy := shop.find_child("TurboBuy", true, false) as Button
	_check.call(shop.find_child("TurboBanner", true, false) != null and buy != null and buy.text.contains("R$ 10,99")
			and not buy.disabled, "Loja: cartão do Turbo com o preço da Play")
	_check.call(shop.find_child("TurboRestore", true, false) != null, "Loja: Restaurar compras com cobrança real")
	buy.pressed.emit()
	await LayoutTests.settle(_host)
	buy = shop.find_child("TurboBuy", true, false) as Button
	var status := shop.find_child("TurboStatus", true, false) as Label
	_check.call(fake.count("purchase") == 1 and buy != null and buy.disabled and status != null
			and status.text == tr("store.turbo_busy"), "Loja: abrindo a Google Play, a compra fica desativada")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(Turbo.PRODUCT, STATE.PENDING)])
	await LayoutTests.settle(_host)
	status = shop.find_child("TurboStatus", true, false) as Label
	buy = shop.find_child("TurboBuy", true, false) as Button
	_check.call(status != null and status.text == tr("store.turbo_pending") and buy != null and buy.disabled
			and not _owned(), "Loja: pagamento pendente avisa e não libera")
	fake.answer_purchases([FakeBillingClient.make_purchase(Turbo.PRODUCT)])
	await LayoutTests.settle(_host)
	_check.call(shop.find_child("TurboOwned", true, false) != null and _owned(), "Loja: pendente concluída mostra Ativo")
	await _close(app)
	Turbo.forced_mode = ""
	_done(play)


func _test_shop_simulated() -> void:
	if Turbo.mode() != "simulated":
		return
	var opened: Array = await _shop()
	var app: App = opened[0]
	var shop: ShopScreen = opened[1]
	var buy := shop.find_child("TurboBuy", true, false) as Button
	_check.call(buy != null and buy.text == tr("store.turbo_buy_plain")
			and shop.find_child("TurboRestore", true, false) == null, "Loja (simulado): Comprar Turbo sem preço e sem Restaurar")
	buy.pressed.emit()
	await LayoutTests.settle(_host)
	_check.call(_owned() and shop.find_child("TurboOwned", true, false) != null, "Loja (simulado): Comprar → Ativo")
	await _close(app)
