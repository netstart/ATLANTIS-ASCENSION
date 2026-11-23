extends RefCounted
## Naves premium (data/ships.json "premium", scripts/core/iap.gd, Loja e coleção):
## - catálogo: três `ship_premium_<id>` e o pacote `premium_fleet`, não consumíveis, preços-alvo 2,99 e 5,99;
## - sem força à venda: cada premium repete casco, velocidade, alvo, cadência, arma, especial, traço e os três
##   poderes da nave de origem ("kit"), com o mesmo Poder no mesmo nível;
## - compra simulada libera na hora; pacote cobre as avulsas; reembolso tira só o que nenhuma outra compra dá;
## - Play (BillingClient falso): restauração ao abrir (com acknowledge), reembolso, economia do pacote em micros;
## - Steam: todas inclusas, nada à venda; conquista de frota não conta premium;
## - arte: base HD, tira do brilho, âncoras da evolução do hangar; efeitos com tiro pastel; textos nos 11 idiomas;
## - Loja: seção "Naves premium" (pacote em destaque, cartões, preços) e a coleção com a grade premium, em todas
##   as resoluções de tests/device_profiles.gd.
## Chamado por tests/integration_tests.gd.

const FakeBillingClient := preload("res://tests/fake_billing_client.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const STATE := BillingClient.PurchaseState
const SHIPS: Array[String] = ["hippocampus", "nereid", "amphitrite"]
const SAME := ["hull", "speed", "hitbox", "fire_rate", "signature", "special", "trait", "role"]
## Idiomas do teste de layout da seção (o mais curto e os mais longos).
const LANGS: Array[String] = ["pt_BR", "de", "ru"]

var _host: Node
var _check: Callable


func run(check: Callable) -> void:
	_catalog(check)
	_no_power_for_sale(check)
	_simulated(check)
	_steam(check)
	_art_and_texts(check)


func run_view(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	SaveManager.reset_profile()
	_play_restore_refund()
	Iap.use_provider(null)
	SaveManager.reset_profile()


## Seção premium da Loja e grade da coleção num caso de layout (unidade das fatias).
func run_layout_case(host: Node, check: Callable, c: Dictionary) -> void:
	var view: Vector2 = c["view"]
	DeviceProfiles.simulate_insets(c["insets"])
	SaveManager.reset_profile()
	for lang: String in LANGS:
		if not (c["langs"] as Array).has(lang):
			continue
		Locale.set_language(lang, false)
		var app := App.new()
		host.add_child(app)
		await host.get_tree().process_frame
		LayoutTests.fit(app, view)
		ShopScreen.next_tab = ShopScreen.TAB_SUPPORT
		app.go(&"shop")
		await LayoutTests.settle(host)
		var tag := "Premium Loja %s [%s]" % [lang, c["label"]]
		var shop := app.screen(&"shop") as ShopScreen
		var fleet := shop.find_child("PremiumFleetCard", true, false) as Control
		check.call(shop.find_child("PremiumSection", true, false) != null and fleet != null
				and shop.find_child("PremiumFleetSave", true, false) != null,
				"%s: seção com o pacote em destaque e a economia" % tag)
		check.call(fleet != null and fleet.get_index() < (shop.find_child("Premium_nereidCard", true, false) as Control)
				.get_index(), "%s: o pacote vem antes das naves avulsas" % tag)
		for ship: String in SHIPS:
			var card := shop.find_child("Premium_%sCard" % ship, true, false) as Control
			check.call(card != null and card.find_child("Premium_%sBuy" % ship, true, false) != null
					and card.find_child("Showcase", true, false) != null
					and card.find_child("Premium_%sBadge" % ship, true, false) != null,
					"%s: cartão de %s com vitrine, selo e compra" % [tag, ship])
		_check_cards(shop, check, tag)
		ShipsScreen.next_focus = "nereid"
		app.go(&"ships")
		await LayoutTests.settle(host)
		var ships := app.screen(&"ships") as ShipsScreen
		check.call(ships.find_child("Premium", true, false) != null and ships.find_child("SeeShop", true, false) != null,
				"Premium Naves %s [%s]: grade premium e o caminho para a Loja" % [lang, c["label"]])
		app.queue_free()
		await host.get_tree().process_frame
	DeviceProfiles.clear_insets()
	Locale.set_language("pt_BR", false)
	SaveManager.reset_profile()


# --- Regras ------------------------------------------------------------------------------------

func _catalog(check: Callable) -> void:
	check.call(",".join(Iap.premium_ships()) == ",".join(SHIPS), "Premium: três naves na ordem da vitrine")
	var ok := true
	for ship: String in SHIPS:
		var p := Iap.product("ship_premium_" + ship)
		ok = ok and String(p.get("kind", "")) == "premium_ship" and String(p.get("usd", "")) == "2.99" \
				and ",".join(Iap.ships_of("ship_premium_" + ship)) == ship and not Iap.is_consumable("ship_premium_" + ship)
	var fleet := Iap.product(Iap.PREMIUM_FLEET)
	var all_three := ",".join(Iap.ships_of(Iap.PREMIUM_FLEET)) == ",".join(SHIPS)
	check.call(ok and String(fleet.get("usd", "")) == "5.99" and all_three
			and not Iap.is_consumable(Iap.PREMIUM_FLEET),
			"Premium: ship_premium_<id> a US$ 2,99 e premium_fleet (as três) a US$ 5,99, não consumíveis")
	var save := Iap.fleet_savings("simulated")
	check.call(save == 33, "Premium: o pacote economiza 33%% (%d)" % save)


## Poder igual ao da nave de origem: atributos, arma, especial, traço e os três poderes (efeitos, ícone, som).
func _no_power_for_sale(check: Callable) -> void:
	var powers := DB.table("powers")
	for ship: String in SHIPS:
		var def := DB.ship(StringName(ship))
		var kit := String(def.get("kit", ""))
		var src := DB.ship(StringName(kit))
		var same := not kit.is_empty() and not src.is_empty() and not src.has("premium")
		for key: String in SAME:
			same = same and def.get(key) == src.get(key)
		check.call(same, "Premium: %s tem os atributos, a arma e o especial da %s" % [ship, kit])
		var p := SaveManager.default_profile()
		p["selected"]["ship"] = kit
		var base := Economy.power(p)
		p["selected"]["ship"] = ship
		check.call(Economy.power(p) == base and is_equal_approx(Economy.ship_factor(def), Economy.ship_factor(src)),
				"Premium: Poder de %s igual ao da %s (%d)" % [ship, kit, base])
		var kit_ok := true
		for tier: int in [1, 2, 3]:
			var mine: Dictionary = powers.get(StringName("%s_%d" % [ship, tier]), {})
			var theirs: Dictionary = powers.get(StringName("%s_%d" % [kit, tier]), {})
			kit_ok = kit_ok and not mine.is_empty() and mine["effects"] == theirs["effects"] \
					and mine["name_key"] == theirs["name_key"] and mine["sfx"] == theirs["sfx"]
		check.call(kit_ok, "Premium: os três poderes de %s são os da %s" % [ship, kit])
	var broken := DB.table("powers").duplicate(true)
	(broken[&"nereid_2"]["effects"] as Array)[0]["mult"] = 9.0
	check.call(not Powers.validate(broken, DB.table("ships")).is_empty(),
			"Premium: Powers.validate reprova poder premium diferente do de origem")


func _simulated(check: Callable) -> void:
	var p := SaveManager.default_profile()
	check.call(not (p["unlocked"]["ships"] as Array).has("nereid"), "Premium: perfil novo não tem nave premium")
	check.call(Iap.buy(p, "ship_premium_nereid", "simulated") and (p["unlocked"]["ships"] as Array).has("nereid")
			and int(p["hangar"]["ship_levels"]["nereid"]) == 1, "Premium: comprar libera a nave na hora, no nível 1")
	p["selected"]["ship"] = "nereid"
	var gone := Iap.apply_state(p, "ship_premium_nereid", "refunded")
	check.call(gone and not (p["unlocked"]["ships"] as Array).has("nereid")
			and String(p["selected"]["ship"]) == "falcon", "Premium: reembolso tira a nave e volta à Falcon")
	var q := SaveManager.default_profile()
	Iap.buy(q, "ship_premium_hippocampus", "simulated")
	check.call(Iap.buy(q, Iap.PREMIUM_FLEET, "simulated") and SHIPS.all(func(s: String) -> bool:
			return (q["unlocked"]["ships"] as Array).has(s)), "Premium: o pacote libera as três")
	check.call(not Iap.visible(q, "ship_premium_nereid", "simulated")
			and not Iap.buy(q, "ship_premium_nereid", "simulated") and Iap.visible(q, Iap.PREMIUM_FLEET, "simulated"),
			"Premium: com o pacote, a avulsa some (não daria nada); o pacote aparece como da conta")
	Iap.apply_state(q, Iap.PREMIUM_FLEET, "refunded")
	check.call((q["unlocked"]["ships"] as Array).has("hippocampus") and not (q["unlocked"]["ships"] as Array).has("nereid")
			and not (q["unlocked"]["ships"] as Array).has("amphitrite"),
			"Premium: reembolso do pacote tira só as que nenhuma outra compra dá")
	var r := SaveManager.default_profile()
	for ship: String in SHIPS:
		Iap.buy(r, "ship_premium_" + ship, "simulated")
	check.call(not Iap.visible(r, Iap.PREMIUM_FLEET, "simulated") and not Iap.buy(r, Iap.PREMIUM_FLEET, "simulated"),
			"Premium: quem tem as três avulsas não vê o pacote")


func _steam(check: Callable) -> void:
	var p := SaveManager.default_profile()
	check.call(not Iap.include_premium(p, false) and not (p["unlocked"]["ships"] as Array).has("hippocampus"),
			"Premium: fora da Steam nada vem de graça")
	check.call(Iap.include_premium(p, true) and SHIPS.all(func(s: String) -> bool:
			return (p["unlocked"]["ships"] as Array).has(s) and int(p["hangar"]["ship_levels"][s]) == 1)
			and not Iap.include_premium(p, true), "Premium: na Steam as três vêm incluídas (uma vez só)")
	var none := true
	for id: String in Iap.ids():
		none = none and not Iap.visible(p, id, "steam") and not Iap.buy(p, id, "steam")
	check.call(none, "Premium: a Steam não vende nada")
	var q := SaveManager.default_profile()
	Iap.include_premium(q, true)
	var fleet := {"id": "test_fleet", "type": "ships", "target": 2}
	check.call(not Achievements._met(q, {}, fleet),
			"Premium: nave premium não adianta a conquista de frota (só a Falcon + as três premium)")


func _art_and_texts(check: Callable) -> void:
	var worst_enemy := 1.0
	for k: Dictionary in BulletKinds.ENEMY:
		worst_enemy = minf(worst_enemy, (k["glow"] as Color).s)
	for ship: String in SHIPS:
		var art := SpriteBank.player(StringName(ship))
		var sheen: Texture2D = art.get("sheen")
		check.call(bool(art.get("hd", false)) and art.get("glow") != null and sheen != null
				and sheen.get_width() == int(art["tex_size"]) * 12,
				"Premium: %s com arte HD, brilho da evolução e a tira do brilho (12 quadros)" % ship)
		check.call(not ShipLivery.anchors(StringName(ship)).is_empty(), "Premium: %s com âncoras da evolução" % ship)
		var fx := Store.ship_fx(ship, "")
		var shot: Color = fx.get("shot", Color.BLACK)
		check.call(fx.has("trail") and fx.has("burst") and shot.s <= 0.3 and shot.v >= 0.9
				and shot.s < worst_enemy - 0.25, "Premium: %s com rastro e estouro próprios e tiro pastel" % ship)
		check.call(Store.ship_fx(ship, "paint_solar")["trail"] == Store.paint_fx("paint_solar")["trail"],
				"Premium: a pintura equipada vale por cima dos efeitos de %s" % ship)
		for key: String in ["ship." + ship, "store.premium_lore_" + ship]:
			check.call(Locale.keys.has(key), "Premium: texto %s existe" % key)
	for key: String in ["store.premium_section", "store.premium_badge", "store.premium_fleet", "store.premium_fleet_desc",
			"store.premium_save", "store.premium_kit", "store.premium_note", "store.premium_owned", "ships.premium_lock",
			"ships.see_shop"]:
		check.call(Locale.keys.has(key), "Premium: texto %s existe" % key)


# --- Play (BillingClient falso) ---------------------------------------------------------------

func _play_restore_refund() -> void:
	var fake := FakeBillingClient.new()
	var play := PlayBillingProvider.new()
	_host.add_child(play)
	Iap.use_provider(play)
	play.setup(Iap.ids(), fake, Iap.consumables())
	fake.connect_now()
	var ids: Array = [Iap.PREMIUM_FLEET]
	for ship: String in SHIPS:
		ids.append("ship_premium_" + ship)
	fake.answer_details(ids)
	var data := SaveManager.data
	_check.call(Iap.visible(data, Iap.PREMIUM_FLEET, "play") and Iap.price("ship_premium_nereid") == "R$ 10,99",
			"Premium (Play): com preço da Play, nave e pacote aparecem")
	_check.call(Iap.fleet_savings("play") == 0, "Premium (Play): sem os micros da Play, nada de economia inventada")
	play.micros[Iap.PREMIUM_FLEET] = 5990000
	for ship: String in SHIPS:
		play.micros["ship_premium_" + ship] = 2990000
	_check.call(Iap.fleet_savings("play") == 33, "Premium (Play): economia do pacote pelos micros da Play")
	fake.answer_purchases([FakeBillingClient.make_purchase(Iap.PREMIUM_FLEET)])
	_check.call(SHIPS.all(func(s: String) -> bool: return (data["unlocked"]["ships"] as Array).has(s))
			and fake.calls[-1] == ["acknowledge_purchase", "token_" + Iap.PREMIUM_FLEET],
			"Premium (Play): restaurar as compras devolve as três naves e confirma o pacote")
	data["selected"]["ship"] = "amphitrite"
	fake.answer_purchases([FakeBillingClient.make_purchase("ship_premium_nereid", STATE.PURCHASED, true)])
	_check.call((data["unlocked"]["ships"] as Array).has("nereid") and not (data["unlocked"]["ships"] as Array)
			.has("amphitrite") and String(data["selected"]["ship"]) == "falcon",
			"Premium (Play): reembolso do pacote tira as naves que não foram compradas à parte")
	Iap.use_provider(null)
	play.get_parent().remove_child(play)
	play.free()


# --- Peças -------------------------------------------------------------------------------------

## Tudo dentro dos cartões premium cabe na largura da lista: textos inteiros, botões com alvo de toque.
func _check_cards(shop: ShopScreen, check: Callable, tag: String) -> void:
	var scroll := shop.find_child("List", true, false) as Control
	var bounds := scroll.get_global_rect() if scroll != null else shop.get_global_rect()
	var ok := true
	var where := ""
	for card: Node in shop.find_children("Premium*Card", "PanelContainer", true, false):
		for node: Node in card.find_children("*", "Control", true, false):
			var c := node as Control
			if not c.is_visible_in_tree() or not (c is Label or c is Button):
				continue
			var rect := c.get_global_rect()
			var fits := rect.position.x >= bounds.position.x - 0.5 and rect.end.x <= bounds.end.x + 0.5
			if c is Label:
				fits = fits and (c as Label).get_minimum_size().x <= rect.size.x + 0.5
			else:
				fits = fits and rect.size.y >= UiTheme.TOUCH_MIN - 0.5 \
						and (c as Button).get_minimum_size().x <= rect.size.x + 0.5
			if not fits:
				ok = false
				where = "%s %s" % [c.name, rect]
	check.call(ok, "%s: textos e botões dos cartões cabem (%s)" % [tag, where])
