extends SceneTree
## 通常の物理・回収処理を動かして録画するため、実行中は時間とゲーム状態が進む。

var game: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	await create_timer(20.0).timeout
	var state: Node = root.get_node("RunState")
	print("デモ録画終了: 状態=%s, 回収数=%d" % [state.phase, state.collected])
	game.music.stop()
	game.sound.stop()
	game.queue_free()
	for _frame: int in range(4):
		await process_frame
	quit(0)
