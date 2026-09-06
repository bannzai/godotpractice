class_name DeliveryGame
extends Control
## 入力・音・画面遷移はイベントの消費として実行するため非冪等。

const INK: Color = Color("153e4a")
const CREAM: Color = Color("fff8e8")
var route: DeliveryRoute
var session: Node
var ui: Control
var panel: Control
var hud: DeliveryHUD
var status_label: Label
var bgm: AudioStreamPlayer
var last_phase: String = ""
var sky_time: float = 0.0
var font: Font
var backdrop: RouteBackdrop
var flash: ColorRect
var shutdown_started: bool = false
var frame_count: int = 0


func _ready() -> void:
	print("platformer boot")
	get_tree().auto_accept_quit = false
	session = get_node("/root/Session")
	var game_theme: Theme = load("res://resources/delivery_theme.tres")
	font = game_theme.default_font
	theme = game_theme
	var background_layer: CanvasLayer = CanvasLayer.new()
	background_layer.layer = -1
	add_child(background_layer)
	backdrop = RouteBackdrop.new()
	background_layer.add_child(backdrop)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = game_theme
	layer.add_child(ui)
	bgm = AudioStreamPlayer.new()
	bgm.volume_db = -12
	bgm.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(bgm)
	var effects_layer: CanvasLayer = CanvasLayer.new()
	effects_layer.layer = 10
	add_child(effects_layer)
	flash = ColorRect.new()
	flash.size = Vector2(1280, 720)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 0.96, 0.81, 0)
	effects_layer.add_child(flash)
	_show_title()


func _process(delta: float) -> void:
	sky_time += delta
	backdrop.stage = route.stage if is_instance_valid(route) else 0
	backdrop.camera_x = route.camera.position.x - 640 if is_instance_valid(route) else sky_time * 9
	backdrop.queue_redraw()
	frame_count += 1
	if "--verify-close" in OS.get_cmdline_user_args() and frame_count == 90:
		_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	if session.phase != last_phase:
		_phase_changed()


func _physics_process(delta: float) -> void:
	session.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if session.phase == "playing":
			session.phase = "paused"
		elif session.phase == "paused":
			_resume()
	elif event.is_action_pressed("confirm") and session.phase == "playing":
		get_viewport().set_input_as_handled()




func _clear_ui() -> void:
	for child: Node in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	hud = null
	panel = null
	status_label = null


func _remove_route() -> void:
	if is_instance_valid(route):
		remove_child(route)
		route.queue_free()
	route = null


func _show_title() -> void:
	_remove_route()
	session.title()
	last_phase = "title"
	_clear_ui()
	_music("title")
	var paper: Panel = _card(ui, Rect2(42, 64, 624, 526), Color("fff8e8"))
	_label(paper, "風の郵便局  ・  小さな配達の物語", Rect2(34, 26, 550, 30), 18)
	_picture(paper, "title_logo", Rect2(365, 65, 220, 66))
	_label(paper, "そらいろ便", Rect2(29, 99, 560, 120), 80)
	_label(paper, "風をたどって、ひかりを届けよう。", Rect2(35, 232, 560, 38), 24)
	_label(paper, "草原を越え、青い洞窟の向こうへ。\n今日もポストが、あなたを待っています。",
		Rect2(35, 296, 555, 82), 21)
	var start: Button = _button(paper, "配達に出発する   →", Rect2(35, 407, 550, 68), start_run)
	start.grab_focus()
	var art: TextureRect = _picture(ui, "title_keyart", Rect2(680, 53, 575, 537))
	var drift: Tween = art.create_tween().set_loops()
	drift.tween_property(art, "position:y", 42.0, 2.4).set_trans(Tween.TRANS_SINE)
	drift.tween_property(art, "position:y", 53.0, 2.4).set_trans(Tween.TRANS_SINE)
	_card(ui, Rect2(42, 618, 1196, 76), Color("fff8e8"))
	_label(ui, "← → / A D  移動     Space / Z  ジャンプ     Shift / X  ダッシュ",
		Rect2(64, 629, 1160, 28), 18)
	_label(ui, "パッド  左スティック・A・X    Esc / Start  休憩    F11  全画面    長押しで高く跳ぼう",
		Rect2(64, 659, 1160, 26), 16)
	_fade_in()


func start_run() -> void:
	session.reset_run()
	_load_stage()


func _load_stage() -> void:
	_remove_route()
	_clear_ui()
	route = DeliveryRoute.new()
	route.stage = session.stage
	route.sound_requested.connect(play_sound)
	route.feedback_requested.connect(_feedback)
	add_child(route)
	last_phase = "playing"
	_build_hud()
	_music("stage%d" % (session.stage + 1))
	_fade_in()


func _build_hud() -> void:
	hud = DeliveryHUD.new()
	hud.route = route
	ui.add_child(hud)
	var help: Panel = _card(ui, Rect2(28, 670, 880, 32), Color("153e4a"))
	_label(help, "← →  移動     Space  ジャンプ     Shift  ダッシュ     Esc  休憩",
		Rect2(14, 1, 850, 28), 15, CREAM)


func _phase_changed() -> void:
	last_phase = session.phase
	if session.phase == "playing" or session.phase == "title":
		return
	if session.phase in ["dead", "game_over"]:
		play_sound("death")
		_music("game_over")
		if is_instance_valid(route):
			route.player.die()
			route.impact("death", route.player.position + Vector2(0, -28), "-1")
	elif session.phase in ["stage_clear", "complete"]:
		play_sound("clear")
		_music("result")
	_show_overlay()


