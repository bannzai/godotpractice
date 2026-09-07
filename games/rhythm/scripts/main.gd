extends Control
## 入力、画面、音声の結線。進行の状態はRhythmStateを正とする。
## 入力と音声再生・Tweenは時間に沿った操作のため非冪等。

const Stage = preload("res://scripts/stage.gd")
const FestivalMeter = preload("res://scripts/festival_meter.gd")
const CREAM := Color("fff0cf")
const MINT := Color("18b7b0")
const CORAL := Color("ef3e2f")
const SUN := Color("ffc62f")
const INK := Color("17131d")
const INDIGO := Color("172c58")
const STALL_RECTS: Array[Rect2] = [
	Rect2(62, 203, 352, 306),
	Rect2(464, 203, 352, 306),
	Rect2(866, 203, 352, 306),
]
var state: Node
var stage: Node2D
var page: Control
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var sfx: Array[AudioStreamPlayer] = []
var transition: ColorRect
var score_label: Label
var combo_label: Label
var accuracy_label: Label
var time_label: Label
var gauge_bar: Control
var progress_bar: ProgressBar
var offset_label: Label
var preview_button: Button
var result_score: Label
var song_buttons: Array[Button] = []
var combo_lanterns: Array[Sprite2D] = []
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
var tutorial_panel: Panel
var tutorial_message: Label
var tutorial_hint: Label
var tutorial_step: int = 0
var tutorial_seen: bool = false
var tutorial_active: bool = false
var tutorial_hold_started: int = 0
var tutorial_left: Button
var tutorial_right: Button


