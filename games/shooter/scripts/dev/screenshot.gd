extends SceneTree
## 撮影用の編隊と時刻を再現するため非冪等。専用保存先で通常の記録を守る。

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
	state.tutorial_seen = false
	await _wait(0.45)
	for label: String in [
		"title",
		"navigation",
		"navigation-highlight",
		"tutorial-move",
		"tutorial-shoot",
		"tutorial-bomb",
		"play",
		"explosion",
		"hit",
		"power",
		"supply",
		"boss-route",
		"boss",
		"boss-phase-two",
		"pause",
		"clear",
		"gameover"
	]:
		if label in ["hit", "power", "supply"]:
			await _wait(0.9)
		_prepare_capture(label)
		await _wait(1.5 if label in ["clear", "gameover", "play"] else 0.22)
		if not await _capture(label):
			return false
	if not await _capture_effect_series():
		return false
	main.hide()
	for kind: String in ["player", "scout", "aim", "fan", "boss"]:
		var gallery: Node2D = load("res://scripts/dev/animation_gallery.gd").new()
		gallery.kind = kind
		root.add_child(gallery)
		if not await _capture("animation-" + kind):
			return false
		gallery.queue_free()
		await process_frame
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	await process_frame
	return true


func _prepare_capture(label: String) -> void:
	match label:
		"navigation":
			main.show_navigation()
		"navigation-highlight":
			main.tutorial_pulse = 0.4
		"tutorial-move":
			main.confirm_route()
		"tutorial-shoot":
			main.tutorial_step = 1
		"tutorial-bomb":
			main.tutorial_step = 2
		"play":
			main.complete_tutorial()
			state.elapsed = 36.0
			state.add_score(4680)
			state.power = 2
			main.wave_index = 32
			for index: int in range(3):
				main.spawn_enemy(
					{"x": 470.0 + index * 155, "kind": ["scout", "aim", "fan"][index], "drop": ""}
				)
				main.enemies[index].position = Vector2(470 + index * 155, 170 + index * 63)
			for index: int in range(8):
				main.bullets.append(
					{
						"position": Vector2(412 + index * 63, 355 + index % 3 * 59),
						"velocity": Vector2.DOWN * 40,
						"friendly": false
					}
				)
			main.fire_player()
			main.items.append({"position": Vector2(760, 490), "kind": "power", "age": 0.0})
		"explosion":
			main.trigger_bomb()
		"hit":
			main.invulnerable = 0
			main.hit_player()
		"power":
			main.items.append({"position": main.player, "kind": "power", "age": 0.0})
		"supply":
			main.items.append({"position": main.player, "kind": "bomb", "age": 0.0})
		"boss-route":
			state.elapsed = 150.0
			main.enemies.clear()
			main.bullets.clear()
			main.wave_index = main.waves.size()
			main.call("_begin_boss_chart")
		"boss":
			main.boss_chart_time = 0.0
			main.advance(0.01)
		"boss-phase-two":
			main.damage_boss(190)
			main.boss_timer = 0
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
	if root.get_texture().get_image().save_png(path) != OK:
		push_error("スクリーンショット保存失敗: %s" % path)
		quit(1)
		return false
	print("screenshot: " + path)
	return true


func _wait(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await process_frame
		var delta: float = minf(root.get_process_delta_time(), 0.05)
		main.advance(delta)
		elapsed += delta


func _capture_effect_series() -> bool:
	main.start_run()
	main.wave_index = main.waves.size()
	await _wait(0.5)
	for kind: String in ["bomb", "hit", "power", "supply", "boss-death"]:
		await _wait(0.9)
		match kind:
			"bomb":
				main.trigger_bomb()
			"hit":
				main.invulnerable = 0
				main.hit_player()
			"power", "supply":
				main.items.append(
					{
						"position": main.player,
						"kind": "power" if kind == "power" else "bomb",
						"age": 0.0
					}
				)
			"boss-death":
				main.boss_active = true
				main.boss_hp = 1
				main.damage_boss(1)
		for frame: int in range(3):
			await _wait(0.02 if frame == 0 else 0.22)
			if not await _capture("effect-%s-%d" % [kind, frame]):
				return false
	return true
