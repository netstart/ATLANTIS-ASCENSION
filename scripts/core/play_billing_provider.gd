class_name PlayBillingProvider
extends Node
## Compra real na Google Play (plano mestre 17, Turbo) pelo plugin oficial GodotGooglePlayBilling
## (addons/GodotGooglePlayBilling, MIT). Só no Android com o plugin; quem cria é o `Turbo.start`.
## Sem Play Store (emulador sem Google Play, aparelho sem conta) a conexão falha e a compra responde
## "unavailable"; nada é liberado sem confirmação do Google.
##
## Origem: scripts/ads/play_billing_provider.gd do projeto hyakki (mesmo autor, MIT), sem os pacotes
## (bundles), que este jogo não vende. Produtos in-app do catálogo (scripts/core/iap.gd): não consumíveis
## (Turbo, Apoiar, pinturas...) e consumíveis (`consumables`, hoje o pacote de revives). Consumível
## concluído não é confirmado nem "reembolsado" pela consulta: sai em `consumable_purchased` com o token, o
## Iap credita e grava, e só então chama `consume` (sem isso a Play não deixa comprar de novo).
##
## Ao conectar (abertura do app) consulta os detalhes (preço) e as compras (queryPurchases): é a
## restauração automática de quem reinstalou ou trocou de aparelho. Compra concluída e ainda não
## confirmada é confirmada (acknowledge; sem isso a Play devolve o dinheiro em 3 dias).
##
## Pedido de compra (um por vez, `_request`), que espera a Play em vez de falhar na hora:
## - "wait": sem conexão, conecta e, ao conectar, consulta os detalhes e abre a compra; conectado mas
##   sem os detalhes do produto, consulta de novo e abre quando chegarem. Detalhes com erro, produto
##   fora da resposta, erro de conexão ou PURCHASE_TIMEOUT sem resposta: "unavailable";
## - "open": a tela de pagamento da Play está aberta; a resposta vem por on_purchase_updated (sem prazo
##   enquanto a tela está na frente). Rede de segurança: quando o jogo volta para a frente depois de
##   ter saído, espera RESUME_GRACE pela resposta; sem ela, passa a "check";
## - "check": a tela fechou sem resposta; consulta as compras: comprado ou pendente termina com esse
##   estado; ausente, "canceled"; erro ou sem resposta, "unavailable";
## - "restore": a Play disse que o produto já é da pessoa (ITEM_ALREADY_OWNED): consulta as compras e
##   entrega pelo caminho normal; sem o produto na consulta, "failed".
## Compra PENDENTE (boleto, dinheiro em loja) responde "pending" e não libera nada: libera quando a
## Play mandar a compra como PURCHASED (na próxima consulta ou pelo on_purchase_updated).
## Os avisos não usam "falhou": o tools/run_checks lê "FALHOU" nos logs dos testes como reprovação.

signal product_price_changed(product: String, price: String)
## state: "purchased", "pending", "refunded" (a consulta da Play não traz mais o produto), "canceled",
## "unavailable" (a Play não respondeu ou o produto está indisponível) ou "failed" (outro erro).
signal purchase_state(product: String, state: String)
## Consumível concluído (pela tela de pagamento ou pela consulta): crédito a fazer antes do `consume`.
signal consumable_purchased(product: String, token: String)

const SINGLETON := "GodotGooglePlayBilling"
## Prazo (s) para a Play conectar e mandar os detalhes (ou a consulta da restauração) de um pedido.
const PURCHASE_TIMEOUT := 12.0
## Espera (s) pela resposta da tela de pagamento depois que o jogo volta para a frente.
const RESUME_GRACE := 4.0
## Códigos de "a Play não está disponível agora" (rede, serviço, cobrança, produto inativo).
const UNAVAILABLE_CODES: Array[int] = [
	BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE,
	BillingClient.BillingResponseCode.BILLING_UNAVAILABLE,
	BillingClient.BillingResponseCode.ITEM_UNAVAILABLE,
	BillingClient.BillingResponseCode.NETWORK_ERROR,
	BillingClient.BillingResponseCode.SERVICE_DISCONNECTED,
	BillingClient.BillingResponseCode.FEATURE_NOT_SUPPORTED,
	BillingClient.BillingResponseCode.SERVICE_TIMEOUT,
]

## product -> formatted_price (só os que a Play já respondeu).
var prices: Dictionary = {}
## Prazos (os testes encurtam).
var purchase_timeout: float = PURCHASE_TIMEOUT
var resume_grace: float = RESUME_GRACE
var _client: BillingClient
var _products: PackedStringArray = PackedStringArray()
var _consumables: PackedStringArray = PackedStringArray()
## Produtos com detalhes na última consulta que deu certo (o plugin só compra esses).
var _fetched: Dictionary = {}
## Produto do pedido em andamento ("" = nenhum) e a fase ("wait", "open", "check" ou "restore").
var _request: String = ""
var _phase: String = ""
var _left_app: bool = false
var _grace_started: bool = false
var _retried: bool = false
var _timer: Timer


static func is_supported() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(SINGLETON)


