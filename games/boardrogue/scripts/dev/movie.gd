extends SceneTree
## 起動録画の終了前に音声を止め、Movie Maker のフレームで解放を進める。

var main: Control
var frames: int = 0
var frame_limit: int = 150


func _initialize() -> void:
	var value: String = OS.get_environment("BOARDROGUE_MOVIE_FRAMES")
	if value.is_valid_int():
		frame_limit = maxi(60, int(value))
	_start.call_deferred()


func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


# 固定fpsの録画を進めるため非冪等。
func _process(_delta: float) -> bool:
	frames += 1
	if frames == frame_limit - 24 and is_instance_valid(main):
		main.stop_audio()
	if frames >= frame_limit:
		print("movie OK")
		quit(0)
	return false
