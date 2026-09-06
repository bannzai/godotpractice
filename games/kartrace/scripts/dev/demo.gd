extends SceneTree
## Movie Maker 向け。実入力を時刻ごとに投入して25秒のプレイを収録する。

const Course = preload("res://scripts/course_data.gd")
var _main: Node
var _effects: Dictionary = {}
var _moved: bool = false
var _drift_started: float = -1.0
var _next_drift: float = 4.0
var _drift_turn: float = 0.45


func _initialize() -> void:
	_run.call_deferred()


# 録画は入力イベントと物理時刻を順に進めるため非冪等。
func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	var state: Node = root.get_node("RaceState")
	state.save_enabled = false
	# 録画ごとに同じアイテム抽選を再現し、入力シナリオの揺れをなくす。
	state._rng.seed = 380038
	state.effect.connect(func(kind: String, racer: int) -> void:
		if racer == 0:
			_effects[kind] = true)
	for frame: int in range(750):
		if frame == 30:
			key(KEY_ENTER, true)
		if frame == 31:
			key(KEY_ENTER, false)
			key(KEY_UP, true)
		if state.phase == "racing":
			# 他のGUI検証へフォーカスが移っても、保持入力を実イベントで再送する。
			axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
			_moved = _moved or state.racers[0].speed > 8.0
			var local_time: float = float(frame) / 30.0
			var drift_active: bool = _update_drift_attempt(state)
			var target: float = -3.0 if local_time < 7.0 else 0.0
			var turn: float = _drift_turn if drift_active else clampf(
				(target - state.racers[0].lateral) * 0.5 - 0.085, -0.65, 0.65)
			axis(JOY_AXIS_LEFT_X, turn)
			key(KEY_SPACE, drift_active)
			key(KEY_E, frame % 90 == 0)
		if frame % 60 == 0 and not state.racers.is_empty():
			print("録画経過 %.1f秒: レース %.1f秒 / 距離 %.1f / 速度 %.1f" % [
				frame / 30.0, state.elapsed, state.racers[0].progress, state.racers[0].speed])
		await process_frame
	release_all()
	await _main.prepare_shutdown()
	var success: bool = (state.phase in ["racing", "results"]
		and state.racers[0].progress > Course.LENGTH and _moved
		and _effects.has("pickup") and _effects.has("boost"))
	if success:
		print("demo OK: 実入力で1周以上走行し、アイテム取得とブーストを録画")
	else:
		printerr("録画シナリオ不成立: phase=%s progress=%.1f moved=%s effects=%s" % [
			state.phase, state.racers[0].progress, _moved, _effects])
	quit(0 if success else 1)


# 被弾時は回復を待って実入力で再試行し、偶然の命中で演出の記録が欠けるのを防ぐ。
func _update_drift_attempt(state: Node) -> bool:
	var racer: Dictionary = state.racers[0]
	if _effects.has("boost"):
		return false
	if _drift_started >= 0.0:
		if racer.spin > 0.0 or racer.speed < 8.0:
			_drift_started = -1.0
			_next_drift = state.elapsed + 1.0
		elif state.elapsed - _drift_started >= 0.9:
			_drift_started = -1.0
			_next_drift = state.elapsed + 2.0
	elif state.elapsed >= _next_drift and racer.spin <= 0.0 and racer.speed > 12.0:
		_drift_started = state.elapsed
		_drift_turn = -0.45 if racer.lateral > 0.0 else 0.45
	return _drift_started >= 0.0


static func key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


static func button(index: JoyButton, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)


static func axis(index: JoyAxis, value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = 0
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)


static func release_all() -> void:
	for code: Key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_E, KEY_ENTER]:
		key(code, false)
	for index: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]:
		button(index, false)
	for index: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		axis(index, 0.0)
