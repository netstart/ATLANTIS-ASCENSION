class_name Iap
extends RefCounted
## Compras com dinheiro real na Google Play (plano mestre 17): o catálogo, o estado de cada produto e o que
## cada um libera. Nada de força à venda: Turbo (mais rápido, não mais fácil), "Apoiar" (sem anúncio e tema
## dourado), "Remover anúncios" (só tira o anúncio opcional, sem tema nem cosmético), pinturas (só visual;
## também saem por Pérolas), o atalho da Tridente (nave lateral, que também sai
## por fragmentos), o pacote inicial (Apoiar + uma pintura) e o pacote de 3 revives (consumível: só troca o
## anúncio do reviver pela carga; o reviver continua 1 por missão).
## Naves premium (data/ships.json "premium"): a única coisa que não sai jogando, mas também não dá força: cada uma
## repete casco, velocidade, arma, especial e poderes de uma nave do hangar ("kit", conferido por Powers.validate) e
## só muda o visual (a arte mais vistosa do jogo, rastro, tiro e estouro próprios). Uma por produto
## (`ship_premium_<id>`) ou as três no pacote `premium_fleet`. Na Steam vêm todas incluídas (`include_premium`).
## Pacotes de Pérolas (`pearls_<total>`, consumíveis, PEARL_PACKS): só a moeda dos cosméticos, nunca créditos,
## oricalco ou outra coisa que dê força.
##
## Modos (`mode()`, os mesmos do Turbo): "steam" (nada a comprar: tudo incluso ou por jogo), "play"
## (PlayBillingProvider), "simulated" (desenvolvimento sem o plugin: a compra é fingida na hora) e "off"
## (release sem o plugin: nada se vende nem se finge).
##
## Na Play: ao abrir, consulta preços e compras (restaura quem reinstalou); pendente não libera até a Play
## concluir; concluída é confirmada (acknowledge); reembolso (some da consulta) tira. Produto sem preço da
## Play (ainda não criado no Console) não aparece (`visible`). Consumível: credita, grava e só então consome,
## com o token guardado para nunca creditar duas vezes a mesma compra.
##
## No perfil: profile["purchases"][id] (não consumíveis; "supporter" é derivado de "support" ou
## "starter_pack") e profile["iap"] (cargas de reviver, tokens creditados, oferta do pacote inicial já feita).

const SUPPORT := "support"
## Só tira o anúncio opcional (não consumível, sem tema nem cosmético; mais barato que o "Apoiar").
const REMOVE_ADS := "remove_ads"
const STARTER := "starter_pack"
const SHIP_SHORTCUT := "ship_trident"
const REVIVE_PACK := "revive_pack_3"
## Pacote das três naves premium.
const PREMIUM_FLEET := "premium_fleet"
const PREMIUM_SHIP_USD := "2.99"
const PREMIUM_FLEET_USD := "5.99"
## Pintura que vem no pacote inicial.
const STARTER_PAINT := "paint_solar"
## Tokens de consumíveis já creditados guardados no perfil (os mais novos).
const CREDITED_KEEP := 32
## Pacotes de Pérolas: "pearls" = total creditado, "bonus" = % acima da base, "best" = selo "Melhor valor".
## A conta: base de 100 Pérolas por dólar e bônus crescente (0, 10, 20, 30%). US$ 4,99 = 550, uma pintura de 400
## (Abissal ou Solar) e um tom de 120 de sobra. A pintura avulsa da Play (250 por US$ 0,99, 400 por US$ 1,99, uns
## 200 por dólar) continua o caminho mais barato para UMA pintura: quem já comprou avulsa nunca sai no prejuízo, e
## o pacote é a moeda livre (os tons, que não se vendem avulsos, e qualquer pintura). O catálogo inteiro de
## cosméticos por Pérolas soma 1.770; jogando, o baú dá 5 a cada 6 h e a missão uns 2 a 5.
const PEARL_PACKS: Array[Dictionary] = [
	{"id": "pearls_100", "kind": "consumable", "usd": "0.99", "pearls": 100, "bonus": 0},
	{"id": "pearls_550", "kind": "consumable", "usd": "4.99", "pearls": 550, "bonus": 10},
	{"id": "pearls_1200", "kind": "consumable", "usd": "9.99", "pearls": 1200, "bonus": 20},
	{"id": "pearls_2600", "kind": "consumable", "usd": "19.99", "pearls": 2600, "bonus": 30, "best": true},
]
## Produtos fixos ("usd": preço-alvo, só documentação; o preço mostrado é sempre o da Play). As pinturas
## entram de data/cosmetics.json (campo "product") e as naves premium de data/ships.json (campo "premium").
const PRODUCTS: Array[Dictionary] = [
	{"id": "turbo", "kind": "turbo", "usd": "1.99"},
	{"id": SUPPORT, "kind": "support", "usd": "3.99", "cosmetics": ["tint_supporter"]},
	{"id": REMOVE_ADS, "kind": "no_ads", "usd": "2.99"},
	{"id": STARTER, "kind": "bundle", "usd": "4.49", "cosmetics": ["tint_supporter", STARTER_PAINT]},
	{"id": SHIP_SHORTCUT, "kind": "ship", "usd": "1.99", "ship": "trident"},
	{"id": REVIVE_PACK, "kind": "consumable", "usd": "0.99", "charges": 3},
]

