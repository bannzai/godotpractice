extends SceneTree
## 最長35秒の操作録画。終盤の出撃を初期条件とし、以降は実InputEventで射撃・回避する。
## 時刻と入力の反復は非冪等。検証専用保存先を使い、結果を直接確定させない。

var main: Control
var state: Node
var tick: int = 0
var held_direction: Key = KEY_NONE
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("GameState")
	state.save_path = "res://tmp/demo-save.json"
	state.high_score = 0
	state.tutorial_seen = false
	Input.use_accumulated_input = false
	var caption: Label = Label.new()
	caption.text = "操作録画 / 航路選択 → 計器チェック → 旗艦迎撃"
	caption.position = Vector2(450, 693)
	caption.add_theme_font_override("font", main.view.font)
	caption.add_theme_font_size_override("font_size", 14)
	root.add_child(caption)
	var result_frames: int = 0
	for frame: int in range(1050):
		tick = frame
		_events()
		if main.boss_active and state.mode == state.Mode.PLAYING and frame % 3 == 0:
			_aim_with_input()
		await process_frame
		if state.mode == state.Mode.RESULT:
			result_frames += 1
			if result_frames >= 45:
				break
	_key(KEY_Z, false)
	_key(KEY_A, false)
	_key(KEY_D, false)
	if state.mode != state.Mode.RESULT or not state.cleared:
		push_error(
			(
				"操作録画がクリア結果まで到達していない: mode=%d elapsed=%.1f boss=%s chart=%s hp=%d"
				% [
					state.mode,
					state.elapsed,
					main.boss_active,
					main.boss_chart_active,
					main.boss_hp
				]
			)
		)
		failed = true
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	await process_frame
	if not failed:
		print("demo OK: 入力によるボス撃破と結果表示")
	quit(1 if failed else 0)


func _events() -> void:
	match tick:
		20:
			_tap(KEY_ENTER)
		40:
			_tap(KEY_ENTER)
		60:
			_tap(KEY_ENTER)
			# 3分全体はintegration_checkで検証し、録画では終盤の最長35秒へ絞る。
			state.elapsed = 140.0
			state.power = 3
			while main.wave_index < main.waves.size() and main.waves[main.wave_index].time < 140.0:
				main.wave_index += 1
		75:
			_key(KEY_Z, true)
		90:
			_key(KEY_A, true)
		105:
			_key(KEY_A, false)
		150:
			_key(KEY_D, true)
		180:
			_key(KEY_D, false)
		210:
			_tap(KEY_ESCAPE)
		240:
			_tap(KEY_ESCAPE)
		510, 600, 690:
			_tap(KEY_X)


func _aim_with_input() -> void:
	var distance: float = main.boss_position.x - main.player.x
	var next: Key = KEY_NONE if absf(distance) < 12 else (KEY_D if distance > 0 else KEY_A)
	if next == held_direction:
		return
	if held_direction != KEY_NONE:
		_key(held_direction, false)
	held_direction = next
	if held_direction != KEY_NONE:
		_key(held_direction, true)


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