func _ready() -> void:
	print("rhythm boot")
	DisplayServer.window_set_title("星灯りの祭り囃子")
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
	ambience = AudioStreamPlayer.new()
	ambience.name = "FestivalAmbience"
	ambience.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	ambience.volume_db = -17
	add_child(ambience)
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
	theme.default_font = load("res://assets/fonts/RampartOne-Regular.ttf")
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", CREAM)
	for kind: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var color: Color = {
			"normal": Color("222033"),
			"hover": Color("40324a"),
			"pressed": Color("14121c"),
			"focus": Color(0, 0, 0, 0),
			"disabled": Color("38323a")
		}[kind]
		var border: Color = SUN if kind == "focus" else INK
		var box: StyleBoxFlat = _box(color, 6, border)
		box.set_border_width_all(6 if kind == "focus" else 3)
		theme.set_stylebox(kind, "Button", box)
		theme.set_color("font_%s_color" % kind, "Button", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_stylebox("background", "ProgressBar", _box(INK, 3))
	theme.set_stylebox("fill", "ProgressBar", _box(SUN, 3))


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
	box.shadow_color = Color(INK, 0.55)
	box.shadow_size = 5
	box.shadow_offset = Vector2(7, 8)
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


func _paper_texture(path: String, rect: Rect2) -> Sprite2D:
	var image: Sprite2D = Sprite2D.new()
	image.texture = load(path)
	image.position = rect.position + rect.size / 2.0
	var scale_factor: float = minf(
		rect.size.x / image.texture.get_width(), rect.size.y / image.texture.get_height()
	)
	image.scale = Vector2.ONE * scale_factor
	var paper: ShaderMaterial = ShaderMaterial.new()
	paper.shader = load("res://shaders/paper_shadow.gdshader")
	image.material = paper
	page.add_child(image)
	return image


func _show_screen() -> void:
	if state.screen == last_screen:
		return
	last_screen = state.screen
	previewing = false
	tutorial_active = false
	touches.clear()
	inputs = [{}, {}]
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()
	song_buttons.clear()
	combo_lanterns.clear()
	settings_panel = null
	tutorial_panel = null
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
	_play_ambience()
	transition.color.a = 0.65
	var tween: Tween = create_tween()
	tween.tween_property(transition, "color:a", 0.0, 0.32)


func _title() -> void:
	_panel(Rect2(46, 54, 620, 594), Color(INDIGO, 0.94))
	_label("今夜の主役は、あなたの一打。", Rect2(82, 86, 510, 38), 22, SUN)
	_label("星灯り\n祭り囃子", Rect2(76, 128, 540, 194), 67)
	_label("三つの屋台をめぐり、\n太鼓と笛で花火を咲かせよう。", Rect2(82, 344, 520, 94), 25)
	_label("初めての一曲は、場内の稽古から始まります。", Rect2(82, 454, 510, 44), 18, Color("f7cf86"))
	var start: Button = _button("Enter / A　縁日へ歩き出す", Rect2(82, 514, 500, 78), state.show_select)
	start.add_theme_font_size_override("font_size", 24)
	start.grab_focus()
	_button("終了", Rect2(82, 607, 180, 48), request_close)
	_paper_texture("res://assets/generated/combo-lantern.png", Rect2(605, 36, 90, 108))


func _select() -> void:
	_panel(Rect2(38, 24, 1204, 145), Color(INDIGO, 0.93))
	_label("屋台の並ぶ縁日を歩こう", Rect2(68, 40, 710, 52), 38)
	_label("← → で歩く　　黄色い縁の屋台で Enter / A", Rect2(70, 102, 750, 38), 20, SUN)
	_label("三つの屋台は、どれも開店中", Rect2(842, 106, 310, 32), 17, CREAM)
	_button("タイトルへ", Rect2(1032, 46, 178, 48), state.show_title)
	for index: int in range(state.songs.size()):
		var song: Dictionary = state.songs[index]
		var record: Dictionary = state.get_record(index, state.difficulty)
		var selected: bool = index == state.selected_song
		var outline: Panel = Panel.new()
		outline.position = STALL_RECTS[index].position
		outline.size = STALL_RECTS[index].size
		var outline_box: StyleBoxFlat = _box(Color(INDIGO, 0.05), 5, SUN if selected else INK)
		outline_box.set_border_width_all(8 if selected else 3)
		outline.add_theme_stylebox_override("panel", outline_box)
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(outline)
		var best: String = (
			"初演奏"
			if record.is_empty()
			else "最高 %06d / %s" % [int(record.score), str(record.rank)]
		)
		var text: String = "%s\n%s　%d BPM　%s" % [
			str(song.title), _song_flavor(index), int(song.bpm), best
		]
		var button: Button = _button(
			text,
			Rect2(STALL_RECTS[index].position + Vector2(10, 194), Vector2(332, 102)),
			func() -> void: _activate_stall(index)
		)
		button.add_theme_font_size_override("font_size", 18)
		song_buttons.append(button)
		if selected:
			button.add_theme_stylebox_override("normal", _box(Color(INDIGO, 0.95), 4, SUN))
			button.grab_focus()
	var walker_x: float = STALL_RECTS[state.selected_song].position.x + 130.0
	_paper_texture("res://assets/generated/fox-taiko.png", Rect2(walker_x, 472, 92, 96))
	_label("▲ ここにいる", Rect2(walker_x - 20, 552, 150, 28), 16, SUN)
	_panel(Rect2(38, 576, 1204, 112), Color(INDIGO, 0.95))
	var selected_song: Dictionary = state.songs[state.selected_song]
	_label(
		"選択中　%s / %s" % [str(selected_song.title), _difficulty_name()],
		Rect2(64, 590, 415, 34),
		21,
		SUN
	)
	_label("もう一度この屋台を選ぶと、場内の稽古へ", Rect2(64, 632, 445, 30), 16, CREAM)
	_button("やさしい", Rect2(510, 598, 150, 58), func() -> void: _difficulty("easy"))
	_button("むずかしい", Rect2(672, 598, 168, 58), func() -> void: _difficulty("hard"))
	preview_button = _button("試聴 ♪", Rect2(852, 598, 150, 58), _toggle_preview)
	_button("音の調整", Rect2(1014, 598, 188, 58), _settings)
	if not state.error_message.is_empty():
		_label(state.error_message, Rect2(66, 662, 700, 24), 16, CORAL)


func _song_flavor(index: int) -> String:
	return ["大太鼓", "風鈴", "花火"][index]


func _activate_stall(index: int) -> void:
	if state.selected_song == index:
		start_song()
	else:
		_choose_song(index)


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


func _tutorial() -> void:
	tutorial_active = true
	tutorial_step = 0
	tutorial_hold_started = 0
	for child: Node in page.get_children():
		if child is Button:
			child.disabled = true
	tutorial_panel = _panel(Rect2(104, 70, 1072, 580), Color(INDIGO, 0.98))
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_paper_texture("res://assets/generated/combo-lantern.png", Rect2(142, 102, 128, 154))
	_label("場内の稽古　1曲目だけ", Rect2(302, 100, 650, 48), 32, SUN)
	tutorial_message = _label("", Rect2(300, 164, 744, 92), 30)
	tutorial_hint = _label("", Rect2(300, 250, 744, 62), 20, Color("f7cf86"))
	tutorial_left = _button("朱の面\nF / X / 左タップ", Rect2(180, 350, 420, 150), func() -> void: pass)
	tutorial_right = _button("藍のふち\nJ / B / 右タップ", Rect2(680, 350, 420, 150), func() -> void: pass)
	tutorial_left.add_theme_color_override("font_color", CORAL)
	tutorial_right.add_theme_color_override("font_color", MINT)
	tutorial_left.button_down.connect(func() -> void: _tutorial_press(0))
	tutorial_left.button_up.connect(func() -> void: _tutorial_release(0))
	tutorial_right.button_down.connect(func() -> void: _tutorial_press(1))
	tutorial_right.button_up.connect(func() -> void: _tutorial_release(1))
	_button("稽古をスキップして本番へ", Rect2(812, 565, 290, 50), _finish_tutorial)
	_play_music(str(state.songs[state.selected_song].id))
	_render_tutorial_step()


func _render_tutorial_step() -> void:
	match tutorial_step:
		0:
			tutorial_message.text = "一、流れてきた朱の音を、面でたたく"
			tutorial_hint.text = "朱の太鼓を一度たたいてください。"
			tutorial_left.grab_focus()
		1:
			tutorial_message.text = "二、藍の音は、太鼓のふちで返す"
			tutorial_hint.text = "次は藍の太鼓を一度たたいてください。"
			tutorial_right.grab_focus()
		2:
			tutorial_message.text = "三、尾の長い音は、終わりまで押さえる"
			tutorial_hint.text = "朱の太鼓を少し長く押してから放してください。"
			tutorial_left.grab_focus()
		3:
			tutorial_message.text = "稽古完了！　三つの打ち方を覚えました"
			tutorial_hint.text = "提灯が灯ったら本番です。"
			tutorial_left.disabled = true
			tutorial_right.disabled = true
			var start: Button = _button("Enter / A　本番の演奏へ", Rect2(314, 520, 520, 74), _finish_tutorial)
			start.grab_focus()


func _tutorial_press(lane: int) -> void:
	if not tutorial_active:
		return
	if tutorial_step == 0 and lane == 0:
		tutorial_step = 1
		_play_sfx("hit-coral")
		_render_tutorial_step()
	elif tutorial_step == 1 and lane == 1:
		tutorial_step = 2
		_play_sfx("hit-mint")
		_render_tutorial_step()
	elif tutorial_step == 2 and lane == 0:
		tutorial_hold_started = Time.get_ticks_msec()
		tutorial_hint.text = "そのまま……尾が切れるところで放す！"
	else:
		tutorial_hint.text = "今、光っている太鼓をたたいてください。"


func _tutorial_release(lane: int) -> void:
	if tutorial_step != 2 or lane != 0 or tutorial_hold_started == 0:
		return
	if Time.get_ticks_msec() - tutorial_hold_started >= 350:
		tutorial_step = 3
		_play_sfx("hold")
		_render_tutorial_step()
	else:
		tutorial_hint.text = "もう少し長く。尾の終わりまで押し続けます。"
	tutorial_hold_started = 0


func _finish_tutorial() -> void:
	if not tutorial_active:
		return
	tutorial_seen = true
	tutorial_active = false
	state.start_song()


func _play() -> void:
	fever = false
	last_combo = 0
	shown_score = 0
	_panel(Rect2(38, 22, 1204, 142), Color(INDIGO, 0.94))
	_label(str(state.songs[state.selected_song].title), Rect2(64, 38, 500, 48), 31)
	_label(_difficulty_name() + "　祭り本番", Rect2(67, 91, 330, 28), 18, SUN)
	_button("Esc　中断", Rect2(1050, 44, 164, 50), state.abort_song)
	_label("奉納点", Rect2(548, 37, 150, 26), 16, SUN)
	score_label = _label("0000000", Rect2(545, 66, 230, 50), 34)
	accuracy_label = _label("精度 100.0%", Rect2(792, 74, 242, 38), 21)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(64, 131)
	progress_bar.size = Vector2(1152, 8)
	progress_bar.show_percentage = false
	page.add_child(progress_bar)
	time_label = _label("", Rect2(914, 171, 292, 30), 17, CREAM)
	_label("ここで打つ", Rect2(235, 170, 220, 30), 18, SUN)
	gauge_bar = FestivalMeter.new()
	gauge_bar.position = Vector2(48, 500)
	gauge_bar.size = Vector2(188, 188)
	gauge_bar.theme = theme
	page.add_child(gauge_bar)
	_label("太鼓の張り", Rect2(230, 514, 220, 32), 20, SUN)
	_label("60% で花火が上がる", Rect2(230, 550, 300, 30), 17, CREAM)
	combo_label = _label("0 連", Rect2(250, 594, 185, 52), 30)
	_label("コンボ提灯", Rect2(250, 642, 185, 28), 17, SUN)
	for index: int in range(6):
		var lantern: Sprite2D = _paper_texture(
			"res://assets/generated/combo-lantern.png", Rect2(430 + index * 55, 574, 48, 58)
		)
		lantern.modulate = Color(0.4, 0.4, 0.45, 0.24)
		combo_lanterns.append(lantern)


func start_song() -> void:
	if state.screen == "select" and not tutorial_seen:
		_tutorial()
		return
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
		combo_label.text = "%d 連" % state.combo
		accuracy_label.text = "精度 %.1f%%" % (state.accuracy * 100)
		gauge_bar.set("value", state.gauge)
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
			for index: int in range(combo_lanterns.size()):
				combo_lanterns[index].modulate = (
					Color.WHITE if index < mini(state.combo, combo_lanterns.size())
					else Color(0.4, 0.4, 0.45, 0.24)
				)
		if state.gauge >= 0.999 and not fever:
			fever = true
			stage.celebrate()
			_play_sfx("fever")
		elif state.gauge < 0.95:
			fever = false
	elif previewing and Time.get_ticks_msec() / 1000.0 - preview_started >= 12:
		_toggle_preview()


func _result() -> void:
	_panel(Rect2(42, 28, 1196, 126), Color(CORAL if state.cleared else INDIGO, 0.96))
	_label("大花火！" if state.cleared else "祭りは、まだ終わらない。", Rect2(72, 48, 810, 62), 45)
	_label(
		str(state.songs[state.selected_song].title) + "  /  " + _difficulty_name(),
		Rect2(74, 112, 760, 34),
		20,
		SUN
	)
	_panel(Rect2(58, 184, 704, 364), Color(CREAM, 0.97))
	_label("今回の奉納点", Rect2(94, 211, 380, 40), 21, CORAL)
	result_score = _label("0", Rect2(90, 254, 610, 76), 55, INK)
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
		Rect2(94, 350, 620, 40),
		23,
		INK
	)
	_label(
		(
			"パーフェクト %d     グッド %d     ミス %d"
			% [state.counts.Perfect, state.counts.Good, state.counts.Miss]
		),
		Rect2(94, 411, 620, 40),
		20,
		INK
	)
	_label("太鼓の張り %.0f%%  /  花火 60%%" % (state.gauge * 100), Rect2(94, 474, 610, 36), 20, CORAL)
	_paper_texture("res://assets/generated/combo-lantern.png", Rect2(832, 174, 238, 286))
	_label("ランク", Rect2(893, 232, 180, 34), 22, INK)
	_label(str(state.rank), Rect2(879, 273, 190, 132), 94, INK)
	var retry: Button = _button("もう一度、太鼓をたたく", Rect2(58, 584, 392, 70), start_song)
	retry.grab_focus()
	_button("縁日の屋台へ戻る", Rect2(470, 584, 360, 70), state.show_select)
	_label("提灯の記録は曲・難易度ごとに残ります。", Rect2(62, 674, 760, 28), 17, SUN)
	if not state.error_message.is_empty():
		_label(state.error_message, Rect2(780, 641, 450, 40), 18, CORAL)


