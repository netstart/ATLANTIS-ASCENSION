extends Node
## Preferências do jogador (plano mestre 2.3, 2.4 e 7.5), salvas em user://settings.cfg.
## Ficam separadas do save de progresso: apagar uma não afeta a outra.
##
## Origem: settings.gd do projeto hyakki (mesmo autor, MIT), com as opções deste jogo.

signal changed(key: String)

const PATH := "user://settings.cfg"
## Arquivo dos testes (use_test_file): o do jogador nunca é tocado por eles.
const TEST_PATH := "user://test_settings.cfg"
const VERSION := 1
const DEFAULTS := {
	"language": "",
	"music_volume": 0.7,
	"sfx_volume": 0.85,
	"ui_volume": 0.8,
	"vibration": true,
	"vibration_strength": 1.0,
	"fps": 60,
	"text_scale": 1.0,
	## "off" | "protanopia" | "deuteranopia" | "tritanopia" (paleta das balas inimigas).
	"colorblind": "off",
	"reduce_flashes": false,
	## Multiplicador do tremor de tela (0 desliga).
	"screen_shake": 1.0,
	## Corta o parallax por inclinação e limita o deslocamento das camadas.
	"reduce_motion": false,
	"tilt_parallax": true,
	## Sensibilidade do arrasto relativo (0,8 a 2,0).
	"drag_sensitivity": 1.25,
	"auto_fire": true,
	## "right" | "left": lado dos botões da zona do polegar.
	"handedness": "right",
	## Bomba de pânico automática ao receber dano.
	"panic_bomb": false,
	## Qualidade gráfica (GfxQuality): "auto" | "low" | "medium" | "high".
	"graphics_quality": "auto",
	"show_fps": false,
	## Fantasma do Abismo: o recorde voa junto, translúcido.
	"ghost": true,
	## PC e Steam: "portrait" (janela em pé, modo tate), "landscape" (janela deitada, campo 9:16 no centro) ou
	## "fullscreen" (a orientação segue o monitor; monitor girado no sistema = tate em tela cheia).
	"window_mode": "portrait",
}

var path: String = PATH
var _values: Dictionary = {}
var _last_vibration_ms: int = 0


func _ready() -> void:
	load_settings()


## Testes: passa a ler e gravar em TEST_PATH, começando dos padrões.
func use_test_file() -> void:
	path = TEST_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	load_settings()


func load_settings() -> void:
	_values = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(path) == OK:
		for key: String in DEFAULTS:
			if config.has_section_key("settings", key):
				_values[key] = config.get_value("settings", key)
	apply_engine_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in _values:
		config.set_value("settings", key, _values[key])
	config.set_value("meta", "version", VERSION)
	config.save(path)


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	save_settings()
	apply_engine_settings()
	changed.emit(key)


## Limite de FPS pela opção, sem brigar com o VSync quando ela pede a taxa da tela (FramePacing).
func apply_engine_settings() -> void:
	FramePacing.apply(int(get_value("fps")))


## Vibração curta, respeitando a opção, a intensidade e um intervalo mínimo de 80 ms reais.
func vibrate(duration_ms: int, amplitude: float = -1.0) -> void:
	if not bool(get_value("vibration")):
		return
	var now := Time.get_ticks_msec()
	if now - _last_vibration_ms < 80:
		return
	_last_vibration_ms = now
	var strength := clampf(float(get_value("vibration_strength")), 0.0, 1.0)
	Input.vibrate_handheld(duration_ms, amplitude if amplitude >= 0.0 else strength)
