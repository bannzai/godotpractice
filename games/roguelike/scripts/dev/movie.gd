extends SceneTree
## 一本の起動録画を作るためフレームを消費する。音声を先に止めて終了する。
var frames: int = 0
var limit: int = 150


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--frames="):
			limit = maxi(30, int(argument.trim_prefix("--frames=")))
	_start.call_deferred()


func _start() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())


func _process(_delta: float) -> bool:
	frames += 1
	if frames == limit - 12:
		root.get_node("Sound").stop_all()
	if frames >= limit:
		quit(0)
	return false
