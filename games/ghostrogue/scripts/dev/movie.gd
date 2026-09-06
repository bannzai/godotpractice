extends SceneTree
## 起動録画。音声の解放後もタイトルを表示してから終了するため非冪等。

var main: Control
var frames: int = 0
var frame_limit: int = 150


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		frame_limit = maxi(30, int(arguments[0]))
	_start.call_deferred()


func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == frame_limit - 18 and is_instance_valid(main):
		main.stop_audio()
	if frames >= frame_limit:
		print("movie OK")
		quit(0)
	return false
