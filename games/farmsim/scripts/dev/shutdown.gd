extends SceneTree
## ゲームへ通常のウィンドウ終了要求を届ける。


func _initialize() -> void:
	_run.call_deferred()


## 起動後に一度の終了要求を送る検証のため非冪等。
func _run() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.25).timeout
	main.start_new()
	await create_timer(0.25).timeout
	main.use_tool()
	await create_timer(0.20).timeout
	print("通常終了要求: 農作業と音声の終了処理")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
