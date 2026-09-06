extends SceneTree
## 録画の終了前に音声を停止し、オーディオ処理が再生資源を解放する時間を確保する。


func _initialize() -> void:
	_record.call_deferred()


## フレーム進行と録画を行うので一度だけ呼ぶ。
func _record() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var frames: int = int(arguments[0]) if not arguments.is_empty() else 150
	for index: int in range(maxi(frames, 10)):
		if index == maxi(frames, 10) - 6:
			main.stop_audio()
		await process_frame
	# 終端フレームまで庭を描画し、停止済みの音声とシーンは終了処理で解放する。
	quit(0)
