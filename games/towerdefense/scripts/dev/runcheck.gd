extends SceneTree
## 通常の run 起動・音声ドライバでタイトルを撮り、実 Esc 入力による終了経路を検査する。
## 起動・撮影・終了を一度ずつ行う検証なので非冪等。

var main: Node
var sound: Node
var failed: bool = false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	sound = root.get_node("Sound")
	await create_timer(1.2).timeout
	_check(root.get_node("Run").phase == "title", "通常起動でタイトルを表示")
	_check(AudioServer.get_driver_name() != "Dummy", "通常の音声ドライバを使用")
	_check(sound.has_played and sound.music.playing, "タイトル BGM を再生")
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.save_png("res://tmp/run-title.png") == OK, "通常起動のタイトルを撮影")
	sound.shutdown_finished.connect(_normal_exit_confirmed)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await create_timer(5.0).timeout
	_check(false, "Esc 入力から 5 秒以内に通常終了")
	quit(1)


func _normal_exit_confirmed() -> void:
	_check(main.closing and sound.shutdown_complete, "通常の終了処理が完了")
	_check(sound.music.stream == null, "終了前に BGM の参照を解放")
	for player: AudioStreamPlayer in sound.effects:
		_check(player.stream == null, "終了前に SE の参照を解放")
	if not failed:
		print("runcheck OK")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error("runcheck FAIL: " + description)
