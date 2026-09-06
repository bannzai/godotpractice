extends SceneTree
## 入力イベントを時刻ごとに送る。ゲーム状態や位置を直接変更せず、通常の物理と回収を録画する。

var game: Node3D
var state: Node
var elapsed: float = 0.0
var started: bool = false
var sent_events: int = 0
var last_axes: Vector2 = Vector2.ZERO
var result_time: float = 0.0
var initial_items: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	state = root.get_node("RunState")
	initial_items = game.items.get_child_count()
	while elapsed < 25.0:
		await physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
		if elapsed >= 1.3 and not started:
			_key(KEY_ENTER, true)
			_key(KEY_ENTER, false)
			started = true
		if state.phase == "playing":
			var direction: Vector3 = game._demo_direction().rotated(Vector3.UP, -game.yaw)
			# 短い停止を挟む実入力で、成長の各段階を録画に残す。
			var stick: Vector2 = Vector2(direction.x, direction.z)
			if elapsed < 12.0:
				stick *= 0.65 if fmod(elapsed - 1.3, 2.0) < 1.0 else 0.0
			_axes(stick)
		else:
			_axes(Vector2.ZERO)
			if started and state.phase == "won" and result_time == 0.0:
				result_time = elapsed
	_axes(Vector2.ZERO)
	print("デモ録画終了: 状態=%s, 回収数=%d, 直径=%.3f, 入力イベント=%d" % [
		state.phase, state.collected, state.diameter, sent_events
	])
	print("結果到達: %.2f 秒" % result_time)
	# 経路で回収する大きさが変わるので、固定個数ではなくゲームの勝利条件を検査する。
	var successful: bool = (
		state.phase == "won" and state.diameter >= state.TARGET_DIAMETER
		and state.collected > 0 and game.attached.size() == state.collected
		and initial_items >= 100 and sent_events > 50
	)
	await game.prepare_shutdown()
	game.queue_free()
	for _frame: int in range(8):
		await process_frame
	if not successful:
		push_error("実入力のプレイ録画でクリアまで進まない")
		quit(1)
		return
	print("demo OK")
	quit(0)


func _key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	sent_events += 1


func _axes(value: Vector2) -> void:
	if value.is_equal_approx(last_axes):
		return
	last_axes = value
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = value.x if axis == JOY_AXIS_LEFT_X else value.y
		Input.parse_input_event(event)
		sent_events += 1
