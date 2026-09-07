extends Control
## 情報デザインの画面と入力。進行状態は Session が所有する。

const BoardView = preload("res://scripts/board_view.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const Piece = preload("res://scripts/piece_sprite.gd")
const FONT = preload("res://assets/fonts/Murecho[wght].ttf")
const INK := Color("18181d")
const PAPER := Color("f7f4ed")
const PRIMARY := Color("6750a4")
const SECONDARY := Color("00a6a6")
const CORAL := Color("ff5d73")
const YELLOW := Color("ffca3a")
const MUTED := Color("6f6d73")

var state: Node
var content: Control
var sound: Node
var boards: Array = []
var score_display: float = 0.0
var closing: bool = false
var hud: Dictionary = {}
var tutorial_step: int = -1
var score_history: Array[float] = [0.0]
var graph_second: int = -1


func _ready() -> void:
	print("blockpuzzle boot")
	state = get_node("/root/Session")
	_setup_theme()
	_setup_input()
	_build_background()
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
	font.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): 560,
	}
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("aaa7a0"))
	theme.set_stylebox("normal", "Button", _style(Color("ffffff"), Color("d6d1c8"), 14, 1))
	theme.set_stylebox("hover", "Button", _style(Color("f0ebff"), PRIMARY, 14, 3))
	theme.set_stylebox("focus", "Button", _style(Color("f0ebff"), PRIMARY, 14, 4))
	theme.set_stylebox("pressed", "Button", _style(PRIMARY, PRIMARY, 14, 2))
	theme.set_stylebox("disabled", "Button", _style(Color("ece8df"), Color("d4d0c8"), 14, 1))


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
		["soft_drop", JOY_AXIS_LEFT_Y, 1.0],
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


## 実入力を一度だけ進行へ渡すため非冪等。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		get_viewport().set_input_as_handled()
		return
	if state.screen != "play" or tutorial_step >= 0:
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


func _build_background() -> void:
	_rect(self, Rect2(0, 0, 1280, 720), PAPER)
	var square := Node2D.new()
	add_child(square)
	_rect(square, Rect2(1038, -82, 230, 230), Color("e8ddff"))
	square.rotation = -0.10
	_float(square, Vector2(-18, 14), 5.2)
	var circle := Node2D.new()
	add_child(circle)
	_circle(circle, Vector2(1120, 590), 180.0, Color("d5f3ee"))
	_float(circle, Vector2(24, -12), 6.4)
	var marker := Node2D.new()
	add_child(marker)
	_circle(marker, Vector2(89, 624), 72.0, Color("ffe6a3"))
	_rect(marker, Rect2(22, 557, 134, 134), Color(1, 1, 1, 0.42))
	_float(marker, Vector2(12, -20), 4.6)


func _float(node: Node2D, offset: Vector2, duration: float) -> void:
	var origin: Vector2 = node.position
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "position", origin + offset, duration * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position", origin, duration * 0.5).set_trans(Tween.TRANS_SINE)


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
	create_tween().tween_property(content, "modulate:a", 1.0, 0.22)


func _title() -> void:
	sound.set_scene("title")
	_label("CHAIN / LAB", Rect2(68, 42, 290, 30), 18, PRIMARY)
	_label("04", Rect2(1010, 18, 220, 150), 116, Color("ded4f7"))
	_label("連鎖設計室", Rect2(66, 82, 700, 95), 68)
	_label("色を4つ接続し、次の連鎖を設計する。", Rect2(72, 180, 650, 40), 22, MUTED)
	_static_chart(Rect2(760, 69, 230, 107), [8.0, 18.0, 14.0, 39.0, 33.0, 64.0], PRIMARY)
	_label("MODE SELECT", Rect2(70, 279, 280, 30), 16, MUTED)
	_mode_card(
		"cpu", "CPU 対戦", "2本先取", "相手の盤面へ予告ブロックを送る",
		Rect2(70, 322, 404, 176), "cpu", PRIMARY
	)
	_mode_card(
		"solo", "90秒 計測", "スコアアタック", "折れ線をどこまで伸ばせるか測る",
		Rect2(493, 322, 404, 176), "solo", SECONDARY
	)
	_panel(Rect2(925, 238, 292, 338), Color("ffffff"), Color("d8d3cb"), 10)
	_rect(content, Rect2(925, 238, 9, 338), PRIMARY).name = "PreviewAccent"
	_label("選択プレビュー", Rect2(959, 268, 228, 28), 15, MUTED)
	hud.title_preview = _label("", Rect2(959, 316, 225, 160), 20)
	hud.title_note = _label("", Rect2(959, 487, 225, 54), 15, MUTED)
	_button(
		"difficulty",
		"CPUレベル  /  " + ["やさしい", "ふつう", "つよい"][state.difficulty],
		Rect2(70, 526, 282, 54),
		_cycle_difficulty
	)
	_button("help", "仕組みを見る", Rect2(370, 526, 210, 54), _help)
	_label(
		"BEST SCORE  %06d        MAX CHAIN  %02d"
		% [state.records.high_score, state.records.best_chain],
		Rect2(70, 626, 755, 32),
		19,
		INK
	)
	_set_title_preview("cpu")
	content.get_node("cpu").grab_focus()


