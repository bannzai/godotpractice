extends SceneTree
## 実入力を通した画面遷移・演奏と、AudioStreamPlayer の時計を検証する。
## テスト用入力と時刻進行はシナリオを進めるため非冪等。

const Rules = preload("res://scripts/rhythm_rules.gd")
const Stage = preload("res://scripts/stage.gd")

var main: Control
var state: Node
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	state = root.get_node("RhythmState")
	state.save_path = "res://tmp/integration-records.json"
	state.records = {}
	state.offset_ms = 0
	state.show_title()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.manual_clock = true
	await process_frame
	await _check_navigation()
	await _check_input_devices()
	await _check_all_charts()
	await _check_audio_clock()
	main.closing = true
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	if failed:
		quit(1)
	else:
		print("integration OK")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("integration FAIL: " + label)


func _dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	_dispatch(event)


func _pad(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	_dispatch(event)


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_dispatch(event)


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	_dispatch(event)


func _click_button(prefix: String) -> void:
	await process_frame
	var found := false
	for child: Node in main.page.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			found = true
			var center: Vector2 = child.get_global_rect().get_center()
			_mouse(center, true)
			_mouse(center, false)
			break
	_check(found, "ボタンを実クリック: " + prefix)
	await process_frame


func _check_navigation() -> void:
	_check(state.screen == "title", "タイトルで起動")
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, false)
	await process_frame
	_check(state.screen == "select", "パッド A のフォーカス決定で選曲へ")
	await _click_button("音の調整")
	await _click_button("＋10 ms")
	_check(state.offset_ms == 10, "調整ボタンから保存値を変更")
	await _click_button("初期値")
	await _click_button("保存して戻る")
	_check(state.offset_ms == 0 and main.settings_panel == null, "調整を閉じて初期値に復帰")
	await _click_button("試聴する")
	_check(main.previewing, "試聴を開始")
	await _click_button("試聴を止める")
	_check(not main.previewing, "試聴を終了")
	main.manual_time = 0.0
	await _click_button("この曲を演奏する")
	_check(state.screen == "play", "実クリックで演奏開始")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	_check(state.screen == "select", "Escape で演奏を中断")
	await _click_button("タイトル")
	_check(state.screen == "title", "選曲からタイトルへ")
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	await process_frame
	_check(state.screen == "select", "Enter のフォーカス決定で選曲へ")


func _prepare_input_chart() -> void:
	main.manual_time = 0.0
	main.start_song()
	state.chart = {"bpm": 120.0, "offset": 0.0, "duration": 60.0, "notes": []}
	state.notes = []
	for index: int in range(8):
		state.notes.append({"beat": 4.0 + index * 2.0,
			"type": "coral" if index % 2 == 0 else "mint", "lane": index % 2,
			"length": 0.0, "status": "pending", "judgment": ""})
	state.notes.append({"beat": 22.0, "type": "long", "lane": 0,
		"length": 2.0, "status": "pending", "judgment": ""})
	state.notes.append({"beat": 26.0, "type": "long", "lane": 1,
		"length": 2.0, "status": "pending", "judgment": ""})


func _lane_event(lane: int, pressed: bool, device: int) -> void:
	match device:
		0:
			_key(KEY_F if lane == 0 else KEY_J, pressed)
		1:
			_pad(JOY_BUTTON_X if lane == 0 else JOY_BUTTON_B, pressed)
		2:
			_mouse(Vector2(320 if lane == 0 else 960, 500), pressed)
		3:
			_touch(lane, Vector2(320 if lane == 0 else 960, 500), pressed)


func _check_input_devices() -> void:
	_prepare_input_chart()
	await process_frame
	for index: int in range(8):
		main.manual_time = 2.0 + index
		_lane_event(index % 2, true, index / 2)
		_lane_event(index % 2, false, index / 2)
	_check(state.counts.Perfect == 8, "F/J・X/B・左右マウス・左右タッチの全入力を判定")
	main.manual_time = 11.0
	_key(KEY_F, true)
	_check(state.notes[8].status == "holding", "実キー入力でロング保持を開始")
	main.manual_time = 11.5
	_key(KEY_F, false)
	_check(state.notes[8].judgment == "Miss", "実キーの途中離しで Miss")
	main.manual_time = 13.0
	_touch(1, Vector2(960, 500), true)
	main.manual_time = 14.0
	_touch(1, Vector2(960, 100), false)
	_check(state.notes[9].judgment == "Perfect", "タッチを画面上部で離してもロング成功")
	_check(main.inputs[1].is_empty(), "上部で離したタッチ入力が残らない")
	main.manual_time = 60.0
	await process_frame
	_check(state.screen == "result", "入力した演奏の曲終了で結果へ")
	await _click_button("選曲に戻る")
	_check(state.screen == "select", "結果から実クリックで選曲へ")


