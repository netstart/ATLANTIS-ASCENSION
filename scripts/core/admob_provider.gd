class_name AdMobProvider
extends Node
## Anúncio recompensado REAL (plano mestre 17): Google Mobile Ads + consentimento UMP pelo plugin Poing
## AdMob (addons/admob, MIT). Só existe no Android grátis com o singleton nativo; `Ads` é quem o usa.
## Portado do hyakki (scripts/ads/admob_provider.gd, mesmo autor, MIT), só a parte de recompensado, UMP
## e opções de privacidade.
##
## IDs: build de debug usa os blocos de TESTE oficiais do Google (nunca geram receita nem ferem a
## política de cliques); release usa RELEASE_UNITS e `admob/general/android/app_id` do project.godot.
## Release sem IDs reais ficaria no modo "off": o SDK e o UMP nunca são iniciados e a recompensa sai
## direto, sem anúncio (docs/store/play-console.md, fim).

signal ready_changed

const SINGLETON := "PoingGodotAdMob"
## Blocos de teste do Google (developers.google.com/admob/android/test-ads).
const TEST_UNITS := {"rewarded": "ca-app-pub-3940256099942544/5224354917"}
## Blocos de produção deste jogo (AdMob do mantenedor, app ca-app-pub-6552169828297838~1447443371).
const RELEASE_UNITS := {"rewarded": "ca-app-pub-6552169828297838/1146567180"}
const RETRY_SECONDS := 20.0
## Prazo depois de o app voltar à frente para o anúncio "preso" ser liberado (`_notification`).
const RESUME_GRACE := 5.0
## ID real do app no project.godot; sem a linha valeria o padrão do plugin, o app de TESTE do Google.
const APP_ID_SETTING := "admob/general/android/app_id"
## Conta dos IDs de teste do Google: nunca vale como ID "real".
const TEST_PUBLISHER := "ca-app-pub-3940256099942544"

var initialized: bool = false
var _rewarded: RewardedAd
var _loader: RewardedAdLoader
var _loading: bool = false
var _initializing: bool = false
## Fim do anúncio na tela (rede de segurança de `_notification`); vazio sem anúncio aberto.
var _pending_finish: Callable


static func is_supported() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(SINGLETON)


static func has_release_ids() -> bool:
	return ids_configured(RELEASE_UNITS, String(ProjectSettings.get_setting(APP_ID_SETTING, "")))


## Regra pura: todo bloco e o ID do app preenchidos, nenhum de teste.
static func ids_configured(units: Dictionary, app_id: String) -> bool:
	if units.is_empty() or not _is_real_id(app_id, "~"):
		return false
	for kind: String in units:
		if not _is_real_id(String(units[kind]), "/"):
			return false
	return true


static func _is_real_id(id: String, separator: String) -> bool:
	id = id.strip_edges()
	return id.begins_with("ca-app-pub-") and id.contains(separator) and not id.begins_with(TEST_PUBLISHER)


## Regra pura: "admob" (SDK nativo e IDs de teste em debug ou reais em release), "mock" (debug sem o
## SDK: editor, testes, PC, APK de debug sem o plugin) ou "off" (release sem IDs reais ou sem o SDK; o
## simulado nunca chega a jogador de verdade).
static func startup_provider(is_debug: bool, release_ids: bool, sdk_supported: bool) -> String:
	if sdk_supported and (is_debug or release_ids):
		return "admob"
	return "mock" if is_debug else "off"


static func current_startup_provider() -> String:
	return startup_provider(OS.is_debug_build(), has_release_ids(), is_supported())


static func unit(kind: String) -> String:
	var release := String(RELEASE_UNITS.get(kind, ""))
	return String(TEST_UNITS[kind]) if OS.is_debug_build() or release.is_empty() else release


## Regra pura (política do Google, UMP): só se inicia o SDK e se pede anúncio com o consentimento obtido
## ou dispensado. REQUIRED (formulário não respondido ou falhou) e UNKNOWN (UMP sem resposta, sem internet
## na 1ª abertura) ficam sem anúncio, e a recompensa segue a regra de "sem anúncio" (Ads).
static func consent_allows_ads(status: int) -> bool:
	return status in [ConsentInformation.ConsentStatus.OBTAINED, ConsentInformation.ConsentStatus.NOT_REQUIRED]