func _mode_card(
	id: String,
	title: String,
	kicker: String,
	description: String,
	rect: Rect2,
	mode: String,
	accent: Color
) -> void:
	var button: Button = _button(id, "", rect, func() -> void: _start_mode(mode))
	button.focus_entered.connect(_set_title_preview.bind(mode))
	button.mouse_entered.connect(func() -> void: button.grab_focus())
	_rect(content, Rect2(rect.position + Vector2(24, 23), Vector2(60, 10)), accent)
	_label(kicker, Rect2(rect.position + Vector2(24, 46), Vector2(340, 27)), 15, accent)
	_label(title, Rect2(rect.position + Vector2(24, 76), Vector2(340, 44)), 30)
	_label(description, Rect2(rect.position + Vector2(24, 127), Vector2(352, 28)), 15, MUTED)


func _set_title_preview(mode: String) -> void:
	if not hud.has("title_preview"):
		return
	var cpu: bool = mode == "cpu"
	hud.title_preview.text = (
		"盤面が2つ\n連鎖で送る\n先に2勝する"
		if cpu
		else "盤面が1つ\n90秒で得点\n自己記録を更新"
	)
	hud.title_note.text = "選ぶとすぐに開始  →\n初回だけ3手順の案内"
	var accent: ColorRect = content.get_node("PreviewAccent")
	accent.color = PRIMARY if cpu else SECONDARY
	var difficulty: Button = content.get_node("difficulty")
	difficulty.disabled = not cpu
	difficulty.tooltip_text = "CPU対戦を選択中のみ変更できます" if not cpu else "CPUの思考レベル"


func _start_mode(mode: String) -> void:
	sound.play_sfx("select")
	tutorial_step = 0 if not state.records.tutorial_seen else -1
	score_history = [0.0]
	graph_second = -1
	score_display = 0.0
	state.start_game(mode)


func _cycle_difficulty() -> void:
	state.difficulty = (state.difficulty + 1) % 3
	_render()
	content.get_node("difficulty").grab_focus()


func _help() -> void:
	for child: Node in content.get_children():
		if child is Button:
			child.disabled = true
	_rect(content, Rect2(0, 0, 1280, 720), Color(0.08, 0.07, 0.10, 0.66))
	_panel(Rect2(228, 86, 824, 548), Color("ffffff"), PRIMARY, 16)
	_label("4つを接続する", Rect2(284, 130, 650, 54), 38)
	_label(
		"同じ色の図形が上下左右に4つ以上つながると消えます。\n"
		+ "空いた場所へ落ちた図形が再びつながると、連鎖。\n"
		+ "連鎖数が増えるほどスコアと相手への予告が増えます。",
		Rect2(284, 207, 680, 120),
		21
	)
	_rect(content, Rect2(284, 353, 12, 104), CORAL)
	_label(
		"ゲーム開始後は、盤面上の3手順で操作を案内します。\n"
		+ "予告ブロックは隣の色を消すと同時に消せます。",
		Rect2(320, 354, 630, 100),
		19,
		MUTED
	)
	_button("closehelp", "モード選択へ戻る", Rect2(422, 525, 436, 58), _render).grab_focus()


