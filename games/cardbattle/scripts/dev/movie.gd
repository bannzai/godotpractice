extends SceneTree
## 音声の非同期解放を待ってから録画を終了する。

const AUDIO_RELEASE_FRAMES: int = 8

var movie_frames: int = 150


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		if (
			arguments.size() != 2
			or arguments[0] != "--movie-frames"
			or not arguments[1].is_valid_int()
		):
			push_error("録画フレーム数は --movie-frames <整数> で指定してください")
			quit(1)
			return
		movie_frames = arguments[1].to_int()
	if movie_frames <= AUDIO_RELEASE_FRAMES:
		push_error("録画には音声の解放待ちを含めて 9 フレーム以上が必要です")
		quit(1)
		return
	_run.call_deferred()


# 描画と音声を進める録画処理なので非冪等。
func _run() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in range(movie_frames):
		await RenderingServer.frame_post_draw
		if frame + 1 == movie_frames - AUDIO_RELEASE_FRAMES:
			main.stop_audio()
	print("movie OK: %d フレーム" % movie_frames)
	quit(0)
