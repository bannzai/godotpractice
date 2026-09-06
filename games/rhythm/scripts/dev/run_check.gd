extends SceneTree
## 通常描画・F11往復・通常終了を実入力で確認するため、時刻とウィンドウ状態を進める。

var _main: Control
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await create_timer(0.8).timeout
	await _capture("run-title")
	_tap_f11()
	await create_timer(1.5).timeout
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11で全画面")
	await _capture("run-fullscreen")
	_tap_f11()
	await create_timer(1.5).timeout
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "F11でウィンドウへ復帰")
	await _capture("run-windowed")
	_main.stop_audio()
	await create_timer(0.2).timeout
	if _failed:
		quit(1)
		return
	print("run-check OK: 通常描画・F11往復・終了通知")
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _tap_f11() -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_F11
		event.physical_keycode = KEY_F11
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var status: Error = root.get_texture().get_image().save_png("res://tmp/%s.png" % name)
	_check(status == OK, "PNG保存: " + name)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error(label)
