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
## A cobrança é a do catálogo de compras (scripts/core/iap.gd), que o Turbo usa como os outros produtos;
## esta classe guarda a API do HUD e as regras próprias do Turbo (velocidades, cartão sempre visível com
## o plugin, reembolso que volta a 1x). O passe dourado (season_gold) continua só simulado.
##
## A compra fica em profile["purchases"]["turbo"] e a velocidade escolhida em
## profile["selected"]["turbo"] (1.0 nos saves antigos, por SaveManager.migrate). Este arquivo não
## depende de autoload: grava em disco só quando o perfil é o do SaveManager (achado pela árvore).

const PRODUCT := "turbo"
const SPEEDS: Array[float] = [1.0, 1.5, 2.0]

## Só os testes: finge o modo (ex.: "play" com o BillingClient falso no PC). "" = o do aparelho.
## Vale para todo o catálogo (Iap.mode).
static var forced_mode: String = ""


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
	Iap.persist(profile)
	return next


# --- Compra (pelo catálogo, scripts/core/iap.gd) ------------------------------------------------

## "steam", "play", "simulated" ou "off" neste aparelho e neste build (veja o topo).
static func mode() -> String:
	return Iap.mode()


static func mode_for(steam: bool, play: bool, simulated: bool) -> String:
	return Iap.mode_for(steam, play, simulated)


## O cartão da Loja aparece: dá para comprar (Play ou simulado) ou a conta já tem (para mostrar "Ativo").
static func shop_visible(profile: Dictionary, in_mode: String = "") -> bool:
	var m := in_mode if not in_mode.is_empty() else mode()
	return m == "play" or m == "simulated" or (m != "steam" and owned(profile))


## Abertura do app: cria o provedor da Play com o catálogo inteiro (Iap.start).
static func start(parent: Node) -> void:
	Iap.start(parent)


static func use_provider(play: PlayBillingProvider) -> void:
	Iap.use_provider(play)


static func buy(profile: Dictionary, in_mode: String = "") -> bool:
	if owned(profile):
		return false
	return Iap.buy(profile, PRODUCT, in_mode)


static func restore() -> void:
	Iap.restore()


static func price() -> String:
	return Iap.price(PRODUCT)


static func status() -> String:
	return Iap.status(PRODUCT)


static func on_changed(target: Callable) -> void:
	Iap.on_changed(target)


static func off_changed(target: Callable) -> void:
	Iap.off_changed(target)


## Regra pura: aplica um desfecho da Play ao Turbo (o reembolso volta a 1x). Veja Iap.apply_state.
static func apply_state(profile: Dictionary, state: String) -> bool:
	return Iap.apply_state(profile, PRODUCT, state)
