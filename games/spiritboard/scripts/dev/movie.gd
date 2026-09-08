extends SceneTree
## 起動録画の終了前に音声だけを停止し、最後まで画面を保持する。
## フレーム進行が録画対象なので、このスクリプトは1回の実行で1本の動画を作る。

const AudioStop := preload("res://scripts/dev/audio_stop.gd")
const AUDIO_STOP_MARGIN_FRAMES: int = 10

var frames_left: int = 0


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or not arguments[0].is_valid_int():
		push_error("録画フレーム数を -- <N> で渡してください")
		quit(2)
		return
	frames_left = int(arguments[0])
	if frames_left <= AUDIO_STOP_MARGIN_FRAMES:
		push_error("録画フレーム数は %d より大きくしてください" % AUDIO_STOP_MARGIN_FRAMES)
		quit(2)
		return
	_start.call_deferred()


func _start() -> void:
	if current_scene != null:
		return
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null or change_scene_to_packed(packed) != OK:
		push_error("起動録画: メインシーンをロードできません")
		quit(1)


## 経過フレームを数えるため、呼び出すたびに残り時間を減らす。
func _process(_delta: float) -> bool:
	frames_left -= 1
	if frames_left == AUDIO_STOP_MARGIN_FRAMES:
		AudioStop.stop(root)
	return false
