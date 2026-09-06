extends SceneTree
## OSの閉じる通知と同じ経路で正常終了することを検査する。


func _initialize() -> void:
	_run.call_deferred()


# ウィンドウを閉じる操作は一度限りのイベント。
func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for _frame: int in range(30):
		await process_frame
	print("run smoke OK: ウィンドウ終了通知を送信")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
