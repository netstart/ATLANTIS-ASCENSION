class_name Screen
extends Control
## Base das telas do App: ocupa a tela inteira, recalcula o layout quando o tamanho ou a área segura
## mudam (furo da câmera que troca de lado ao girar 180°) e pede navegação por sinal, sem conhecer o
## App.

signal navigate(screen: StringName)
## Pede para começar uma missão.
signal play(mission_id: StringName)
## Pede para começar um modo (Arcade, Boss Rush, Diário, Sobrevivência).
signal play_mode(mode: StringName)
## Pede uma missão de prática (sem recompensas).
signal play_practice(mission_id: StringName)

## Área segura atual (fora do recorte da câmera), em coordenadas da própria tela.
var safe := Rect2()
## O idioma mudou com a tela escondida: os textos esperam a próxima abertura (present), em vez de
## remontar no mesmo quadro todas as telas já criadas.
var _stale_texts: bool = false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	resized.connect(relayout)
	MenuKit.on_insets_change(self, relayout)
	Locale.language_changed.connect(_on_language_changed)
	# O App sempre chama present() logo depois de criar a tela: a que monta os textos no on_show não os
	# monta aqui (montaria tudo duas vezes na primeira abertura). O relayout fica: o on_show já
	# encontra `safe` e o tamanho calculados (o hangar escolhe a escala da nave por eles).
	if not refreshes_on_show():
		refresh_texts()
	relayout()


## Mostra a tela (App.go): textos do idioma trocado enquanto ela estava escondida e depois on_show.
func present(app: Node) -> void:
	if _stale_texts and not refreshes_on_show():
		refresh_texts()
	_stale_texts = false
	on_show(app)


func _on_language_changed(_code: String) -> void:
	if is_visible_in_tree():
		refresh_texts()
	else:
		_stale_texts = true


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


## O on_show sempre chama refresh_texts(): a tela não monta os textos no _ready nem ao voltar depois
## de uma troca de idioma escondida (o on_show já monta com o estado novo).
func refreshes_on_show() -> bool:
	return false


## Controle que recebe o foco quando a tela abre pelo controle ou teclado (FocusNav); null deixa a
## tela sem foco até o primeiro movimento.
func default_focus() -> Control:
	return FocusNav.first(self)


## Volta de nível (botão voltar do Android, Esc, B do controle). Devolve se tratou; false deixa o
## App voltar pelo histórico.
func back() -> bool:
	return false