## Só os testes: finge o modo. "" = o do aparelho (ou o Turbo.forced_mode dos testes do Turbo).
static var forced_mode: String = ""
static var _billing: PlayBillingProvider
## Último desfecho que não liberou, por produto: "pending", "canceled", "unavailable", "failed".
static var _status: Dictionary = {}
static var _listeners: Array[Callable] = []
static var _catalog: Array[Dictionary] = []


# --- Catálogo ----------------------------------------------------------------------------------

static func catalog() -> Array[Dictionary]:
	if _catalog.is_empty():
		for p: Dictionary in PRODUCTS:
			_catalog.append(p)
		for p: Dictionary in PEARL_PACKS:
			_catalog.append(p)
		for c: Variant in Store.cosmetics():
			var def := c as Dictionary
			if def.has("product"):
				_catalog.append({"id": String(def["product"]), "kind": "paint", "usd": String(def.get("usd", "")),
						"cosmetics": [String(def["id"])]})
		var fleet: Array = premium_ships()
		for ship: String in fleet:
			_catalog.append({"id": premium_product(ship), "kind": "premium_ship", "usd": PREMIUM_SHIP_USD,
					"ships": [ship]})
		if not fleet.is_empty():
			_catalog.append({"id": PREMIUM_FLEET, "kind": "premium_bundle", "usd": PREMIUM_FLEET_USD, "ships": fleet})
	return _catalog


## Naves premium na ordem de data/ships.json.
static func premium_ships() -> Array[String]:
	var out: Array[String] = []
	for row: Variant in Economy.data_rows("ships"):
		if (row as Dictionary).has("premium"):
			out.append(String((row as Dictionary)["id"]))
	return out


static func is_premium_ship(ship: String) -> bool:
	return premium_ships().has(ship)


## Produto da Play de uma nave premium ("" se não é premium).
static func premium_product(ship: String) -> String:
	for row: Variant in Economy.data_rows("ships"):
		if String((row as Dictionary)["id"]) == ship:
			return String((row as Dictionary).get("premium", ""))
	return ""


## Naves que um produto libera (o atalho da Tridente, uma premium ou as três do pacote).
static func ships_of(id: String) -> Array[String]:
	var def := product(id)
	var out: Array[String] = []
	for ship: Variant in def.get("ships", [def["ship"]] if def.has("ship") else []):
		out.append(String(ship))
	return out


## Alguma compra da conta libera esta nave.
static func ship_bought(profile: Dictionary, ship: String) -> bool:
	for p: Dictionary in catalog():
		if ships_of(String(p["id"])).has(ship) and owns(profile, String(p["id"])):
			return true
	return false


## O produto de naves não daria nada novo: toda nave dele já veio por outra compra.
static func ships_covered(profile: Dictionary, id: String) -> bool:
	var ships := ships_of(id)
	if ships.is_empty() or String(product(id).get("kind", "")) == "ship":
		return false
	for ship: String in ships:
		if not ship_bought(profile, ship):
			return false
	return true


## Steam (premium, sem compra no app): as naves premium vêm incluídas, como as pinturas e o Turbo. Devolve se o
## perfil mudou. Fora da Steam não faz nada (a compra é que libera).
static func include_premium(profile: Dictionary, steam: bool) -> bool:
	if not steam:
		return false
	var changed := false
	for ship: String in premium_ships():
		if not (profile["unlocked"]["ships"] as Array).has(ship):
			(profile["unlocked"]["ships"] as Array).append(ship)
			changed = true
		if not (profile["hangar"]["ship_levels"] as Dictionary).has(ship):
			profile["hangar"]["ship_levels"][ship] = 1
	return changed


