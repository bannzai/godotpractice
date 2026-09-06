extends SceneTree
## 起動からタイトル表示を撮影し、音を停止してから終了する。


func _initialize() -> void:
	_run.call_deferred()


# 録画フレームを進める開発専用の一度限りの処理。
func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for _frame: int in range(134):
		await process_frame
	await main.prepare_shutdown()
	print("movie OK")
	quit()
