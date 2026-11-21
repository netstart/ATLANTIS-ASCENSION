class_name Iap
extends RefCounted
## Compras com dinheiro real na Google Play (plano mestre 17): o catálogo, o estado de cada produto e o que
## cada um libera. Nada de força à venda: Turbo (mais rápido, não mais fácil), "Apoiar" (sem anúncio e tema
## dourado), pinturas (só visual; também saem por Pérolas), o atalho da Tridente (nave lateral, que também sai
## por fragmentos), o pacote inicial (Apoiar + uma pintura) e o pacote de 3 revives (consumível: só troca o
## anúncio do reviver pela carga; o reviver continua 1 por missão).
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
const STARTER := "starter_pack"
const SHIP_SHORTCUT := "ship_trident"
const REVIVE_PACK := "revive_pack_3"
## Pintura que vem no pacote inicial.
const STARTER_PAINT := "paint_solar"
## Tokens de consumíveis já creditados guardados no perfil (os mais novos).
const CREDITED_KEEP := 32
## Produtos fixos ("usd": preço-alvo, só documentação; o preço mostrado é sempre o da Play). As pinturas
## entram de data/cosmetics.json (campo "product").
const PRODUCTS: Array[Dictionary] = [
	{"id": "turbo", "kind": "turbo", "usd": "1.99"},
	{"id": SUPPORT, "kind": "support", "usd": "3.99", "cosmetics": ["tint_supporter"]},
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
		for c: Variant in Store.cosmetics():
			var def := c as Dictionary
			if def.has("product"):
				_catalog.append({"id": String(def["product"]), "kind": "paint", "usd": String(def.get("usd", "")),
						"cosmetics": [String(def["id"])]})
	return _catalog


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
## com o preço já respondido). Pacote inicial e pacote de revives somem para quem já apoiou (não dariam nada).
static func visible(profile: Dictionary, id: String, in_mode: String = "") -> bool:
	var m := in_mode if not in_mode.is_empty() else mode()
	if product(id).is_empty() or m == "steam":
		return false
	if owns(profile, id):
		return true
	if (id == STARTER or id == REVIVE_PACK) and supporter(profile):
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
	if (not is_consumable(id) and owns(profile, id)) or ((id == STARTER or id == REVIVE_PACK) and supporter(profile)):
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


## Regra pura do consumível: credita as cargas da compra `token` uma vez só. Devolve se creditou.
static func credit(profile: Dictionary, id: String, token: String) -> bool:
	var iap: Dictionary = profile["iap"]
	var done: Array = iap["credited"]
	if token.is_empty() or done.has(token) or not is_consumable(id):
		return false
	iap["revive_charges"] = revive_charges(profile) + int(product(id).get("charges", 0))
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
	var ship := String(product(id).get("ship", ""))
	if ship.is_empty() or (profile["unlocked"]["ships"] as Array).has(ship):
		return
	(profile["unlocked"]["ships"] as Array).append(ship)
	var levels: Dictionary = profile["hangar"]["ship_levels"]
	if not levels.has(ship):
		levels[ship] = 1


static func _revoke(profile: Dictionary, id: String) -> void:
	var def := product(id)
	if id == "turbo":
		(profile["selected"] as Dictionary)["turbo"] = 1.0
	var ship := String(def.get("ship", ""))
	if not ship.is_empty() and not _earned_ship(profile, ship):
		(profile["unlocked"]["ships"] as Array).erase(ship)
		if String(profile["selected"]["ship"]) == ship:
			profile["selected"]["ship"] = "falcon"
	var equipped := String(profile["selected"].get("cosmetic", ""))
	if not equipped.is_empty() and not Store.owned(profile, equipped):
		profile["selected"]["cosmetic"] = ""


## A nave também foi ganha jogando (fragmentos completos): o reembolso do atalho não a tira.
static func _earned_ship(profile: Dictionary, ship: String) -> bool:
	for row: Variant in DB.rows("ships"):
		var def := row as Dictionary
		if String(def["id"]) == ship:
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
