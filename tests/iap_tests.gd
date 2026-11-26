extends RefCounted
## Catálogo de compras com dinheiro real (scripts/core/iap.gd), com o BillingClient falso
## (tests/fake_billing_client.gd) quando há Play:
## - catálogo: IDs estáveis, toda pintura à venda também sai por Pérolas, nada que dê força;
## - leitura: o halo do tiro de cada pintura é pastel, longe das balas inimigas (saturadas);
## - visibilidade: produto sem preço da Play some (release), Steam não vende nada, "off" só mostra o que é seu;
## - não consumíveis: compra simulada, restauração ao abrir, reembolso que tira (e devolve o que foi ganho
##   jogando), pacote inicial = Apoiar + pintura, atalho da Tridente que não tira os fragmentos;
## - pacote de revives: crédito só da compra concluída, uma vez por token, gravado ANTES do consumo;
##   pendente não credita; a carga troca o anúncio e o reviver continua 1 por missão;
## - pacotes de Pérolas: quantidades coerentes (base 100/US$ e bônus crescente, nunca mais barato que a pintura
##   avulsa), crédito exato uma vez por token, pendente e cancelado não creditam, consumo só depois de gravar,
##   pacote sem preço não aparece, nada à venda na Steam; a Loja mostra a vitrine e o "+" das Pérolas a abre;
## - pacote inicial oferecido uma única vez, na vitória contra um chefe de ato;
## - pintura não muda a Sim (mesmo hash com e sem).
## Chamado por tests/integration_tests.gd.

