extends SceneTree
## 通常終了通知を送り、実際に再生中の音声が解放されるまで待つ経路を確認する。

var _main: Control
var _started: bool = false


func _initialize() -> void:
	auto_accept_quit = false
	_run.call_deferred()


func _run() -> void:
	if _started:
		return
	_started = true
	_main = load("res://scenes/main.tscn").instantiate()
	_main.force_audio = true
	root.add_child(_main)
	_deadline()
	await create_timer(0.3).timeout
	_main._play_music("title")
	await create_timer(0.1).timeout
	if not _has_playing_audio(_main):
		push_error("終了検証の前に音声が再生されていない")
		_main.stop_audio()
		await create_timer(0.2).timeout
		quit(1)
		return
	print("shutdown_check: 音声再生中に通常の終了通知を送信")
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _has_playing_audio(node: Node) -> bool:
	if node is AudioStreamPlayer and node.playing:
		return true
	for child: Node in node.get_children():
		if _has_playing_audio(child):
			return true
	return false


# 終了通知を処理しない回帰で検証が永久に待たないよう、実時間に上限を設ける。
func _deadline() -> void:
	await create_timer(5.0).timeout
	push_error("終了通知から5秒以内に終了しなかった")
	_main.stop_audio()
	await create_timer(0.2).timeout
	quit(1)
