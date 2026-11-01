class_name UiFx
extends RefCounted
## Resposta física da interface (redesenho 1.6): todo botão afunda ao apertar (0,94 em 60 ms) e volta
## com um pequeno salto (1,05 e 1,0 em 180 ms, curva "back"); foco e hover crescem 3 %. Instalado uma
## vez na árvore, vale para os botões criados depois, sem cada tela precisar lembrar.
## "Reduzir movimento" desliga a escala (as cores de estado do tema continuam).
##
## 1.9: o toque também acende uma onda com centelhas no ponto tocado (UiSpark) e a entrada de tela vira
## uma cascata: os blocos da tela surgem um após o outro enquanto a varredura de sonar sobe.

const PRESS_SCALE := 0.94
const POP_SCALE := 1.05
const FOCUS_SCALE := 1.03
const PRESS_TIME := 0.06
const POP_TIME := 0.18
const META_KEY := &"ui_fx"
const ENTER_TIME := 0.26
## Atraso entre um bloco e o próximo na cascata de entrada, e quantos blocos têm atraso próprio.
const CASCADE_STEP := 0.035
const CASCADE_MAX := 8


static func install(tree: SceneTree) -> void:
	if UiSpark.instance == null:
		tree.root.add_child.call_deferred(UiSpark.new())
	tree.node_added.connect(func(node: Node) -> void:
		if node is BaseButton and not node.has_meta(META_KEY):
			attach(node as BaseButton))


static func attach(button: BaseButton) -> void:
	button.set_meta(META_KEY, true)
	var center := func() -> void: button.pivot_offset = button.size * 0.5
	button.resized.connect(center)
	center.call()
	button.button_down.connect(func() -> void:
		_to(button, PRESS_SCALE, PRESS_TIME, Tween.TRANS_QUAD)
		_spark(button))
	button.button_up.connect(func() -> void: _pop(button))
	button.mouse_entered.connect(func() -> void: _to(button, FOCUS_SCALE, POP_TIME, Tween.TRANS_SINE))
	button.mouse_exited.connect(func() -> void: _rest(button))
	button.focus_entered.connect(func() -> void: _to(button, FOCUS_SCALE, POP_TIME, Tween.TRANS_SINE))
	button.focus_exited.connect(func() -> void: _rest(button))


## Onda no ponto do toque (ou no centro, pelo teclado e controle), na cor do papel do botão.
static func _spark(button: BaseButton) -> void:
	if UiSpark.instance == null or not button.is_inside_tree():
		return
	var rect := Rect2(Vector2.ZERO, button.size)
	var local := button.get_local_mouse_position()
	if not rect.has_point(local):
		local = rect.get_center()
	var color := UiTheme.GOLD if button.material == UiGlint.material() else UiTheme.CYAN
	UiSpark.instance.ripple(button.get_global_transform_with_canvas() * local, color)


static func reduced() -> bool:
	var loop := Engine.get_main_loop() as SceneTree
	var settings := loop.root.get_node_or_null(^"Settings") if loop != null else null
	return settings != null and bool(settings.call("get_value", "reduce_motion"))


static func _to(button: BaseButton, value: float, seconds: float, trans: Tween.TransitionType) -> void:
	if not button.is_inside_tree() or button.disabled or reduced():
		return
	_kill(button)
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * value, seconds).set_trans(trans).set_ease(Tween.EASE_OUT)
	button.set_meta(&"ui_fx_tween", tween)


static func _pop(button: BaseButton) -> void:
	if not button.is_inside_tree() or reduced():
		return
	_kill(button)
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * POP_SCALE, POP_TIME * 0.4).set_trans(Tween.TRANS_QUAD)
	var rest := FOCUS_SCALE if button.has_focus() else 1.0
	tween.tween_property(button, "scale", Vector2.ONE * rest, POP_TIME * 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button.set_meta(&"ui_fx_tween", tween)


static func _rest(button: BaseButton) -> void:
	if not button.is_inside_tree():
		return
	if button.has_focus() or button.is_hovered():
		return
	_kill(button)
	if reduced():
		button.scale = Vector2.ONE
		return
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_SINE)
	button.set_meta(&"ui_fx_tween", tween)


static func _kill(button: BaseButton) -> void:
	if not button.has_meta(&"ui_fx_tween"):
		return
	var old: Variant = button.get_meta(&"ui_fx_tween")
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()


## Entrada de tela: surge da água (transparente para opaco) e os blocos da tela chegam em cascata,
## de cima para baixo na ordem de criação, enquanto a varredura de sonar sobe. Blocos que a própria
## tela já está animando (alfa abaixo de 1, como o logo do título) ficam com a animação dela.
static func enter(screen: CanvasItem) -> void:
	if screen.has_meta(&"ui_fx_enter"):
		var old: Variant = screen.get_meta(&"ui_fx_enter")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).custom_step(99.0)
			(old as Tween).kill()
	if reduced():
		screen.modulate = Color.WHITE
		return
	screen.modulate = Color(1, 1, 1, 0)
	var tween := screen.create_tween().set_parallel(true)
	tween.tween_property(screen, "modulate", Color.WHITE, ENTER_TIME * 0.8) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var step := 0
	for child: Node in screen.get_children():
		var item := child as CanvasItem
		if item == null or not item.visible or item.modulate.a < 0.99:
			continue
		var target := item.modulate
		item.modulate = Color(target, 0.0)
		tween.tween_property(item, "modulate", target, ENTER_TIME) \
				.set_delay(CASCADE_STEP * mini(step, CASCADE_MAX)).set_trans(Tween.TRANS_SINE)
		step += 1
	screen.set_meta(&"ui_fx_enter", tween)
	if UiSpark.instance != null:
		UiSpark.instance.sweep()


## Contagem animada de um número num rótulo (resultados, moedas do hub): `from` até `value` em
## `seconds`, com formato.
static func count_up(label: Label, value: int, seconds: float, format: Callable, from: int = 0) -> Tween:
	var tween := label.create_tween()
	if reduced() or value <= 0 or value == from:
		label.text = format.call(value)
		# Tween vazio é erro no Godot: um intervalo nulo mantém o retorno encadeável.
		tween.tween_interval(0.0)
		return tween
	tween.tween_method(func(v: float) -> void: label.text = format.call(roundi(v)), float(from), float(value), seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween
