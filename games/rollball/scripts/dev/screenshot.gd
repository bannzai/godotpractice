extends SceneTree
## 描画完了後に代表画面を保存する。経過時間を進めるため、撮影は順番に実行する。

var game: Node3D
var state: Node


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


func _run() -> void:
	if await _capture_scenes():
		print("screenshot OK")
		quit(0)


func _capture_scenes() -> bool:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	state = root.get_node("RunState")
	await create_timer(0.5).timeout
	if not await _capture("title"):
		return false
	game.start_run()
	await create_timer(0.3).timeout
	if not await _capture("play"):
		return false
	return await _capture_growth()


func _capture_growth() -> bool:
	game.demo_mode = true
	var frames: int = 0
	while state.collected < 12 and frames < 1800:
		await physics_frame
		frames += 1
	game.demo_mode = false
	if state.collected < 12:
		push_error("撮影用の通常操作で巻き込みが進まない")
		quit(1)
		return false
	game.set_physics_process(false)
	game.effect_time = 0.6
	if not await _capture("growth"):
		return false
	game.set_physics_process(true)
	game.demo_mode = true
	while state.phase == "playing" and frames < 7200:
		await physics_frame
		frames += 1
	if state.phase != "won":
		push_error("撮影用の通常操作で目標へ到達しない")
		quit(1)
		return false
	await create_timer(0.2).timeout
	if not await _capture("clear"):
		return false
	return await _capture_timeout()


func _capture_timeout() -> bool:
	game.demo_mode = false
	game.start_run()
	state.tick(state.TIME_LIMIT)
	await physics_frame
	game.hud.show_mode("lost")
	if not await _capture("timeout"):
		return false
	game.show_title()
	await process_frame
	game.queue_free()
	await process_frame
	return true


func _capture(label: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % label
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		push_error("撮影失敗: %s" % error_string(status))
		quit(1)
		return false
	print("screenshot: " + path)
	return true