const FakeBillingClient := preload("res://tests/fake_billing_client.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const CODE := BillingClient.BillingResponseCode
const STATE := BillingClient.PurchaseState
const EXPECTED := ["turbo", "support", "remove_ads", "starter_pack", "ship_trident", "revive_pack_3", "pearls_100",
		"pearls_550", "pearls_1200", "pearls_2600", "paint_aurora", "paint_reef",
		"paint_abyssal", "paint_solar", "ship_premium_hippocampus", "ship_premium_nereid", "ship_premium_amphitrite",
		"premium_fleet"]

var _host: Node
var _check: Callable


func run(check: Callable) -> void:
	_catalog(check)
	_readability(check)
	_visibility(check)
	_simulated(check)
	_consumable(check)
	_pearls(check)
	_starter_offer(check)
	_same_hash(check)


func run_view(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	SaveManager.reset_profile()
	_play_restore_refund()
	_play_consumable()
	_play_pearls()
	await _shop_hides_unpriced()
	await _shop_pearls()
	await _revive_in_game()
	Iap.use_provider(null)
	Iap.forced_mode = ""
	SaveManager.reset_profile()


# --- Regras puras ------------------------------------------------------------------------------

func _catalog(check: Callable) -> void:
	var ids := Array(Iap.ids())
	check.call(ids == EXPECTED, "Compras: catálogo com os IDs estáveis do Play Console (%s)" % ", ".join(ids))
	var pearls := true
	for p: Dictionary in Iap.catalog():
		if String(p["kind"]) == "paint":
			var def := Store.cosmetic(String((p["cosmetics"] as Array)[0]))
			pearls = pearls and int(def.get("pearls", 0)) > 0 and not bool(def.get("supporter", false))
	check.call(pearls, "Compras: toda pintura vendida na Play também sai por Pérolas ganhas jogando")
	check.call(Array(Iap.consumables()) == [Iap.REVIVE_PACK] + Iap.pearl_packs(),
			"Compras: só o pacote de revives e os de Pérolas são consumíveis")
	var ship := {}
	for row: Variant in DB.rows("ships"):
		if String((row as Dictionary)["id"]) == "trident":
			ship = row
	check.call(int(ship.get("hull", 0)) == 3 and float(ship.get("speed", 9.0)) <= 1.0
			and float(ship.get("fire_rate", 9.0)) <= 1.0 and float(ship.get("hitbox", 0.0)) >= 3.0
			and not ship.has("trait") and int(ship.get("fragments", 0)) > 0,
			"Compras: o atalho é de nave lateral (Tridente sem casco, velocidade, cadência ou traço a mais)")


## O halo do tiro de cada pintura: pastel (saturação baixa, muito claro); toda bala inimiga é saturada.
func _readability(check: Callable) -> void:
	var worst_enemy := 1.0
	for k: Dictionary in BulletKinds.ENEMY:
		worst_enemy = minf(worst_enemy, (k["glow"] as Color).s)
	var ok := true
	var count := 0
	for c: Variant in Store.cosmetics():
		var fx := Store.paint_fx(String((c as Dictionary)["id"]))
		if fx.has("shot"):
			count += 1
			var shot: Color = fx["shot"]
			ok = ok and shot.s <= 0.3 and shot.v >= 0.9 and shot.s < worst_enemy - 0.25
	check.call(count >= 4 and ok, "Pinturas: tiro do jogador em cor pastel, nunca com cara de bala inimiga")


func _visibility(check: Callable) -> void:
	var p := SaveManager.default_profile()
	var hidden := true
	for id: String in Iap.ids():
		hidden = hidden and not Iap.visible(p, id, "play") and not Iap.visible(p, id, "steam") \
				and not Iap.visible(p, id, "off") and Iap.visible(p, id, "simulated")
	check.call(hidden, "Compras: sem preço da Play o produto não aparece; Steam e release sem plugin não vendem")
	p["purchases"]["support"] = true
	check.call(Iap.visible(p, "support", "off") and not Iap.buy(p, "support", "off"),
			"Compras: o que é da conta aparece como Ativo, mesmo sem a Play")
	p["purchases"]["supporter"] = true
	check.call(not Iap.visible(p, Iap.STARTER, "simulated") and not Iap.visible(p, Iap.REVIVE_PACK, "simulated")
			and not Iap.visible(p, Iap.REMOVE_ADS, "simulated") and not Iap.buy(p, Iap.REMOVE_ADS, "simulated")
			and not Iap.buy(p, Iap.REVIVE_PACK, "simulated"),
			"Compras: quem apoiou não vê o pacote inicial, o de revives nem Remover anúncios (não dariam nada)")


func _simulated(check: Callable) -> void:
	var p := SaveManager.default_profile()
	check.call(Iap.buy(p, Iap.SUPPORT, "simulated") and Iap.supporter(p) and not Store.ads_allowed(p)
			and Store.owned(p, "tint_supporter"), "Apoiar: tira os anúncios e dá a pintura dourada")
	check.call(not Iap.buy(p, Iap.SUPPORT, "simulated"), "Apoiar: a mesma compra de novo não muda nada")
	var ads := SaveManager.default_profile()
	check.call(Store.ads_allowed(ads) and Iap.buy(ads, Iap.REMOVE_ADS, "simulated") and not Store.ads_allowed(ads)
			and not Iap.supporter(ads) and not Store.owned(ads, "tint_supporter"),
			"Remover anúncios: tira o anúncio, sem virar apoiador nem dar o tema dourado")
	check.call(not Iap.buy(ads, Iap.REMOVE_ADS, "simulated"), "Remover anúncios: a mesma compra de novo não muda nada")
	var q := SaveManager.default_profile()
	check.call(Iap.buy(q, Iap.STARTER, "simulated") and Iap.supporter(q) and Store.owned(q, Iap.STARTER_PAINT)
			and Store.owned(q, "tint_supporter"), "Pacote inicial: Apoiar + a pintura Solar")
	Store.equip(q, Iap.STARTER_PAINT)
	check.call(Iap.apply_state(q, Iap.STARTER, "refunded") and not Iap.supporter(q)
			and not Store.owned(q, Iap.STARTER_PAINT) and String(q["selected"]["cosmetic"]).is_empty(),
			"Pacote inicial: reembolso tira o apoio e a pintura (e desequipa)")
	# Pintura com produto: também por Pérolas; comprada assim, o reembolso de outra compra não a tira.
	var r := SaveManager.default_profile()
	r["wallet"]["pearls"] = 250
	check.call(Store.buy(r, "paint_aurora") and int(r["wallet"]["pearls"]) == 0 and Store.owned(r, "paint_aurora"),
			"Pinturas: a mesma pintura da Play sai com Pérolas")
	check.call(Iap.buy(r, "paint_reef", "simulated") and Store.owned(r, "paint_reef")
			and Iap.apply_state(r, "paint_reef", "refunded") and not Store.owned(r, "paint_reef")
			and Store.owned(r, "paint_aurora"), "Pinturas: compra e reembolso na Play, sem mexer nas de Pérolas")
	var s := SaveManager.default_profile()
	check.call(Iap.buy(s, Iap.SHIP_SHORTCUT, "simulated") and (s["unlocked"]["ships"] as Array).has("trident")
			and int(s["hangar"]["ship_levels"]["trident"]) == 1, "Atalho: libera a Tridente no nível 1")
	s["selected"]["ship"] = "trident"
	Iap.apply_state(s, Iap.SHIP_SHORTCUT, "refunded")
	check.call(not (s["unlocked"]["ships"] as Array).has("trident") and String(s["selected"]["ship"]) == "falcon",
			"Atalho: reembolso tira a nave (e volta à Falcon)")
	Iap.buy(s, Iap.SHIP_SHORTCUT, "simulated")
	for row: Variant in DB.rows("ships"):
		if String((row as Dictionary)["id"]) == "trident":
			s["hangar"]["fragments"]["trident"] = int((row as Dictionary)["fragments"])
	Iap.apply_state(s, Iap.SHIP_SHORTCUT, "refunded")
	check.call((s["unlocked"]["ships"] as Array).has("trident"),
			"Atalho: quem completou os fragmentos jogando fica com a nave mesmo com reembolso")
	var old := SaveManager.default_profile()
	(old["purchases"] as Dictionary).erase("support")
	old.erase("iap")
	old["purchases"]["supporter"] = true
	var migrated := SaveManager.migrate(old)
	check.call(bool(migrated["purchases"]["support"]) and Iap.revive_charges(migrated) == 0,
			"Save antigo: o Apoiar simulado vira a compra \"support\" e o perfil ganha as cargas zeradas")


func _consumable(check: Callable) -> void:
	var p := SaveManager.default_profile()
	check.call(not Iap.apply_state(p, Iap.REVIVE_PACK, "pending") and Iap.revive_charges(p) == 0
			and Iap.status(Iap.REVIVE_PACK) == "pending", "Revives: compra pendente não credita")
	check.call(Iap.credit(p, Iap.REVIVE_PACK, "t1") and Iap.revive_charges(p) == 3, "Revives: a compra credita 3 cargas")
	check.call(not Iap.credit(p, Iap.REVIVE_PACK, "t1") and Iap.revive_charges(p) == 3,
			"Revives: a mesma compra nunca credita duas vezes")
	check.call(not Iap.apply_state(p, Iap.REVIVE_PACK, "purchased") and not Iap.apply_state(p, Iap.REVIVE_PACK, "refunded")
			and Iap.revive_charges(p) == 3, "Revives: consumível some da consulta sem virar reembolso")
	check.call(Iap.buy(p, Iap.REVIVE_PACK, "simulated") and Iap.revive_charges(p) == 6,
			"Revives: o simulado credita na hora e dá para comprar de novo")
	check.call(Iap.revive_path(p) == "charge" and Iap.spend_revive(p) and Iap.revive_charges(p) == 5,
			"Revives: com carga, o reviver sai sem anúncio e gasta uma")
	var none := SaveManager.default_profile()
	check.call(Iap.revive_path(none) == "ad" and not Iap.spend_revive(none), "Revives: sem carga, segue o anúncio")
	none["purchases"]["supporter"] = true
	none["iap"]["revive_charges"] = 2
	check.call(Iap.revive_path(none) == "free", "Revives: sem anúncio (apoiador) a vez não gasta carga")
	for i: int in range(Iap.CREDITED_KEEP + 5):
		Iap.credit(p, Iap.REVIVE_PACK, "k%d" % i)
	check.call((p["iap"]["credited"] as Array).size() == Iap.CREDITED_KEEP, "Revives: o perfil guarda só os tokens novos")


## Pacotes de Pérolas: a conta das quantidades e o crédito (uma vez por token, só da compra concluída).
func _pearls(check: Callable) -> void:
	var coherent := true
	var last_bonus := -1
	var bests := 0
	var cheapest_paint := INF
	for c: Variant in Store.cosmetics():
		var def := c as Dictionary
		if def.has("product"):
			cheapest_paint = minf(cheapest_paint, float(String(def["usd"])) / float(def["pearls"]))
	for id: String in Iap.pearl_packs():
		var def := Iap.product(id)
		var usd := float(String(def["usd"]))
		var base := roundi((usd + 0.01) * 100.0)
		var pearls := int(def["pearls"])
		var bonus := int(def["bonus"])
		coherent = coherent and id == "pearls_%d" % pearls and pearls == roundi(base * (1.0 + bonus / 100.0)) \
				and bonus > last_bonus and usd / pearls > cheapest_paint
		last_bonus = bonus
		bests += 1 if bool(def.get("best", false)) else 0
	check.call(coherent and Iap.pearl_packs().size() == 4 and bests == 1
			and bool(Iap.product(Iap.pearl_packs()[-1]).get("best", false)),
			"Pérolas: 4 pacotes, 100 por dólar com bônus crescente, selo no maior, nunca mais barato que a pintura avulsa")
	var p := SaveManager.default_profile()
	var total := 0
	var ok := true
	for id: String in Iap.pearl_packs():
		var amount := int(Iap.product(id)["pearls"])
		ok = ok and Iap.credit(p, id, "tok_" + id) and int(p["wallet"]["pearls"]) == total + amount
		total += amount
		ok = ok and not Iap.credit(p, id, "tok_" + id) and int(p["wallet"]["pearls"]) == total
	check.call(ok and int(p["earned"].get("pearls", 0)) == 0 and Iap.revive_charges(p) == 0,
			"Pérolas: cada pacote credita a quantidade certa uma vez só (mesmo token não credita de novo)")
	var q := SaveManager.default_profile()
	check.call(not Iap.apply_state(q, "pearls_550", "pending") and Iap.status("pearls_550") == "pending"
			and not Iap.apply_state(q, "pearls_550", "canceled") and Iap.status("pearls_550") == "canceled"
			and not Iap.apply_state(q, "pearls_550", "purchased") and int(q["wallet"]["pearls"]) == 0,
			"Pérolas: pendente e cancelado não creditam (o crédito só sai pelo token da compra concluída)")
	var hidden := true
	for id: String in Iap.pearl_packs():
		hidden = hidden and not Iap.visible(q, id, "play") and not Iap.visible(q, id, "steam") \
				and not Iap.buy(q, id, "steam") and not Iap.buy(q, id, "off")
	check.call(hidden and int(q["wallet"]["pearls"]) == 0,
			"Pérolas: sem preço da Play o pacote não aparece; Steam e release sem plugin não vendem")
	q["purchases"]["supporter"] = true
	check.call(Iap.visible(q, "pearls_100", "simulated") and Iap.buy(q, "pearls_100", "simulated")
			and Iap.buy(q, "pearls_100", "simulated") and int(q["wallet"]["pearls"]) == 200,
			"Pérolas: o simulado credita na hora, dá para comprar de novo e quem apoia também vê")


func _starter_offer(check: Callable) -> void:
	var p := SaveManager.default_profile()
	var act := {"cleared": true, "mission": "c2m3", "mode": ""}
	check.call(Iap.act_boss_win(act) and not Iap.act_boss_win({"cleared": true, "mission": "c1m1", "mode": ""})
			and not Iap.act_boss_win({"cleared": false, "mission": "c2m3", "mode": ""})
			and not Iap.act_boss_win({"cleared": true, "mission": "c2m3", "mode": "boss_rush"}),
			"Pacote inicial: só a vitória contra um chefe de ato conta")
	Iap.forced_mode = "simulated"
	check.call(Iap.starter_offer_due(p, act), "Pacote inicial: oferecido na primeira vitória contra chefe de ato")
	p["iap"]["starter_offered"] = true
	check.call(not Iap.starter_offer_due(p, act), "Pacote inicial: oferecido uma única vez")
	var q := SaveManager.default_profile()
	q["purchases"]["supporter"] = true
	check.call(not Iap.starter_offer_due(q, act), "Pacote inicial: quem já apoiou não recebe a oferta")
	Iap.forced_mode = "play"
	check.call(not Iap.starter_offer_due(SaveManager.default_profile(), act),
			"Pacote inicial: sem preço da Play não é oferecido")
	Iap.forced_mode = ""


## A pintura é só desenho: a mesma semente com e sem pintura dá o mesmo hash da Sim.
func _same_hash(check: Callable) -> void:
	var tables := Sim.load_tables()
	var hashes: Array[String] = []
	for cosmetic: String in ["", Iap.STARTER_PAINT]:
		var sim := Sim.new()
		var load := Sim.default_loadout(&"falcon")
		load["cosmetic"] = cosmetic
		sim.setup(Sim.load_mission(&"c1m1"), tables, load, 7)
		var bot := BotPilot.new()
		while not sim.finished and sim.frame < 1800:
			sim.step(bot.decide(sim))
			sim.take_events()
		hashes.append(sim.state_hash())
	check.call(hashes[0] == hashes[1], "Pinturas: mesmo hash da Sim com e sem pintura")


# --- Play (BillingClient falso) ---------------------------------------------------------------

func _provider(fake: FakeBillingClient) -> PlayBillingProvider:
	var play := PlayBillingProvider.new()
	_host.add_child(play)
	Iap.use_provider(play)
	play.setup(Iap.ids(), fake, Iap.consumables())
	return play


func _done(play: PlayBillingProvider) -> void:
	Iap.use_provider(null)
	play.get_parent().remove_child(play)
	play.free()
	SaveManager.reset_profile()


func _play_restore_refund() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details([Iap.SUPPORT, "paint_solar"])
	_check.call(Iap.price(Iap.SUPPORT) == "R$ 10,99" and Iap.price(Iap.REVIVE_PACK).is_empty()
			and Iap.visible(SaveManager.data, Iap.SUPPORT, "play")
			and not Iap.visible(SaveManager.data, Iap.REVIVE_PACK, "play"),
			"Play: preço vem da Play; produto que a Play não respondeu fica escondido")
	fake.answer_purchases([FakeBillingClient.make_purchase(Iap.SUPPORT, STATE.PURCHASED, true),
			FakeBillingClient.make_purchase("paint_solar")])
	_check.call(Iap.supporter(SaveManager.data) and Store.owned(SaveManager.data, "paint_solar")
			and fake.calls[-1] == ["acknowledge_purchase", "token_paint_solar"] and fake.count("acknowledge_purchase") == 1,
			"Play: quem reinstalou recupera Apoiar e a pintura; só a compra nova é confirmada")
	fake.answer_purchases([FakeBillingClient.make_purchase(Iap.SUPPORT, STATE.PURCHASED, true)])
	_check.call(Iap.supporter(SaveManager.data) and not Store.owned(SaveManager.data, "paint_solar"),
			"Play: reembolso da pintura tira só a pintura")
	fake.answer_purchases([])
	_check.call(not Iap.supporter(SaveManager.data) and Store.ads_allowed(SaveManager.data),
			"Play: reembolso do Apoiar devolve os anúncios")
	_done(play)


func _play_consumable() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details([Iap.REVIVE_PACK])
	fake.answer_purchases([])
	_check.call(not Iap.buy(SaveManager.data, Iap.REVIVE_PACK, "play") and fake.count("purchase") == 1
			and Iap.status(Iap.REVIVE_PACK) == "busy", "Play: comprar revives abre a tela de pagamento")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(Iap.REVIVE_PACK, STATE.PENDING, false, "r1")])
	_check.call(Iap.revive_charges(SaveManager.data) == 0 and Iap.status(Iap.REVIVE_PACK) == "pending"
			and fake.count("consume_purchase") == 0, "Play: revives pendentes não creditam nem consomem")
	# Ao consumir, o crédito já tem de estar no save gravado.
	var saved := [-1]
	var on_save := func() -> void: saved[0] = Iap.revive_charges(SaveManager.data)
	SaveManager.saved.connect(on_save)
	fake.answer_purchases([FakeBillingClient.make_purchase(Iap.REVIVE_PACK, STATE.PURCHASED, false, "r1")])
	SaveManager.saved.disconnect(on_save)
	_check.call(Iap.revive_charges(SaveManager.data) == 3 and saved[0] == 3
			and fake.calls[-1] == ["consume_purchase", "r1"] and fake.count("acknowledge_purchase") == 0
			and Iap.status(Iap.REVIVE_PACK).is_empty(),
			"Play: pendente concluída credita 3, grava e só então consome (sem acknowledge)")
	fake.answer_purchases([FakeBillingClient.make_purchase(Iap.REVIVE_PACK, STATE.PURCHASED, false, "r1")])
	_check.call(Iap.revive_charges(SaveManager.data) == 3 and fake.count("consume_purchase") == 2,
			"Play: consumo que não fechou volta na consulta e é consumido de novo, sem crédito em dobro")
	fake.answer_purchases([])
	_check.call(Iap.revive_charges(SaveManager.data) == 3, "Play: consumível fora da consulta não é reembolso")
	Iap.buy(SaveManager.data, Iap.REVIVE_PACK, "play")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(Iap.REVIVE_PACK, STATE.PURCHASED, false, "r2")])
	_check.call(Iap.revive_charges(SaveManager.data) == 6 and fake.calls[-1] == ["consume_purchase", "r2"],
			"Play: a segunda compra credita mais 3")
	_done(play)


