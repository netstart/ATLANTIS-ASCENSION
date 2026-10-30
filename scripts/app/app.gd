class_name App
extends Node
## Raiz do jogo: monta a camada de interface com o tema, troca de tela e trata o "voltar" do
## Android, o Esc e o B do controle. As telas pedem navegação pelo sinal Screen.navigate.

const SCREENS := {
	&"boot": preload("res://scripts/app/screens/boot_screen.gd"),
	&"credits": preload("res://scripts/app/screens/credits_screen.gd"),
}

var current: StringName = &""

var _layer: CanvasLayer
var _root: Control
var _screens: Dictionary = {}


func _ready() -> void:
	InputSetup.ensure_actions()
	TouchScroll.install(get_tree())
	_layer = CanvasLayer.new()
	add_child(_layer)
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.build(Locale.font)
	_layer.add_child(_root)
	Locale.language_changed.connect(_on_language_changed)
	go(&"boot")


func go(screen_name: StringName) -> void:
	if not SCREENS.has(screen_name):
		Log.error("App: tela desconhecida " + String(screen_name))
		return
	for key: StringName in _screens:
		(_screens[key] as Control).visible = key == screen_name
	if not _screens.has(screen_name):
		var screen := (SCREENS[screen_name] as GDScript).new() as Screen
		screen.name = String(screen_name).capitalize().replace(" ", "")
		screen.navigate.connect(go)
		_root.add_child(screen)
		_screens[screen_name] = screen
	current = screen_name
	Events.screen_changed.emit(screen_name)


## Tela já criada (testes).
func screen(screen_name: StringName) -> Screen:
	return _screens.get(screen_name) as Screen


## Raiz das telas (testes ajustam o tamanho para simular cada aparelho).
func root() -> Control:
	return _root


func back() -> void:
	var screen := screen(current)
	if screen != null and screen.back():
		return
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func _on_language_changed(_code: String) -> void:
	_root.theme = UiTheme.build(Locale.font)
