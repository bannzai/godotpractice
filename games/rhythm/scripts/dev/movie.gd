extends SceneTree
## 起動を録画し、Godotの終了指定より先に音声を解放する。

var _main: Control
var _capture_frames: int = 150
var _audio_stopped: bool = false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-frames="):
			_capture_frames = maxi(16, argument.get_slice("=", 1).to_int())
	_start.call_deferred()


func _start() -> void:
	if is_instance_valid(_main):
		return
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


# フレーム進行に応じて一度だけ停止する。シーンは録画の末尾まで残す。
func _process(_delta: float) -> bool:
	if (
		is_instance_valid(_main)
		and not _audio_stopped
		and Engine.get_process_frames() >= _capture_frames - 15
	):
		_audio_stopped = true
		_main.stop_audio()
	return false