func _play_pearls() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details(["pearls_550", "pearls_2600"])
	fake.answer_purchases([])
	var data := SaveManager.data
	var start := int(data["wallet"]["pearls"])
	_check.call(Iap.visible(data, "pearls_550", "play") and Iap.visible(data, "pearls_2600", "play")
			and not Iap.visible(data, "pearls_100", "play") and not Iap.visible(data, "pearls_1200", "play"),
			"Play: só os pacotes de Pérolas com preço da Play aparecem")
	Iap.buy(data, "pearls_550", "play")
	fake.purchase_update(CODE.USER_CANCELED)
	_check.call(int(data["wallet"]["pearls"]) == start and Iap.status("pearls_550") == "canceled"
			and fake.count("consume_purchase") == 0, "Play: Pérolas canceladas não creditam")
	Iap.buy(data, "pearls_550", "play")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase("pearls_550", STATE.PENDING, false, "p1")])
	_check.call(int(data["wallet"]["pearls"]) == start and Iap.status("pearls_550") == "pending"
			and fake.count("consume_purchase") == 0, "Play: Pérolas pendentes não creditam nem consomem")
	var saved := [-1]
	var on_save := func() -> void: saved[0] = int(SaveManager.data["wallet"]["pearls"])
	SaveManager.saved.connect(on_save)
	fake.answer_purchases([FakeBillingClient.make_purchase("pearls_550", STATE.PURCHASED, false, "p1")])
	SaveManager.saved.disconnect(on_save)
	_check.call(int(data["wallet"]["pearls"]) == start + 550 and saved[0] == start + 550
			and fake.calls[-1] == ["consume_purchase", "p1"] and fake.count("acknowledge_purchase") == 0,
			"Play: Pérolas concluídas creditam 550, gravam e só então consomem")
	fake.answer_purchases([FakeBillingClient.make_purchase("pearls_550", STATE.PURCHASED, false, "p1")])
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase("pearls_550", STATE.PURCHASED, false, "p1")])
	_check.call(int(data["wallet"]["pearls"]) == start + 550 and fake.count("consume_purchase") == 3,
			"Play: o mesmo token de Pérolas repetido só é consumido de novo, nunca credita em dobro")
	Iap.buy(data, "pearls_2600", "play")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase("pearls_2600", STATE.PURCHASED, false, "p2")])
	_check.call(int(data["wallet"]["pearls"]) == start + 550 + 2600 and fake.calls[-1] == ["consume_purchase", "p2"],
			"Play: o pacote de 2.600 credita 2.600")
	_done(play)