func _show_overlay() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	panel = Control.new()
	ui.add_child(panel)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.04, 0.13, 0.18, 0.6)
	veil.size = Vector2(1280, 720)
	panel.add_child(veil)
	var card: Panel = _card(panel, Rect2(330, 173, 620, 410), CREAM)
	card.position.y += 24
	card.modulate.a = 0
	var entrance: Tween = card.create_tween().set_parallel()
	entrance.tween_property(card, "position:y", 173.0, 0.34).set_trans(
		Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrance.tween_property(card, "modulate:a", 1.0, 0.22)
	var title_text: String = "ひとやすみ"
	var detail: String = "準備ができたら、続きを走ろう。"
	var action: String = "配達を続ける"
	match session.phase:
		"dead":
			title_text = "もう一度、飛び出そう"
			detail = "%s   ・   残機 %d" % [session.death_reason, session.lives]
			action = "このステージを再開"
		"game_over":
			title_text = "今日はここまで"
			detail = "%s\nスコア %06d   ・   コイン %d" % [
				session.death_reason, session.score, session.coins]
			action = "はじめから再挑戦"
		"stage_clear":
			title_text = "草原の配達、完了！"
			detail = "次の目的地は、ひかりの洞窟。\n残り時間をスコアに加算しました。"
			action = "洞窟へ進む   →"
		"complete":
			title_text = "ひかりが届いた！"
			detail = "すべての配達を達成\nスコア %06d   ・   コイン %d" % [session.score, session.coins]
			action = "もう一度遊ぶ"
	_picture(card, "ui_life" if session.phase in ["dead", "game_over"] else "ui_score",
		Rect2(280, 17, 60, 60))
	_label(card, title_text, Rect2(30, 78, 560, 60), 32, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_label(card, detail, Rect2(30, 147, 560, 62), 20, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var button: Button = _button(card, action, Rect2(80, 230, 460, 62), _continue)
	button.grab_focus()
	_button(card, "タイトルへ戻る", Rect2(80, 309, 460, 52), _show_title)


func _continue() -> void:
	match session.phase:
		"paused":
			_resume()
		"dead":
			session.begin_stage()
			_load_stage()
		"stage_clear":
			session.advance_stage()
			_load_stage()
		"game_over", "complete":
			start_run()


func _resume() -> void:
	session.phase = "playing"
	last_phase = "playing"
	if is_instance_valid(panel):
		panel.queue_free()
		panel = null


func _music(track_name: String) -> void:
	# headless には音声出力がなく、即時終了時の WAV 再生リソース保持も避ける。
	if DisplayServer.get_name() == "headless" or shutdown_started:
		return
	var track: AudioStreamWAV = load("res://assets/audio/%s.wav" % track_name)
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_end = int(track.get_length() * track.mix_rate)
	if bgm.stream != track or not bgm.playing:
		bgm.stream = track
		bgm.play()


func play_sound(sound: String) -> void:
	if DisplayServer.get_name() == "headless" or shutdown_started:
		return
	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	audio.stream = load("res://assets/audio/%s.wav" % sound)
	audio.volume_db = -8
	audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()


func _card(parent: Node, rect: Rect2, color: Color) -> Panel:
	var result: Panel = Panel.new()
	result.position = rect.position
	result.size = rect.size
	var style: StyleBoxFlat = theme.get_stylebox("panel", "Panel").duplicate()
	style.bg_color = color
	result.add_theme_stylebox_override("panel", style)
	parent.add_child(result)
	return result


func _label(parent: Node, text_value: String, rect: Rect2, font_size: int,
		color: Color = INK, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, rect: Rect2, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 23)
	button.pivot_offset = rect.size / 2
	button.mouse_entered.connect(func() -> void: _button_motion(button, 1.025))
	button.mouse_exited.connect(func() -> void: _button_motion(button, 1.0))
	button.button_down.connect(func() -> void: _button_motion(button, 0.98))
	button.button_up.connect(func() -> void: _button_motion(button, 1.0))
	button.pressed.connect(func() -> void: play_sound("ui"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _picture(parent: Node, file: String, rect: Rect2) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.texture = load("res://assets/images/%s.svg" % file)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.position = rect.position
	picture.size = rect.size
	parent.add_child(picture)
	return picture


func stop_audio() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not shutdown_started:
		shutdown_started = true
		stop_audio()
		await get_tree().create_timer(0.15).timeout
		get_tree().quit()


func _exit_tree() -> void:
	stop_audio()
	# --quit-after はエンジンに消費され、引数から終了フレームを取得できない。
	# SceneTree 終了中は await できないため、音声スレッドの停止反映を短時間待つ。
	if not shutdown_started and DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		OS.delay_msec(150)


func _button_motion(button: Button, amount: float) -> void:
	if button.has_meta("motion"):
		(button.get_meta("motion") as Tween).kill()
	var motion: Tween = button.create_tween()
	motion.tween_property(button, "scale", Vector2.ONE * amount, 0.14)
	button.set_meta("motion", motion)


func _fade_in() -> void:
	var veil: ColorRect = ColorRect.new()
	veil.color = CREAM
	veil.size = Vector2(1280, 720)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(veil)
	var transition: Tween = veil.create_tween()
	transition.tween_property(veil, "modulate:a", 0.0, 0.32)
	transition.tween_callback(veil.queue_free)


func _feedback(kind: String, _at: Vector2) -> void:
	if kind not in ["stomp", "power", "hurt", "death", "clear"]:
		return
	flash.color = Color("ffc6a6") if kind in ["hurt", "death"] else Color("fff6ca")
	flash.modulate.a = 0.18 if kind == "stomp" else 0.30
	if flash.has_meta("motion"):
		(flash.get_meta("motion") as Tween).kill()
	var pulse: Tween = flash.create_tween()
	pulse.tween_property(flash, "modulate:a", 0.0, 0.25)
	flash.set_meta("motion", pulse)