func _play() -> void:
	sound.set_scene("play")
	_label("CHAIN / 04", Rect2(48, 24, 220, 32), 21, PRIMARY)
	_label("4個を接続 → 落下で次の連鎖", Rect2(274, 28, 510, 30), 18, MUTED)
	_button("pause", "一時停止", Rect2(1090, 22, 142, 44), state.toggle_pause)
	if state.mode == "cpu":
		_add_board(0, Vector2(70, 145))
		_add_board(1, Vector2(865, 145))
		_label("YOU / 操作する盤面", Rect2(70, 91, 310, 34), 22)
		_label(
			"CPU / " + ["やさしい", "ふつう", "つよい"][state.difficulty],
			Rect2(865, 91, 310, 34),
			22
		)
		_center_hud()
	else:
		_add_board(0, Vector2(210, 145))
		_label("YOU / 90秒の計測", Rect2(210, 91, 330, 34), 22)
		_solo_hud()
	if tutorial_step >= 0:
		state.paused = true
		_tutorial_overlay()
	elif state.paused:
		_pause_overlay()


func _add_board(side: int, point: Vector2) -> void:
	var view: Node2D = BoardView.new()
	content.add_child(view)
	view.position = point
	view.setup(state, side)
	boards.append(view)
	_label("NEXT", Rect2(point + Vector2(270, 2), Vector2(86, 26)), 14, MUTED)
	_label("AFTER", Rect2(point + Vector2(270, 82), Vector2(86, 26)), 14, MUTED)
	hud["pending%d" % side] = _label(
		"", Rect2(point + Vector2(0, 496), Vector2(342, 28)), 15, CORAL
	)


func _center_hud() -> void:
	_panel(Rect2(463, 137, 354, 500), Color("ffffff"), Color("d8d3cb"), 10)
	_label("MATCH / FIRST TO 2", Rect2(490, 160, 300, 24), 14, MUTED)
	_label(
		"%d  :  %d" % [state.wins[0], state.wins[1]],
		Rect2(490, 186, 300, 58),
		42,
		PRIMARY
	)
	_label("MAX CHAIN", Rect2(490, 262, 170, 24), 14, MUTED)
	hud.chain_number = _label("", Rect2(486, 284, 304, 88), 70)
	_label("SCORE", Rect2(490, 376, 120, 24), 14, MUTED)
	hud.score = _label("", Rect2(490, 400, 285, 45), 34)
	_score_graph(Rect2(490, 458, 296, 74))
	hud.action = _label("", Rect2(490, 550, 296, 54), 16)
	hud.time = _label("", Rect2(490, 610, 296, 22), 14, MUTED)


func _solo_hud() -> void:
	_panel(Rect2(654, 132, 502, 505), Color("ffffff"), Color("d8d3cb"), 10)
	_label("90 SECOND MEASURE", Rect2(691, 160, 420, 25), 14, SECONDARY)
	hud.time = _label("", Rect2(691, 189, 420, 72), 50)
	_label("MAX CHAIN", Rect2(691, 283, 170, 24), 14, MUTED)
	hud.chain_number = _label("", Rect2(686, 306, 194, 90), 72)
	_label("SCORE", Rect2(903, 283, 180, 24), 14, MUTED)
	hud.score = _label("", Rect2(901, 316, 215, 60), 38)
	_score_graph(Rect2(691, 415, 425, 90))
	hud.action = _label("", Rect2(691, 532, 425, 60), 17)
	_label("薄い図形 = 落下位置のプレビュー", Rect2(691, 598, 425, 25), 14, MUTED)


func _score_graph(rect: Rect2) -> void:
	var graph := Node2D.new()
	graph.position = rect.position
	content.add_child(graph)
	_rect(graph, Rect2(Vector2.ZERO, rect.size), Color("f0ede7"))
	for index: int in range(1, 4):
		_rect(
			graph,
			Rect2(0, rect.size.y * float(index) / 4.0, rect.size.x, 1),
			Color("d7d2ca")
		)
	var lines := Node2D.new()
	graph.add_child(lines)
	hud.graph_lines = lines
	hud.graph_size = rect.size
	_render_chart(lines, rect.size, score_history, PRIMARY)


