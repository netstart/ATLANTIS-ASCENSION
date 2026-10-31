class_name UiFx
extends RefCounted
## Resposta física da interface (redesenho 1.6): todo botão afunda ao apertar (0,94 em 60 ms) e volta
## com um pequeno salto (1,05 e 1,0 em 180 ms, curva "back"); foco e hover crescem 3 %. Instalado uma
## vez na árvore, vale para os botões criados depois, sem cada tela precisar lembrar.
## "Reduzir movimento" desliga a escala (as cores de estado do tema continuam).

const PRESS_SCALE := 0.94
const POP_SCALE := 1.05
const FOCUS_SCALE := 1.03
const PRESS_TIME := 0.06
const POP_TIME := 0.18
const META_KEY := &"ui_fx"


static func install(tree: SceneTree) -> void:
	tree.node_added.connect(func(node: Node) -> void:
		if node is BaseButton and not node.has_meta(META_KEY):
			attach(node as BaseButton))


static func attach(button: BaseButton) -> void:
	button.set_meta(META_KEY, true)
	var center := func() -> void: button.pivot_offset = button.size * 0.5
	button.resized.connect(center)
	center.call()
	button.button_down.connect(func() -> void: _to(button, PRESS_SCALE, PRESS_TIME, Tween.TRANS_QUAD))
	button.button_up.connect(func() -> void: _pop(button))
	button.mouse_entered.connect(func() -> void: _to(button, FOCUS_SCALE, POP_TIME, Tween.TRANS_SINE))
	button.mouse_exited.connect(func() -> void: _rest(button))
	button.focus_entered.connect(func() -> void: _to(button, FOCUS_SCALE, POP_TIME, Tween.TRANS_SINE))
	button.focus_exited.connect(func() -> void: _rest(button))


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


## Entrada de tela: surge da água (transparente para opaco) em 220 ms.
static func enter(screen: CanvasItem) -> void:
	if reduced():
		screen.modulate = Color.WHITE
		return
	screen.modulate = Color(1, 1, 1, 0)
	var tween := screen.create_tween()
	tween.tween_property(screen, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Contagem animada de um número num rótulo (resultados): 0 até `value` em `seconds`, com formato.
static func count_up(label: Label, value: int, seconds: float, format: Callable) -> Tween:
	var tween := label.create_tween()
	if reduced() or value <= 0:
		label.text = format.call(value)
		return tween
	tween.tween_method(func(v: float) -> void: label.text = format.call(roundi(v)), 0.0, float(value), seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween
