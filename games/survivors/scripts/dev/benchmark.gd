extends SceneTree
## 本物の main シーンを描画し、通常の入力・進行を含むフレーム時間を測る。
## 敵の HP を増やす負荷用条件。描画を省く headless と固定 fps の録画は対象外。

const WARMUP_SECONDS: float = 2.0
const SAMPLE_SECONDS: float = 10.0
const REQUIRED_ENEMIES: int = 240
const FRAME_BUDGET_MS: float = 1000.0 / 60.0
const ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down"]

var state: Node
var frame_times: Array[float] = []
var minimum_enemies: int = 1000000
var maximum_enemies: int = 0
var minimum_visible: int = 1000000
var minimum_gems: int = 1000000
var maximum_effects: int = 0
var maximum_projectiles: int = 0
var maximum_player_distance: float = 0.0
var process_total_ms: float = 0.0
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


# 実時間の描画と入力を計測する一回限りの実験なので非冪等。
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("描画付きで起動してください")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		_fail("GL Compatibility が必要です")
		quit(1)
		return
	for argument: String in OS.get_cmdline_args():
		if argument.begins_with("--fixed-fps") or argument.begins_with("--write-movie"):
			_fail("固定 fps と録画モードでは実時間の負荷を計測できません")
			quit(1)
			return
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_mute(0, true)
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var main: Node = load(main_path).instantiate()
	root.add_child(main)
	state = root.get_node("RunState")
	_prepare_fixture()
	print("負荷計測: %s / %s / %s / 1280x720 / VSync 無効 / fps 上限なし" % [
		OS.get_name(), RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name()])
	var warmup_start: int = Time.get_ticks_usec()
	while _seconds_since(warmup_start) < WARMUP_SECONDS:
		_move(_seconds_since(warmup_start))
		await RenderingServer.frame_post_draw
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var simulation_start: float = state.elapsed
	while _seconds_since(start) < SAMPLE_SECONDS:
		_move(_seconds_since(warmup_start))
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
		_sample_load()
		if state.phase != "playing":
			_fail("計測中にゲームが停止しました: " + str(state.phase))
			break
	for action: String in ACTIONS:
		Input.action_release(action)
	var duration: float = float(previous - start) / 1000000.0
	_report(duration, float(state.elapsed) - simulation_start)
	# 計測区間の外で、実際に描画した負荷状態の証拠を保存する。
	var capture_status: Error = root.get_texture().get_image().save_png("tmp/benchmark.png")
	if capture_status != OK:
		_fail("負荷状態の画像を保存できません: " + error_string(capture_status))
	main.queue_free()
	await process_frame
	if not failed:
		print("benchmark OK")
	quit(1 if failed else 0)


func _prepare_fixture() -> void:
	state.start_run(240)
	state.elapsed = 450.0
	state.max_hp = 1000000.0
	state.hp = state.max_hp
	# 通常スポーンからの少量の経験値でも計測が止まらない閾値にする。
	state.level = 100
	state.weapons = {"bolt": 3, "orbit": 3, "pulse": 3}
	# 普通の武器更新と衝突判定を動かしたまま、敵数の急減を防ぐ。
	for index: int in range(300):
		var angle: float = TAU * float(index) / 300.0
		var distance: float = 130.0 + float(index % 5) * 22.0
		state.spawn_enemy(index % 3, Vector2.from_angle(angle) * distance)
		state.enemies[-1].hp = 1000000.0
	# 移動経路から離し、強化選択による停止を避けつつ画面内に描画する。
	for index: int in range(180):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var point := Vector2(side * (340.0 + float(index % 10) * 20.0),
			-200.0 + float(index / 10) * 25.0)
		state.gems.append({"pos": point, "value": 1})
	state.items.append({"pos": Vector2(-280, 150), "kind": "heal"})
	state.items.append({"pos": Vector2(280, 150), "kind": "magnet"})


func _seconds_since(start: int) -> float:
	return float(Time.get_ticks_usec() - start) / 1000000.0


func _move(seconds: float) -> void:
	# アクションを毎フレーム設定し、main の Input.get_vector → step を通す。
	var direction := Vector2.from_angle(seconds * PI)
	Input.action_press("move_left", maxf(-direction.x, 0.0))
	Input.action_press("move_right", maxf(direction.x, 0.0))
	Input.action_press("move_up", maxf(-direction.y, 0.0))
	Input.action_press("move_down", maxf(direction.y, 0.0))


# 各描画フレームの標本を蓄積するため非冪等。
func _sample_load() -> void:
	minimum_enemies = mini(minimum_enemies, state.enemies.size())
	maximum_enemies = maxi(maximum_enemies, state.enemies.size())
	minimum_gems = mini(minimum_gems, state.gems.size())
	maximum_effects = maxi(maximum_effects, state.effects.size())
	maximum_projectiles = maxi(maximum_projectiles, state.projectiles.size())
	maximum_player_distance = maxf(maximum_player_distance, Vector2(state.player_pos).length())
	process_total_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var visible_enemies: int = 0
	for enemy: Dictionary in state.enemies:
		var screen_position: Vector2 = Vector2(enemy.pos) - Vector2(state.player_pos) + Vector2(640, 392)
		if Rect2(0, 0, 1280, 720).has_point(screen_position):
			visible_enemies += 1
	minimum_visible = mini(minimum_visible, visible_enemies)


func _report(duration: float, simulation_duration: float) -> void:
	if frame_times.is_empty() or duration <= 0.0:
		_fail("フレームを計測できませんでした")
		return
	frame_times.sort()
	var average_fps: float = float(frame_times.size()) / duration
	var p95: float = frame_times[ceili(float(frame_times.size()) * 0.95) - 1]
	print("計測 %.3f 秒 / %d フレーム / 平均 %.2f fps / p95 %.3f ms" % [
		duration, frame_times.size(), average_fps, p95])
	print("敵数 %d〜%d / 画面内敵数 最小 %d / ジェム 最小 %d / 演出 最大 %d / 弾 最大 %d" % [
		minimum_enemies, maximum_enemies, minimum_visible, minimum_gems,
		maximum_effects, maximum_projectiles])
	print("simulation %.3f 秒 / process 平均 %.3f ms / 終了位置 %s" % [
		simulation_duration, process_total_ms / frame_times.size(), str(state.player_pos)])
	if average_fps < 60.0 or p95 > FRAME_BUDGET_MS:
		_fail("平均 60 fps 以上かつ p95 16.667 ms 以下の条件を満たしません")
	if minimum_enemies < REQUIRED_ENEMIES or minimum_visible < REQUIRED_ENEMIES:
		_fail("敵 240 体以上の同時描画を維持できません")
	if minimum_gems == 0 or maximum_effects == 0 or maximum_projectiles == 0:
		_fail("ジェム・攻撃弾・演出が動作していません")
	if simulation_duration < duration * 0.9 or simulation_duration > duration * 1.1:
		_fail("ゲームの時間進行が実時間の 90〜110% の範囲外です")
	if maximum_player_distance < 40.0:
		_fail("通常入力によるプレイヤー移動を確認できません")


func _fail(message: String) -> void:
	failed = true
	push_error("benchmark FAIL: " + message)
