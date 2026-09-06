extends RefCounted
## キー列挙値から設定し、特殊キーの整数値の取り違えを避ける。


static func configure() -> void:
	_bind("ui_accept", [KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_A])
	_bind("ui_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT])
	_bind("ui_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT])
	_bind("ui_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP])
	_bind("ui_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_bind("wave", [KEY_SPACE], [JOY_BUTTON_Y])
	_bind("faster", [KEY_F], [JOY_BUTTON_X])
	_bind("tower_next", [KEY_TAB], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("upgrade", [KEY_U], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("sell", [KEY_X], [JOY_BUTTON_B])
	_bind("cancel", [KEY_ESCAPE], [JOY_BUTTON_START])
	_bind("fullscreen", [KEY_F11], [])
	for entry: Array in [["ui_left", JOY_AXIS_LEFT_X, -1.0],
		["ui_right", JOY_AXIS_LEFT_X, 1.0], ["ui_up", JOY_AXIS_LEFT_Y, -1.0],
		["ui_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = entry[1]
		motion.axis_value = entry[2]
		InputMap.action_add_event(entry[0], motion)


static func _bind(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	InputMap.action_erase_events(action)
	for code: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event(action, event)
	for code: JoyButton in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		InputMap.action_add_event(action, event)
