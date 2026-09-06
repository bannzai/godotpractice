extends SceneTree
## 画面と動作の描画証拠を、本番シーンを通して作る。

const AudioStop = preload("res://scripts/dev/audio_stop.gd")

var main: Control
var session: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


# 撮影一式を一度だけ順番に進める。
func _run() -> void:
	root.size = Vector2i(1280, 720)
	session = root.get_node("Session")
	session.save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _capture_scenes()
	AudioStop.stop(root)
	await create_timer(0.25).timeout
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _capture_scenes() -> void:
	await create_timer(0.8).timeout
	await _capture("title")
	session.new_run(222223)
	await create_timer(0.8).timeout
	await _capture("map")
	var branch: int = 0 if session.run.nodes[0][0].kind == "battle" else 1
	session.choose_node(branch)
	await create_timer(0.8).timeout
	await _capture("battle")
	session.abandon_run()
	await create_timer(0.8).timeout
	await _capture("defeat")
	session.to_title()
	await create_timer(0.8).timeout
	await _capture("return-title")


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % name
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		push_error("撮影に失敗: %s" % name)
		failed = true
	else:
		print("screenshot: " + path)