static func product(id: String) -> Dictionary:
	for p: Dictionary in catalog():
		if String(p["id"]) == id:
			return p
	return {}


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for p: Dictionary in catalog():
		out.append(String(p["id"]))
	return out


static func consumables() -> PackedStringArray:
	var out := PackedStringArray()
	for p: Dictionary in catalog():
		if String(p["kind"]) == "consumable":
			out.append(String(p["id"]))
	return out


static func is_consumable(id: String) -> bool:
	return String(product(id).get("kind", "")) == "consumable"


## Ids dos pacotes de Pérolas, do menor ao maior.
static func pearl_packs() -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in PEARL_PACKS:
		out.append(String(p["id"]))
	return out


# --- O que o perfil tem ------------------------------------------------------------------------

static func owns(profile: Dictionary, id: String) -> bool:
	return bool((profile["purchases"] as Dictionary).get(id, false))


## Quem apoiou ("Apoiar" ou o pacote inicial; também o "supporter" gravado à mão nos testes).
static func supporter(profile: Dictionary) -> bool:
	return bool((profile["purchases"] as Dictionary).get("supporter", false))


## Alguma compra do perfil dá este cosmético.
static func grants_cosmetic(profile: Dictionary, cosmetic: String) -> bool:
	if cosmetic == "tint_supporter" and supporter(profile):
		return true
	for p: Dictionary in catalog():
		if (p.get("cosmetics", []) as Array).has(cosmetic) and owns(profile, String(p["id"])):
			return true
	return false


static func revive_charges(profile: Dictionary) -> int:
	return int((profile.get("iap", {}) as Dictionary).get("revive_charges", 0))


## Como sai o reviver agora: "charge" (carga do pacote, sem anúncio), "ad" (anúncio) ou "free" (sem anúncio:
## Steam, apoiador, anúncio que não carregou). A carga só troca o anúncio: sem anúncio a vez não gasta carga.
static func revive_path(profile: Dictionary) -> String:
	if not Ads.can_show(profile):
		return "free"
	return "charge" if revive_charges(profile) > 0 else "ad"


## Texto do botão de reviver: "Reviver (2)" com carga, "Reviver · ver anúncio" ou "Reviver (1 vez)".
static func revive_text(profile: Dictionary) -> String:
	match revive_path(profile):
		"charge":
			return TranslationServer.translate("hud.revive_charge") % revive_charges(profile)
		"ad":
			return TranslationServer.translate("hud.revive_ad")
	return TranslationServer.translate("hud.revive_free")


## Gasta uma carga de reviver. Devolve se havia carga.
static func spend_revive(profile: Dictionary) -> bool:
	if revive_charges(profile) <= 0:
		return false
	profile["iap"]["revive_charges"] = revive_charges(profile) - 1
	return true


# --- Compra ------------------------------------------------------------------------------------

static func mode() -> String:
	if not forced_mode.is_empty():
		return forced_mode
	if not Turbo.forced_mode.is_empty():
		return Turbo.forced_mode
	return mode_for(Store.is_steam(), PlayBillingProvider.is_supported(), Store.simulated())


static func mode_for(steam: bool, play: bool, simulated: bool) -> String:
	if steam:
		return "steam"
	if play:
		return "play"
	return "simulated" if simulated else "off"


## O produto aparece na Loja: já é da conta (para mostrar "Ativo"), ou dá para comprar (simulado, ou na Play
## com o preço já respondido). Pacote inicial, pacote de revives e "Remover anúncios" somem para quem já
## apoiou (não dariam nada); nave premium (ou o pacote delas) some quando outra compra já deu todas as suas naves.
static func visible(profile: Dictionary, id: String, in_mode: String = "") -> bool:
	var m := in_mode if not in_mode.is_empty() else mode()
	if product(id).is_empty() or m == "steam":
		return false
	if owns(profile, id):
		return true
	if (id == STARTER or id == REVIVE_PACK or id == REMOVE_ADS) and supporter(profile):
		return false
	if ships_covered(profile, id):
		return false
	if m == "simulated":
		return true
	return m == "play" and not price(id).is_empty()


## Abertura do app: no modo "play" cria o provedor (preços e restauração das compras).
static func start(parent: Node) -> void:
	if mode() != "play" or _billing != null:
		return
	var play := PlayBillingProvider.new()
	play.name = "PlayBilling"
	play.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(play)
	use_provider(play)
	play.setup(ids(), null, consumables())


