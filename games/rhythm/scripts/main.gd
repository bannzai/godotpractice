extends Control
## 入力、画面、音声の結線。進行の状態はRhythmStateを正とする。
## 入力と音声再生・Tweenは時間に沿った操作のため非冪等。

const Stage = preload("res://scripts/stage.gd")
const CREAM := Color("fff0cf")
const MINT := Color("87dfcf")
const CORAL := Color("ff8c89")
const INK := Color("192d47")
var state: Node
var stage: Node2D
var page: Control
var music: AudioStreamPlayer
var sfx: Array[AudioStreamPlayer] = []
var transition: ColorRect
var score_label: Label
var combo_label: Label
var accuracy_label: Label
var time_label: Label
var gauge_bar: ProgressBar
var progress_bar: ProgressBar
var offset_label: Label
var preview_button: Button
var result_score: Label
var song_buttons: Array[Button] = []
var force_audio: bool = false
var closing: bool = false
var previewing: bool = false
var last_screen: String = ""
var shown_score: float = 0.0
var preview_started: float = 0.0
var audio_origin: float = 0.0
var manual_clock: bool = false
var manual_time: float = 0.0
var last_combo: int = 0
var fever: bool = false
var touches: Dictionary = {}
var inputs: Array[Dictionary] = [{}, {}]
var settings_panel: Panel


