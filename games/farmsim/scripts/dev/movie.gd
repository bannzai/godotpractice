extends SceneTree
## 録画の末尾に音声ミキサーが停止要求を処理する時間を残す。


func _initialize() -> void:
	_run.call_deferred()


## 時刻ごとの描画を記録するため非冪等。
func _run() -> void:
	var frames: int = 150
	for argument: String in OS.get_cmdline_user_args():
		if argument.is_valid_int():
			frames = maxi(15, int(argument))
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in frames:
		if frame == frames - 12:
			main.stop_audio()
		await process_frame
	quit(0)
