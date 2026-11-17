class_name Ads
extends RefCounted
## Anúncio recompensado OPCIONAL (plano mestre 17): só o jogador pede, nunca durante a missão, e a
## recompensa é pequena (reviver 1 vez, dobrar créditos, dobrar as Pérolas do diário, baú em dobro). Nada
## de intersticial nem banner. Três modos (AdMobProvider.startup_provider):
## - "admob": Android com o plugin Poing; UMP na abertura e anúncio de verdade;
## - "mock": builds de desenvolvimento sem o plugin (editor, testes, PC); a recompensa sai na hora;
## - "off": release sem IDs reais do AdMob (ou sem o plugin); sem SDK, a recompensa sai direto.
## Na Steam e para quem apoiou não há anúncio (`Store.ads_allowed` falso): a recompensa sai direto.
##
## Anúncio ainda não carregado (sem internet, sem preenchimento): `can_show` fica falso, as telas mostram o
## texto sem anúncio e a recompensa sai de presente, como para quem apoiou. O baú em dobro, que só existe
## com anúncio, some até o anúncio carregar. As telas abertas se refazem com `on_ready_changed`. Anúncio que
## falha ao abrir conta como "sem anúncio" (falha técnica não é recusa). Quem fecha o anúncio antes do fim
## não ganha a mesma recompensa de graça na mesma tela (`allow_free`, tela de resultado).

## Desfechos de um anúncio real (AdMobProvider.show_rewarded).
const EARNED := &"earned"
const DECLINED := &"declined"
const FAILED := &"failed"
const LOST := &"lost"

static var _mode: String = ""
static var _admob: AdMobProvider
## Um anúncio na tela: um segundo pedido (toque repetido) é ignorado, sem resposta.
static var _showing: bool = false


## "admob", "mock" ou "off" neste aparelho e neste build (decidido uma vez).
static func mode() -> String:
	if _mode.is_empty():
		_mode = AdMobProvider.current_startup_provider()
	return _mode


## Abertura do app: consentimento (UMP) e SDK, só no modo "admob". Não trava a abertura: `parent` segue
## sem esperar. Sem consentimento que permita anúncio o SDK nem inicia (AdMobProvider.consent_allows_ads).
static func start(parent: Node) -> void:
	if mode() != "admob" or _admob != null:
		return
	_admob = AdMobProvider.new()
	_admob.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(_admob)
	_admob.start()


## Há anúncio para mostrar agora (anúncios ligados para o jogador e, no AdMob, um recompensado carregado).
static func can_show(profile: Dictionary) -> bool:
	return Store.ads_allowed(profile) and (mode() != "admob" or (_admob != null and _admob.rewarded_ready()))


## Chama `target` quando um anúncio carrega ou é usado (a tela troca o texto do botão).
static func on_ready_changed(target: Callable) -> void:
	if _admob != null and not _admob.ready_changed.is_connected(target):
		_admob.ready_changed.connect(target)


## Opções › Privacidade e anúncios: só quando o UMP exige (EEE, Reino Unido...).
static func privacy_options_required() -> bool:
	return _admob != null and _admob.privacy_options_required()


static func show_privacy_options(done: Callable) -> void:
	if _admob != null:
		_admob.show_privacy_options(done)
	else:
		done.call_deferred()


## Regra pura do anúncio real: recompensa se o Google confirmou; anúncio que não abriu (falha técnica)
## ou que nem havia carregado vale como "sem anúncio": de presente, salvo se `allow_free` for falso (o
## jogador já recusou um anúncio por esta recompensa). Fechado antes do fim (DECLINED) ou preso (LOST): nada.
static func rewarded_granted(outcome: StringName, allow_free: bool) -> bool:
	return outcome == EARNED or (outcome == FAILED and allow_free)


## Pede um anúncio recompensado; `done(granted: bool)` vem depois (no quadro seguinte sem anúncio). Só o
## anúncio real pode negar: fechado antes do fim, sem recompensa. `allow_free` falso tira o presente de
## "sem anúncio": quem fechou um anúncio por esta recompensa não a ganha de graça logo em seguida (o
## anúncio usado sai da fila e o próximo ainda não carregou). Só vale no AdMob; Steam, apoiador, "mock" e
## "off" seguem de presente.
static func show_rewarded(profile: Dictionary, done: Callable, allow_free: bool = true) -> void:
	if _showing:
		return
	if not Store.ads_allowed(profile) or mode() != "admob":
		done.call_deferred(true)
		return
	if _admob == null or not _admob.rewarded_ready():
		done.call_deferred(rewarded_granted(FAILED, allow_free))
		return
	_showing = true
	var tree := _admob.get_tree()
	var was_paused := tree.paused
	tree.paused = true
	var master := AudioServer.get_bus_index("Master")
	var muted := AudioServer.is_bus_mute(master)
	AudioServer.set_bus_mute(master, true)
	_admob.show_rewarded(func(outcome: StringName) -> void:
		_showing = false
		AudioServer.set_bus_mute(master, muted)
		tree.paused = was_paused
		done.call(rewarded_granted(outcome, allow_free)))
