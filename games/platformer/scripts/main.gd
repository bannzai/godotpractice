class_name DeliveryGame
extends Control
## 入力・音・画面遷移はイベントの消費として実行するため非冪等。

const CLOUD: Texture2D = preload("res://assets/images/cloud.svg")
const CRYSTAL: Texture2D = preload("res://assets/images/crystal.svg")
const INK: Color = Color("153e4a")
const CREAM: Color = Color("fff8e8")
var route: DeliveryRoute
var session: Node
var ui: Control
var panel: Control
var hud: Label
var status_label: Label
var bgm: AudioStreamPlayer
var last_phase: String = ""
var sky_time: float = 0.0
var font: Font


func _ready() -> void:
	print("platformer boot")
	session = get_node("/root/Session")
	var variation: FontVariation = FontVariation.new()
	variation.base_font = load("res://assets/fonts/NotoSansJP[wght].ttf")
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	font = variation
	var game_theme: Theme = Theme.new()
	game_theme.default_font = font
	game_theme.default_font_size = 22
	theme = game_theme
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
	_show_title()


func _process(delta: float) -> void:
	sky_time += delta
	queue_redraw()
	if is_instance_valid(hud):
		hud.text = "スコア  %06d     コイン  %02d     残機  %d     時間  %03d" % [
			session.score, session.coins, session.lives, int(ceil(session.seconds))]
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


func _draw() -> void:
	var cave: bool = is_instance_valid(route) and route.stage == 1
	draw_rect(Rect2(0, 0, 1280, 720), Color("142f4f") if cave else Color("bce5df"))
	var offset: float = route.camera.position.x - 640 if is_instance_valid(route) else sky_time * 9
	if cave:
		for i: int in 22:
			var x: float = fposmod(i * 139 - offset * 0.18, 1450) - 80
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, 0), Vector2(x + 65, 170 + (i % 4) * 32), Vector2(x + 120, 0)]),
				Color("203b60"))
			draw_texture_rect(CRYSTAL, Rect2(x, 450 + (i % 3) * 25, 80, 120), false,
				Color(0.4, 0.8, 1, 0.55))
	else:
		draw_circle(Vector2(1080, 158), 76, Color("fff4c5"))
		for i: int in 8:
			var x: float = fposmod(i * 340 - offset * 0.15, 1700) - 200
			draw_circle(Vector2(x, 720), 290, Color("8dc6b0"))
			draw_circle(Vector2(x + 180, 750), 260, Color("5eaa95"))
			draw_texture_rect(CLOUD, Rect2(x, 130 + i % 3 * 48, 192, 80), false)


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
	_music(0)
	_label(ui, "風をたどって、ひかりを届けよう。", Rect2(82, 115, 680, 42), 25)
	_label(ui, "そらいろ便", Rect2(75, 156, 740, 130), 88)
	_label(ui, "草原を越え、青い洞窟の向こうへ。\n小さな配達人の、ふたつの冒険。", Rect2(85, 310, 720, 90), 26)
	var start: Button = _button(ui, "配達に出発する   →", Rect2(85, 447, 395, 68), start_run)
	start.grab_focus()
	_label(ui, "移動  ← → / A D     ジャンプ  Space / Z     ダッシュ  Shift / X",
		Rect2(85, 561, 1050, 36), 20)
	_label(ui, "パッド  左スティック / 十字キー・A・X     Esc / Start  一時停止     F11  全画面",
		Rect2(85, 602, 1120, 36), 18)
	_label(ui, "長く押すと高くジャンプ。敵は上から踏もう。", Rect2(85, 651, 950, 30), 18)
	_picture(ui, "player", Rect2(903, 272, 128, 192))
	_picture(ui, "ground", Rect2(795, 469, 340, 90))
	_picture(ui, "coin", Rect2(824, 343, 40, 40))
	_picture(ui, "coin", Rect2(1110, 272, 40, 40))
	_picture(ui, "power", Rect2(1090, 413, 52, 52))


func start_run() -> void:
	session.reset_run()
	_load_stage()


func _load_stage() -> void:
	_remove_route()
	_clear_ui()
	route = DeliveryRoute.new()
	route.stage = session.stage
	route.sound_requested.connect(play_sound)
	add_child(route)
	last_phase = "playing"
	_build_hud()
	_music(session.stage)


func _build_hud() -> void:
	var bar: Panel = _card(ui, Rect2(28, 22, 1224, 90), Color("fff8e8"))
	_label(bar, "%02d / 02    %s" % [session.stage + 1, DeliveryRoute.NAMES[session.stage]],
		Rect2(24, 12, 340, 30), 22)
	hud = _label(bar, "", Rect2(380, 23, 810, 42), 24)
	_label(bar, "ひかりを右端のポストへ届けよう", Rect2(24, 48, 400, 25), 15)
	status_label = _label(ui, "← →  移動    Space  ジャンプ    Shift  ダッシュ    Esc  休憩",
		Rect2(32, 673, 1080, 28), 17, CREAM)


func _phase_changed() -> void:
	last_phase = session.phase
	if session.phase == "playing" or session.phase == "title":
		return
	if session.phase in ["dead", "game_over"]:
		play_sound("death")
		bgm.stop()
		if is_instance_valid(route):
			var tween: Tween = route.player.create_tween()
			tween.tween_property(route.player.sprite, "rotation", PI, 0.35)
	elif session.phase in ["stage_clear", "complete"]:
		play_sound("clear")
		bgm.stop()
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
	var card: Panel = _card(panel, Rect2(330, 173, 620, 390), CREAM)
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
	_label(card, title_text, Rect2(30, 30, 560, 60), 36, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_label(card, detail, Rect2(30, 110, 560, 80), 21, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var button: Button = _button(card, action, Rect2(80, 215, 460, 62), _continue)
	button.grab_focus()
	_button(card, "タイトルへ戻る", Rect2(80, 292, 460, 52), _show_title)


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


func _music(stage_index: int) -> void:
	# headless には音声出力がなく、即時終了時の WAV 再生リソース保持も避ける。
	if DisplayServer.get_name() == "headless":
		return
	var track: AudioStreamWAV = load("res://assets/audio/stage%d.wav" % (stage_index + 1))
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_end = int(track.get_length() * track.mix_rate)
	if bgm.stream != track or not bgm.playing:
		bgm.stream = track
		bgm.play()


func play_sound(sound: String) -> void:
	if DisplayServer.get_name() == "headless":
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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.05, 0.2, 0.2, 0.15)
	style.shadow_size = 8
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
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_focus_color", CREAM)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("236c70") if state == "normal" else Color("174d59")
		style.set_corner_radius_all(12)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(3)
			style.border_color = Color("e2b85d")
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _picture(parent: Node, file: String, rect: Rect2) -> void:
	var picture: TextureRect = TextureRect.new()
	picture.texture = load("res://assets/images/%s.svg" % file)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.position = rect.position
	picture.size = rect.size
	parent.add_child(picture)


func _exit_tree() -> void:
	if is_instance_valid(bgm):
		bgm.stop()
		bgm.stream = null
