extends SceneTree
## 実際の入力イベントと HUD の接続を検証する。操作の積算が目的なので非冪等。

var failed: bool = false
var main: Node
var model: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_key_bindings()
	_check_button_bindings()
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	model = root.get_node("Expedition")
	await _frames(3)
	_check(model.phase == "title" and main.hud._title.visible, "起動時にタイトルを表示")
	await _tap_key(KEY_ENTER)
	_check(model.phase == "map" and main.hud._map.visible, "タイトルの Enter で島の絵地図を開く")
	await _tap_key(KEY_ENTER)
	_check(model.phase == "playing" and model.tutorial_page == 0,
		"地図の選択から操作ノートの 1 頁目を開く")
	var tutorial_remaining: float = model.remaining
	_key(KEY_W, true)
	await _frames(4)
	_key(KEY_W, false)
	_check(model.remaining == tutorial_remaining, "操作ノートを読んでいる間は探索時間を止める")
	await _tap_key(KEY_ENTER)
	_check(model.tutorial_page == 1, "決定操作で投げ方の頁へ進む")
	await _tap_button(JOY_BUTTON_A)
	_check(model.tutorial_page == 2, "パッド A で笛の頁へ進む")
	await _tap_button(JOY_BUTTON_A)
	_check(model.tutorial_page == -1 and model.tutorial_seen, "最後の頁から探索を開始する")
	await _check_keyboard()
	await _check_gamepad()
	await _check_mouse()
	await _check_animation_flow()
	await _check_result_loop()
	main.show_title()
	await _frames(2)
	await _check_fullscreen()
	main.stop_audio()
	await create_timer(0.15).timeout
	main.queue_free()
	await _frames(2)
	if failed:
		quit(1)
	else:
		print("integration OK")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("integration FAIL: " + message)


func _check_key_bindings() -> void:
	var bindings: Dictionary = {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"camera_left": [KEY_Q], "camera_right": [KEY_E], "throw": [KEY_SPACE],
		"whistle": [KEY_SHIFT], "dismiss": [KEY_R], "switch_kind": [KEY_TAB],
		"pause": [KEY_ESCAPE], "fullscreen": [KEY_F11],
	}
	for action: String in bindings:
		for key: int in bindings[action]:
			var found: bool = false
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey and event.physical_keycode == key:
					found = true
			_check(found, "%s に %s (%d) を割り当てる" % [action, OS.get_keycode_string(key), key])


func _check_button_bindings() -> void:
	var bindings: Dictionary = {
		"throw": JOY_BUTTON_A, "whistle": JOY_BUTTON_B,
		"switch_kind": JOY_BUTTON_X, "dismiss": JOY_BUTTON_Y,
		"pause": JOY_BUTTON_START, "ui_accept": JOY_BUTTON_A,
		"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN,
	}
	for action: String in bindings:
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == bindings[action]:
				found = true
		_check(found, "%s にパッドボタン %d を割り当てる" % [action, bindings[action]])


func _check_keyboard() -> void:
	main.start_day()
	await _frames(2)
	var initial: Vector3 = model.leader
	_key(KEY_W, true)
	await _frames(6)
	_key(KEY_W, false)
	await _frames(2)
	_check(model.leader.z < initial.z - 0.1, "W キーで前進")
	var yaw: float = main.yaw
	_key(KEY_Q, true)
	await _frames(5)
	_key(KEY_Q, false)
	await _frames(2)
	_check(main.yaw > yaw, "Q キーで視点回転")
	await _tap_key(KEY_TAB)
	_check(model.selected_kind == 1, "Tab キーで種別切替")
	await _tap_key(KEY_SPACE)
	_check(model.following_count() < 30, "Space キーで投げる")
	await _tap_key(KEY_R)
	_check(model.following_count() == 0, "R キーで解散")
	await _tap_key(KEY_SHIFT)
	_check(model.following_count() == 30, "Shift キーで笛を吹き再集合")
	await _tap_key(KEY_ESCAPE)
	_check(main.paused and main.hud._pause.visible, "Esc キーで休憩画面")
	var remaining: float = model.remaining
	initial = model.leader
	_key(KEY_W, true)
	await _frames(6)
	_key(KEY_W, false)
	_check(model.remaining == remaining and model.leader == initial, "休憩中は時間と移動が止まる")
	await _tap_key(KEY_ESCAPE)
	_check(not main.paused and not main.hud._pause.visible, "Esc キーで再開")
	await _frames(3)
	_check(model.remaining < remaining, "再開後は時間が進む")


func _check_gamepad() -> void:
	main.start_day()
	await _frames(2)
	var initial: Vector3 = model.leader
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(6)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(2)
	_check(model.leader.x > initial.x + 0.1, "左スティックで移動")
	var yaw: float = main.yaw
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(5)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(2)
	_check(main.yaw < yaw, "右スティックで視点回転")
	await _tap_button(JOY_BUTTON_X)
	_check(model.selected_kind == 1, "X ボタンで種別切替")
	await _tap_button(JOY_BUTTON_A)
	_check(model.following_count() < 30, "A ボタンで投げる")
	await _tap_button(JOY_BUTTON_Y)
	_check(model.following_count() == 0, "Y ボタンで解散")
	await _tap_button(JOY_BUTTON_B)
	_check(model.following_count() == 30, "B ボタンで笛を吹き再集合")
	await _tap_button(JOY_BUTTON_START)
	_check(main.paused and main.hud._pause.visible, "Start ボタンで休憩")
	var remaining: float = model.remaining
	await _frames(6)
	_check(model.remaining == remaining, "パッドの休憩中は制限時間が止まる")
	await _tap_button(JOY_BUTTON_START)
	_check(not main.paused, "Start ボタンで再開")
	await _frames(3)
	_check(model.remaining < remaining, "パッドで再開すると時間が進む")


