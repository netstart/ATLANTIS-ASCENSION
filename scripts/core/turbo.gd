class_name Turbo
extends RefCounted
## Turbo (plano mestre 17): acelera a partida em 1,5x ou 2x (o botão do HUD alterna 1x → 1,5x → 2x).
## Deixa o jogo mais RÁPIDO, não mais fácil: tudo acelera junto (inimigos, balas, a nave), nada de dano,
## vida ou recompensa a mais. Compra única (não consumível, produto "turbo", US$ 1,99) na Google Play;
## na Steam vem incluído, sem compra.
##
## Modos (`mode()`):
## - "steam": incluído (feature "steam"), nada a comprar;
## - "play": Android com o plugin GodotGooglePlayBilling: cobrança real pelo PlayBillingProvider. Ao
##   abrir o app ele consulta as compras (restauração de quem reinstalou); compra PENDENTE não libera
##   nada até a Play mandar a compra concluída; reembolso (a consulta não traz mais o produto) tira;
## - "simulated": desenvolvimento sem o plugin (Store.simulated: editor, testes, APK de debug sem o
##   plugin): a compra é fingida na hora, sem cobrança;
## - "off": release sem o plugin: não há como comprar (o cartão da Loja some) e nada é fingido.
##
## ATENÇÃO: só o Turbo é cobrado de verdade. O "Apoiar" (supporter) e o passe dourado (season_gold)
## ainda não têm produto no Play Console e continuam só simulados (Store.simulated), escondidos em
## release, mesmo com o plugin de Billing no pacote (Store.purchases_enabled).
##
## A compra fica em profile["purchases"]["turbo"] e a velocidade escolhida em
## profile["selected"]["turbo"] (1.0 nos saves antigos, por SaveManager.migrate). Este arquivo não
## depende de autoload: grava em disco só quando o perfil é o do SaveManager (achado pela árvore).

const PRODUCT := "turbo"
const SPEEDS: Array[float] = [1.0, 1.5, 2.0]

## Só os testes: finge o modo (ex.: "play" com o BillingClient falso no PC). "" = o do aparelho.
static var forced_mode: String = ""
static var _billing: PlayBillingProvider
## Último desfecho que não liberou: "pending", "canceled", "unavailable", "failed" ou "" (nenhum).
static var _status: String = ""
## Telas que se refazem quando a compra ou o preço mudam (on_changed).
static var _listeners: Array[Callable] = []


# --- API do HUD (fixa) -------------------------------------------------------------------------

static func owned(profile: Dictionary) -> bool:
	return owned_in(profile, Store.is_steam())


## Regra pura de `owned`: na Steam sempre; fora dela, só com a compra registrada no perfil.
static func owned_in(profile: Dictionary, steam: bool) -> bool:
	return steam or bool((profile.get("purchases", {}) as Dictionary).get(PRODUCT, false))


## Velocidade escolhida (1.0, 1.5 ou 2.0); 1.0 sem o Turbo ou com valor estranho no save.
static func speed(profile: Dictionary) -> float:
	if not owned(profile):
		return 1.0
	var value := float((profile.get("selected", {}) as Dictionary).get("turbo", 1.0))
	for s: float in SPEEDS:
		if is_equal_approx(s, value):
			return s
	return 1.0


## Passa para a próxima velocidade (1.0 → 1.5 → 2.0 → 1.0), guarda no perfil (e grava o save quando o
## perfil é o do jogador) e devolve a nova. Sem o Turbo não muda nada e devolve 1.0.
static func cycle(profile: Dictionary) -> float:
	if not owned(profile):
		return 1.0
	var next := SPEEDS[(SPEEDS.find(speed(profile)) + 1) % SPEEDS.size()]
	(profile["selected"] as Dictionary)["turbo"] = next
	_persist(profile)
	return next


# --- Compra ------------------------------------------------------------------------------------

## "steam", "play", "simulated" ou "off" neste aparelho e neste build (veja o topo).
static func mode() -> String:
	if not forced_mode.is_empty():
		return forced_mode
	return mode_for(Store.is_steam(), PlayBillingProvider.is_supported(), Store.simulated())


static func mode_for(steam: bool, play: bool, simulated: bool) -> String:
	if steam:
		return "steam"
	if play:
		return "play"
	return "simulated" if simulated else "off"