## `client`: o BillingClient do plugin (padrão) ou, nos testes, um falso que o estende. Chame com o nó
## já na árvore (o prazo é um Timer filho).
func setup(products: PackedStringArray, client: BillingClient = null,
		consumables: PackedStringArray = PackedStringArray()) -> void:
	_products = products
	_consumables = consumables
	_client = client if client != null else BillingClient.new()
	if _client.get_parent() == null:
		add_child(_client)
	_timer = Timer.new()
	_timer.name = "PurchaseTimeout"
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	_client.connected.connect(_on_connected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases.bind(true))
	_client.on_purchase_updated.connect(_on_purchases.bind(false))
	_client.acknowledge_purchase_response.connect(func(response: Dictionary) -> void:
		if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
			push_warning("Billing: erro na confirmação (%d) %s" % [
					int(response.get("response_code", -1)), response.get("debug_message", "")]))
	# Consumo que não fecha: a compra volta na próxima consulta e o Iap não credita de novo (token guardado).
	_client.consume_purchase_response.connect(func(response: Dictionary) -> void:
		if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
			push_warning("Billing: erro no consumo (%d) %s" % [
					int(response.get("response_code", -1)), response.get("debug_message", "")]))
	_client.start_connection()


func price_of(product: String) -> String:
	return String(prices.get(product, ""))


## Consome a compra de um consumível (só depois de o crédito estar gravado).
func consume(token: String) -> void:
	if _client != null and not token.is_empty():
		_client.consume_purchase(token)


func is_ready() -> bool:
	return _client != null and _client.is_ready()


## Produto do pedido em andamento (esperando a Play, tela de pagamento aberta ou restaurando) ou "".
func busy_product() -> String:
	return _request


## "Restaurar compras": consulta as compras de novo (conecta antes, se preciso; ao conectar consulta).
func restore() -> void:
	if is_ready():
		_client.query_purchases(BillingClient.ProductType.INAPP)
	elif _client != null:
		_client.start_connection()


## Pede a compra: abre a tela de pagamento da Play assim que houver conexão e detalhes do produto.
## Com outro pedido em andamento, não faz nada.
func purchase(product: String) -> void:
	if not _request.is_empty():
		return
	if _client == null or not product in _products:
		_request = product
		_finish("failed", -1, "produto desconhecido ou Billing sem cliente")
		return
	_request = product
	_phase = "wait"
	_retried = false
	_start_timer()
	if not is_ready():
		_client.start_connection()
	elif _fetched.has(product):
		_launch()
	else:
		_query_details()


func _query_details() -> void:
	_client.query_product_details(_products, BillingClient.ProductType.INAPP)


func _start_timer() -> void:
	if _timer != null and _timer.is_inside_tree():
		_timer.start(purchase_timeout)


## Abre a tela de pagamento do pedido; o resultado do lançamento já pode ser a resposta final.
func _launch() -> void:
	_phase = "open"
	_left_app = false
	_grace_started = false
	if _timer != null:
		_timer.stop()
	var response: Dictionary = _client.purchase(_request)
	var code := int(response.get("response_code", BillingClient.BillingResponseCode.OK))
	var message := String(response.get("debug_message", ""))
	if code == BillingClient.BillingResponseCode.OK:
		return
	if code == BillingClient.BillingResponseCode.DEVELOPER_ERROR \
			and message.to_lower().contains("not found") and not _retried:
		push_warning("Billing: %s sem detalhes no plugin (%d) %s; consultando de novo" % [_request, code, message])
		_retried = true
		_fetched.erase(_request)
		_phase = "wait"
		_start_timer()
		_query_details()
		return
	if code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		_restore_owned()
		return
	_finish(state_for(code), code, message)


## A Play diz que o produto já é da pessoa: consulta as compras e entrega pelo caminho normal.
func _restore_owned() -> void:
	_phase = "restore"
	_start_timer()
	restore()


## "canceled", "unavailable" ou "failed" para um código de erro da Play.
static func state_for(code: int) -> String:
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		return "canceled"
	if code in UNAVAILABLE_CODES:
		return "unavailable"
	return "failed"


## Estado final do pedido: limpa o pedido (busy_product() == "" ao emitir), avisa no logcat e emite.
func _finish(state: String, code: int, message: String) -> void:
	var product := _request
	_clear_request()
	if state != "purchased" and state != "pending":
		push_warning("Billing: compra de %s %s (%d) %s" % [product, state, code, message])
	if not product.is_empty():
		purchase_state.emit(product, state)


func _clear_request() -> void:
	_request = ""
	_phase = ""
	_retried = false
	_left_app = false
	_grace_started = false
	if _timer != null:
		_timer.stop()


## Rede de segurança da tela de pagamento: saiu do jogo e voltou com a fase "open".
func _notification(what: int) -> void:
	if _phase != "open":
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_left_app = true
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _left_app and not _grace_started and _timer != null and _timer.is_inside_tree():
				_grace_started = true
				_timer.start(resume_grace)


