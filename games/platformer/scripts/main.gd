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
var ambience: AudioStreamPlayer
var last_phase: String = ""
var sky_time: float = 0.0
var font: Font
var backdrop: RouteBackdrop
var flash: ColorRect
var shutdown_started: bool = false
var frame_count: int = 0
var tutorial_panel: Control
var map_preview_title: Label
var map_preview_detail: Label


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
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -24
	ambience.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(ambience)
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
	elif session.phase == "playing" and _tutorial_is_active():
		_handle_tutorial_input(event)
	elif event.is_action_pressed("confirm") and session.phase == "playing":
		get_viewport().set_input_as_handled()




func _clear_ui() -> void:
	for child: Node in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	hud = null
	panel = null
	status_label = null
	tutorial_panel = null
	map_preview_title = null
	map_preview_detail = null


func _remove_route() -> void:
	if is_instance_valid(route):
		remove_child(route)
		route.queue_free()
	route = null


func _show_title() -> void:
	_remove_route()
	_set_ambience("")
	session.title()
	last_phase = "title"
	_clear_ui()
	_music("title")
	_generated_picture(ui, "title_background", Rect2(0, 0, 1280, 720))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.01, 0.08, 0.14, 0.32)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	var paper: Panel = _comic_card(ui, Rect2(54, 76, 526, 550), Color("fff0bd"))
	var burst: Label = _label(paper, "新しい配達だ！", Rect2(28, 27, 468, 45), 25,
		Color("e7412b"), HORIZONTAL_ALIGNMENT_CENTER)
	burst.add_theme_color_override("font_outline_color", Color("182a39"))
	burst.add_theme_constant_override("outline_size", 7)
	_label(paper, "そらいろ便", Rect2(24, 82, 478, 112), 74, Color("102f47"),
		HORIZONTAL_ALIGNMENT_CENTER)
	_label(paper, "風を追い越し、\nひかりの手紙を届けよう！", Rect2(38, 210, 450, 104), 30,
		INK, HORIZONTAL_ALIGNMENT_CENTER)
	var speech: Panel = _speech_bubble(paper, Rect2(38, 328, 450, 88))
	_label(speech, "まずは地図で行き先を選ぼう。", Rect2(20, 18, 410, 52), 21,
		INK, HORIZONTAL_ALIGNMENT_CENTER)
	var start: Button = _button(paper, "ルート地図をひらく  →", Rect2(38, 446, 450, 68),
		_start_new_run_map)
	start.grab_focus()
	_fade_in()


func _start_new_run_map() -> void:
	session.reset_run_to_map()
	_show_world_map()


func _show_world_map() -> void:
	_remove_route()
	_set_ambience("")
	session.show_map()
	last_phase = "map"
	_clear_ui()
	_music("title")
	_generated_picture(ui, "world_map", Rect2(0, 0, 1280, 720))
	var heading: Label = _label(ui, "配達ルートを選べ！", Rect2(34, 22, 520, 65), 38,
		Color("fff2bd"))
	heading.add_theme_color_override("font_outline_color", Color("12344a"))
	heading.add_theme_constant_override("outline_size", 10)
	var meadow: Button = _map_button(
		ui,
		"旗 1\n風の草原\nENTER / A で出発",
		Rect2(444, 247, 202, 137),
		func() -> void: _select_map_stage(0)
	)
	meadow.focus_entered.connect(func() -> void: _update_map_preview(0))
	meadow.mouse_entered.connect(func() -> void: _update_map_preview(0))
	var cave_unlocked: bool = session.unlocked_stage >= 1
	var cave: Button = _map_button(
		ui,
		"旗 2\nひかりの洞窟\nENTER / A で出発" if cave_unlocked else "旗 2\nひかりの洞窟\nLOCKED",
		Rect2(825, 31, 202, 137),
		func() -> void: _select_map_stage(1)
	)
	cave.disabled = not cave_unlocked
	if cave_unlocked:
		cave.focus_entered.connect(func() -> void: _update_map_preview(1))
		cave.mouse_entered.connect(func() -> void: _update_map_preview(1))
	else:
		var lock: Panel = _speech_bubble(ui, Rect2(991, 177, 260, 88))
		_label(lock, "風の草原へ配達すると\nこの旗がひらきます。", Rect2(14, 11, 232, 66), 17,
			INK, HORIZONTAL_ALIGNMENT_CENTER)
	var preview: Panel = _comic_card(ui, Rect2(884, 488, 354, 194), Color("fff0bd"))
	_label(preview, "NEXT DELIVERY", Rect2(20, 14, 314, 28), 15, Color("e7412b"))
	map_preview_title = _label(preview, "", Rect2(20, 45, 314, 42), 27)
	map_preview_detail = _label(preview, "", Rect2(20, 91, 314, 80), 17)
	var back: Button = _button(ui, "郵便局へ戻る", Rect2(28, 636, 206, 54), _show_title)
	back.add_theme_font_size_override("font_size", 17)
	var selected_stage: int = mini(session.stage, session.unlocked_stage)
	_update_map_preview(selected_stage)
	(cave if selected_stage == 1 and cave_unlocked else meadow).grab_focus()
	_fade_in()