## O cartão da Loja aparece: dá para comprar (Play ou simulado) ou a conta já tem (para mostrar "Ativo").
static func shop_visible(profile: Dictionary, in_mode: String = "") -> bool:
	var m := in_mode if not in_mode.is_empty() else mode()
	return m == "play" or m == "simulated" or (m != "steam" and owned(profile))


## Abertura do app: no modo "play" cria o provedor, que conecta, busca o preço e consulta as compras
## (restauração). Nos outros modos não faz nada.
static func start(parent: Node) -> void:
	if mode() != "play" or _billing != null:
		return
	var play := PlayBillingProvider.new()
	play.name = "PlayBilling"
	play.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(play)
	use_provider(play)
	play.setup(PackedStringArray([PRODUCT]))


## Liga um provedor (o do `start` ou, nos testes, um com o BillingClient falso, antes do setup).
## null desliga.
static func use_provider(play: PlayBillingProvider) -> void:
	if _billing != null and _billing.purchase_state.is_connected(_on_state):
		_billing.purchase_state.disconnect(_on_state)
		_billing.product_price_changed.disconnect(_on_price)
	_billing = play
	_status = ""
	if play != null:
		play.purchase_state.connect(_on_state)
		play.product_price_changed.connect(_on_price)


## Pede a compra. Simulado: libera na hora e devolve true. Play: abre a tela de pagamento e devolve
## false (o resultado chega por on_changed). Steam, "off" ou já comprado: nada, false.
static func buy(profile: Dictionary, in_mode: String = "") -> bool:
	var m := in_mode if not in_mode.is_empty() else mode()
	if owned(profile):
		return false
	if m == "simulated":
		apply_state(profile, "purchased")
		return true
	if m == "play" and _billing != null:
		_status = ""
		_billing.purchase(PRODUCT)
	return false


## "Restaurar compras": consulta as compras na Play de novo (só no modo "play").
static func restore() -> void:
	if _billing != null:
		_status = ""
		_billing.restore()


## Preço formatado pela Play ("US$ 1,99", "R$ 10,99"...) ou "" enquanto não chegou.
static func price() -> String:
	return _billing.price_of(PRODUCT) if _billing != null else ""


## "busy" (esperando a Play ou com a tela de pagamento aberta), "pending", "canceled", "unavailable",
## "failed" ou "".
static func status() -> String:
	if _billing != null and _billing.busy_product() == PRODUCT:
		return "busy"
	return _status


## Chama `target` (sem argumentos) quando a compra ou o preço mudam.
static func on_changed(target: Callable) -> void:
	if not _listeners.has(target):
		_listeners.append(target)


## Tira um `target` de on_changed. Use com lambdas: guardada em variável estática até o fim do processo,
## uma lambda sobrevive ao script que a criou e derruba o Godot ao sair.
static func off_changed(target: Callable) -> void:
	_listeners.erase(target)


## Regra pura: aplica um desfecho da Play ao perfil e devolve se o perfil mudou. Só "purchased" libera
## (pendente não); "refunded" tira o Turbo e volta a 1x; os outros só viram o status da Loja.
static func apply_state(profile: Dictionary, state: String) -> bool:
	var purchases: Dictionary = profile["purchases"]
	var had := bool(purchases.get(PRODUCT, false))
	match state:
		"purchased":
			_status = ""
			purchases[PRODUCT] = true
			return not had
		"refunded":
			if _status == "pending":
				_status = ""
			purchases[PRODUCT] = false
			if had:
				(profile["selected"] as Dictionary)["turbo"] = 1.0
			return had
		_:
			_status = state
			return false


static func _on_state(product: String, state: String) -> void:
	if product != PRODUCT:
		return
	var saver := _saver()
	if saver != null and apply_state(saver.get("data") as Dictionary, state):
		saver.call("save_profile")
	_notify()


static func _on_price(product: String, _price: String) -> void:
	if product == PRODUCT:
		_notify()


static func _notify() -> void:
	_listeners = _listeners.filter(func(c: Callable) -> bool: return c.is_valid())
	for c: Callable in _listeners:
		c.call()


## Grava o save se `profile` é o do jogador (SaveManager.data).
static func _persist(profile: Dictionary) -> void:
	var saver := _saver()
	if saver != null and is_same(profile, saver.get("data")):
		saver.call("save_profile")


static func _saver() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"SaveManager")
