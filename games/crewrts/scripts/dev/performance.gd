extends SceneTree
## 実描画を含む30体の追従と生存敵2体のフレーム時間を計測する。


func _initialize() -> void:
	_run.call_deferred()


## 計測用に実時間を進めるため一度だけ実行する。
func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_day()
	main.set_physics_process(false)
	var samples: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for index: int in range(720):
		var angle: float = index * 0.01
		main.model.step(1.0 / 120.0, Vector3(cos(angle), 0, sin(angle)))
		main.world.sync(main.model, 1.0 / 120.0, main.model.leader)
		main.world.set_camera(main.model, 0.0, 1.0 / 120.0)
		main.hud.refresh(main.model)
		await process_frame
		var now: int = Time.get_ticks_usec()
		if index >= 120:
			samples.append(float(now - last) / 1000.0)
		last = now
	var total: float = 0.0
	for sample: float in samples:
		total += sample
	samples.sort()
	var fps: float = samples.size() * 1000.0 / total
	var p95: float = samples[int(samples.size() * 0.95)]
	print("描画性能: 仲間=%d 敵=%d 平均=%.1f fps p95=%.2f ms フレーム=%d" % [
		main.model.crew.size(), main.model.enemies.size(), fps, p95, samples.size()])
	main.stop_audio()
	await create_timer(0.15).timeout
	main.queue_free()
	await process_frame
	if fps < 60.0 or p95 > 16.67:
		push_error("60 fps の性能基準を満たしていません")
		quit(1)
	else:
		print("performance OK")
		quit(0)
