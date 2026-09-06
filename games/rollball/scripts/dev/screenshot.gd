extends SceneTree
## 描画完了後に代表画面を保存する。経過時間を進めるため、撮影は順番に実行する。

var game: Node3D
var state: Node
var gallery: Node3D


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


func _run() -> void:
	var success: bool = await _capture_scenes()
	if is_instance_valid(gallery):
		gallery.queue_free()
	if is_instance_valid(game):
		await game.prepare_shutdown()
		game.queue_free()
	for _frame: int in range(8):
		await process_frame
	if success:
		print("screenshot OK")
	quit(0 if success else 1)


func _capture_scenes() -> bool:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	state = root.get_node("RunState")
	await create_timer(0.8).timeout
	if not await _capture("title"):
		return false
	game.start_run()
	await create_timer(0.1).timeout
	if not await _capture("transition-play"):
		return false
	await create_timer(0.8).timeout
	if not await _capture("play"):
		return false
	if not await _capture_effects():
		return false
	return await _capture_growth()


func _capture_effects() -> bool:
	game.set_physics_process(false)
	for kind: String in ["pickup", "growth", "bump", "win"]:
		game.effects.clear()
		game.effects.burst(game.ball.position, state.diameter, kind)
		match kind:
			"pickup":
				game.core.play_state("collect")
				game.hud.show_pickup(0.05)
			"growth":
				game.core.play_state("celebrate")
				game.hud.show_growth()
			"bump":
				game.core.play_state("bump")
				game.hud.show_bump(true)
			"win":
				game.core.play_state("celebrate")
		await create_timer(0.13).timeout
		if not await _capture("effect-" + kind):
			return false
		await create_timer(1.3).timeout
	game.effects.clear()
	game.set_physics_process(true)
	return true


func _capture_growth() -> bool:
	game.demo_mode = true
	var frames: int = 0
	while state.collected < 12 and frames < 1800:
		await physics_frame
		frames += 1
	game.demo_mode = false
	if state.collected < 12:
		push_error("撮影用の通常操作で巻き込みが進まない")
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
		return false
	await create_timer(0.1).timeout
	if not await _capture("transition-result"):
		return false
	await create_timer(0.8).timeout
	if not await _capture("clear"):
		return false
	return await _capture_timeout()


func _capture_timeout() -> bool:
	game.demo_mode = false
	game.start_run()
	state.tick(state.TIME_LIMIT)
	game._finish_run()
	await create_timer(0.8).timeout
	if not await _capture("timeout"):
		return false
	return await _capture_models()


func _capture_models() -> bool:
	game.set_physics_process(false)
	game.set_process(false)
	game.hide()
	game.hud.hide()
	# 元の部屋の指向性ライトは遠くの展示にも届くため、専用照明へ切り替える。
	for child: Node in game.room.get_children():
		if child is Light3D:
			child.light_energy = 0.0
			child.shadow_enabled = false
	gallery = preload("res://scripts/dev/model_gallery.gd").new()
	root.add_child(gallery)
	for animation: String in gallery.STATES:
		for progress: float in [0.0, 0.5, 0.95]:
			gallery.show_pose(animation, progress)
			if not await _capture("models-%s-%02d" % [animation, roundi(progress * 100)]):
				return false
	return true


func _capture(label: String) -> bool:
	# ソフトウェア描画でも3フレームの待機中に短い演出が終わらないよう停止する。
	var was_paused: bool = paused
	paused = true
	# フォントアトラス更新直後の文字欠けを避け、複数の描画完了を待つ。
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % label
	var status: Error = root.get_texture().get_image().save_png(path)
	paused = was_paused
	if status != OK:
		push_error("撮影失敗: %s" % error_string(status))
		return false
	print("screenshot: " + path)
	return true
