extends SceneTree
## 撮影は進行を再現するため非冪等。専用保存先を使い、通常プレイの記録を変更しない。

var main: Control
var state: Node


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


func _run() -> void:
	if await _capture_scenes():
		quit(0)


func _capture_scenes() -> bool:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.automatic = false
	state = root.get_node("GameState")
	state.save_path = "res://tmp/screenshot-save.json"
	state.high_score = 0
	await create_timer(0.2).timeout
	for label: String in [
		"title",
		"play",
		"explosion",
		"alert",
		"boss",
		"boss-phase-two",
		"pause",
		"clear",
		"gameover"
	]:
		_prepare_capture(label)
		if not await _capture(label):
			return false
	main.music.stop()
	for voice: AudioStreamPlayer in main.sounds.values():
		voice.stop()
	# 音声ミキサーが再生参照を解放するまで待つ。固定刻みの進行では実時間が経過しない。
	await create_timer(0.15).timeout
	main.queue_free()
	await process_frame
	return true


func _prepare_capture(label: String) -> void:
	match label:
		"play":
			main.start_run()
			Input.action_press("shoot")
			for frame: int in range(900):
				main.invulnerable = 1.0
				main.advance(1.0 / 60.0)
			Input.action_release("shoot")
		"explosion":
			main.trigger_bomb()
			_step(0.2)
		"alert":
			_step(1.0)
			state.elapsed = 148.0
			main.enemies.clear()
			main.bullets.clear()
			main.wave_index = main.waves.size()
		"boss":
			_step(2.5)
		"boss-phase-two":
			main.damage_boss(190)
			_step(1.3)
		"pause":
			main.paused = true
			main.call("_sync_menu")
		"clear":
			main.resume_run()
			main.damage_boss(1000)
		"gameover":
			main.start_run()
			for hit: int in range(3):
				main.invulnerable = 0.0
				main.hit_player()


func _capture(label: String) -> bool:
	main.view.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "tmp/screenshot-%s.png" % label
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: %s" % path)
		quit(1)
		return false
	print("screenshot: " + path)
	return true


func _step(seconds: float) -> void:
	for frame: int in range(int(seconds * 60)):
		main.advance(1.0 / 60.0)