## Liga um provedor (o do `start` ou, nos testes, um com o BillingClient falso, antes do setup). null desliga.
static func use_provider(play: PlayBillingProvider) -> void:
	if _billing != null and _billing.purchase_state.is_connected(_on_state):
		_billing.purchase_state.disconnect(_on_state)
		_billing.product_price_changed.disconnect(_on_price)
		_billing.consumable_purchased.disconnect(_on_consumable)
	_billing = play
	_status.clear()
	if play != null:
		play.purchase_state.connect(_on_state)
		play.product_price_changed.connect(_on_price)
		play.consumable_purchased.connect(_on_consumable)


## Pede a compra. Simulado: libera (ou credita) na hora e devolve true. Play: abre a tela de pagamento e
## devolve false (o resultado chega por on_changed). Steam, "off", já comprado ou sem sentido: false.
static func buy(profile: Dictionary, id: String, in_mode: String = "") -> bool:
	var m := in_mode if not in_mode.is_empty() else mode()
	if product(id).is_empty() or m == "steam" or m == "off":
		return false
	if (not is_consumable(id) and owns(profile, id)) \
			or ((id == STARTER or id == REVIVE_PACK or id == REMOVE_ADS) and supporter(profile)):
		return false
	if ships_covered(profile, id):
		return false
	if m == "simulated":
		if is_consumable(id):
			return credit(profile, id, "sim_%d" % Time.get_ticks_usec())
		return apply_state(profile, id, "purchased")
	if m == "play" and _billing != null:
		_status[id] = ""
		_billing.purchase(id)
	return false


## "Restaurar compras": consulta as compras na Play de novo (só no modo "play").
static func restore() -> void:
	if _billing != null:
		_status.clear()
		_billing.restore()


## Preço formatado pela Play ("US$ 0,99", "R$ 5,49"...) ou "" enquanto não chegou (ou sem produto no Console).
static func price(id: String) -> String:
	return _billing.price_of(id) if _billing != null else ""


## Economia do pacote premium em relação às naves avulsas, em % inteiro (0 sem dados): na Play, pelos valores em
## micros que ela respondeu (moeda da conta); sem a Play, pelos preços-alvo em dólar do catálogo.
static func fleet_savings(in_mode: String = "") -> int:
	var m := in_mode if not in_mode.is_empty() else mode()
	var fleet := 0.0
	var apart := 0.0
	for ship: String in ships_of(PREMIUM_FLEET):
		var single := premium_product(ship)
		if m == "play":
			if _billing == null or not _billing.micros.has(single):
				return 0
			apart += float(_billing.micros[single])
		else:
			apart += float(String(product(single).get("usd", "0")))
	if m == "play":
		if _billing == null or not _billing.micros.has(PREMIUM_FLEET):
			return 0
		fleet = float(_billing.micros[PREMIUM_FLEET])
	else:
		fleet = float(String(product(PREMIUM_FLEET).get("usd", "0")))
	if apart <= 0.0 or fleet >= apart:
		return 0
	return floori((1.0 - fleet / apart) * 100.0)


## "busy" (esperando a Play ou com a tela de pagamento aberta), "pending", "canceled", "unavailable",
## "failed" ou "".
static func status(id: String) -> String:
	if _billing != null and _billing.busy_product() == id:
		return "busy"
	return String(_status.get(id, ""))


static func on_changed(target: Callable) -> void:
	if not _listeners.has(target):
		_listeners.append(target)


## Tira um `target` de on_changed (lambdas guardadas aqui sobrevivem ao script e derrubam o Godot ao sair).
static func off_changed(target: Callable) -> void:
	_listeners.erase(target)


## Regra pura: aplica um desfecho da Play ao perfil e devolve se o perfil mudou. Só "purchased" libera
## (pendente não); "refunded" tira; os outros só viram o status da Loja. Consumível não passa por aqui
## (credita por `credit`, com o token).
static func apply_state(profile: Dictionary, id: String, state: String) -> bool:
	var purchases: Dictionary = profile["purchases"]
	var had := bool(purchases.get(id, false))
	match state:
		"purchased":
			_status[id] = ""
			if is_consumable(id):
				return false
			purchases[id] = true
			_sync(profile)
			if not had:
				_grant(profile, id)
			return not had
		"refunded":
			if String(_status.get(id, "")) == "pending":
				_status[id] = ""
			if is_consumable(id):
				return false
			purchases[id] = false
			_sync(profile)
			if had:
				_revoke(profile, id)
			return had
		_:
			_status[id] = state
			return false