func _chart_events(device: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for note: Dictionary in state.notes:
		events.append({"time": Rules.note_time(note, state.chart),
			"lane": int(note.lane), "pressed": true, "device": device})
		events.append({"time": Rules.end_time(note, state.chart) + 0.00001,
			"lane": int(note.lane), "pressed": false, "device": device})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return events


func _check_all_charts() -> void:
	for song_index: int in range(3):
		for difficulty: String in ["easy", "hard"]:
			state.select_song(song_index)
			state.set_difficulty(difficulty)
			main.manual_time = 0.0
			main.start_song()
			await process_frame
			var events: Array[Dictionary] = _chart_events(song_index % 2)
			var event_index := 0
			var ticks := ceili(float(state.chart.duration) * 120.0)
			for tick: int in range(ticks + 1):
				var time := tick / 120.0
				while event_index < events.size() and float(events[event_index].time) <= time:
					var event: Dictionary = events[event_index]
					main.manual_time = event.time
					_lane_event(event.lane, event.pressed, event.device)
					event_index += 1
				main.manual_time = time
				state.advance(time)
				if tick % 120 == 0:
					await process_frame
			_check(state.screen == "result" and state.cleared,
				"全曲・全難易度の実入力演奏でクリア結果")
			_check(state.score == 1000000 and state.counts.Miss == 0,
				"全曲・全難易度で全 Perfect と 100 万点")
			await _click_button("選曲に戻る")
	state.select_song(0)
	state.set_difficulty("easy")
	main.manual_time = 0.0
	main.start_song()
	main.manual_time = float(state.chart.duration)
	await process_frame
	_check(state.screen == "result" and not state.cleared, "無入力では失敗結果")
	main.manual_time = 0.0
	await _click_button("もう一度演奏")
	_check(state.screen == "play", "結果の再演奏ボタンで再開")
	await _click_button("中断")
	await _click_button("タイトル")
	_check(state.screen == "title", "再演奏・中断からタイトルに帰還")


func _check_audio_clock() -> void:
	state.select_song(0)
	state.set_difficulty("easy")
	state.offset_ms = 100
	main.manual_clock = false
	main.force_audio = true
	main.start_song()
	await create_timer(0.35).timeout
	_check(main.music.playing, "実 AudioStreamPlayer で音源を再生")
	var position: float = main.music.get_playback_position()
	_check(position > 0.1, "実再生位置が進む")
	var expected: float = maxf(0.0, position + AudioServer.get_time_since_last_mix()
		- AudioServer.get_output_latency())
	var observed: float = main.audio_time()
	_check(absf(observed - expected) < 0.025, "音声補正式の時刻差が 25 ms 未満")
	var target: float = Rules.note_time(state.notes[0], state.chart) + 0.1
	var deadline: int = Time.get_ticks_msec() + 8000
	while main.audio_time() < target and Time.get_ticks_msec() < deadline:
		await process_frame
	observed = main.audio_time()
	_key(KEY_F, true)
	_key(KEY_F, false)
	_check(state.notes[0].judgment == "Perfect", "実音声の最初の拍を遅延補正して Perfect")
	var error_seconds: float = absf(state.song_time - Rules.note_time(state.notes[0], state.chart))
	_check(error_seconds <= float(state.thresholds.perfect), "音声の拍と判定線の差が Perfect 範囲内")
	print(("audio-sync driver=%s playback=%.3f corrected=%.3f "
		+ "offset_ms=%d deviation_ms=%.3f line_px=%.3f")
		% [AudioServer.get_driver_name(), main.music.get_playback_position(), observed,
			state.offset_ms, error_seconds * 1000.0, error_seconds * Stage.SPEED])
	state.abort_song()
	state.offset_ms = 0