func _static_chart(rect: Rect2, values: Array[float], color: Color) -> void:
	var graph := Node2D.new()
	graph.position = rect.position
	content.add_child(graph)
	_render_chart(graph, rect.size, values, color)


func _render_chart(lines: Node2D, size: Vector2, values: Array[float], color: Color) -> void:
	for child: Node in lines.get_children():
		child.queue_free()
	var points: Array[Vector2] = []
	var peak: float = 100.0
	for value: float in values:
		peak = maxf(peak, value)
	var count: int = maxi(values.size(), 2)
	for index: int in count:
		var value: float = values[mini(index, values.size() - 1)]
		points.append(
			Vector2(
				size.x * float(index) / float(count - 1),
				size.y - 4.0 - value / peak * (size.y - 8.0)
			)
		)
	for index: int in range(points.size() - 1):
		_line(lines, points[index], points[index + 1], 4.0, color)
	for point: Vector2 in points:
		_circle(lines, point, 4.5, color)


func _line(parent: Node, start: Vector2, end: Vector2, width: float, color: Color) -> void:
	var direction: Vector2 = end - start
	var normal: Vector2 = direction.normalized().orthogonal() * width * 0.5
	var segment := Polygon2D.new()
	segment.polygon = PackedVector2Array([
		start + normal, end + normal, end - normal, start - normal,
	])
	segment.color = color
	parent.add_child(segment)


func _tutorial_overlay() -> void:
	_rect(content, Rect2(0, 0, 1280, 720), Color(0.06, 0.05, 0.08, 0.74))
	var targets: Array[Rect2] = [
		Rect2(53 if state.mode == "cpu" else 193, 128, 282, 526),
		Rect2(53 if state.mode == "cpu" else 193, 128, 370, 526),
		Rect2(
			446 if state.mode == "cpu" else 636,
			120,
			390 if state.mode == "cpu" else 538,
			535
		),
	]
	_outline(targets[tutorial_step], YELLOW, 6)
	var card: Rect2 = (
		Rect2(735, 172, 470, 384) if tutorial_step < 2 else Rect2(24, 172, 420, 384)
	)
	_panel(card, Color("ffffff"), YELLOW, 14)
	var codes: Array[String] = ["01 / POSITION", "02 / PREVIEW", "03 / CHAIN"]
	var titles: Array[String] = ["空いた列へ合わせる", "着地点を先に見る", "同じ色を4つ接続"]
	var bodies: Array[String] = [
		"← → / 左スティックで移動\n↑・Z / A・Xで回転\n\n紫の枠が、いま操作できる盤面です。",
		"薄い図形が落下位置のプレビュー。\n↓で速く、Space / Yで一気に落とします。\n\n置く前なら移動と回転をやり直せます。",
		"上下左右に4つつなぐと消えます。\n落下でもう一度つながれば連鎖。\n\n中央の大きな数字と折れ線が伸びます。",
	]
	_label(codes[tutorial_step], Rect2(card.position + Vector2(38, 34), Vector2(390, 28)), 16, PRIMARY)
	_label(titles[tutorial_step], Rect2(card.position + Vector2(38, 77), Vector2(390, 53)), 30)
	_label(
		bodies[tutorial_step],
		Rect2(card.position + Vector2(38, 153), Vector2(390, 124)),
		18,
		MUTED
	)
	_button(
		"tutorial_next",
		"プレイ開始" if tutorial_step == 2 else "次へ  →",
		Rect2(card.position + Vector2(38, 300), Vector2(244, 56)),
		_tutorial_next
	).grab_focus()
	_button(
		"tutorial_skip",
		"スキップ",
		Rect2(card.position + Vector2(300, 300), Vector2(104, 56)),
		_tutorial_skip
	)


func _tutorial_next() -> void:
	sound.play_sfx("select")
	tutorial_step += 1
	if tutorial_step >= 3:
		_tutorial_finish()
	else:
		_render()


func _tutorial_skip() -> void:
	sound.play_sfx("select")
	_tutorial_finish()