func _on_timeout() -> void:
	if _phase == "open":
		push_warning("Billing: %s sem resposta da tela de pagamento %.1f s depois da volta; consultando" % [
				_request, resume_grace])
		_phase = "check"
		_start_timer()
		restore()
	elif _phase == "wait" or _phase == "restore" or _phase == "check":
		_finish("unavailable", BillingClient.BillingResponseCode.SERVICE_TIMEOUT,
				"sem resposta da Play em %.1f s (%s)" % [purchase_timeout, _phase])


func _on_connect_error(code: int, message: String) -> void:
	push_warning("Billing: sem conexão (%d) %s" % [code, message])
	if _phase == "wait" or _phase == "restore" or _phase == "check":
		_finish("unavailable", code, message)


func _on_connected() -> void:
	_query_details()
	_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_product_details(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.OK:
		for details: Variant in response.get("product_details", []):
			if not details is Dictionary:
				continue
			var product := String((details as Dictionary).get("product_id", ""))
			if not product in _products:
				continue
			_fetched[product] = true
			var price := find_formatted_price(details)
			if not price.is_empty():
				prices[product] = price
				product_price_changed.emit(product, price)
	else:
		push_warning("Billing: sem os detalhes dos produtos (%d) %s" % [code, response.get("debug_message", "")])
	if _phase != "wait":
		return
	if code != BillingClient.BillingResponseCode.OK:
		_finish("unavailable", code, String(response.get("debug_message", "")))
	elif _fetched.has(_request):
		_launch()
	else:
		_finish("unavailable", code, "produto fora da resposta da Play (unfetched_products: %s)" %
				str(response.get("unfetched_products", [])))


## O preço vem aninhado (one_time_purchase_offer_details.formatted_price); procura a chave.
static func find_formatted_price(value: Variant) -> String:
	if value is Dictionary:
		var dict: Dictionary = value
		if dict.has("formatted_price"):
			return String(dict["formatted_price"])
		for key: Variant in dict:
			var found := find_formatted_price(dict[key])
			if not found.is_empty():
				return found
	elif value is Array:
		for item: Variant in value:
			var found := find_formatted_price(item)
			if not found.is_empty():
				return found
	return ""


## `from_query`: resposta de queryPurchases (lista completa; produto ausente = reembolsado).
## Fora da consulta (resposta da tela de pagamento), cancelar, já possuir ou falhar responde pelo
## produto do pedido.
func _on_purchases(response: Dictionary, from_query: bool) -> void:
	var code := int(response.get("response_code", -1))
	var message := String(response.get("debug_message", ""))
	if code != BillingClient.BillingResponseCode.OK:
		if from_query:
			push_warning("Billing: erro na consulta das compras (%d) %s" % [code, message])
			if _phase == "restore":
				_finish("unavailable" if code in UNAVAILABLE_CODES else "failed", code, message)
			elif _phase == "check":
				_finish("unavailable", code, message)
		elif code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED and not _request.is_empty():
			_restore_owned()
		else:
			_finish(state_for(code), code, message)
		return
	var found: Dictionary = {}
	for item: Variant in response.get("purchases", []):
		if not item is Dictionary:
			continue
		var purchase: Dictionary = item
		var ids := Array(purchase.get("product_ids", []))
		var state := int(purchase.get("purchase_state", 0))
		for product: String in _products:
			if not product in ids:
				continue
			found[product] = true
			match state:
				BillingClient.PurchaseState.PURCHASED:
					if product in _consumables:
						consumable_purchased.emit(product, String(purchase.get("purchase_token", "")))
					_emit_state(product, "purchased", from_query)
				BillingClient.PurchaseState.PENDING:
					_emit_state(product, "pending", from_query)
		# Uma confirmação por compra (o token vale para todos os produtos dela); pendente não se confirma e
		# consumível também não (o consumo já confirma).
		if state == BillingClient.PurchaseState.PURCHASED and not bool(purchase.get("is_acknowledged", false)) \
				and ids.any(func(id: Variant) -> bool: return String(id) in _products and not String(id) in _consumables):
			_client.acknowledge_purchase(String(purchase.get("purchase_token", "")))
	if from_query:
		for product: String in _products:
			if found.has(product):
				continue
			# Consumível consumido some da consulta: isso não é reembolso (só encerra o pedido em "check"/"restore").
			if product in _consumables and not (product == _request and _phase in ["check", "restore"]):
				continue
			if product == _request and _phase == "check":
				_finish("canceled", code, "a tela de pagamento fechou sem resposta e a compra não está na consulta")
			elif product == _request and _phase == "restore":
				_finish("failed", BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED,
						"a Play disse que já é seu, mas a consulta não trouxe a compra")
			else:
				purchase_state.emit(product, "refunded")
	elif _phase == "open":
		_finish("failed", code, "resposta da compra sem o produto pedido")


## Estado de um produto de uma compra; se é o do pedido, ele termina aqui. Uma consulta com a tela de
## pagamento aberta entrega o produto mas não encerra o pedido (a resposta da tela vem depois).
func _emit_state(product: String, state: String, from_query: bool) -> void:
	if product == _request and not (from_query and _phase == "open"):
		_finish(state, BillingClient.BillingResponseCode.OK, "")
	else:
		purchase_state.emit(product, state)
