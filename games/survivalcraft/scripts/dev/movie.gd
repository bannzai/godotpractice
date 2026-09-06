extends SceneTree
## 音声停止後のフレームを確保してタイトル起動を録画する。


func _initialize() -> void:
	_record.call_deferred()


func _record() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var frames: int = maxi(12, int(arguments[0])) if not arguments.is_empty() else 150
	for index: int in range(frames):
		if index == frames - 10:
			main.stop_audio()
		await process_frame
	quit(0)