func _tutorial_finish() -> void:
	tutorial_step = -1
	state.records.tutorial_seen = true
	state.save_records()
	state.paused = false
	_render()


func _pause_overlay() -> void:
	_rect(content, Rect2(0, 0, 1280, 720), Color(0.06, 0.05, 0.08, 0.72))
	_panel(Rect2(405, 184, 470, 354), Color("ffffff"), PRIMARY, 14)
	_label("PAUSED", Rect2(458, 222, 360, 34), 16, PRIMARY)
	_label("計測を止めています", Rect2(458, 267, 360, 52), 30)
	_button("resume", "つづける", Rect2(465, 352, 350, 62), state.toggle_pause).grab_focus()
	_button("title", "モード選択へ", Rect2(465, 438, 350, 56), state.show_title)


func _result() -> void:
	sound.set_scene("result")
	sound.play_sfx("victory" if state.round_winner == 0 or state.mode == "solo" else "defeat")
	_label("RESULT / MEASURE COMPLETE", Rect2(76, 55, 480, 30), 17, PRIMARY)
	var heading: String = "90秒の計測結果"
	if state.mode == "cpu":
		heading = "YOU WIN" if state.round_winner == 0 else "CPU WIN"
		if state.screen == "round":
			heading = "ROUND / " + ("YOU" if state.round_winner == 0 else "CPU")
	_label(heading, Rect2(72, 103, 720, 86), 62)
	_label(state.result_text, Rect2(77, 194, 610, 34), 19, MUTED)
	_panel(Rect2(72, 260, 743, 270), Color("ffffff"), Color("d8d3cb"), 10)
	_label("SCORE", Rect2(112, 294, 170, 25), 14, MUTED)
	_label("%06d" % state.score, Rect2(106, 320, 335, 78), 57, PRIMARY)
	_label("MAX CHAIN", Rect2(483, 294, 170, 25), 14, MUTED)
	_label("%02d" % state.max_chain, Rect2(478, 319, 260, 82), 62, SECONDARY)
	_static_chart(Rect2(111, 425, 620, 65), score_history, PRIMARY)
	var summary: String = "対戦 %d : %d" % [state.wins[0], state.wins[1]]
	if not state.save_message.is_empty():
		summary += "    /    " + state.save_message
	_label(summary, Rect2(111, 494, 620, 24), 14, MUTED)
	var action: Callable = state.next_round if state.screen == "round" else _retry
	_button(
		"retry",
		"次のラウンド  →" if state.screen == "round" else "もう一度  →",
		Rect2(882, 330, 310, 72),
		action
	).grab_focus()
	_button("title", "モード選択へ", Rect2(882, 424, 310, 62), state.show_title)
	_circle(content, Vector2(1040, 172), 94, Color("e8ddff"))
	_rect(content, Rect2(977, 109, 126, 126), Color(1, 1, 1, 0.55)).rotation = 0.18


func _retry() -> void:
	score_history = [0.0]
	graph_second = -1
	state.start_game(state.mode)


func _panel(
	rect: Rect2,
	color: Color,
	border: Color = Color("d8d3cb"),
	radius: int = 10
) -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style(color, border, radius, 1))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size


func _style(color: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.08, 0.07, 0.10, 0.10)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _rect(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var shape := ColorRect.new()
	shape.color = color
	shape.position = rect.position
	shape.size = rect.size
	shape.pivot_offset = rect.size * 0.5
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shape)
	return shape


func _circle(parent: Node, point: Vector2, radius: float, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	var points := PackedVector2Array()
	for index: int in range(36):
		var angle: float = TAU * float(index) / 36.0
		points.append(point + Vector2(cos(angle), sin(angle)) * radius)
	shape.polygon = points
	shape.color = color
	parent.add_child(shape)
	return shape


func _outline(rect: Rect2, color: Color, width: float) -> void:
	_rect(content, Rect2(rect.position, Vector2(rect.size.x, width)), color)
	_rect(
		content,
		Rect2(rect.position + Vector2(0, rect.size.y - width), Vector2(rect.size.x, width)),
		color
	)
	_rect(content, Rect2(rect.position, Vector2(width, rect.size.y)), color)
	_rect(
		content,
		Rect2(rect.position + Vector2(rect.size.x - width, 0), Vector2(width, rect.size.y)),
		color
	)


func _label(text: String, rect: Rect2, font_size: int, color: Color = INK) -> Label:
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
			button.create_tween().tween_property(button, "scale", Vector2.ONE * 1.018, 0.10)
	)
	button.mouse_exited.connect(
		func() -> void: button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.10)
	)
	return button


