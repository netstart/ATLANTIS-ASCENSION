class_name InputSetup
extends RefCounted
## Ações de entrada criadas em código: teclado e controle (plano mestre 2.3). O toque é tratado
## pelo arrasto relativo da partida e pelos botões da zona do polegar.
##
## Origem: input_setup.gd do projeto hyakki (mesmo autor, MIT), com as ações deste jogo.

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"precise",
		&"fire", &"special", &"tide", &"bomb", &"pause", &"tab_prev", &"tab_next"]


static func ensure_actions() -> void:
	_add_keys(&"move_left", [KEY_A, KEY_LEFT])
	_add_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_add_keys(&"move_up", [KEY_W, KEY_UP])
	_add_keys(&"move_down", [KEY_S, KEY_DOWN])
	_add_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis(&"move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis(&"move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_button(&"move_left", JOY_BUTTON_DPAD_LEFT)
	_add_button(&"move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_button(&"move_up", JOY_BUTTON_DPAD_UP)
	_add_button(&"move_down", JOY_BUTTON_DPAD_DOWN)
	_add_keys(&"precise", [KEY_SHIFT])
	_add_axis(&"precise", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_keys(&"fire", [KEY_J])
	_add_button(&"fire", JOY_BUTTON_A)
	_add_keys(&"special", [KEY_K])
	_add_button(&"special", JOY_BUTTON_X)
	_add_keys(&"tide", [KEY_SPACE])
	_add_axis(&"tide", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_keys(&"bomb", [KEY_L])
	_add_button(&"bomb", JOY_BUTTON_B)
	_add_keys(&"pause", [KEY_ESCAPE, KEY_P])
	_add_button(&"pause", JOY_BUTTON_START)
	_add_button(&"tab_prev", JOY_BUTTON_LEFT_SHOULDER)
	_add_button(&"tab_next", JOY_BUTTON_RIGHT_SHOULDER)
	_add_keys(&"tab_prev", [KEY_Q])
	_add_keys(&"tab_next", [KEY_E])


static func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


static func _add_keys(action: StringName, keys: Array[Key]) -> void:
	_ensure(action)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


static func _add_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)


static func _add_button(action: StringName, button: JoyButton) -> void:
	_ensure(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
