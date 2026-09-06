extends SceneTree
## 実際の入力・物理フレーム・接触回収を通して、ラウンド全体を検証する。
## --headless --fixed-fps 60 --script res://scripts/dev/integration.gd で実行する。

var failed: bool = false
var game: Node3D
var state: Node


func _initialize() -> void:
	_run.call_deferred()


# 検証では入力や経過フレームの副作用が必要なため、起動時に一度だけ実行する。
func _run() -> void:
	state = root.get_node("RunState")
	var scene: PackedScene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	_check(state.phase == "title", "起動時はタイトル")
	game.start_run()
	var initial_items: int = game.items.get_child_count()
	_check(initial_items >= 100, "ステージに 100 個以上の物体")
	_check(state.phase == "playing", "タイトルからゲーム開始")
	await _check_input()
	game.start_run()
	await _check_attachment_and_bump(initial_items)
	game.start_run()
	await _check_natural_clear()
	game.demo_mode = false
	game.show_title()
	_check(state.phase == "title" and state.collected == 0, "クリアからタイトルに復帰")
	_check(game.items.get_child_count() == initial_items, "タイトルで配置を復元")
	game.start_run()
	await _check_timeout()
	game.start_run()
	_check(state.phase == "playing" and state.collected == 0, "失敗後に再挑戦")
	_check(state.remaining == state.TIME_LIMIT, "再挑戦時の制限時間")
	_check(game.items.get_child_count() == initial_items, "再挑戦時の物体数")
	game.show_title()
	_check(state.phase == "title", "再挑戦からタイトルに復帰")
	game.queue_free()
	await process_frame
	if failed:
		quit(1)
	else:
		print("integration OK")
		quit(0)


# 入力状態は操作時間に応じて変えるため、対になる release で必ず解除する。
func _check_input() -> void:
	var initial_position: Vector3 = game.ball.position
	Input.action_press("move_forward")
	await _frames(24)
	Input.action_release("move_forward")
	_check(game.ball.position.z < initial_position.z - 0.2, "前進入力で物理移動")
	var initial_yaw: float = game.yaw
	Input.action_press("camera_right")
	await _frames(20)
	Input.action_release("camera_right")
	_check(game.yaw > initial_yaw + 0.1, "カメラ入力で方向が変化")
	game.start_run()
	initial_position = game.ball.position
	var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	Input.parse_input_event(stick)
	await _frames(24)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	_check(game.ball.position.z < initial_position.z - 0.2, "ゲームパッドイベントで物理移動")


# 自動操作は通常の移動・接触を使い、検証に必要な付着物が揃うまで進める。
func _check_attachment_and_bump(initial_items: int) -> void:
	game.demo_mode = true
	for frame: int in range(1200):
		await process_frame
		if state.collected >= 3:
			break
	game.demo_mode = false
	game.set_physics_process(false)
	_check(state.collected >= 3, "移動と接触により小物を巻き込む")
	_check(game.attached.size() == state.collected, "付着メッシュ数と状態が一致")
	_check(game.items.get_child_count() + state.collected == initial_items, "物体を重複取得しない")
	_check(is_equal_approx(game.ball_shape.radius, state.diameter * 0.5), "球の衝突半径が成長に追従")
	for visual: Node3D in game.attached:
		_check(visual.get_parent() == game.rolling, "付着物は回転する玉の子になる")
		_check(not _has_collision(visual), "付着物には個別の衝突形状を残さない")
	var before_count: int = state.collected
	var before_diameter: float = state.diameter
	game.bump_cooldown = 0.0
	game._bump(Vector3.FORWARD)
	_check(state.collected == before_count - 1, "障害物との衝突で一つ脱落")
	_check(state.diameter < before_diameter, "脱落で直径が減少")
	_check(game.attached.size() == state.collected, "脱落で表示と状態が同期")
	_check(game.items.get_child_count() + state.collected == initial_items, "脱落物が部屋に戻る")
	_check(is_equal_approx(game.ball_shape.radius, state.diameter * 0.5), "脱落後も球の半径が同期")
	game._bump(Vector3.FORWARD)
	_check(state.collected == before_count - 1, "連続衝突はクールダウンで抑制")
	await process_frame
	game.set_physics_process(true)


# 値の直接加算を使わず、通常と同じ接触処理だけで目標直径まで進める。
func _check_natural_clear() -> void:
	game.demo_mode = true
	for frame: int in range(60 * 120):
		await process_frame
		if state.phase != "playing":
			break
	_check(state.phase == "won", "通常の移動と巻き込みで 120 秒以内にクリア")
	_check(state.diameter >= state.TARGET_DIAMETER, "クリア時に目標直径へ到達")
	print("自然操作: 直径 %.3f / 個数 %d / 経過 %.2f 秒" % [
		state.diameter, state.collected, state.TIME_LIMIT - state.remaining
	])
	var final_diameter: float = state.diameter
	var final_time: float = state.remaining
	await _frames(30)
	_check(state.diameter == final_diameter and state.remaining == final_time, "結果画面で進行が停止")


# 無操作の実フレームを積み上げ、時間切れ経路を検証する。
func _check_timeout() -> void:
	for frame: int in range(60 * int(state.TIME_LIMIT) + 5):
		await process_frame
		if state.phase != "playing":
			break
	_check(state.phase == "lost" and state.remaining == 0.0, "無操作で制限時間を迎えると失敗")
	_check(game.previous_phase == "lost", "失敗の結果画面へ遷移")


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child: Node in node.get_children():
		if _has_collision(child):
			return true
	return false


# フレーム進行が検証対象なので、指定回数分待つ副作用を持つ。
func _frames(count: int) -> void:
	for frame: int in range(count):
		await process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("integration FAIL: " + label)
		failed = true
