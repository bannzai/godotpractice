extends SceneTree
## 夜の敵6体と島を実描画する負荷確認。録画・固定fpsとは別に実時間を測る。

const WARMUP_FRAMES: int = 120
const SAMPLE_FRAMES: int = 300
const MAX_SECONDS: float = 35.0

var main: Node
var _finished: bool = false
var _times: Array[float] = []
var _draw_calls: Array[float] = []
var _slow_frames: Array[Dictionary] = []
var _started_at: int = 0
var _minimum_visible: int = 6


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("movie"):
		push_error("性能計測は実描画で起動し、録画・固定fpsを指定しないでください")
		quit(1)
		return
	if "--fixed-fps" in OS.get_cmdline_args():
		push_error("固定fpsでは実時間の描画性能を計測できません")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_started_at = Time.get_ticks_usec()
	create_timer(MAX_SECONDS).timeout.connect(_timeout)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_game()
	_prepare_night()
	for index: int in range(WARMUP_FRAMES):
		await RenderingServer.frame_post_draw
		if _finished:
			return
		_keep_playing()
	var previous: int = Time.get_ticks_usec()
	for index: int in range(SAMPLE_FRAMES):
		await RenderingServer.frame_post_draw
		if _finished:
			return
		var now: int = Time.get_ticks_usec()
		var elapsed: float = float(now - previous) / 1000.0
		_times.append(elapsed)
		if elapsed > 16.667:
			_slow_frames.append({"frame": index, "milliseconds": elapsed,
				"projectiles": main.model.projectiles.size()})
		_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		previous = now
		_keep_playing()
		_minimum_visible = mini(_minimum_visible, _visible_enemies())
	_report()
	await _finish(0 if _minimum_visible == 6 else 1)


func _prepare_night() -> void:
	main.model.day_time = 0.72
	main.player.set_physics_process(false)
	main.player.position = Vector3(16.5, 7.05, 16.5)
	main.player.camera.position = Vector3(0, 13.0, 22.0)
	main.player.camera.look_at(Vector3(16.5, 6.0, 16.5))
	main.player.camera.fov = 68.0
	main.hand.visible = false
	main.enemies.reset()
	for index: int in range(6):
		main.enemies._spawn("mossling" if index % 2 == 0 else "wisp", main.player.position)
		if main.model.enemies.size() <= index:
			continue
		var enemy: Dictionary = main.model.enemies[index]
		enemy.position = Vector3(13.5 + float(index % 3) * 3.0, 7.0,
			14.5 + float(index / 3) * 4.0)
		main.enemies.views[int(enemy.id)].position = enemy.position
	main.enemies._was_night = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _keep_playing() -> void:
	# 性能検証中にゲームオーバーへ遷移しないよう生存値のみ固定する。
	main.model.hp = 100.0
	main.model.hunger = 100.0
	main.model.day_time = 0.72
	main.hand.visible = false


func _visible_enemies() -> int:
	var count: int = 0
	for enemy: Dictionary in main.model.enemies:
		if not bool(enemy.dying) and main.player.camera.is_position_in_frustum(
			enemy.position + Vector3.UP
		):
			count += 1
	return count


func _mesh_totals(node: Node) -> Dictionary:
	var total: Dictionary = {"mesh_instances": 0, "surfaces": 0, "vertices": 0}
	if node is MeshInstance3D and node.mesh != null:
		total.mesh_instances = 1
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total.surfaces += 1
			total.vertices += vertices.size()
	for child: Node in node.get_children():
		var child_total: Dictionary = _mesh_totals(child)
		for key: String in total:
			total[key] += int(child_total[key])
	return total


func _report() -> void:
	_times.sort()
	_draw_calls.sort()
	var average: float = _times.reduce(func(total: float, value: float) -> float:
		return total + value, 0.0) / float(SAMPLE_FRAMES)
	var report: Dictionary = {
		"resolution": "1280x720", "renderer": "gl_compatibility", "vsync": "disabled",
		"gpu": RenderingServer.get_video_adapter_name(),
		"warmup_frames": WARMUP_FRAMES, "sample_frames": SAMPLE_FRAMES,
		"frame_ms_p50": _times[149], "frame_ms_p95": _times[284],
		"frame_ms_max": _times[299], "average_fps": 1000.0 / average,
		"draw_calls_p50": _draw_calls[149], "draw_calls_p95": _draw_calls[284],
		"minimum_visible_enemies": _minimum_visible,
		"frames_over_16_667ms": _slow_frames,
		"scene_meshes": _mesh_totals(main), "world_meshes": _mesh_totals(main.world),
		"elapsed_seconds": float(Time.get_ticks_usec() - _started_at) / 1000000.0
	}
	var output: FileAccess = FileAccess.open("res://tmp/performance.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print("描画性能計測: " + JSON.stringify(report))
	var screenshot: Error = root.get_texture().get_image().save_png("res://tmp/performance.png")
	if screenshot != OK:
		push_error("性能計測画面の保存に失敗")
	if _minimum_visible != 6:
		push_error("敵6体が計測中の画角に収まりませんでした")


func _timeout() -> void:
	if not _finished:
		push_error("描画性能計測が35秒の上限に達しました")
		await _finish(1)


func _finish(code: int) -> void:
	if _finished:
		return
	_finished = true
	if is_instance_valid(main):
		main.stop_audio()
		await create_timer(0.2).timeout
		main.queue_free()
		await process_frame
	quit(code)