## Consentimento pelo formulário oficial do Google (UMP) e, se ele permitir, o SDK. Assíncrono: a
## abertura nunca espera. Com o UMP em erro vale o estado guardado da sessão anterior.
func start() -> void:
	UserMessagingPlatform.consent_information.update(ConsentRequestParameters.new(),
			_after_consent_info, func(_error: FormError) -> void: _initialize_if_allowed())


func _after_consent_info() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED \
			and info.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(
				func(form: ConsentForm) -> void:
					form.show(func(_error: FormError) -> void: _initialize_if_allowed()),
				func(_error: FormError) -> void: _initialize_if_allowed())
	else:
		_initialize_if_allowed()


func _initialize_if_allowed() -> void:
	if initialized or _initializing \
			or not consent_allows_ads(UserMessagingPlatform.consent_information.get_consent_status()):
		return
	_initializing = true
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		initialized = true
		load_rewarded()
	var config := RequestConfiguration.new()
	# Classificação do jogo PEGI 7 / ESRB E10+ (docs/store/play-console.md): anúncio no máximo "PG".
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_PG
	MobileAds.set_request_configuration(config)
	MobileAds.initialize(listener)


## Opções › Privacidade e anúncios: o UMP diz se a entrada é exigida (EEE, Reino Unido, Suíça...).
func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
			== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


## A escolha nova pode liberar o SDK (quem recusou e depois aceitou).
func show_privacy_options(done: Callable) -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_error: FormError) -> void:
		_initialize_if_allowed()
		done.call())


func rewarded_ready() -> bool:
	return _rewarded != null


func load_rewarded() -> void:
	if _loading or _rewarded != null or not initialized:
		return
	_loading = true
	_loader = RewardedAdLoader.new()
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading = false
		_rewarded = ad
		ready_changed.emit()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading = false
		push_warning("AdMob: recompensado não carregou (%d) %s" % [error.code, error.message])
		get_tree().create_timer(RETRY_SECONDS, true).timeout.connect(load_rewarded)
	_loader.load(unit("rewarded"), AdRequest.new(), callback)


## `done(outcome)`, uma vez só: Ads.EARNED se o Google confirmar a recompensa (assistido até o fim),
## Ads.DECLINED se o jogador fechou antes, Ads.FAILED se o anúncio não abriu (falha técnica, não recusa)
## e Ads.LOST se o app voltou à frente e nenhum callback veio (rede de segurança, `_notification`).
func show_rewarded(done: Callable) -> void:
	if _rewarded == null:
		done.call(Ads.FAILED)
		return
	var ad := _rewarded
	_rewarded = null
	ready_changed.emit()
	var state := {"earned": false, "finished": false}
	var finish := func(outcome: StringName) -> void:
		if bool(state["finished"]):
			return
		state["finished"] = true
		_pending_finish = Callable()
		ad.destroy()
		load_rewarded()
		done.call(Ads.EARNED if bool(state["earned"]) else outcome)
	_pending_finish = finish.bind(Ads.LOST)
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = finish.bind(Ads.DECLINED)
	callbacks.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("AdMob: recompensado não abriu (%d) %s" % [error.code, error.message])
		finish.call(Ads.FAILED)
	ad.full_screen_content_callback = callbacks
	var reward := OnUserEarnedRewardListener.new()
	reward.on_user_earned_reward = func(_item: RewardedItem) -> void: state["earned"] = true
	ad.show(reward)


## Rede de segurança: o app voltou à frente com o anúncio ainda "aberto" e o callback de fechar não veio
## em RESUME_GRACE segundos. Libera a pausa e o som sem dar recompensa (salvo a já confirmada pelo Google).
## O prazo evita correr na frente do callback normal, que chega logo depois da volta.
func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN) \
			and _pending_finish.is_valid() and is_inside_tree():
		get_tree().create_timer(RESUME_GRACE, true, false, true).timeout.connect(_release_stuck)


func _release_stuck() -> void:
	if _pending_finish.is_valid():
		push_warning("AdMob: anúncio sem callback de fechar; liberado sem recompensa")
		_pending_finish.call()
