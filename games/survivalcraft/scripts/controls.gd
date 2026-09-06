extends RefCounted
## 入力の割り当て。再構成しても同じイベント集合になる。

static func configure() -> void:
	_bind("move_left", KEY_A, -1, JOY_AXIS_LEFT_X, -1.0)
	_bind("move_right", KEY_D, -1, JOY_AXIS_LEFT_X, 1.0)
	_bind("move_forward", KEY_W, -1, JOY_AXIS_LEFT_Y, -1.0)
	_bind("move_back", KEY_S, -1, JOY_AXIS_LEFT_Y, 1.0)
	_bind("look_left", KEY_LEFT, -1, JOY_AXIS_RIGHT_X, -1.0)
	_bind("look_right", KEY_RIGHT, -1, JOY_AXIS_RIGHT_X, 1.0)
	_bind("look_up", KEY_UP, -1, JOY_AXIS_RIGHT_Y, -1.0)
	_bind("look_down", KEY_DOWN, -1, JOY_AXIS_RIGHT_Y, 1.0)
	_bind("jump", KEY_SPACE, JOY_BUTTON_A)
	_bind("mine", KEY_Q, JOY_BUTTON_RIGHT_SHOULDER, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind("place", KEY_R, JOY_BUTTON_LEFT_SHOULDER, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_bind("craft_menu", KEY_E, JOY_BUTTON_X)
	_bind("eat", KEY_F, JOY_BUTTON_Y)
	_bind("pause_game", KEY_ESCAPE, JOY_BUTTON_START)
	_bind("next_slot", KEY_TAB, JOY_BUTTON_DPAD_RIGHT)
	_bind("prev_slot", KEY_Z, JOY_BUTTON_DPAD_LEFT)
	_bind("fullscreen", KEY_F11)
	_bind("ui_accept", KEY_ENTER, JOY_BUTTON_A)
	_mouse("mine", MOUSE_BUTTON_LEFT)
	_mouse("place", MOUSE_BUTTON_RIGHT)


static func _bind(action: String, key: int, button: int = -1,
		axis: int = -1, value: float = 0.0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_erase_events(action)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = key
	InputMap.action_add_event(action, keyboard)
	if button >= 0:
		var pad := InputEventJoypadButton.new()
		pad.button_index = button
		InputMap.action_add_event(action, pad)
	if axis >= 0:
		var stick := InputEventJoypadMotion.new()
		stick.axis = axis
		stick.axis_value = value
		InputMap.action_add_event(action, stick)


static func _mouse(action: String, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
