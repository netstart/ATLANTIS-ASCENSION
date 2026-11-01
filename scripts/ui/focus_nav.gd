class_name FocusNav
extends Node
## Menus pelo controle e pelo teclado (Steam Deck, PC). O foco do Godot já anda entre os botões pela
## geometria (D-pad, analógico, setas) e o tema já desenha o estado "focus"; faltava alguém dar o
## primeiro foco: sem ele, apertar o D-pad numa tela recém-aberta não fazia nada.
##
## Aqui fica o modo de entrada atual (pad): verdadeiro depois de um botão do controle, analógico ou
## tecla; falso depois de um toque ou clique. Com o pad ativo, o App foca o controle padrão de cada
## tela que abre (Screen.default_focus); no toque nada muda (o foco só aparece no botão tocado, como
## antes). Toda ScrollContainer passa a seguir o foco: descer pela lista com o D-pad rola até o cartão.
##
## install(tree) liga isso para a árvore inteira (o App chama no início), como UiFx e TouchScroll.

## Ações que movem ou usam o foco: a primeira delas numa tela sem foco só acorda o foco.
const NAV_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept",
		&"ui_focus_next", &"ui_focus_prev"]
## Analógico abaixo disto é ruído do repouso (não troca o modo de entrada).
const AXIS_DEAD := 0.5
## Espera (s) até o foco chegar a um painel que abre no meio da ação (reviver, bênção).
const ARM_SECONDS := 0.6

## Última entrada veio do controle ou teclado (true) ou do toque e mouse (false).
static var pad: bool = false


static func install(tree: SceneTree) -> void:
	if tree.root.get_node_or_null(^"FocusNav") == null:
		var node := FocusNav.new()
		node.name = "FocusNav"
		tree.root.add_child.call_deferred(node)
	tree.node_added.connect(func(node: Node) -> void:
		if node is ScrollContainer:
			(node as ScrollContainer).follow_focus = true)


func _input(event: InputEvent) -> void:
	note(event)


## Atualiza o modo de entrada a partir de um evento (sem consumi-lo).
static func note(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventKey:
		if event.is_pressed():
			pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= AXIS_DEAD:
			pad = true
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.is_pressed():
			pad = false


static func is_nav(event: InputEvent) -> bool:
	for action: StringName in NAV_ACTIONS:
		if event.is_action_pressed(action):
			return true
	return false


## Controles visíveis que o controle e o teclado alcançam, na ordem da árvore.
static func all(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for node: Node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree():
			out.append(control)
	return out


## Primeiro controle alcançável dentro de root (as telas são montadas de cima para baixo); prefere
## os habilitados e cai num desabilitado só se não houver outro.
static func first(root: Node) -> Control:
	var fallback: Control = null
	for control: Control in all(root):
		if not (control is BaseButton and (control as BaseButton).disabled):
			return control
		if fallback == null:
			fallback = control
	return fallback


## Há foco num controle visível?
static func has_focus(viewport: Viewport) -> bool:
	var focused := viewport.gui_get_focus_owner() if viewport != null else null
	return focused != null and focused.is_visible_in_tree()


## Foca no próximo quadro (depois do layout e de quem soltou o foco ao trocar de tela).
static func focus(control: Control) -> void:
	if control != null:
		(func() -> void:
			if is_instance_valid(control) and control.is_visible_in_tree():
				control.grab_focus()).call_deferred()


## Foco atrasado para painéis que abrem no meio da ação, com o A (tiro) talvez apertado: nenhum toque
## de tiro escolhe sem o jogador ver o painel.
static func arm(button: Control) -> void:
	if not button.is_inside_tree():
		return
	button.get_tree().create_timer(ARM_SECONDS, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(button) and button.is_visible_in_tree():
			button.grab_focus())