func _check_mouse() -> void:
	main.start_day()
	await _frames(2)
	_mouse_motion(Vector2(420, 400))
	await _frames(3)
	var first_aim: Vector3 = main.aim
	_mouse_motion(Vector2(820, 400))
	await _frames(3)
	_check(main.mouse_aim, "マウス移動で照準操作へ切り替わる")
	_check(main.aim.distance_to(first_aim) > 1.0, "マウス位置に合わせて地面の照準が動く")
	await _tap_mouse(MOUSE_BUTTON_LEFT, Vector2(820, 400))
	_check(model.following_count() < 30, "左クリックで隊員を投げる")
	await _tap_key(KEY_R)
	_check(model.following_count() == 0, "右クリック前に隊列を解散")
	await _tap_mouse(MOUSE_BUTTON_RIGHT, Vector2(820, 400))
	_check(model.following_count() == 30, "右クリックの笛で隊員を再集合")
	_check(main.world.whistle_time > 0.0, "右クリックの笛が視覚効果に届く")


func _check_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var original: int = DisplayServer.window_get_mode()
	var expected: int = DisplayServer.WINDOW_MODE_FULLSCREEN
	if original == DisplayServer.WINDOW_MODE_FULLSCREEN:
		expected = DisplayServer.WINDOW_MODE_WINDOWED
	await _tap_key(KEY_F11)
	await create_timer(0.8).timeout
	_check(DisplayServer.window_get_mode() == expected, "F11 でウィンドウ表示モードが切り替わる")
	await _tap_key(KEY_F11)
	await create_timer(0.8).timeout
	_check(DisplayServer.window_get_mode() == original, "F11 の再押下で元の表示モードへ戻る")


func _check_animation_flow() -> void:
	main.start_day()
	await _frames(3)
	_key(KEY_W, true)
	await _frames(6)
	_check(main.world.leader_mesh.animation_player.current_animation == "walk",
		"移動入力から隊長の歩行アニメーションへ接続")
	_key(KEY_W, false)
	await _tap_key(KEY_SHIFT)
	await _tap_key(KEY_ESCAPE)
	var actor: Node3D = main.world.leader_mesh
	var position: float = actor.animation_player.current_animation_position
	var remaining: float = actor._action_time
	await _frames(8)
	_check(is_equal_approx(actor.animation_player.current_animation_position, position),
		"休憩中は部位アニメーションが止まる")
	_check(is_equal_approx(actor._action_time, remaining), "休憩中は一回演出の残り時間も止まる")
	await _tap_key(KEY_ESCAPE)
	await _frames(5)
	_check(actor._action_time < remaining, "再開すると一回演出が続きから動く")
	# 残り時間の差に頼ると、短時間の再出発で前日の姿勢とエフェクトが残る。
	main.start_day()
	main.world.notify_action("whistle")
	main.world.whistle_time = 1.0
	main.start_day()
	await _frames(3)
	_check(actor._action.is_empty() and main.world.whistle_time == 0.0,
		"短時間の再出発でも隊長の一回演出をリセット")
	_check(main.world.crew_meshes.size() == model.crew.size()
		and main.world._retired.is_empty(), "再出発時に前日の隊員表示を残さない")


func _check_result_loop() -> void:
	main.start_day()
	model.remaining = 0.001
	await _frames(3)
	_check(model.phase == "failed" and main.hud._result.visible, "失敗時に結果を表示")
	_check(main.hud._result_body.text.contains("0 / 5"), "結果に回収数を表示")
	await _tap_button(JOY_BUTTON_A)
	_check(model.phase == "playing" and model.crew.size() == 30, "結果から A ボタンで再出発")
	model.collected = model.goal
	await _frames(3)
	_check(model.phase == "clear" and main.hud._result.visible, "クリア時に結果を表示")
	_check(main.hud._result_heading.text == "おかえりなさい！", "クリアの見出しを表示")
	# 十字キーと決定ボタンから HUD の signal を通り、タイトル遷移に到達する。
	var result_buttons: Array[Node] = main.hud._result.find_children("*", "Button", true, false)
	_check(result_buttons.size() == 2, "結果画面に再開・タイトルの 2 ボタンがある")
	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	await _tap_button(JOY_BUTTON_A)
	await _frames(3)
	_check(model.phase == "title" and main.hud._title.visible, "結果から十字キーと A ボタンでタイトルへ戻る")
	main.hud._start.pressed.emit()
	await _frames(3)
	_check(model.phase == "map", "表紙から島の絵地図へ進む")
	main.hud._map_depart.pressed.emit()
	await _frames(3)
	_check(model.phase == "playing" and model.collected == 0,
		"地図の調査ボタンで新しい日を開始")


func _key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _axis(axis: int, value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _button(button: int, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse_motion(position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - root.get_mouse_position()
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse_button(button: int, pressed: bool, position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.global_position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap_mouse(button: int, position: Vector2) -> void:
	_mouse_button(button, true, position)
	await _frames(1)
	_mouse_button(button, false, position)
	await _frames(2)


func _tap_key(code: int) -> void:
	_key(code, true)
	await _frames(1)
	_key(code, false)
	await _frames(2)


func _tap_button(button: int) -> void:
	_button(button, true)
	await _frames(1)
	_button(button, false)
	await _frames(2)


func _frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame
