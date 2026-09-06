extends SceneTree
## タイトルを録画し、終了前に音声を止めてミキサーへ解放を反映する。
## 時間を進める録画処理のため非冪等。

var main: Node
var frames: int = 0
var frame_limit: int = 150


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		frame_limit = maxi(20, int(arguments[0]))
	_start.call_deferred()


func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == frame_limit - 12 and is_instance_valid(main):
		main.stop_audio()
	if frames >= frame_limit:
		quit(0)
	return false