## 数字の補間と折れ線の採取はフレーム時間に依存するため非冪等。
func _process(delta: float) -> void:
	if state.screen != "play" or tutorial_step >= 0:
		return
	if score_display > state.score:
		score_display = float(state.score)
	score_display = move_toward(
		score_display, float(state.score), maxf(90.0, state.score - score_display) * delta * 5
	)
	hud.score.text = "%06d" % int(score_display)
	hud.chain_number.text = "%02d" % state.max_chain
	hud.time.text = (
		"残り %02d 秒" % ceili(maxf(0.0, state.LIMIT - state.elapsed))
		if state.mode == "solo"
		else "経過 %02d 秒" % int(state.elapsed)
	)
	var current_second: int = int(state.elapsed)
	if current_second != graph_second:
		graph_second = current_second
		score_history.append(float(state.score))
		if score_history.size() > 24:
			score_history.pop_front()
		_render_chart(hud.graph_lines, hud.graph_size, score_history, PRIMARY)
	var danger: bool = state.mode == "solo" and state.elapsed > state.LIMIT - 20.0
	for side: int in boards.size():
		var board_state: Dictionary = state.boards[side]
		hud["pending%d" % side].text = (
			"予告ブロック  %02d" % board_state.pending if board_state.pending > 0 else "予告なし"
		)
		if board_state.board[3].any(func(value: int) -> bool: return value != 0):
			danger = true
	boards[0].set_available(state.can_control())
	if state.can_control():
		hud.action.text = "NOW / 移動・回転できます\n薄い図形へ落とす → 4個を接続"
		hud.action.add_theme_color_override("font_color", PRIMARY)
	else:
		hud.action.text = _unavailable_reason(state.boards[0].phase)
		hud.action.add_theme_color_override("font_color", MUTED)
	if not state.paused:
		sound.set_scene("danger" if danger else "play")


func _unavailable_reason(phase: String) -> String:
	match phase:
		"land":
			return "WAIT / 着地を判定中\n次の図形が出るまで待ちます"
		"clear":
			return "WAIT / 消去中\n連鎖数とスコアを計算しています"
		"gravity":
			return "WAIT / 落下中\n次の連鎖を確認しています"
		"garbage":
			return "WAIT / 予告ブロック落下中\n揺れが止まるまで待ちます"
		_:
			return "WAIT / 次の図形を準備中"


func _board_changed(side: int, pose: String) -> void:
	if side < boards.size():
		boards[side].refresh(pose)


func _effect(side: int, kind: String, cells: Array, chain: int) -> void:
	if side < boards.size():
		boards[side].animate(kind, cells, chain)
	sound.play_sfx(kind, minf(1.0 + chain * 0.15, 2.1))
	if kind != "clear":
		return
	var point: Vector2 = boards[side].origin + Vector2(-8, 184)
	var popup: Label = _label(
		"%02d" % chain,
		Rect2(point, Vector2(280, 100)),
		mini(68 + chain * 5, 92),
		PRIMARY if chain < 3 else SECONDARY
	)
	var caption: Label = _label(
		"CHAIN", Rect2(point + Vector2(130, 54), Vector2(130, 30)), 18, INK
	)
	popup.pivot_offset = Vector2(120, 50)
	popup.scale = Vector2.ONE * 0.45
	var tween := popup.create_tween()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.30)
	tween.tween_property(popup, "modulate:a", 0.0, 0.30)
	tween.tween_callback(popup.queue_free)
	var caption_tween := caption.create_tween()
	caption_tween.tween_interval(0.48)
	caption_tween.tween_property(caption, "modulate:a", 0.0, 0.30)
	caption_tween.tween_callback(caption.queue_free)


func stop_audio() -> void:
	sound.stop_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		closing = true
		await sound.shutdown()
		get_tree().quit()
