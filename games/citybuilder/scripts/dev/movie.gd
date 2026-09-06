extends SceneTree
## 起動画面の録画。終了前に音声スレッドを停止し、素材参照を解放する。


func _initialize() -> void:
	_run.call_deferred()


# 固定フレームの撮影手順を一巡だけ進める。
func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var frames: int = int(arguments[0]) if not arguments.is_empty() else 150
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in range(maxi(1, frames - 10)):
		await process_frame
	await root.get_node("Sound").shutdown()
	main.queue_free()
	await process_frame
	quit()