# --- Telas -------------------------------------------------------------------------------------

func _shop_hides_unpriced() -> void:
	Locale.set_language("pt_BR", false)
	Iap.forced_mode = "play"
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details([Turbo.PRODUCT, Iap.SUPPORT])
	fake.answer_purchases([])
	var app := App.new()
	_host.add_child(app)
	await _host.get_tree().process_frame
	LayoutTests.fit(app, Vector2(270, 480))
	ShopScreen.next_tab = ShopScreen.TAB_SUPPORT
	app.go(&"shop")
	await LayoutTests.settle(_host)
	var shop := app.screen(&"shop") as ShopScreen
	var buy := shop.find_child("SupportBuy", true, false) as Button
	_check.call(buy != null and buy.text.contains("R$ 10,99") and shop.find_child("StarterBanner", true, false) == null
			and shop.find_child("ShipBanner", true, false) == null and shop.find_child("ReviveBanner", true, false) == null
			and shop.find_child("Restore", true, false) != null,
			"Loja (Play): Apoiar com o preço da Play; sem preço, pacote, atalho e revives não aparecem")
	SaveManager.data["wallet"]["pearls"] = 999
	shop.call("_open", "paint_solar")
	await LayoutTests.settle(_host)
	_check.call(shop.find_child("BuyPlay_paint_solar", true, false) == null
			and shop.find_child("Buy_paint_solar", true, false) != null
			and (shop.find_child("PaintPreview", true, false) as ListScreen.ShipView).fx.has("shot"),
			"Loja (Play): pintura sem preço da Play só por Pérolas, com prévia do rastro e do tiro")
	app.queue_free()
	await _host.get_tree().process_frame
	Iap.forced_mode = ""
	_done(play)


