extends SceneTree
## 通常終了通知から本番の音声停止・終了処理へ入れることを検証する。
## 終了通知はプロセスを一度終了させるため、実行全体は非冪等。


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var main: Node = scene.instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	print("shutdown requested")
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await create_timer(3.0).timeout
	push_error("通常終了が制限時間内に完了しませんでした")
	quit(1)
