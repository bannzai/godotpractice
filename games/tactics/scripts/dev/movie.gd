extends SceneTree
## 起動の描画を録画し、終了前に音声参照の解放を待つ。
## 経過フレームを消費する検証なので、一度の起動で一本だけ録画する。

var frames: int = 0
var frame_limit: int = 150
var main: Node


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		frame_limit = maxi(30, int(arguments[0]))
	_start.call_deferred()


func _start() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	main = scene.instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == frame_limit - 12 and is_instance_valid(main):
		main.stop_audio()
	if frames >= frame_limit:
		quit(0)
	return false
