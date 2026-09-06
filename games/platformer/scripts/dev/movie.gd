extends SceneTree
## Movie Maker の終了前に音声ミキサーへ停止を反映するため、数フレームの余裕を設ける。

var main: DeliveryGame
var frames_left: int = 0


func _initialize() -> void:
	frames_left = int(OS.get_cmdline_user_args()[0])
	_start.call_deferred()


func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames_left -= 1
	if frames_left == 8 and is_instance_valid(main):
		main.stop_audio()
	return false
