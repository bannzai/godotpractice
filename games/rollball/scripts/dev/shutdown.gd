extends SceneTree
## ウィンドウの閉じる要求と同じ経路で音声を停止し、終了コードを検証する。


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for _frame: int in range(20):
		await process_frame
	game.start_run()
	for _frame: int in range(20):
		await process_frame
	print("shutdown OK")
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