func _ready() -> void:
	print("rhythm boot")
	DisplayServer.window_set_title("星灯りのリズム便")
	state = get_node("/root/RhythmState")
	get_tree().auto_accept_quit = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_theme()
	music = AudioStreamPlayer.new()
	music.name = "Music"
	# Webでも同じ音声時計を使うため、BGMはストリームとして再生する。
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	music.volume_db = -4
	music.finished.connect(_music_finished)
	add_child(music)
	for index: int in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = -8
		add_child(player)
		sfx.append(player)
	stage = Stage.new()
	add_child(stage)
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	transition = ColorRect.new()
	transition.color = Color(INK, 0)
	transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(transition)
	state.screen_changed.connect(_show_screen)
	state.judged.connect(_on_judged)
	_show_screen()


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = load("res://assets/fonts/MPLUSRounded1c-Regular.ttf")
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", CREAM)
	for kind: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var color: Color = {
			"normal": Color("29445c"),
			"hover": Color("3b6375"),
			"pressed": Color("172c43"),
			"focus": Color(0, 0, 0, 0),
			"disabled": Color("263649")
		}[kind]
		var border: Color = MINT if kind == "focus" else Color("65818d")
		var box: StyleBoxFlat = _box(color, 16, border)
		box.set_border_width_all(3 if kind == "focus" else 1)
		theme.set_stylebox(kind, "Button", box)
		theme.set_color("font_%s_color" % kind, "Button", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_stylebox("background", "ProgressBar", _box(Color("233f55"), 8))
	theme.set_stylebox("fill", "ProgressBar", _box(MINT, 8))


func _box(color: Color, radius: int = 18, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.border_color = border
	box.set_border_width_all(1)
	return box


func _label(text: String, rect: Rect2, font_size: int = 22, color: Color = CREAM) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(label)
	return label


func _button(text: String, rect: Rect2, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.pivot_offset = rect.size / 2
	button.pressed.connect(callback)
	button.mouse_entered.connect(
		func() -> void:
			var tween: Tween = button.create_tween()
			tween.tween_property(button, "scale", Vector2.ONE * 1.025, 0.12)
	)
	button.mouse_exited.connect(
		func() -> void:
			var tween: Tween = button.create_tween()
			tween.tween_property(button, "scale", Vector2.ONE, 0.12)
	)
	page.add_child(button)
	return button


func _panel(rect: Rect2, color: Color = Color("192d47")) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _box(color, 24, Color("496679")))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(panel)
	return panel


func _show_screen() -> void:
	if state.screen == last_screen:
		return
	last_screen = state.screen
	previewing = false
	touches.clear()
	inputs = [{}, {}]
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()
	song_buttons.clear()
	settings_panel = null
	match state.screen:
		"title":
			_title()
			_play_music("title")
		"select":
			_select()
			_play_music("select")
		"play":
			_play()
			_play_music(str(state.songs[state.selected_song].id))
		"result":
			_result()
			_play_music("result-clear" if state.cleared else "result-fail")
			stage.celebrate()
	transition.color.a = 0.65
	var tween: Tween = create_tween()
	tween.tween_property(transition, "color:a", 0.0, 0.32)


func _title() -> void:
	_label("夜空の音楽郵便局", Rect2(76, 65, 440, 36), 23, MINT)
	_label("星灯りの\nリズム便", Rect2(72, 135, 680, 210), 76)
	_label("ひとつのビートが、街の灯りになる。", Rect2(78, 364, 650, 40), 25)
	_label("3つの夜。3人の奏者。あなたが届ける音楽。", Rect2(78, 411, 640, 40), 20, Color("b7ccd4"))
	var start: Button = _button("曲を選ぶ  →", Rect2(78, 490, 400, 76), state.show_select)
	start.add_theme_font_size_override("font_size", 27)
	start.grab_focus()
	_button("終了", Rect2(500, 490, 150, 76), request_close)
	_label("F / J ・ パッド X / B ・ 左右のタップ", Rect2(78, 614, 800, 36), 20, MINT)
	_label("Enter / A で決定     F11 全画面", Rect2(78, 656, 800, 32), 18, Color("b7ccd4"))
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/ui/logo-mark.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(890, 88)
	icon.size = Vector2(166, 166)
	page.add_child(icon)


func _select() -> void:
	_label("今日の配達曲", Rect2(64, 38, 780, 60), 42)
	_label("夜の行き先を選んで、演奏しよう。", Rect2(66, 103, 700, 36), 21, MINT)
	_button("タイトル", Rect2(1035, 48, 180, 52), state.show_title)
	for index: int in range(state.songs.size()):
		var song: Dictionary = state.songs[index]
		var record: Dictionary = state.get_record(index, state.difficulty)
		var best: String = (
			"まだ演奏していません"
			if record.is_empty()
			else ("最高 %06d   ランク %s" % [int(record.score), str(record.rank)])
		)
		var text: String = (
			"%02d    %s\n%d BPM  /  %d秒     %s"
			% [index + 1, song.title, song.bpm, song.duration, best]
		)
		var button: Button = _button(
			text, Rect2(64, 166 + index * 126, 668, 108), func() -> void: _choose_song(index)
		)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 22)
		song_buttons.append(button)
		if index == state.selected_song:
			button.add_theme_stylebox_override("normal", _box(Color("345e69"), 16, MINT))
	_panel(Rect2(770, 166, 446, 256), Color(0.09, 0.16, 0.25, 0.94))
	_label("演奏の準備", Rect2(795, 183, 380, 42), 28)
	_button("やさしい", Rect2(795, 242, 183, 54), func() -> void: _difficulty("easy"))
	_button("むずかしい", Rect2(990, 242, 201, 54), func() -> void: _difficulty("hard"))
	_label("選択中：" + _difficulty_name(), Rect2(795, 310, 380, 34), 21, MINT)
	preview_button = _button("試聴する ♪", Rect2(795, 353, 182, 46), _toggle_preview)
	_button("音の調整", Rect2(990, 353, 201, 46), _settings)
	var start: Button = _button("この曲を演奏する  →", Rect2(64, 576, 430, 68), start_song)
	start.grab_focus()
	_label("F：コーラル   J：ミント   尾のある音は長押し", Rect2(64, 663, 1040, 32), 19, Color("c0d4dc"))
	if not state.error_message.is_empty():
		_label(state.error_message, Rect2(64, 626, 700, 30), 18, CORAL)


func _choose_song(index: int) -> void:
	state.select_song(index)
	_refresh_select()


func _difficulty(value: String) -> void:
	state.set_difficulty(value)
	_refresh_select()


func _refresh_select() -> void:
	last_screen = ""
	_show_screen()


func _difficulty_name() -> String:
	return "やさしい" if state.difficulty == "easy" else "むずかしい"


func _settings() -> void:
	if settings_panel != null:
		return
	for child: Node in page.get_children():
		if child is Button:
			child.disabled = true
	settings_panel = _panel(Rect2(220, 140, 840, 440), Color("192d47"))
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label("音のタイミング調整", Rect2(268, 170, 750, 50), 36)
	_label("叩く音が遅く聞こえるときは ＋ へ。\n判定の時刻を最大 ±200 ms 調整できます。", Rect2(268, 242, 750, 88), 23)
	offset_label = _label("%+d ms" % state.offset_ms, Rect2(566, 359, 220, 60), 36, MINT)
	_button("−10 ms", Rect2(300, 360, 220, 60), func() -> void: _offset(-10))
	_button("＋10 ms", Rect2(765, 360, 220, 60), func() -> void: _offset(10))
	_button("初期値", Rect2(300, 474, 220, 60), func() -> void: _offset(-state.offset_ms))
	var close: Button = _button("保存して戻る", Rect2(560, 474, 425, 60), _refresh_select)
	close.grab_focus()


func _offset(amount: int) -> void:
	state.set_offset(state.offset_ms + amount)
	offset_label.text = "%+d ms" % state.offset_ms


func _play() -> void:
	fever = false
	last_combo = 0
	shown_score = 0
	_label(str(state.songs[state.selected_song].title), Rect2(64, 30, 610, 50), 32)
	_label(_difficulty_name(), Rect2(67, 82, 460, 28), 19, MINT)
	_button("中断  Esc", Rect2(1050, 35, 166, 52), state.abort_song)
	_label("スコア", Rect2(565, 31, 220, 30), 17, MINT)
	score_label = _label("0000000", Rect2(565, 63, 230, 55), 36)
	accuracy_label = _label("精度 100.0%", Rect2(815, 68, 260, 40), 23)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(64, 132)
	progress_bar.size = Vector2(1152, 7)
	progress_bar.show_percentage = false
	page.add_child(progress_bar)
	time_label = _label("", Rect2(890, 155, 320, 30), 18, MINT)
	_label("ここで叩く", Rect2(229, 157, 300, 30), 19, CREAM)
	combo_label = _label("", Rect2(65, 456, 210, 65), 40)
	_label("街の灯り", Rect2(67, 525, 210, 35), 21, MINT)
	gauge_bar = ProgressBar.new()
	gauge_bar.position = Vector2(65, 568)
	gauge_bar.size = Vector2(525, 22)
	gauge_bar.max_value = 1.0
	gauge_bar.show_percentage = false
	page.add_child(gauge_bar)
	_label("60% で配達成功", Rect2(65, 602, 420, 32), 18, CREAM)
	_label("│", Rect2(65 + 525 * 0.6 - 10, 566, 35, 30), 24, INK)
	var left: Button = _button("F / パッド X　 コーラル", Rect2(64, 650, 552, 54), func() -> void: pass)
	var right: Button = _button("J / パッド B　 ミント", Rect2(640, 650, 576, 54), func() -> void: pass)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.focus_mode = Control.FOCUS_NONE
	right.focus_mode = Control.FOCUS_NONE
	left.add_theme_color_override("font_color", CORAL)
	right.add_theme_color_override("font_color", MINT)


func start_song() -> void:
	state.start_song()


func audio_time() -> float:
	if manual_clock:
		return manual_time
	if music.playing:
		return maxf(
			0.0,
			(
				music.get_playback_position()
				+ AudioServer.get_time_since_last_mix()
				- AudioServer.get_output_latency()
			)
		)
	return maxf(0.0, Time.get_ticks_usec() / 1000000.0 - audio_origin)


func _process(delta: float) -> void:
	if closing:
		return
	if state.screen == "play":
		state.advance(audio_time())
		if state.screen != "play":
			return
		shown_score = lerpf(shown_score, state.score, minf(1.0, delta * 15))
		score_label.text = "%07d" % roundi(shown_score)
		combo_label.text = "%d" % state.combo if state.combo > 0 else ""
		accuracy_label.text = "精度 %.1f%%" % (state.accuracy * 100)
		gauge_bar.value = state.gauge
		progress_bar.value = state.song_time / float(state.chart.duration) * 100
		time_label.text = (
			"%02d:%02d / %02d:%02d"
			% [
				int(maxf(0, state.song_time)) / 60,
				int(maxf(0, state.song_time)) % 60,
				int(state.chart.duration) / 60,
				int(state.chart.duration) % 60
			]
		)
		if state.combo != last_combo:
			last_combo = state.combo
			combo_label.scale = Vector2.ONE * 1.15
			create_tween().tween_property(combo_label, "scale", Vector2.ONE, 0.18)
		if state.gauge >= 0.999 and not fever:
			fever = true
			stage.celebrate()
			_play_sfx("fever")
		elif state.gauge < 0.95:
			fever = false
	elif previewing and Time.get_ticks_msec() / 1000.0 - preview_started >= 12:
		_toggle_preview()


func _result() -> void:
	_label("配達成功！" if state.cleared else "もう一度、届けよう。", Rect2(64, 42, 1150, 75), 48)
	_label(
		str(state.songs[state.selected_song].title) + "  /  " + _difficulty_name(),
		Rect2(66, 127, 1070, 40),
		23,
		MINT
	)
	_panel(Rect2(64, 194, 668, 353), Color(0.09, 0.16, 0.25, 0.95))
	_label("今回のスコア", Rect2(97, 219, 380, 40), 22, MINT)
	result_score = _label("0", Rect2(93, 264, 600, 75), 57)
	var tween: Tween = create_tween()
	tween.tween_method(
		func(value: float) -> void:
			if is_instance_valid(result_score):
				result_score.text = "%07d" % roundi(value),
		0.0,
		float(state.score),
		0.8
	)
	_label(
		"最大コンボ  %d     精度  %.1f%%" % [state.max_combo, state.accuracy * 100],
		Rect2(98, 357, 600, 40),
		24
	)
	_label(
		(
			"パーフェクト %d     グッド %d     ミス %d"
			% [state.counts.Perfect, state.counts.Good, state.counts.Miss]
		),
		Rect2(98, 418, 620, 40),
		21
	)
	_label("街の灯り %.0f%%  /  クリア条件 60%%" % (state.gauge * 100), Rect2(98, 480, 610, 36), 21, MINT)
	_label("ランク", Rect2(897, 203, 270, 40), 26, MINT)
	_label(str(state.rank), Rect2(891, 230, 290, 170), 118)
	var retry: Button = _button("もう一度演奏", Rect2(64, 582, 322, 68), start_song)
	retry.grab_focus()
	_button("選曲に戻る", Rect2(408, 582, 324, 68), state.show_select)
	_label("記録は曲・難易度ごとに保存されます。", Rect2(66, 673, 900, 28), 18, MINT)
	if not state.error_message.is_empty():
		_label(state.error_message, Rect2(780, 641, 450, 40), 18, CORAL)


func _input(event: InputEvent) -> void:
	if closing:
		return
	if event.is_action_pressed("fullscreen"):
		var current: int = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_WINDOWED
				if current == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN
			)
		)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if settings_panel != null:
			_refresh_select()
		elif state.screen == "play":
			state.abort_song()
		elif state.screen in ["result", "select"]:
			if state.screen == "select":
				state.show_title()
			else:
				state.show_select()
		get_viewport().set_input_as_handled()
		return
	if state.screen != "play":
		return
	_play_input(event)


