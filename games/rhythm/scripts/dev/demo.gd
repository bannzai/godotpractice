extends SceneTree
## 26秒の実入力録画。最初の約20秒は等速演奏し、中盤を省略して通常の失敗結果まで進める。
## 時刻と音声のseekだけを同期して変更し、スコア・判定・画面状態は変更しない。

const Rules = preload("res://scripts/rhythm_rules.gd")
const DURATION: float = 26.0
var _main: Control
var _state: Node
var _elapsed: float = 0.0
var _started_at: float = -1.0
var _time_shift: float = 0.0
var _events: Array[Dictionary] = []
var _event_index: int = 0
var _menu_step: int = 0
var _jumped: bool = false
var _stopped: bool = false
var _complete: bool = false
var _long_success: bool = false
var _screens: Array[String] = []


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	_state = root.get_node("RhythmState")
	_state.save_path = "res://tmp/demo-records.json"
	_state.records = {}
	_state.set_offset(0)
	_state.screen_changed.connect(_observe_screen)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.manual_clock = true
	root.add_child(_main)
	_observe_screen()


# 固定30fpsの映像・音声と同じ経過秒で入力するため、呼び出しごとに時間が進む。
func _process(delta: float) -> bool:
	if _main == null or _complete:
		return false
	_elapsed += delta
	_menu_input()
	if _state.screen == "play":
		_play_input()
	if _elapsed >= DURATION - 0.5 and not _stopped:
		_stopped = true
		_main.stop_audio()
	if _elapsed >= DURATION:
		_finish()
	return false


func _menu_input() -> void:
	var events: Array[Dictionary] = [
		{"time": 0.7, "code": KEY_ENTER, "pressed": true},
		{"time": 0.75, "code": KEY_ENTER, "pressed": false},
		{"time": 1.5, "code": KEY_ENTER, "pressed": true},
		{"time": 1.55, "code": KEY_ENTER, "pressed": false},
		{"time": 2.2, "code": KEY_F, "pressed": true},
		{"time": 2.25, "code": KEY_F, "pressed": false},
		{"time": 2.7, "code": KEY_J, "pressed": true},
		{"time": 2.75, "code": KEY_J, "pressed": false},
		{"time": 3.0, "code": KEY_F, "pressed": true},
		{"time": 3.5, "code": KEY_F, "pressed": false},
		{"time": 4.1, "code": KEY_ENTER, "pressed": true},
		{"time": 4.15, "code": KEY_ENTER, "pressed": false},
	]
	if _menu_step >= events.size() or _elapsed < float(events[_menu_step].time):
		return
	_key(events[_menu_step].code, events[_menu_step].pressed)
	_menu_step += 1


func _observe_screen() -> void:
	_screens.append(str(_state.screen))
	if _state.screen == "play" and _started_at < 0:
		_started_at = _elapsed
		_build_events()


func _build_events() -> void:
	for note: Dictionary in _state.notes:
		var start: float = Rules.note_time(note, _state.chart)
		var finish: float = Rules.end_time(note, _state.chart)
		_events.append({"time": start, "lane": int(note.lane), "pressed": true})
		_events.append({"time": maxf(start + 0.04, finish + 0.035),
			"lane": int(note.lane), "pressed": false})
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)


func _play_input() -> void:
	var song_time: float = _elapsed - _started_at + _time_shift
	if _elapsed >= 21.5 and not _jumped:
		_jump_to_ending(song_time)
		song_time = float(_state.chart.duration) - 2.0
	_main.manual_time = song_time
	if not _jumped:
		while _event_index < _events.size() and float(_events[_event_index].time) <= song_time:
			var event: Dictionary = _events[_event_index]
			_key(KEY_F if int(event.lane) == 0 else KEY_J, bool(event.pressed))
			_event_index += 1
	_state.advance(song_time)
	for note: Dictionary in _state.notes:
		if note.type == "long" and note.status == "judged" and note.judgment in ["Perfect", "Good"]:
			_long_success = true


func _jump_to_ending(song_time: float) -> void:
	_jumped = true
	# 長押しを残したままseekしない。省略区間のノーツはadvanceが通常のミスとして処理する。
	_key(KEY_F, false)
	_key(KEY_J, false)
	var ending: float = float(_state.chart.duration) - 2.0
	_time_shift = ending - song_time
	_main.music.seek(ending)
	var notice: Label = Label.new()
	notice.text = "録画用：曲の中盤を省略して終盤へ"
	notice.position = Vector2(750, 4)
	notice.add_theme_font_size_override("font_size", 17)
	_main.add_child(notice)
	print("demo seek: %.2f秒から%.2f秒へ、音声も同時にseek" % [song_time, ending])


func _finish() -> void:
	_complete = true
	var passed: bool = (
		_screens == ["title", "select", "play", "result"]
		and int(_state.counts.Perfect) + int(_state.counts.Good) >= 8
		and int(_state.counts.Miss) > 0
		and _long_success
		and _stopped
	)
	if not passed:
		push_error("録画の画面遷移・成功入力・長押し成功・失敗結果の確認が不足")
		quit(1)
		return
	print("demo OK: 実入力%d成功、長押し成功、%dミス、通常結果まで到達。中盤省略あり"
		% [int(_state.counts.Perfect) + int(_state.counts.Good), int(_state.counts.Miss)])
	quit(0)


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