func _update_map_preview(stage_index: int) -> void:
	if not is_instance_valid(map_preview_title) or not is_instance_valid(map_preview_detail):
		return
	if stage_index == 0:
		map_preview_title.text = "旗 1  風の草原"
		map_preview_detail.text = "風車の島を駆けぬけ、\n右端のポストへ手紙を届ける。"
	else:
		map_preview_title.text = "旗 2  ひかりの洞窟"
		map_preview_detail.text = "結晶の洞窟を越え、\n空のいちばん奥へ光を届ける。"


func _select_map_stage(stage_index: int) -> void:
	if session.select_stage(stage_index):
		_load_stage()


func start_run() -> void:
	# 自動検証と既存呼び出し向けに、地図を経由せず第1ステージを始める互換入口を保つ。
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
	_set_ambience("wind" if session.stage == 0 else "cave_ambience")
	if session.stage == 0 and not session.tutorial_seen:
		_start_tutorial()
	_fade_in()


func _build_hud() -> void:
	hud = DeliveryHUD.new()
	hud.route = route
	ui.add_child(hud)


func _start_tutorial() -> void:
	session.start_tutorial()
	_show_tutorial_step()


func _tutorial_is_active() -> bool:
	return (
		session.phase == "playing"
		and not session.tutorial_seen
		and session.tutorial_step < 3
	)


func _handle_tutorial_input(event: InputEvent) -> void:
	var completed_step: bool = false
	match session.tutorial_step:
		0:
			completed_step = (
				event.is_action_pressed("move_left") or event.is_action_pressed("move_right")
			)
		1:
			completed_step = event.is_action_pressed("jump")
		2:
			completed_step = event.is_action_pressed("dash")
	if completed_step:
		session.advance_tutorial()
		_show_tutorial_step()
		return
	var skip_pressed: bool = (
		InputMap.has_action("tutorial_skip") and event.is_action_pressed("tutorial_skip")
	)
	if skip_pressed or event.is_action_pressed("confirm"):
		_finish_tutorial()
		get_viewport().set_input_as_handled()


