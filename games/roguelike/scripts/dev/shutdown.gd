extends SceneTree
## 通常の起動targetで全画面切替とウィンドウ終了要求を検証する。

var main: Node
var failed: bool = false


func _initialize() -> void:
	_verify.call_deferred()


# 実ウィンドウのモードと入力を順に変えるため非冪等。
func _verify() -> void:
	root.get_node("RunState").save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	_check(root.get_texture().get_image().save_png("res://tmp/screenshot-run.png") == OK,
		"起動画面を保存できる")
	await _key(KEY_F11)
	await create_timer(1.1).timeout
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"F11で全画面になる")
	_check(root.get_texture().get_image().save_png("res://tmp/screenshot-fullscreen.png") == OK,
		"全画面を保存できる")
	await _key(KEY_F11)
	await create_timer(1.1).timeout
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
		"F11でウィンドウへ戻る")
	main.start_new(609)
	root.get_node("Sound").play("hit")
	await create_timer(0.5).timeout
	if failed:
		await root.get_node("Sound").shutdown()
		quit(1)
		return
	print("通常起動・F11往復・音声再生中の通常終了 OK")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _key(code: Key) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)


func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
