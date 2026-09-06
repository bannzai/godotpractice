extends Node
## SURVIVORS_RUN_CAPTURE=1 make -C games/survivors run で通常の起動経路を撮影する。
## 検証用環境変数があるエディタバイナリだけで使い、通常起動とexportでは終了させない。


# 実フレームを待って撮影・終了する一回限りの検証なので非冪等。
func _ready() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var state: Node = get_node("/root/RunState")
	var image: Image = get_viewport().get_texture().get_image()
	if state.phase != "title" or image.is_empty():
		push_error("runcheck FAIL: タイトルの描画を確認できません")
		get_tree().quit(1)
		return
	var status: Error = image.save_png("res://tmp/run-title.png")
	if status != OK:
		push_error("runcheck FAIL: タイトル画像を保存できません: " + error_string(status))
		get_tree().quit(1)
		return
	print("runcheck OK")
	for child: Node in get_parent().get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)
