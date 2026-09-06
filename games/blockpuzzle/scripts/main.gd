extends Control
## 温室の画面と入力。進行状態は Session が所有する。

const BoardView = preload("res://scripts/board_view.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const Piece = preload("res://scripts/piece_sprite.gd")
const SKY = preload("res://assets/art/sky.svg")
const HOUSE = preload("res://assets/art/greenhouse.svg")
const LEAVES = preload("res://assets/art/foliage.svg")
const KEYART = preload("res://assets/art/keyart.svg")
const LOGO = preload("res://assets/art/logo.svg")
const FONT = preload("res://assets/fonts/NotoSansJP.ttf")

var state: Node
var content: Control
var sound: Node
var boards: Array = []
var background: Array[TextureRect] = []
var clock: float = 0.0
var score_display: float = 0.0
var closing: bool = false
var hud: Dictionary = {}


func _ready() -> void:
	print("blockpuzzle boot")
	state = get_node("/root/Session")
	_setup_theme()
	_setup_input()
	for texture: Texture2D in [SKY, HOUSE, LEAVES]:
		var layer: TextureRect = _image(self, texture, Rect2(-16, -8, 1312, 736))
		background.append(layer)
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://scripts/night_glow.gdshader")
	background[0].material = glow
	sound = Soundscape.new()
	add_child(sound)
	state.screen_changed.connect(_render)
	state.board_changed.connect(_board_changed)
	state.effect.connect(_effect)
	get_tree().auto_accept_quit = false
	_render()


func _setup_theme() -> void:
	theme = Theme.new()
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 550}
	theme.default_font = font
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", Color("e4f4ed"))
	theme.set_color("font_color", "Button", Color("edf6ed"))
	for kind: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var color: Color = Color("26474e")
		if kind in ["hover", "focus"]:
			color = Color("38625f")
		if kind == "pressed":
			color = Color("507972")
		var style: StyleBoxFlat = _style(color, Color("88bdb1"), 13)
		theme.set_stylebox(kind, "Button", style)


