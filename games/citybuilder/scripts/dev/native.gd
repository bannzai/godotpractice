extends SceneTree
## 描画ありでF11を往復し、ネイティブのウィンドウ状態と保存画像を検査する。

var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


# OSの画面切替を待つ実行シナリオなので一巡だけ進める。
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("native検証には描画が必要です")
		quit(1)
		return
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("City").saving_enabled = false
	await create_timer(0.8).timeout
	await _key(KEY_F11)
	await create_timer(1.2).timeout
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11で全画面")
	await _shot("fullscreen")
	await _key(KEY_F11)
	await create_timer(1.2).timeout
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "F11でウィンドウ復帰")
	await _shot("windowed")
	await root.get_node("Sound").shutdown()
	main.queue_free()
	await process_frame
	print("native OK" if not failed else "native FAIL")
	quit(1 if failed else 0)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://tmp/native-" + name + ".png")
	_check(result == OK, "画面保存: " + name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