## Vitrine de Pérolas: só os pacotes com preço da Play, o preço no botão, o selo no maior; o "+" das Pérolas
## na barra do topo abre a Loja direto nela (também já estando na Loja); na Steam a sub-aba não existe.
func _shop_pearls() -> void:
	Locale.set_language("pt_BR", false)
	Iap.forced_mode = "play"
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details(["pearls_100", "pearls_2600"])
	fake.answer_purchases([])
	var app := App.new()
	_host.add_child(app)
	await _host.get_tree().process_frame
	LayoutTests.fit(app, Vector2(270, 480))
	app.go(&"shop")
	await LayoutTests.settle(_host)
	var shell := app.find_child("NavShell", true, false) as NavShell
	(shell.find_child("Pill_pearls", true, false) as Button).pressed.emit()
	await LayoutTests.settle(_host)
	var shop := app.screen(&"shop") as ShopScreen
	var buy := shop.find_child("PackBuy_pearls_2600", true, false) as Button
	_check.call(app.current == &"shop" and shop.find_child("PearlPacks", true, false) != null
			and buy != null and buy.text.contains("R$ 10,99") and shop.find_child("PackBest", true, false) != null
			and shop.find_child("Pack_pearls_100", true, false) != null
			and shop.find_child("Pack_pearls_550", true, false) == null
			and shop.find_child("Pack_pearls_1200", true, false) == null,
			"Loja (Play): o \"+\" das Pérolas abre a vitrine, só com os pacotes que têm preço e o selo no maior")
	var start := int(SaveManager.data["wallet"]["pearls"])
	buy.pressed.emit()
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase("pearls_2600", STATE.PURCHASED, false, "s1")])
	await LayoutTests.settle(_host)
	_check.call(int(SaveManager.data["wallet"]["pearls"]) == start + 2600
			and shop.find_child("PackBuy_pearls_2600", true, false) != null,
			"Loja (Play): comprar o pacote credita as Pérolas e a vitrine continua à venda")
	app.queue_free()
	await _host.get_tree().process_frame
	_done(play)
	Iap.forced_mode = "steam"
	var steam := App.new()
	_host.add_child(steam)
	await _host.get_tree().process_frame
	LayoutTests.fit(steam, Vector2(270, 480))
	ShopScreen.next_tab = ShopScreen.TAB_PEARLS
	steam.go(&"shop")
	await LayoutTests.settle(_host)
	var tabs := steam.screen(&"shop").find_child("SubTabs", true, false) as PillTabs
	_check.call(not tabs.has(ShopScreen.TAB_PEARLS)
			and steam.screen(&"shop").find_child("PearlPacks", true, false) == null, "Loja (Steam): sem pacotes de Pérolas")
	steam.queue_free()
	await _host.get_tree().process_frame
	Iap.forced_mode = ""