func _play_input(event: InputEvent) -> void:
	for lane: int in range(2):
		var action: String = "hit_coral" if lane == 0 else "hit_mint"
		if event.is_action(action):
			if event is InputEventKey and event.echo:
				return
			var source: String = (
				"key_%d" % event.physical_keycode
				if event is InputEventKey
				else "pad_%d" % event.device
			)
			_lane_input(lane, event.is_pressed(), source)
			get_viewport().set_input_as_handled()
			return
	_pointer_input(event)


func _pointer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y < 180:
			return
		if event.pressed:
			touches[-1] = 0 if event.position.x < 640 else 1
		if not touches.has(-1):
			return
		if touches.has(-1):
			_lane_input(touches[-1], event.pressed, "mouse")
			if not event.pressed:
				touches.erase(-1)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and event.position.y < 180:
			return
		if event.pressed:
			touches[event.index] = 0 if event.position.x < 640 else 1
		if not touches.has(event.index):
			return
		if touches.has(event.index):
			_lane_input(touches[event.index], event.pressed, "touch_%d" % event.index)
			if not event.pressed:
				touches.erase(event.index)
		get_viewport().set_input_as_handled()


func _lane_input(lane: int, pressed: bool, source: String) -> void:
	if pressed:
		if inputs[lane].has(source):
			return
		inputs[lane][source] = true
		if inputs[lane].size() == 1:
			state.press_lane(lane, audio_time())
			stage.pulses[lane] = 0.8
			_play_sfx("hit-coral" if lane == 0 else "hit-mint")
	else:
		inputs[lane].erase(source)
		if inputs[lane].is_empty():
			state.release_lane(lane, audio_time())