func _setup_input() -> void:
	_bind("piece_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT])
	_bind("piece_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT])
	_bind("rotate_right", [KEY_UP, KEY_X], [JOY_BUTTON_A])
	_bind("rotate_left", [KEY_Z], [JOY_BUTTON_X])
	_bind("soft_drop", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_bind("hard_drop", [KEY_SPACE], [JOY_BUTTON_Y])
	_bind("pause_game", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_bind("fullscreen", [KEY_F11], [JOY_BUTTON_BACK])
	_bind("ui_accept", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	for entry: Array in [
		["piece_left", JOY_AXIS_LEFT_X, -1.0],
		["piece_right", JOY_AXIS_LEFT_X, 1.0],
		["soft_drop", JOY_AXIS_LEFT_Y, 1.0]
	]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = entry[1]
		axis.axis_value = entry[2]
		InputMap.action_add_event(entry[0], axis)


func _bind(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)
	InputMap.action_erase_events(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button: int in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)


# 実入力を一度だけ進行へ渡すため非冪等。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		get_viewport().set_input_as_handled()
		return
	if state.screen != "play":
		return
	if event.is_action_pressed("pause_game"):
		state.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if state.paused:
		return
	if event.is_action_pressed("rotate_right"):
		state.rotate_piece(1)
	elif event.is_action_pressed("rotate_left"):
		state.rotate_piece(-1)
	elif event.is_action_pressed("hard_drop"):
		state.hard_drop()
	else:
		return
	get_viewport().set_input_as_handled()


func _render() -> void:
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	boards.clear()
	hud.clear()
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	match state.screen:
		"title":
			_title()
		"play":
			_play()
		_:
			_result()
	content.modulate.a = 0.0
	create_tween().tween_property(content, "modulate:a", 1.0, 0.28)


func _title() -> void:
	sound.set_scene("title")
	_image(content, KEYART, Rect2(570, 20, 690, 690))
	_panel(Rect2(68, 64, 548, 596), Color(0.06, 0.13, 0.20, 0.94))
	_label("夜の温室へ、ようこそ", Rect2(109, 98, 450, 30), 19, Color("abd1c6"))
	_image(content, LOGO, Rect2(95, 141, 476, 119))
	_label("つないだ星が、次の星を呼ぶ。", Rect2(110, 285, 440, 36), 24)
	_label("同じ精霊を4つつなげて、連鎖を育てよう。", Rect2(110, 332, 450, 30), 18)
	_button("cpu", "CPUと対戦   ›", Rect2(110, 394, 440, 60), func() -> void: state.start_game("cpu"))
	_button(
		"solo", "ひとりで   ·   90秒", Rect2(110, 469, 440, 60), func() -> void: state.start_game("solo")
	)
	_button(
		"difficulty",
		"CPUの強さ：" + ["やさしい", "ふつう", "つよい"][state.difficulty],
		Rect2(110, 551, 272, 44),
		_cycle_difficulty
	)
	_button("help", "遊び方", Rect2(400, 551, 150, 44), _help)
	_label(
		"最高 %06d 点    ·    最高 %d 連鎖" % [state.records.high_score, state.records.best_chain],
		Rect2(110, 614, 460, 26),
		16,
		Color("b3cbbf")
	)
	content.get_node("cpu").grab_focus()


func _cycle_difficulty() -> void:
	state.difficulty = (state.difficulty + 1) % 3
	_render()
	content.get_node("difficulty").grab_focus()


func _help() -> void:
	for child: Node in content.get_children():
		if child is Button:
			child.disabled = true
	_panel(Rect2(225, 86, 830, 550), Color("122c3b"))
	_label("星のつなぎ方", Rect2(277, 120, 700, 50), 32)
	_label(
		(
			"同じ色の精霊が、上下左右に4つ以上つながると消えます。\n"
			+ "空いた場所へ落ちた精霊がつながると、連鎖！\n"
			+ "連鎖が増えるほど得点と相手へのおじゃまが増えます。\n"
			+ "おじゃまは隣の精霊を消すと一緒に消せます。"
		),
		Rect2(277, 188, 735, 140),
		21
	)
	_label(
		(
			"← → / A D：移動　　↑ / X：右回転　　Z：左回転\n"
			+ "↓ / S：速く落とす　　Space：一気に落とす\n"
			+ "パッド：十字/左スティック移動　A/X回転　Y一気に落とす\n"
			+ "Esc / Start：一時停止　　F11 / Back：全画面切替"
		),
		Rect2(277, 350, 735, 142),
		19,
		Color("b9d5c8")
	)
	_button("closehelp", "温室へ戻る", Rect2(451, 539, 380, 58), _render).grab_focus()


func _play() -> void:
	sound.set_scene("play")
	_label("星つむぎ", Rect2(56, 20, 240, 50), 34)
	_label("同じ精霊を4つ。空いた隙間に、次の連鎖。", Rect2(284, 33, 590, 34), 18)
	_button("pause", "一時停止", Rect2(1082, 26, 142, 42), state.toggle_pause)
	if state.mode == "cpu":
		_add_board(0, Vector2(100, 145))
		_add_board(1, Vector2(840, 145))
		_label("あなた", Rect2(100, 90, 240, 34), 25)
		_label("CPU · " + ["やさしい", "ふつう", "つよい"][state.difficulty], Rect2(840, 90, 330, 34), 25)
		_center_hud()
	else:
		_add_board(0, Vector2(220, 145))
		_label("あなたの温室", Rect2(220, 90, 320, 34), 25)
		_panel(Rect2(705, 129, 424, 496), Color(0.05, 0.12, 0.18, 0.95))
		_label("ひとりで   ·   スコアアタック", Rect2(745, 159, 345, 35), 22)
		hud.time = _label("", Rect2(745, 204, 345, 62), 44, Color("f7d89e"))
		_label("スコア", Rect2(745, 295, 345, 30), 18)
		hud.score = _label("", Rect2(745, 331, 345, 70), 46)
		hud.chain = _label("", Rect2(745, 432, 345, 36), 24, Color("a5e4cb"))
		_label("90秒で、どこまでつなげる？\n淡い精霊は着地する場所の目印。\n置く直前でも移動・回転できます。", Rect2(745, 507, 345, 93), 17)
	_label(
		"← → 移動    ↑ / X 右回転    Z 左回転    ↓ 速く落とす    Space 一気に落とす",
		Rect2(100, 661, 1110, 30),
		18,
		Color("c3d8c8")
	)
	for child: Node in content.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
	if state.paused:
		_pause_overlay()


func _add_board(side: int, point: Vector2) -> void:
	var view: Node2D = BoardView.new()
	content.add_child(view)
	view.position = point
	view.setup(state, side)
	boards.append(view)
	_label("つぎ", Rect2(point + Vector2(269, 0), Vector2(80, 30)), 16)
	_label("そのつぎ", Rect2(point + Vector2(269, 80), Vector2(90, 30)), 15)
	hud["pending%d" % side] = _label(
		"", Rect2(point + Vector2(0, 488), Vector2(325, 28)), 16, Color("ffc7a5")
	)


func _center_hud() -> void:
	_panel(Rect2(490, 136, 282, 489), Color(0.05, 0.12, 0.18, 0.95))
	_label("2本先取", Rect2(524, 164, 225, 34), 21, Color("c8d6c2"))
	_label(
		"%d   :   %d" % [state.wins[0], state.wins[1]],
		Rect2(520, 209, 236, 70),
		48,
		Color("f7d89e")
	)
	_label("あなたのスコア", Rect2(520, 319, 226, 30), 17)
	hud.score = _label("", Rect2(520, 358, 230, 57), 36)
	hud.chain = _label("", Rect2(520, 449, 235, 35), 21, Color("a5e4cb"))
	hud.time = _label("", Rect2(520, 505, 236, 30), 18)
	_label("連鎖でおじゃまを送ろう\n予告は次の組が出る前に落下", Rect2(520, 551, 232, 54), 14)


func _pause_overlay() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.065, 0.82)
	shade.size = Vector2(1280, 720)
	content.add_child(shade)
	_panel(Rect2(405, 185, 470, 355), Color("142e3b"))
	_label("ひと休み", Rect2(476, 222, 340, 50), 38)
	_button("resume", "つづける", Rect2(465, 312, 350, 62), state.toggle_pause).grab_focus()
	_button("title", "タイトルへ", Rect2(465, 396, 350, 56), state.show_title)


func _result() -> void:
	sound.set_scene("result")
	sound.play_sfx("victory" if state.round_winner == 0 or state.mode == "solo" else "defeat")
	_image(content, KEYART, Rect2(690, 96, 555, 555))
	_panel(Rect2(113, 77, 670, 574), Color(0.06, 0.13, 0.20, 0.97))
	var heading: String = "今回の収穫"
	if state.mode == "cpu":
		heading = "あなたの勝ち！" if state.round_winner == 0 else "CPUの勝ち"
		if state.screen == "round":
			heading = "このラウンドは " + ("あなたの勝ち" if state.round_winner == 0 else "CPUの勝ち")
	_label(heading, Rect2(159, 122, 590, 65), 35, Color("f7d89e"))
	_label(state.result_text, Rect2(160, 202, 570, 35), 18)
	_label("スコア", Rect2(160, 271, 530, 35), 19)
	_label("%06d" % state.score, Rect2(160, 310, 530, 67), 52)
	_label(
		"最大 %d 連鎖    ·    対戦 %d : %d" % [state.max_chain, state.wins[0], state.wins[1]],
		Rect2(160, 398, 535, 42),
		24
	)
	_label(state.save_message, Rect2(160, 461, 540, 30), 16, Color("b5d6c7"))
	var action: Callable = state.next_round if state.screen == "round" else _retry
	(
		_button(
			"retry",
			"次のラウンド" if state.screen == "round" else "もう一度",
			Rect2(158, 535, 277, 60),
			action
		)
		. grab_focus()
	)
	_button("title", "タイトルへ", Rect2(455, 535, 277, 60), state.show_title)


func _retry() -> void:
	state.start_game(state.mode)


func _panel(rect: Rect2, color: Color) -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style(color, Color("507770"), 20))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size


func _style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _image(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var view := TextureRect.new()
	view.texture = texture
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	view.position = rect.position
	view.size = rect.size
	return view


func _label(text: String, rect: Rect2, font_size: int, color: Color = Color("e4f4ed")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


func _button(id: String, text: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.pressed.connect(action)
	content.add_child(button)
	button.position = rect.position
	button.size = rect.size
	button.pivot_offset = rect.size * 0.5
	button.mouse_entered.connect(
		func() -> void:
			button.create_tween().tween_property(button, "scale", Vector2.ONE * 1.025, 0.12)
	)
	button.mouse_exited.connect(
		func() -> void: button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.12)
	)
	return button


# 視差と数字の補間はフレーム時間に依存するため非冪等。
func _process(delta: float) -> void:
	clock += delta
	for index: int in background.size():
		background[index].position.x = -16 + sin(clock * 0.10) * index * 5
	if state.screen != "play":
		return
	if score_display > state.score:
		score_display = float(state.score)
	score_display = move_toward(
		score_display, float(state.score), maxf(90.0, state.score - score_display) * delta * 5
	)
	hud.score.text = "%06d" % int(score_display)
	hud.chain.text = "最大 %d 連鎖" % state.max_chain
	hud.time.text = (
		"残り %02d 秒" % ceili(maxf(0.0, state.LIMIT - state.elapsed))
		if state.mode == "solo"
		else "経過 %02d 秒" % int(state.elapsed)
	)
	var danger: bool = state.mode == "solo" and state.elapsed > state.LIMIT - 20.0
	for side: int in boards.size():
		var b: Dictionary = state.boards[side]
		hud["pending%d" % side].text = "おじゃま予告  %d 個" % b.pending if b.pending > 0 else ""
		if b.board[3].any(func(value: int) -> bool: return value != 0):
			danger = true
	if not state.paused:
		sound.set_scene("danger" if danger else "play")


func _board_changed(side: int, pose: String) -> void:
	if side < boards.size():
		boards[side].refresh(pose)


func _effect(side: int, kind: String, cells: Array, chain: int) -> void:
	if side < boards.size():
		boards[side].animate(kind, cells, chain)
	sound.play_sfx(kind, minf(1.0 + chain * 0.15, 2.1))
	if kind != "clear":
		return
	var point: Vector2 = boards[side].origin + Vector2(-12, 193)
	var popup: Label = _label(
		"%d 連鎖！" % chain,
		Rect2(point, Vector2(290, 90)),
		mini(40 + chain * 5, 66),
		Color("ffdf9c") if chain < 3 else Color("a8ffe1")
	)
	popup.add_theme_color_override("font_shadow_color", Color("152e38"))
	popup.add_theme_constant_override("shadow_offset_x", 3)
	popup.add_theme_constant_override("shadow_offset_y", 4)
	popup.pivot_offset = Vector2(130, 45)
	popup.scale = Vector2.ONE * 0.45
	var tween := popup.create_tween()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_interval(0.30)
	tween.tween_property(popup, "modulate:a", 0.0, 0.30)
	tween.tween_callback(popup.queue_free)


func stop_audio() -> void:
	sound.stop_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		closing = true
		await sound.shutdown()
		get_tree().quit()