func _input(event: InputEvent) -> void:
	if closing:
		return
	if event.is_action_pressed("fullscreen"):
		_toggle_fullscreen()
		return
	if tutorial_active:
		_tutorial_input(event)
		return
	if state.screen == "select" and _select_input(event):
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_screen()
		return
	if state.screen == "play":
		_play_input(event)


func _toggle_fullscreen() -> void:
	var current: int = DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(
		(
			DisplayServer.WINDOW_MODE_WINDOWED
			if current == DisplayServer.WINDOW_MODE_FULLSCREEN
			else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	)
	get_viewport().set_input_as_handled()


func _tutorial_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_finish_tutorial()
		get_viewport().set_input_as_handled()
		return
	for lane: int in range(2):
		var tutorial_action: String = "hit_coral" if lane == 0 else "hit_mint"
		if event.is_action(tutorial_action):
			if event.is_pressed():
				_tutorial_press(lane)
			else:
				_tutorial_release(lane)
			get_viewport().set_input_as_handled()
			return


func _select_input(event: InputEvent) -> bool:
	var direction: int = 0
	if event.is_action_pressed("ui_left"):
		direction = -1
	elif event.is_action_pressed("ui_right"):
		direction = 1
	if direction == 0:
		return false
	state.select_song(posmod(state.selected_song + direction, state.songs.size()))
	_refresh_select()
	get_viewport().set_input_as_handled()
	return true


func _cancel_screen() -> void:
	if settings_panel != null:
		_refresh_select()
	elif state.screen == "play":
		state.abort_song()
	elif state.screen == "select":
		state.show_title()
	elif state.screen == "result":
		state.show_select()
	get_viewport().set_input_as_handled()


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


func _play_ambience() -> void:
	if ambience.playing:
		return
	if not force_audio and AudioServer.get_driver_name() == "Dummy" and not OS.has_feature("movie"):
		return
	ambience.stream = load("res://assets/audio/festival-ambience.ogg")
	if ambience.stream is AudioStreamOggVorbis:
		ambience.stream.loop = true
	ambience.play()


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
	if ambience != null:
		ambience.stop()
		ambience.stream = null
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
