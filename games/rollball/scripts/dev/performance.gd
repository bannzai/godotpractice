extends SceneTree
## 描画と通常の物理処理を実測する。時刻・入力・音声・保存に副作用があるため一度だけ実行する。

const MINIMUM_ITEMS: int = 100
const MINIMUM_FPS: float = 60.0

var game: Node3D
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("性能計測には描画可能なウィンドウが必要です")
		quit(1)
		return
	if Engine.max_fps != 0 or DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
		push_error("--disable-vsync --max-fps 0 を付けて性能計測を実行してください")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _warmup()
	game.start_run()
	await process_frame
	var initial_count: int = game.items.get_child_count()
	_check(initial_count >= MINIMUM_ITEMS, "開始時に100個以上の物体が存在する")
	var idle: Dictionary = await _measure("非操作・%d物体" % initial_count, 5.0)
	_check(game.items.get_child_count() == initial_count, "非操作中に物体数を維持する")
	var state: Node = root.get_node("RunState")
	_check(state.phase == "playing", "非操作計測をプレイ中に行う")
	game.demo_mode = true
	var growth: Dictionary = await _measure("通常移動・巻き込み・成長", 10.0)
	_check(state.collected > 0, "通常移動で物体を巻き込む")
	var report: Dictionary = {
		"display_server": DisplayServer.get_name(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"viewport_width": root.size.x,
		"viewport_height": root.size.y,
		"initial_items": initial_count,
		"minimum_average_fps": MINIMUM_FPS,
		"stages": [idle, growth],
		"passed": not failed,
	}
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var file: FileAccess = FileAccess.open("res://tmp/performance.json", FileAccess.WRITE)
	if file == null:
		_check(false, "性能計測結果を保存する")
	else:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	await _finish()


func _warmup() -> void:
	var started: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - started < 5000000:
		await process_frame


func _measure(label: String, duration: float) -> Dictionary:
	var samples: Array[float] = []
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	while Time.get_ticks_usec() - started < duration * 1000000.0:
		await process_frame
		var current: int = Time.get_ticks_usec()
		samples.append(float(current - previous) / 1000.0)
		previous = current
	var elapsed: float = float(previous - started) / 1000000.0
	var average_fps: float = float(samples.size()) / elapsed
	samples.sort()
	var percentile_index: int = maxi(0, ceili(float(samples.size()) * 0.95) - 1)
	var p95_ms: float = samples[percentile_index]
	print("%s: 平均 %.2f FPS / p95 %.3f ms / %d フレーム / %.3f 秒" % [
		label, average_fps, p95_ms, samples.size(), elapsed,
	])
	_check(average_fps >= MINIMUM_FPS, label + "の平均 FPS が 60 以上")
	var state: Node = root.get_node("RunState")
	return {
		"label": label,
		"elapsed_seconds": elapsed,
		"frames": samples.size(),
		"average_fps": average_fps,
		"p95_frame_ms": p95_ms,
		"remaining_items": game.items.get_child_count(),
		"collected_items": state.collected,
		"diameter": state.diameter,
		"phase": state.phase,
	}


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("性能検証失敗: " + label)


func _finish() -> void:
	await game.prepare_shutdown()
	game.queue_free()
	for _frame: int in range(4):
		await process_frame
	if not failed:
		print("performance OK")
	quit(1 if failed else 0)
