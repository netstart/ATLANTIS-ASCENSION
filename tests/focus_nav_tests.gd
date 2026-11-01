extends RefCounted
## Menus pelo controle (Steam Deck): A e B ligados a ui_accept e ui_cancel, foco inicial em cada tela
## aberta pelo controle, nenhum foco aberto pelo toque, D-pad acorda o foco numa tela sem foco, lista
## que remonta mantém o foco no mesmo lugar, listas seguem o foco e o mapa anda pelas missões abertas.
## Chamado por tests/integration_tests.gd.

const LayoutTests := preload("res://tests/layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")


func run(host: Node, check: Callable) -> void:
	InputSetup.ensure_actions()
	check.call(_has_button(&"ui_accept", JOY_BUTTON_A), "Controle: A confirma nos menus (ui_accept)")
	check.call(_has_button(&"ui_cancel", JOY_BUTTON_B), "Controle: B volta nos menus (ui_cancel)")
	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	LayoutTests.fit(app, DeviceProfiles.main_view())
	var viewport := host.get_viewport()

	FocusNav.pad = false
	app.go(&"hub")
	await LayoutTests.settle(host)
	check.call(not FocusNav.has_focus(viewport), "Controle: tela aberta pelo toque fica sem foco")
	_press(&"ui_down")
	await LayoutTests.settle(host)
	check.call(viewport.gui_get_focus_owner() == app.screen(&"hub").default_focus(),
			"Controle: o primeiro D-pad numa tela sem foco foca o JOGAR")

	FocusNav.pad = true
	app.go(&"options")
	await LayoutTests.settle(host)
	var options := app.screen(&"options") as ListScreen
	var focused := viewport.gui_get_focus_owner()
	check.call(focused != null and focused.name != "Back" and options.is_ancestor_of(focused),
			"Controle: a lista abre no primeiro item, não no Voltar")
	var scroll := options.find_child("List", true, false) as ScrollContainer
	check.call(scroll != null and scroll.follow_focus, "Controle: a lista rola atrás do foco")
	var before := focused
	_press(&"ui_down")
	await LayoutTests.settle(host)
	focused = viewport.gui_get_focus_owner()
	check.call(focused != null and focused != before and options.is_ancestor_of(focused),
			"Controle: D-pad para baixo anda na lista")
	var controls := FocusNav.all(options)
	var index := controls.find(focused)
	options.refill()
	await LayoutTests.settle(host)
	check.call(FocusNav.all(options).find(viewport.gui_get_focus_owner()) == index,
			"Controle: a lista remontada mantém o foco no mesmo item")

	var pad_b := InputEventJoypadButton.new()
	pad_b.button_index = JOY_BUTTON_B
	pad_b.pressed = true
	Input.parse_input_event(pad_b)
	await LayoutTests.settle(host)
	check.call(app.current == &"hub", "Controle: B volta para a tela anterior")
	check.call(viewport.gui_get_focus_owner() == app.screen(&"hub").default_focus(),
			"Controle: a tela de volta abre com foco")

	SaveManager.mission_record(&"c1m1")["cleared"] = true
	app.go(&"map")
	var map := app.screen(&"map") as MapScreen
	await _frames(host, 150)
	var order := map.pad_order()
	check.call(order.slice(0, 2) == [&"c1m1", &"c1m2"], "Controle: o mapa sobe da 1-1 para a 1-2")
	check.call(map.selected == &"c1m2" and viewport.gui_get_focus_owner() == _node(map, &"c1m2"),
			"Controle: o mapa abre com foco na próxima missão (%s)" % _name(viewport.gui_get_focus_owner()))
	_press(&"ui_down")
	await _frames(host, 150)
	check.call(map.selected == &"c1m1" and viewport.gui_get_focus_owner() == _node(map, &"c1m1"),
			"Controle: baixo desce para a missão anterior e a câmera vai junto")
	_press(&"ui_down")
	await LayoutTests.settle(host)
	check.call(viewport.gui_get_focus_owner() == map.find_child("PlayMission", true, false),
			"Controle: baixo na primeira missão leva ao Jogar")
	_press(&"ui_up")
	await LayoutTests.settle(host)
	check.call(viewport.gui_get_focus_owner() == _node(map, &"c1m1"),
			"Controle: cima no Jogar volta para a missão escolhida")
	_press(&"ui_up")
	await _frames(host, 150)
	check.call(map.selected == &"c1m2" and viewport.gui_get_focus_owner() == _node(map, &"c1m2"),
			"Controle: cima sobe para a próxima missão aberta")

	FocusNav.pad = false
	app.queue_free()
	await host.get_tree().process_frame


static func _node(map: MapScreen, id: StringName) -> Control:
	return map.find_child("Node_" + String(id), true, false) as Control


static func _frames(host: Node, count: int) -> void:
	for i: int in range(count):
		await host.get_tree().process_frame


static func _name(control: Control) -> String:
	return String(control.name) if control != null else "nenhum"


static func _has_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


static func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