## Regra pura do consumível: credita as cargas (ou as Pérolas) da compra `token` uma vez só. Devolve se creditou.
## Pérolas compradas vão só para a carteira (não contam como ganhas jogando em profile["earned"]).
static func credit(profile: Dictionary, id: String, token: String) -> bool:
	var iap: Dictionary = profile["iap"]
	var done: Array = iap["credited"]
	if token.is_empty() or done.has(token) or not is_consumable(id):
		return false
	var def := product(id)
	iap["revive_charges"] = revive_charges(profile) + int(def.get("charges", 0))
	var wallet: Dictionary = profile["wallet"]
	wallet["pearls"] = int(wallet.get("pearls", 0)) + int(def.get("pearls", 0))
	done.append(token)
	while done.size() > CREDITED_KEEP:
		done.pop_front()
	return true


## O pacote inicial se oferece no resultado uma única vez: na primeira vitória contra um chefe de ato em
## que ele está à venda.
static func starter_offer_due(profile: Dictionary, result: Dictionary) -> bool:
	return (not bool(profile["iap"].get("starter_offered", false)) and act_boss_win(result)
			and visible(profile, STARTER) and not owns(profile, STARTER))


static func act_boss_win(result: Dictionary) -> bool:
	if not bool(result.get("cleared", false)) or not String(result.get("mode", "")).is_empty():
		return false
	var mission := Sim.load_mission(StringName(String(result.get("mission", ""))))
	for e: Variant in mission.get("events", []):
		var ev := e as Dictionary
		if String(ev.get("op", "")) == "boss" and StringName(String(ev.get("id", ""))) in Modes.ACT_BOSSES:
			return true
	return false


## Grava o save se `profile` é o do jogador (SaveManager.data).
static func persist(profile: Dictionary) -> void:
	var saver := _saver()
	if saver != null and is_same(profile, saver.get("data")):
		saver.call("save_profile")


# --- Interno -----------------------------------------------------------------------------------

## "supporter" acompanha "support" e "starter_pack" (Store.ads_allowed lê só ele).
static func _sync(profile: Dictionary) -> void:
	var purchases: Dictionary = profile["purchases"]
	purchases["supporter"] = bool(purchases.get(SUPPORT, false)) or bool(purchases.get(STARTER, false))


static func _grant(profile: Dictionary, id: String) -> void:
	for ship: String in ships_of(id):
		if not (profile["unlocked"]["ships"] as Array).has(ship):
			(profile["unlocked"]["ships"] as Array).append(ship)
		var levels: Dictionary = profile["hangar"]["ship_levels"]
		if not levels.has(ship):
			levels[ship] = 1


static func _revoke(profile: Dictionary, id: String) -> void:
	var def := product(id)
	if id == "turbo":
		(profile["selected"] as Dictionary)["turbo"] = 1.0
	# Nave que outra compra ainda dá (a premium avulsa e o pacote) ou que saiu jogando fica; o nível também.
	for ship: String in ships_of(id):
		if _earned_ship(profile, ship) or ship_bought(profile, ship) or (Store.is_steam() and is_premium_ship(ship)):
			continue
		(profile["unlocked"]["ships"] as Array).erase(ship)
		if String(profile["selected"]["ship"]) == ship:
			profile["selected"]["ship"] = "falcon"
	var equipped := String(profile["selected"].get("cosmetic", ""))
	if not equipped.is_empty() and not Store.owned(profile, equipped):
		profile["selected"]["cosmetic"] = ""


## A nave também foi ganha jogando (fragmentos completos): o reembolso do atalho não a tira. Premium nunca sai
## jogando.
static func _earned_ship(profile: Dictionary, ship: String) -> bool:
	for row: Variant in DB.rows("ships"):
		var def := row as Dictionary
		if String(def["id"]) == ship:
			if def.has("premium"):
				return false
			return int((profile["hangar"]["fragments"] as Dictionary).get(ship, 0)) >= int(def.get("fragments", 0))
	return false


static func _on_state(id: String, state: String) -> void:
	var saver := _saver()
	if saver != null and apply_state(saver.get("data") as Dictionary, id, state):
		saver.call("save_profile")
	_notify()


## Consumível concluído: credita e grava ANTES de consumir. Token já creditado só é consumido de novo.
static func _on_consumable(id: String, token: String) -> void:
	var saver := _saver()
	if saver == null:
		return
	if credit(saver.get("data") as Dictionary, id, token):
		saver.call("save_profile")
	if _billing != null:
		_billing.consume(token)
	_notify()


static func _on_price(_id: String, _price: String) -> void:
	_notify()


static func _notify() -> void:
	_listeners = _listeners.filter(func(c: Callable) -> bool: return c.is_valid())
	for c: Callable in _listeners:
		c.call()


static func _saver() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"SaveManager")
