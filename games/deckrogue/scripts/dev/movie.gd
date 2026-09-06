extends SceneTree
## 音源を解放してから終了する起動録画。音声サーバーの終了時リークを避ける。
## フレームを消費する録画処理なので、実行ごとに一本の動画を作る。

var frames: int = 0
var frame_limit: int = 150


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		frame_limit = maxi(20, int(arguments[0]))
	_start.call_deferred()


func _start() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	root.add_child(scene.instantiate())


func _process(_delta: float) -> bool:
	frames += 1
	if frames == frame_limit - 10:
		root.get_node("Sound").stop_all()
	if frames >= frame_limit:
		quit(0)
	return false