func _on_judged(kind: String, _lane: int) -> void:
	if kind == "Miss":
		_play_sfx("miss")


func _toggle_preview() -> void:
	previewing = not previewing
	if previewing:
		_play_music(str(state.songs[state.selected_song].id), 8.0)
		preview_started = Time.get_ticks_msec() / 1000.0
	else:
		_play_music("select")
	preview_button.text = "試聴を止める" if previewing else "試聴する ♪"


func _play_music(id: String, from: float = 0.0) -> void:
	music.stop()
	music.stream = null
	audio_origin = Time.get_ticks_usec() / 1000000.0
	if not force_audio and AudioServer.get_driver_name() == "Dummy" and not OS.has_feature("movie"):
		return
	music.stream = load("res://assets/audio/%s.ogg" % id)
	music.play(from)


func _play_sfx(id: String) -> void:
	if (
		closing
		or (
			AudioServer.get_driver_name() == "Dummy"
			and not OS.has_feature("movie")
			and not force_audio
		)
	):
		return
	for player: AudioStreamPlayer in sfx:
		if not player.playing:
			player.stream = load("res://assets/audio/%s.wav" % id)
			player.play()
			return


func _music_finished() -> void:
	if closing:
		return
	if state.screen == "play":
		state.advance(float(state.chart.duration))
	elif state.screen in ["title", "select"]:
		if previewing:
			_toggle_preview()
		else:
			_play_music(state.screen)


func stop_audio() -> void:
	if music != null:
		music.stop()
		music.stream = null
	for player: AudioStreamPlayer in sfx:
		player.stop()
		player.stream = null


func request_close() -> void:
	if closing:
		return
	closing = true
	stop_audio()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_close()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and state != null and state.screen == "play":
		for lane: int in range(2):
			inputs[lane].clear()
			state.release_lane(lane, audio_time())


func _exit_tree() -> void:
	stop_audio()
	# --quit-afterは非同期の終了待ちを通らないので音声スレッドの回収をここで待つ。
	OS.delay_msec(100)
