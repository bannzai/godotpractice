extends SceneTree
## 描画と音声を有効にして起動し、F11切替と通常の終了通知を検証する。
## 実入力・画面サイズ変更・時間経過は一回の動作確認として非冪等。

var main: Control
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.7).timeout
	await _capture("run-title")
	await _fullscreen_key()
	_check(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11でフルスクリーンになる"
	)
	await _capture("run-fullscreen")
	await _fullscreen_key()
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "F11でウィンドウへ戻る")
	if failed:
		main.stop_audio()
		await create_timer(0.2).timeout
		quit(1)
		return
	print("runcheck OK")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await create_timer(3.0).timeout
	push_error("通常の終了通知でゲームが終了しませんでした")
	quit(1)


func _fullscreen_key() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F11
	key.physical_keycode = KEY_F11
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await create_timer(0.7).timeout


func _capture(name_value: String) -> void:
	await process_frame
	await process_frame
	var status: Error = root.get_texture().get_image().save_png("res://tmp/%s.png" % name_value)
	_check(status == OK, "起動の描画を保存できる")


func _check(value: bool, description: String) -> void:
	if not value:
		failed = true
		push_error(description)
