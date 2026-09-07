extends SceneTree
## 実入力で画面と対戦状態を検証する。勝敗境界だけ満杯盤面を注入する。

var main: Control
var state: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


# 入力と時間を順に適用する検証シナリオなので非冪等。
func _run() -> void:
	root.size = Vector2i(1280, 720)
	state = root.get_node("Session")
	state.save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	_check(state.screen == "title", "タイトルを表示")
	state.records.tutorial_seen = false
	await _tap_key(KEY_ENTER)
	_check(
		state.screen == "play" and state.mode == "cpu" and main.tutorial_step == 0,
		"Enterで対戦と初回チュートリアルを開始"
	)
	_check(state.paused, "チュートリアル中は盤面を停止")
	await _tap_key(KEY_ENTER)
	_check(main.tutorial_step == 1, "Enterでチュートリアルを進める")
	await _click_button("tutorial_skip")
	_check(
		main.tutorial_step == -1 and not state.paused and state.records.tutorial_seen,
		"チュートリアルをスキップして操作を開始"
	)
	await _check_piece_inputs()
	await _check_pause()
	await _check_results()
	main.set_process(false)
	state.set_process(false)
	await main.sound.shutdown()
	if not failed:
		print("integration OK: キー・パッド・スティック・マウスと画面遷移")
	quit(1 if failed else 0)


func _check_piece_inputs() -> void:
	var start_x: int = state.boards[0].position.x
	await _tap_key(KEY_LEFT)
	_check(state.boards[0].position.x == start_x - 1, "キーで左移動")
	await _tap_key(KEY_RIGHT)
	_check(state.boards[0].position.x == start_x, "キーで右移動")
	await _tap_key(KEY_X)
	_check(state.boards[0].rotation == 1, "キーで右回転")
	await _tap_key(KEY_Z)
	_check(state.boards[0].rotation == 0, "キーで左回転")
	await _tap_button(JOY_BUTTON_DPAD_LEFT)
	_check(state.boards[0].position.x == start_x - 1, "パッド十字で移動")
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(2)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(2)
	_check(state.boards[0].position.x == start_x, "左スティックで移動")
	await _tap_button(JOY_BUTTON_A)
	_check(state.boards[0].rotation == 1, "パッドAで右回転")
	await _tap_button(JOY_BUTTON_X)
	_check(state.boards[0].rotation == 0, "パッドXで左回転")
	var before_y: int = state.boards[0].position.y
	_key(KEY_DOWN, true)
	await create_timer(0.16).timeout
	_key(KEY_DOWN, false)
	_check(state.boards[0].position.y > before_y, "下キーでソフトドロップ")
	before_y = state.boards[0].position.y
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	await create_timer(0.12).timeout
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(state.boards[0].position.y > before_y, "スティック下でソフトドロップ")
	await _tap_key(KEY_SPACE)
	_check(state.boards[0].phase == "land", "Spaceでハードドロップして固定")
	await create_timer(0.3).timeout
	_check(state.boards[0].phase == "falling", "固定後に次の組が出る")
	await _tap_button(JOY_BUTTON_Y)
	_check(state.boards[0].phase == "land", "パッドYでハードドロップ")
	await create_timer(1.0).timeout


func _check_pause() -> void:
	await _tap_key(KEY_ESCAPE)
	_check(state.paused, "Escで一時停止")
	var elapsed: float = state.elapsed
	var board: Dictionary = state.boards[0].duplicate(true)
	await _tap_button(JOY_BUTTON_Y)
	await _tap_button(JOY_BUTTON_X)
	await create_timer(0.15).timeout
	_check(state.elapsed == elapsed and state.boards[0] == board, "一時停止中は操作と時間停止")
	await _tap_button(JOY_BUTTON_START)
	_check(not state.paused, "Startで再開")
	await _click_button("pause")
	_check(state.paused, "マウスで一時停止")
	await _click_button("resume")
	_check(not state.paused, "マウスで再開")


func _check_results() -> void:
	await _fill_cpu_board()
	_check(state.screen == "round" and state.wins == [1, 0], "満杯で1本取得しラウンド結果")
	await _tap_button(JOY_BUTTON_A)
	_check(state.screen == "play" and state.wins == [1, 0], "パッドAで次ラウンド")
	await _fill_cpu_board()
	_check(state.screen == "result" and state.wins == [2, 0], "2本先取で試合結果")
	main.score_display = 100000.0
	await _click_button("retry")
	_check(state.screen == "play" and state.wins == [0, 0], "結果からマウスで再戦")
	_check(main.score_display == 0.0, "再戦で前の試合の得点表示を消す")
	await _tap_key(KEY_ESCAPE)
	await _click_button("title")
	_check(state.screen == "title", "一時停止からタイトル")
	await _click_button("solo")
	_check(state.screen == "play" and state.mode == "solo", "マウスでひとりモード開始")
	# 90秒の終端だけを注入し、次の通常フレームで時間切れを判定させる。
	state.elapsed = state.LIMIT
	await _frames(3)
	_check(state.screen == "result", "制限時間で結果")
	await _tap_key(KEY_ENTER)
	_check(state.screen == "play" and state.mode == "solo", "結果からEnterで再戦")
	state.elapsed = state.LIMIT
	await _frames(3)
	await _click_button("title")
	_check(state.screen == "title", "結果からタイトル")


func _fill_cpu_board() -> void:
	# CPUが固定できない天井を用意する。決着処理そのものは通常更新で実行する。
	for row: Array in state.boards[1].board:
		row.fill(5)
	var deadline: int = Time.get_ticks_msec() + 3500
	while state.screen == "play" and Time.get_ticks_msec() < deadline:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("統合検証失敗: " + label)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await process_frame


func _key(key: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap_key(key: int) -> void:
	_key(key, true)
	await _frames(2)
	_key(key, false)
	await _frames(2)


func _tap_button(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)
	event = InputEventJoypadButton.new()
	event.button_index = button
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)


func _axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _click_button(button_name: String) -> void:
	var button: Button = main.content.get_node_or_null(button_name)
	_check(button != null, "クリック対象が存在: " + button_name)
	if button == null:
		return
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(2)
