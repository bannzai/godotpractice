extends SceneTree
## 通常のウィンドウ終了要求を配送し、音声停止を含む終了経路を検証する。

var main: Control
var elapsed: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


## 実際に終了要求を送るため非冪等。
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.35).timeout
	if DisplayServer.get_name() != "headless":
		main.sound.play_sfx("siren")
		await create_timer(0.1).timeout
		if not main.sound.music.playing or not main.sound.has_played:
			push_error("描画付き通常終了の直前にBGMが再生されていない")
			quit(1)
			return
		print("通常終了の条件: BGMとサイレンを再生中")
	print("shutdown OK")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 8.0:
		push_error("通常終了要求の後にゲームが終了しなかった")
		quit(1)
	return false
