class_name Screen
extends Control
## Base das telas do App: ocupa a tela inteira, recalcula o layout quando o tamanho ou a área segura
## mudam (furo da câmera que troca de lado ao girar 180°) e pede navegação por sinal, sem conhecer o
## App.

signal navigate(screen: StringName)
## Pede para começar uma missão.
signal play(mission_id: StringName)

## Área segura atual (fora do recorte da câmera), em coordenadas da própria tela.
var safe := Rect2()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	resized.connect(relayout)
	MenuKit.on_insets_change(self, relayout)
	Locale.language_changed.connect(func(_code: String) -> void: refresh_texts())
	refresh_texts()
	relayout()


func relayout() -> void:
	safe = MenuKit.safe_rect(size, MenuKit.safe_margins(self))
	_layout()


## Cria os nós (uma vez).
func _build() -> void:
	pass


## Posiciona os nós a partir de `safe` e `size`.
func _layout() -> void:
	pass


## Textos do idioma atual.
func refresh_texts() -> void:
	pass


## A tela ficou visível (o App passa a si mesmo para leitura de estado, como o último resultado).
func on_show(_app: Node) -> void:
	pass


## Volta de nível (botão voltar do Android, Esc, B do controle). Devolve se tratou; false deixa o
## App voltar pelo histórico.
func back() -> bool:
	return false