func _show_tutorial_step() -> void:
	if is_instance_valid(tutorial_panel):
		tutorial_panel.queue_free()
		tutorial_panel = null
	if not _tutorial_is_active():
		return
	var rects: Array[Rect2] = [
		Rect2(62, 442, 410, 154),
		Rect2(250, 335, 410, 154),
		Rect2(493, 435, 410, 154),
	]
	var titles: Array[String] = ["まずは走ってみよう！", "段差はジャンプ！", "風を切ってダッシュ！"]
	var keys: Array[String] = ["← →  /  A D  /  左スティック", "SPACE  /  Z  /  PAD A",
		"SHIFT  /  X  /  PAD X"]
	tutorial_panel = _speech_bubble(ui, rects[session.tutorial_step])
	_label(tutorial_panel, "配達人のひとこと  %d / 3" % (session.tutorial_step + 1),
		Rect2(19, 12, 372, 24), 15, Color("e7412b"))
	_label(tutorial_panel, titles[session.tutorial_step], Rect2(19, 38, 372, 38), 24)
	var key_label: Label = _label(tutorial_panel, keys[session.tutorial_step],
		Rect2(19, 82, 372, 33), 18, Color("fff2bd"), HORIZONTAL_ALIGNMENT_CENTER)
	key_label.add_theme_color_override("font_outline_color", Color("153e4a"))
	key_label.add_theme_constant_override("outline_size", 7)
	var skip_text: String = "TAB / Y で案内をスキップ" if InputMap.has_action(
		"tutorial_skip") else "ENTER / A で案内をスキップ"
	_label(tutorial_panel, skip_text, Rect2(19, 121, 372, 22), 13, Color("526b70"),
		HORIZONTAL_ALIGNMENT_CENTER)


func _finish_tutorial() -> void:
	session.finish_tutorial()
	if is_instance_valid(tutorial_panel):
		tutorial_panel.queue_free()
		tutorial_panel = null


func _phase_changed() -> void:
	last_phase = session.phase
	if session.phase in ["playing", "title", "map"]:
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
			detail = "地図に新しい旗が現れました！\n残り時間をスコアに加算しました。"
			action = "ルート地図をひらく   →"
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
			if session.advance_to_map():
				_show_world_map()
		"game_over", "complete":
			_start_new_run_map()


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


func _set_ambience(track_name: String) -> void:
	if not is_instance_valid(ambience):
		return
	if track_name.is_empty():
		ambience.stop()
		ambience.stream = null
		return
	# headless には音声出力がなく、即時終了時の WAV 再生リソース保持も避ける。
	if DisplayServer.get_name() == "headless" or shutdown_started:
		return
	var track: AudioStreamWAV = load("res://assets/audio/%s.wav" % track_name)
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_end = int(track.get_length() * track.mix_rate)
	if ambience.stream != track or not ambience.playing:
		ambience.stream = track
		ambience.play()


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


func _comic_card(parent: Node, rect: Rect2, color: Color) -> Panel:
	var result: Panel = Panel.new()
	result.position = rect.position
	result.size = rect.size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("142f3e")
	style.set_border_width_all(6)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.04, 0.10, 0.14, 0.34)
	style.shadow_size = 10
	style.shadow_offset = Vector2(8, 9)
	result.add_theme_stylebox_override("panel", style)
	parent.add_child(result)
	return result


func _speech_bubble(parent: Node, rect: Rect2) -> Panel:
	var result: Panel = _comic_card(parent, rect, Color("fff7dc"))
	var tail: Polygon2D = Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(28, rect.size.y - 4),
		Vector2(70, rect.size.y - 4),
		Vector2(42, rect.size.y + 26),
	])
	tail.color = Color("fff7dc")
	result.add_child(tail)
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


func _map_button(parent: Node, text_value: String, rect: Rect2, action: Callable) -> Button:
	var button: Button = _button(parent, text_value, rect, action)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("526b70"))
	button.add_theme_stylebox_override("normal", _map_button_style(Color("fff7dc"), 5))
	button.add_theme_stylebox_override("hover", _map_button_style(Color("fff0a7"), 7))
	button.add_theme_stylebox_override("pressed", _map_button_style(Color("ffd85c"), 7))
	button.add_theme_stylebox_override("focus", _map_button_style(Color("fff0a7"), 9))
	button.add_theme_stylebox_override("disabled", _map_button_style(Color("aaa99f"), 5))
	return button


func _map_button_style(color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("e7412b") if border_width > 5 else Color("14354b")
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(64)
	style.shadow_color = Color(0.03, 0.09, 0.13, 0.38)
	style.shadow_size = 6
	style.shadow_offset = Vector2(5, 6)
	return style


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


func _generated_picture(parent: Node, file: String, rect: Rect2) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.texture = load("res://assets/images/generated/%s.png" % file)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