## Reviver com carga no jogo: sem anúncio, gasta 1 e a vez continua 1 por missão.
func _revive_in_game() -> void:
	SaveManager.reset_profile()
	SaveManager.data["iap"]["revive_charges"] = 2
	var app := App.new()
	_host.add_child(app)
	await _host.get_tree().process_frame
	LayoutTests.fit(app, Vector2(270, 480))
	app.play(&"c1m1")
	for i: int in range(5):
		await _host.get_tree().process_frame
	var game := app.game
	_kill(game)
	for i: int in range(5):
		await _host.get_tree().process_frame
	var hud := game.hud()
	var yes := hud.find_child("Revive", true, false) as Button
	_check.call(hud.revive_visible() and yes != null and yes.text == tr("hud.revive_charge") % 2,
			"Reviver: com carga o botão sai sem anúncio e mostra a contagem")
	hud.revive_chosen.emit(true)
	await _host.get_tree().process_frame
	_check.call(Iap.revive_charges(SaveManager.data) == 1 and not game.sim.finished and game.sim.player.alive,
			"Reviver: a carga revive na hora e gasta uma")
	_kill(game)
	for i: int in range(5):
		await _host.get_tree().process_frame
	_check.call(not hud.revive_visible() and Iap.revive_charges(SaveManager.data) == 1,
			"Reviver: continua 1 vez por missão, mesmo com carga sobrando")
	# O foco armado do painel (FocusNav.arm) dispara depois de ARM_SECONDS: espera antes de liberar a partida.
	await _host.get_tree().create_timer(FocusNav.ARM_SECONDS + 0.1, true, false, true).timeout
	game.set_paused(true)
	hud.quit_pressed.emit()
	await LayoutTests.settle(_host)
	app.queue_free()
	await _host.get_tree().process_frame
	SaveManager.reset_profile()


## Fim forçado da partida (o casco acabou), como a Sim deixa ao perder o último segmento.
static func _kill(game: Game) -> void:
	game.sim.player.alive = false
	game.sim.player.hull = 0
	game.sim.finished = true
