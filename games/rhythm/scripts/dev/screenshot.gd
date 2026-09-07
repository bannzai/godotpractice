extends SceneTree
## 本番入力で各画面を作り、動きと演出の時間経過を撮影する。検証シナリオは非冪等。

const Rules = preload("res://scripts/rhythm_rules.gd")
const Dancer = preload("res://scripts/dancer.gd")
var _main: Control
var _state: Node
var _failed: bool = false


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


func _run() -> void:
	_state = root.get_node("RhythmState")
	_state.save_path = "res://tmp/screenshot-records.json"
	_state.records = {}
	_state.set_offset(0)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.manual_clock = true
	root.add_child(_main)
	await _capture_scenes()
	_main.stop_audio()
	await create_timer(0.2).timeout
	_main.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _capture_scenes() -> void:
	await create_timer(0.4).timeout
	await _capture("title")
	await _tap(KEY_ENTER)
	await create_timer(0.4).timeout
	await _capture("select")
	await _tap(KEY_RIGHT)
	await _capture("select-highlight")
	await _tap(KEY_LEFT)
	_main._settings()
	await _capture("settings")
	await _tap(KEY_ESCAPE)
	_main.start_song()
	await _capture("tutorial-coral")
	await _tap(KEY_F)
	await _capture("tutorial-mint")
	await _tap(KEY_J)
	_key(KEY_F, true)
	await create_timer(0.4).timeout
	await _capture("tutorial-hold")
	_key(KEY_F, false)
	await process_frame
	await _capture("tutorial-complete")
	_main._finish_tutorial()
	await create_timer(0.4).timeout
	_main.manual_time = Rules.note_time(_state.notes[0], _state.chart) - 1.0
	await _capture("play")
	await _play_chart()
	_main.manual_time = float(_state.chart.duration)
	_state.advance(_main.manual_time)
	await create_timer(0.9).timeout
	if not _state.cleared:
		_fail("全入力成功の撮影でクリアできなかった")
	await _capture("clear")
	await _tap(KEY_ENTER)
	_main.manual_time = float(_state.chart.duration)
	_state.advance(_main.manual_time)
	await create_timer(0.9).timeout
	if _state.cleared:
		_fail("無入力の撮影が失敗結果にならなかった")
	await _capture("fail")
	_main.manual_time = 0
	await _tap(KEY_ENTER)
	await create_timer(0.4).timeout
	for kind: String in ["Perfect", "Miss"]:
		_main.stage.on_judged(kind, 0)
		await _capture("effect-%s-start" % kind.to_lower())
		await create_timer(0.15).timeout
		await _capture("effect-%s-middle" % kind.to_lower())
		await create_timer(0.5).timeout
		await _capture("effect-%s-end" % kind.to_lower())
	_main.hide()
	_main.stage.frozen_view = true
	for character: String in ["fox", "bird", "rabbit"]:
		await _gallery(character)


func _play_chart() -> void:
	var events: Array[Dictionary] = []
	for note: Dictionary in _state.notes:
		var start: float = Rules.note_time(note, _state.chart)
		var finish: float = Rules.end_time(note, _state.chart)
		events.append({"time": start, "lane": int(note.lane), "pressed": true,
			"long": note.type == "long"})
		events.append({"time": maxf(start + 0.01, finish + 0.001),
			"lane": int(note.lane), "pressed": false, "long": false})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	var captured_hold: bool = false
	var captured_fever: bool = false
	for event: Dictionary in events:
		_main.manual_time = float(event.time)
		_key(KEY_F if int(event.lane) == 0 else KEY_J, bool(event.pressed))
		await process_frame
		if bool(event.long) and not captured_hold:
			captured_hold = true
			await _capture("hold")
		if _state.gauge >= 0.999 and not captured_fever:
			captured_fever = true
			await create_timer(0.15).timeout
			await _capture("fever")
	if not captured_hold or not captured_fever:
		_fail("長押しまたはゲージ満タンの撮影に到達しなかった")


func _gallery(character: String) -> void:
	var gallery: Control = Control.new()
	gallery.theme = _main.theme
	root.add_child(gallery)
	var background: ColorRect = ColorRect.new()
	background.color = Color("192d47")
	background.size = Vector2(1280, 720)
	gallery.add_child(background)
	var names: Dictionary = {"fox": "キツネの奏者", "bird": "トリの奏者", "rabbit": "ウサギの奏者"}
	_gallery_label(gallery, str(names[character]) + "  動きの連続フレーム", Vector2(44, 24), 32)
	for column: int in range(3):
		_gallery_label(gallery, ["開始 0.00秒", "途中 0.30秒", "終了 0.60秒"][column],
			Vector2(320 + column * 320, 76), 23)
	var titles: Array[String] = ["待機", "拍に合わせた踊り", "成功・跳ねる", "ミス・よろめく", "祝福・ジャンプ"]
	for row: int in range(Dancer.POSES.size()):
		_gallery_label(gallery, titles[row], Vector2(44, 154 + row * 110), 22)
		for column: int in range(3):
			var dancer: Node2D = Dancer.new()
			gallery.add_child(dancer)
			dancer.setup(character)
			dancer.position = Vector2(402 + column * 320, 218 + row * 110)
			dancer.scale = Vector2.ONE * 0.34
			dancer.sample(Dancer.POSES[row], column * 0.5)
	await _capture("animation-" + character)
	gallery.queue_free()
	await process_frame


func _gallery_label(parent: Control, text: String, position: Vector2, font_size: int) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)


func _tap(code: Key) -> void:
	_key(code, true)
	await process_frame
	_key(code, false)
	await process_frame
	await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % name
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		_fail("撮影保存に失敗: " + path)
	print("screenshot: " + path)


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
