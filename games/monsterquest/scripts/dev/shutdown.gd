extends SceneTree
## 通常のウィンドウ終了要求を、音楽・効果音の再生中に配送して検証する。


func _initialize() -> void:
	_run.call_deferred()


## 終了要求を実際の一回の操作として配送するため非冪等。
func _run() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.25).timeout
	main.start_new()
	main._play_sound("heal")
	await create_timer(0.20).timeout
	print("通常終了要求: BGM/SE再生中")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
