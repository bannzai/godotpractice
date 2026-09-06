extends SceneTree
## OSと同じ終了通知を送り、再生中の音声がある通常終了を検証する。


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("GameState").save_path = "res://tmp/shutdown-save.json"
	await create_timer(0.3).timeout
	main.start_run()
	main.fire_player()
	await create_timer(0.1).timeout
	if not main.music.playing:
		push_error("終了確認の前にBGMが再生されていない")
		quit(1)
		return
	print("shutdown_check: 音声再生中に通常の終了通知を送信")
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
