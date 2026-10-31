extends Node
## Escala inteira da tela (docs/policies/testes.md, "Resoluções-alvo").
##
## - Retrato (Android): k = min(round(largura / 300), floor(altura / 480)). É a regra do hyakki com a
##   tela girada: no Redmi Note 14 Pro+ (1220x2712) dá k = 4 e 305x678 pixels lógicos.
## - Paisagem (Steam, desktop): k = floor(altura / 540). Altura lógica entre 540 e 800; a área de
##   jogo 9:16 fica no centro e as laterais recebem painéis.
## Sempre k >= 1. O stretch é "canvas_items": a tela lógica continua a mesma (layout, área de jogo e
## regras não mudam), mas texto, contornos e shaders são desenhados na resolução física do aparelho
## (nítidos em 1220x2712), e o pixel art sobe em múltiplo inteiro k com filtro nearest, sem borrão.
##
## Também é a fonte única da troca de área segura (recorte da câmera): girar o celular 180° leva o
## furo de cima para baixo SEM redimensionar a janela, então o sinal safe_insets_changed sai de uma
## checagem barata (a cada INSET_POLL s, só no celular), do size_changed da raiz e, nos testes, na
## hora em que MenuKit.set_test_insets troca o recorte simulado.
##
## Origem: pixel_scaler.gd do projeto hyakki (mesmo autor, MIT), com a regra por orientação.

signal safe_insets_changed

const TARGET_SHORT := 300.0
const MIN_LONG := 480.0
const LANDSCAPE_HEIGHT := 540.0
const INSET_POLL := 0.25
const WINDOW_MODES: Array[String] = ["portrait", "landscape", "fullscreen"]
## Janelas do PC: múltiplos inteiros destas bases (9:16 em pé e 16:9 deitada).
const PORTRAIT_BASE := Vector2i(270, 480)
const LANDSCAPE_BASE := Vector2i(480, 270)

var scale_factor: int = 1
var _last_safe: Array = []
var _inset_wait: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit_desktop_window()
	# Settings pelo caminho: este script também roda nos testes de regras, sem autoloads.
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		if String(settings.call("get_value", "window_mode")) != "portrait":
			apply_window_mode()
		settings.connect("changed", func(key: String) -> void:
			if key == "window_mode":
				apply_window_mode())
	get_tree().root.size_changed.connect(_on_size_changed)
	_apply()
	_last_safe = _safe_key()
	set_process(OS.has_feature("mobile"))


func _apply() -> void:
	var root := get_tree().root
	var window_size := root.size
	if window_size.x <= 0 or window_size.y <= 0:
		return
	scale_factor = factor_for(window_size)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = logical_for(window_size)


## Fator inteiro para uma tela física, pela orientação dela.
static func factor_for(physical: Vector2i) -> int:
	if physical.y >= physical.x:
		return maxi(1, mini(roundi(physical.x / TARGET_SHORT), floori(physical.y / MIN_LONG)))
	return maxi(1, floori(physical.y / LANDSCAPE_HEIGHT))


## Tela lógica para uma tela física.
static func logical_for(physical: Vector2i) -> Vector2i:
	var k := factor_for(physical)
	return Vector2i(floori(float(physical.x) / k), floori(float(physical.y) / k))


## Desktop em retrato: a janela padrão (2x a lógica) pode não caber num monitor 1080p. Reduz para o
## maior múltiplo inteiro da tela lógica que cabe na área útil. Não mexe em celular nem em headless.
func _fit_desktop_window() -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	var usable := DisplayServer.screen_get_usable_rect().size
	var window := DisplayServer.window_get_size()
	if usable.x <= 0 or (window.x <= usable.x and window.y <= usable.y):
		return
	var base := Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var k := maxi(1, mini(floori(float(usable.x) / base.x), floori(usable.y * 0.95 / base.y)))
	DisplayServer.window_set_size(base * k)


## PC e Steam: aplica o modo de janela das Opções. Em pé (tate) e deitada usam o maior múltiplo inteiro da base
## que cabe em 95% da área útil, centralizado; tela cheia deixa a orientação com o monitor.
func apply_window_mode() -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	var settings := get_node_or_null(^"/root/Settings")
	var mode := String(settings.call("get_value", "window_mode")) if settings != null else "portrait"
	if mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var usable := DisplayServer.screen_get_usable_rect()
	var size := window_size_for(mode, usable.size)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


## Tamanho da janela de um modo numa área útil (testável sem janela).
static func window_size_for(mode: String, usable: Vector2i) -> Vector2i:
	var base := LANDSCAPE_BASE if mode == "landscape" else PORTRAIT_BASE
	var k := maxi(1, mini(floori(usable.x * 0.95 / base.x), floori(usable.y * 0.95 / base.y)))
	return base * k


func _process(delta: float) -> void:
	_inset_wait -= delta
	if _inset_wait > 0.0:
		return
	_inset_wait = INSET_POLL
	check_safe_insets()


func _on_size_changed() -> void:
	_apply()
	check_safe_insets()


## Emite safe_insets_changed se a área segura (ou o recorte simulado dos testes) mudou.
func check_safe_insets() -> void:
	var key := _safe_key()
	if key == _last_safe:
		return
	_last_safe = key
	safe_insets_changed.emit()


func _safe_key() -> Array:
	var simulated: Variant = MenuKit.test_insets if MenuKit.test_insets_enabled else null
	if not OS.has_feature("mobile"):
		return [null, null, simulated]
	return [DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size(), simulated]
