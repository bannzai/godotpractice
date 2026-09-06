extends SceneTree
## 音声停止を録画終端の前に行い、シーンを保持したまま終了する。

const RELEASE_FRAMES: int = 16

var movie_frames: int = 150


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		if arguments.size() != 2 or arguments[0] != "--movie-frames":
			push_error("録画フレーム数は --movie-frames <整数> で指定してください")
			quit(1)
			return
		if not arguments[1].is_valid_int():
			push_error("録画フレーム数が整数ではありません")
			quit(1)
			return
		movie_frames = arguments[1].to_int()
	if movie_frames <= RELEASE_FRAMES:
		push_error("録画には17フレーム以上が必要です")
		quit(1)
		return
	_run.call_deferred()


# 描画と音声の時間を進める録画シナリオなので非冪等。
func _run() -> void:
	var state: Node = root.get_node("Session")
	state.save_enabled = false
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var start_frame: int = Engine.get_process_frames()
	while Engine.get_process_frames() - start_frame < movie_frames - RELEASE_FRAMES:
		await process_frame
	main.set_process(false)
	state.set_process(false)
	await main.sound.shutdown()
	while Engine.get_process_frames() - start_frame < movie_frames:
		await process_frame
	print("movie OK: タイトル録画 %d フレーム" % movie_frames)
	quit(0)
