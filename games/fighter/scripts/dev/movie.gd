extends SceneTree
## Movie Maker のミックス更新中に音声を停止し、再生リソースを解放してから終了する。
## フレームを消費する録画処理なので非冪等。


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or not arguments[0].is_valid_int() or int(arguments[0]) < 6:
		push_error("録画フレーム数には6以上の整数が必要")
		quit(1)
		return
	var frames: int = int(arguments[0])
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in range(frames):
		if frame == frames - 4:
			main.stop_audio()
		await process_frame
	quit(0)
