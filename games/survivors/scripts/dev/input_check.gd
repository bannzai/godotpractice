extends SceneTree
## InputMap と実際の UI を通し、キーボード・パッドの操作と画面遷移を検証する。

var state: Node
var main: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


# 入力イベントを順に発生させる結合検証なので非冪等。
func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("RunState")
	await process_frame
	_check(state.phase == "title", "タイトルから開始")
	await _key(KEY_ENTER)
	_check(state.phase == "playing", "Enter で開始")
	var origin: Vector2 = state.player_pos
	await _key(KEY_D, 0.15)
	_check(state.player_pos.x > origin.x + 10, "D で右移動")
	await _key(KEY_ESCAPE)
	_check(state.phase == "paused", "Esc で休止")
	var paused_time: float = state.elapsed
	await create_timer(0.1).timeout
	_check(state.elapsed == paused_time, "休止中は時刻が進まない")
	await _pad(JOY_BUTTON_START)
	_check(state.phase == "playing", "Start で再開")
	origin = state.player_pos
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = -1.0
	Input.parse_input_event(axis)
	await create_timer(0.15).timeout
	axis = InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.0
	Input.parse_input_event(axis)
	_check(state.player_pos.x < origin.x - 10, "左スティックで左移動")
	state.gain_xp(12)
	await process_frame
	await process_frame
	_check(state.phase == "upgrade", "経験値で強化選択")
	var first: Control = root.gui_get_focus_owner()
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_check(root.gui_get_focus_owner() != first, "十字キーで選択肢を移動")
	await _pad(JOY_BUTTON_A)
	_check(state.phase == "playing", "A で強化決定")
	state.invulnerable = 0.0
	state.take_damage(1000)
	await process_frame
	await process_frame
	_check(state.phase == "result" and not state.won, "敗北結果へ遷移")
	await _pad(JOY_BUTTON_A)
	_check(state.phase == "playing" and state.level == 1, "A で初期状態へ再開")
	state.elapsed = 599.99
	await create_timer(0.1).timeout
	_check(state.phase == "result" and state.won, "時間満了でクリア結果")
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	_check(state.phase == "title", "結果からタイトルへ戻る")
	await _check_mouse_and_multiple_levels()
	await _check_fullscreen()
	main.queue_free()
	await process_frame
	if not failed:
		print("inputcheck OK")
	quit(1 if failed else 0)


func _check_mouse_and_multiple_levels() -> void:
	var click := InputEventMouseButton.new()
	click.position = Vector2(265, 465)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click = InputEventMouseButton.new()
	click.position = Vector2(265, 465)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	_check(state.phase == "playing", "マウスで開始")
	state.gain_xp(60)
	await process_frame
	await process_frame
	for _index: int in range(3):
		_check(state.phase == "upgrade", "蓄積経験値による連続強化")
		await _key(KEY_ENTER)
	_check(state.phase == "playing" and state.level == 4, "連続強化後に探索へ復帰")


func _check_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var original_mode: int = DisplayServer.window_get_mode()
	await _key(KEY_F11, 0.1)
	await create_timer(1.2).timeout
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11 で全画面")
	await _key(KEY_F11, 0.1)
	await create_timer(1.2).timeout
	_check(DisplayServer.window_get_mode() == original_mode, "F11 でウィンドウへ復帰")


func _key(code: Key, hold: float = 0.03) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(hold).timeout
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _pad(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.03).timeout
	event = InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("inputcheck FAIL: " + label)
