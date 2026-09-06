extends SceneTree
## 音声を停止してから終了し、音声サーバーの解放が追いつく時間を録画内に確保する。
## 固定フレームで強制終了すると再生中の音声リソースが漏れる既知の問題への対策。
## https://github.com/godotengine/godot/issues/76745


func _initialize() -> void:
	_run.call_deferred()


## 起動からの時間経過を記録するので非冪等。
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
