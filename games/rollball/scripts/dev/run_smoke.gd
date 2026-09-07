extends SceneTree
## エディタなしの起動入口で実入力・全画面・復帰・閉じる要求を一度検証する。

var game: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DirAccess.make_dir_recursive_absolute("res://tmp") != OK:
		push_error("通常起動の撮影先を作成できない")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.8).timeout
	await _capture("run-title")
	await _key(KEY_ENTER)
	await create_timer(0.4).timeout
	await _capture("run-stage-select")
	await _key(KEY_RIGHT)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await create_timer(0.4).timeout
	await _capture("run-tutorial")
	for _step: int in range(3):
		await _key(KEY_ENTER)
	await create_timer(0.6).timeout
	if game.get_node("/root/RunState").phase != "playing":
		push_error("タイトルから部屋選択と初回案内を経て開始できない")
		quit(1)
		return
	var before: Vector3 = game.ball.position
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.5).timeout
	event.pressed = false
	Input.parse_input_event(event)
	if game.ball.position.distance_to(before) < 0.2:
		push_error("通常起動の移動入力が反映されない")
		quit(1)
		return
	await _capture("run-play")
	await _key(KEY_F11)
	await create_timer(0.8).timeout
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		push_error("全画面へ切り替わらない")
		quit(1)
		return
	await _capture("run-fullscreen")
	await _key(KEY_F11)
	await create_timer(0.8).timeout
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		push_error("ウィンドウ表示へ復帰しない")
		quit(1)
		return
	await _key(KEY_ESCAPE)
	await create_timer(0.6).timeout
	await _capture("run-return")
	print("run OK")
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	for _frame: int in range(2):
		await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	for _frame: int in range(2):
		await process_frame


func _capture(label: String) -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var status: Error = root.get_texture().get_image().save_png("res://tmp/%s.png" % label)
	if status != OK:
		push_error("通常起動の撮影失敗")
		quit(1)
