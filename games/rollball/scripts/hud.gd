extends Control
## RunState を表示し、画用紙の札から操作要求を通知する。進行状態は保持しない。

signal start_requested
signal title_requested
signal stage_select_requested
signal stage_changed(stage_id: String)
signal stage_start_requested
signal tutorial_next_requested
signal tutorial_skip_requested

const Room = preload("res://scripts/room.gd")

const INK: Color = Color("493d46")
const CREAM: Color = Color("fff7df")
const TEAL: Color = Color("3e857e")
const CORAL: Color = Color("df725f")
const GOLD: Color = Color("e9b951")
const LILAC: Color = Color("aaa0c8")
const SKY: Color = Color("a8d6d4")
const UI_ROOT: String = "res://assets/ui/"

var title_panel: Control
var stage_panel: Control
var tutorial_panel: Control
var result_panel: Control
var play_panel: Control
var diameter_label: Label
var timer_label: Label
var count_label: Label
var goal_bar: ProgressBar
var feedback: Label
var result_heading: Label
var result_detail: Label
var start_button: Button
var retry_button: Button
var display_diameter: float = RunState.INITIAL_DIAMETER
var display_count: float = 0.0

var _mode: String = ""
var _scrim: ColorRect
var _flash: ColorRect
var _result_icon: TextureRect
var _result_diameter: Label
var _result_count: Label
var _goal_caption: Label
var _stage_name: Label
var _stage_caption: Label
var _stage_buttons: Array[Button] = []
var _stage_start_button: Button
var _tutorial_heading: Label
var _tutorial_detail: Label
var _tutorial_gesture: Label
var _tutorial_tags: Array[PanelContainer] = []
var _tutorial_next_button: Button
var _target_diameter: float = -1.0
var _target_count: int = -1
var _transition: Tween
var _numbers: Tween
var _flash_tween: Tween
var _button_tweens: Dictionary = {}
var _popup_serial: int = 0
var _pickup_label: Label
var _pickup_total: float = 0.0
var _pickup_age: float = 0.0
var _pickup_tween: Tween
var _paper_shader: Shader


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://assets/ui/atelier-theme.tres")
	_build_title()
	_build_stage_select()
	_build_play()
	_scrim = _wash(Color("372c3d00"))
	_build_tutorial()
	_build_result()
	_flash = _wash(Color("fff5cc00"))


func _process(delta: float) -> void:
	diameter_label.text = "%.2f m" % display_diameter
	count_label.text = "%d 個" % roundi(display_count)
	goal_bar.value = display_diameter
	if is_instance_valid(_pickup_label):
		_pickup_age += delta
		if _pickup_tween == null:
			_pickup_label.position.y = move_toward(_pickup_label.position.y, 298.0, delta * 44.0)
			if _pickup_age >= 0.5:
				_fade_pickup()


func _build_title() -> void:
	title_panel = _screen()
	var heading: PanelContainer = _paper(title_panel, Rect2(48, 54, 505, 122), CREAM, -1.4, 8)
	var heading_body: Control = _canvas(heading)
	_picture(heading_body, "logo-emblem.svg", Rect2(-3, 4, 82, 82))
	_at(heading_body, "ころころ工房", Rect2(91, 3, 350, 58), 48)
	_at(heading_body, "ねんどの玩具を ひと玉に", Rect2(94, 63, 350, 27), 19, TEAL)
	var art_paper: PanelContainer = _paper(
		title_panel, Rect2(75, 196, 430, 213), Color("f5b5a2"), 1.1, 12
	)
	var art_body: Control = _canvas(art_paper)
	_picture(art_body, "title-key-art.svg", Rect2(4, 2, 374, 167))
	_at(art_body, "小さい玩具から ころころ集めよう", Rect2(14, 164, 364, 27), 17, INK)
	var note: PanelContainer = _paper(
		title_panel, Rect2(41, 435, 467, 103), Color("f7de91"), -0.7, 5
	)
	var note_body: Control = _canvas(note)
	_at(note_body, "目標", Rect2(3, 0, 72, 25), 15, CORAL)
	_at(note_body, "3分で %.1f m" % RunState.TARGET_DIAMETER, Rect2(3, 23, 178, 38), 28)
	_at(note_body, "大きすぎる玩具は\nまだ巻き込めません", Rect2(224, 6, 190, 55), 16, TEAL)
	start_button = _button("おもちゃ箱をひらく  →", func() -> void: stage_select_requested.emit())
	_place(title_panel, start_button, Rect2(72, 566, 414, 62))
	_at(title_panel, "Enter / A でもひらく", Rect2(164, 640, 230, 25), 15, CREAM)
	var badge: PanelContainer = _paper(
		title_panel, Rect2(1000, 56, 214, 72), Color("b3c3e4"), 2.1, 6
	)
	var badge_body: Control = _canvas(badge)
	_at(badge_body, "NEW", Rect2(0, -3, 48, 22), 14, CORAL)
	_at(badge_body, "2つの部屋", Rect2(0, 20, 160, 28), 20)


func _build_stage_select() -> void:
	stage_panel = _screen()
	var heading: PanelContainer = _paper(
		stage_panel, Rect2(404, 24, 472, 83), CREAM, -0.4, 6
	)
	var heading_body: Control = _canvas(heading)
	_at(heading_body, "おもちゃ箱から 部屋をえらぶ", Rect2(0, 3, 420, 37), 28)
	_at(heading_body, "カードに触れると、部屋の中を先に見られます", Rect2(0, 43, 420, 23), 15, TEAL)
	var lid: PanelContainer = _paper(
		stage_panel, Rect2(112, 337, 1056, 55), Color("96728d"), -0.3, 8
	)
	lid.add_theme_stylebox_override("panel", _paper_style(Color("96728d"), 8, 8))
	var box: PanelContainer = _paper(
		stage_panel, Rect2(91, 372, 1098, 303), Color("d99078"), 0.2, 9
	)
	box.add_theme_stylebox_override("panel", _paper_style(Color("d99078"), 9, 12))
	for index: int in range(Room.STAGES.size()):
		var stage: Dictionary = Room.STAGES[index]
		var card: Button = Button.new()
		card.text = "%s\n%s" % [stage.name, stage.caption]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 19)
		card.set_meta("stage_id", stage.id)
		card.focus_entered.connect(_focus_stage.bind(stage.id))
		card.pressed.connect(_focus_stage.bind(stage.id))
		_place(stage_panel, card, Rect2(146 + index * 502, 395 + index * 7, 448, 116))
		_stage_buttons.append(card)
	var detail: PanelContainer = _paper(
		stage_panel, Rect2(236, 521, 808, 82), Color("f6e9bc"), -0.5, 5
	)
	var detail_body: Control = _canvas(detail)
	_stage_name = _at(detail_body, "", Rect2(8, 0, 320, 31), 23, CORAL)
	_stage_caption = _at(detail_body, "", Rect2(337, 0, 414, 57), 16, INK)
	_stage_start_button = _button("この部屋へ  →", func() -> void: stage_start_requested.emit())
	_place(stage_panel, _stage_start_button, Rect2(445, 614, 390, 58))
	var back: Button = _button("タイトルへ", func() -> void: title_requested.emit(), true)
	_place(stage_panel, back, Rect2(38, 43, 170, 45))


func _build_play() -> void:
	play_panel = _screen()
	var diameter_tag: PanelContainer = _paper(
		play_panel, Rect2(24, 20, 258, 94), Color("f7e1a0"), -1.2, 5
	)
	var diameter_body: Control = _canvas(diameter_tag)
	_at(diameter_body, "いまの直径", Rect2(0, -3, 176, 23), 15, TEAL)
	diameter_label = _at(diameter_body, "0.80 m", Rect2(0, 18, 205, 48), 35)
	var goal_tag: PanelContainer = _paper(
		play_panel, Rect2(339, 20, 466, 88), Color("c4e0cf"), 0.55, 5
	)
	var goal_body: Control = _canvas(goal_tag)
	_at(goal_body, "ゴール  %.1f m" % RunState.TARGET_DIAMETER, Rect2(0, -4, 190, 24), 17)
	goal_bar = ProgressBar.new()
	goal_bar.min_value = 0.0
	goal_bar.max_value = RunState.TARGET_DIAMETER
	goal_bar.show_percentage = false
	_place(goal_body, goal_bar, Rect2(197, 2, 216, 15))
	_goal_caption = _at(goal_body, "小さなものから集めよう", Rect2(0, 30, 414, 26), 15, TEAL)
	var count_tag: PanelContainer = _paper(
		play_panel, Rect2(844, 22, 176, 88), Color("efb09c"), -0.6, 5
	)
	var count_body: Control = _canvas(count_tag)
	_at(count_body, "あつめた", Rect2(0, -4, 124, 22), 14, CORAL)
	count_label = _at(count_body, "0 個", Rect2(0, 18, 124, 42), 31)
	var timer_tag: PanelContainer = _paper(
		play_panel, Rect2(1052, 18, 204, 94), Color("b8c5e3"), 1.0, 5
	)
	var timer_body: Control = _canvas(timer_tag)
	_at(timer_body, "のこり", Rect2(0, -4, 104, 22), 14, TEAL)
	timer_label = _at(timer_body, "03:00", Rect2(0, 18, 148, 42), 31)
	feedback = _at(play_panel, "", Rect2(324, 132, 632, 42), 20)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_color_override("font_shadow_color", Color("4d3d48aa"))
	feedback.add_theme_constant_override("shadow_offset_y", 2)
	feedback.add_theme_color_override("font_outline_color", Color("fff8e8e8"))
	feedback.add_theme_constant_override("outline_size", 7)


func _build_tutorial() -> void:
	tutorial_panel = _screen()
	var speech: PanelContainer = _paper(
		tutorial_panel, Rect2(55, 96, 468, 226), CREAM, -1.0, 10
	)
	var speech_body: Control = _canvas(speech)
	_at(speech_body, "ころちゃんたちの 身振りレッスン", Rect2(0, 0, 416, 32), 23, CORAL)
	_tutorial_heading = _at(speech_body, "", Rect2(0, 50, 416, 43), 31)
	_tutorial_detail = _at(speech_body, "", Rect2(0, 103, 416, 62), 18, TEAL)
	_tutorial_gesture = _at(speech_body, "", Rect2(0, 173, 416, 24), 15, INK)
	for index: int in range(3):
		var tag: PanelContainer = _paper(
			tutorial_panel,
			Rect2(683 + index * 157, 118 + index * 52, 150, 104),
			[Color("f2c28b"), Color("acd6c8"), Color("b9b5dc")][index],
			[-3.0, 1.5, -1.0][index],
			5
		)
		var tag_body: Control = _canvas(tag)
		_at(tag_body, "%d" % (index + 1), Rect2(0, -6, 28, 30), 22, CORAL)
		var label: Label = _at(
			tag_body,
			["ころがす", "見まわす", "小さい物へ"][index],
			Rect2(0, 30, 103, 45),
			17
		)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tutorial_tags.append(tag)
	_tutorial_next_button = _button("身振りをつぎへ  →", func() -> void: tutorial_next_requested.emit())
	_place(tutorial_panel, _tutorial_next_button, Rect2(734, 489, 390, 58))
	var skip: Button = _button("すぐ転がす（スキップ）", func() -> void: tutorial_skip_requested.emit(), true)
	_place(tutorial_panel, skip, Rect2(794, 567, 270, 44))
	_at(tutorial_panel, "Enter / A：つぎへ     Esc / B：スキップ", Rect2(741, 629, 374, 24), 14, CREAM)


func _build_result() -> void:
	result_panel = _screen()
	var icon_paper: PanelContainer = _paper(
		result_panel, Rect2(231, 111, 217, 217), Color("f5c978"), -3.0, 12
	)
	var icon_body: Control = _canvas(icon_paper)
	_result_icon = _picture(icon_body, "goal-rosette.svg", Rect2(24, 20, 121, 121))
	_at(icon_body, "今回の記録", Rect2(13, 158, 145, 27), 18)
	var result_note: PanelContainer = _paper(
		result_panel, Rect2(413, 72, 566, 437), CREAM, 0.8, 8
	)
	var body: Control = _canvas(result_note)
	var eyebrow: Label = _at(body, "ころころ工房  /  できあがり", Rect2(0, 0, 510, 28), 16, TEAL)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_heading = _at(body, "", Rect2(0, 50, 510, 54), 38)
	result_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail = _at(body, "", Rect2(0, 111, 510, 32), 18)
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var diameter_piece: PanelContainer = _paper(
		body, Rect2(13, 172, 225, 102), Color("c2dfcd"), -1.2, 4
	)
	var diameter_body: Control = _canvas(diameter_piece)
	_at(diameter_body, "到達直径", Rect2(0, -3, 174, 24), 15, TEAL)
	_result_diameter = _at(diameter_body, "", Rect2(0, 27, 174, 44), 32)
	var count_piece: PanelContainer = _paper(
		body, Rect2(271, 169, 225, 102), Color("efb09c"), 1.4, 4
	)
	var count_body: Control = _canvas(count_piece)
	_at(count_body, "巻き込んだ数", Rect2(0, -3, 174, 24), 15, CORAL)
	_result_count = _at(count_body, "", Rect2(0, 27, 174, 44), 32)
	retry_button = _button("同じ部屋でもう一度", func() -> void: start_requested.emit())
	_place(body, retry_button, Rect2(35, 308, 440, 58))
	var back: Button = _button("タイトルへ戻る", func() -> void: title_requested.emit(), true)
	_place(body, back, Rect2(35, 379, 440, 45))


func show_mode(mode: String) -> void:
	if mode == _mode:
		return
	_mode = mode
	if _transition:
		_transition.kill()
	title_panel.visible = mode == "title"
	stage_panel.visible = mode == "stage_select"
	play_panel.visible = mode == "playing"
	feedback.visible = mode == "playing"
	tutorial_panel.visible = mode == "tutorial"
	result_panel.visible = mode in ["won", "lost"]
	_scrim.visible = tutorial_panel.visible or result_panel.visible
	_clear_popups()
	var incoming: Control = title_panel
	if mode == "title":
		start_button.grab_focus()
	elif mode == "stage_select":
		incoming = stage_panel
		update_stage(RunState.selected_stage)
		_selected_stage_button().grab_focus()
	elif mode == "playing":
		incoming = play_panel
		_reset_numbers()
	elif mode == "tutorial":
		incoming = tutorial_panel
		update_tutorial(0)
		_tutorial_next_button.grab_focus()
	elif mode in ["won", "lost"]:
		incoming = result_panel
		_update_result(mode)
		retry_button.grab_focus()
	incoming.modulate.a = 0.0
	incoming.position = Vector2(0, 14)
	_scrim.color.a = 0.0
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(incoming, "modulate:a", 1.0, 0.3)
	_transition.tween_property(incoming, "position", Vector2.ZERO, 0.38)
	if _scrim.visible:
		_transition.tween_property(_scrim, "color:a", 0.34, 0.3)


func update_stage(stage_id: String) -> void:
	var stage: Dictionary = Room.stage_data(stage_id)
	_stage_name.text = stage.name
	_stage_caption.text = stage.preview
	_stage_start_button.text = "%sへ  →" % stage.name
	for button: Button in _stage_buttons:
		var button_stage: Dictionary = Room.stage_data(button.get_meta("stage_id"))
		var selected: bool = button_stage.id == stage.id
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_focus_color", INK)
		button.add_theme_stylebox_override(
			"normal", _stage_card_style(button_stage.paper_color, selected)
		)
		button.add_theme_stylebox_override(
			"hover", _stage_card_style(button_stage.paper_color.lightened(0.06), true)
		)
		button.add_theme_stylebox_override(
			"focus", _stage_focus_style(CORAL if selected else GOLD)
		)
	stage_panel.queue_redraw()
	for control: Node in stage_panel.find_children("*", "Control", true, false):
		(control as Control).queue_redraw()


func update_tutorial(step: int) -> void:
	var pages: Array[Dictionary] = [
		{
			"heading": "まずは ころがす",
			"detail": "WASD・矢印キー / 左スティックで\n玉を前後左右へころがします。",
			"gesture": "アヒルが足ぶみして、進む向きを見せています。",
		},
		{
			"heading": "つぎに 見まわす",
			"detail": "Q・E / 右スティックで\nカメラを左右へ回します。",
			"gesture": "ロボットが体をひねって、見回す身振りをします。",
		},
		{
			"heading": "金の輪へ ころころ",
			"detail": "玉より小さい玩具に触れると巻き込みます。\n大きすぎる玩具は、育ってから。",
			"gesture": "ふたりが手を上げたら、金の輪の玩具が次の目標です。",
		},
	]
	var selected_step: int = clampi(step, 0, pages.size() - 1)
	_tutorial_heading.text = pages[selected_step].heading
	_tutorial_detail.text = pages[selected_step].detail
	_tutorial_gesture.text = pages[selected_step].gesture
	_tutorial_next_button.text = "転がしはじめる  →" if selected_step == 2 else "身振りをつぎへ  →"
	for index: int in range(_tutorial_tags.size()):
		var tag_color: Color = [Color("f2c28b"), Color("acd6c8"), Color("b9b5dc")][index]
		_tutorial_tags[index].add_theme_stylebox_override(
			"panel", _paper_style(tag_color if index == selected_step else tag_color.darkened(0.18), 5,
				14 if index == selected_step else 5)
		)
		_tutorial_tags[index].scale = Vector2.ONE * (1.08 if index == selected_step else 0.94)


func _focus_stage(stage_id: String) -> void:
	stage_changed.emit(stage_id)
	update_stage(stage_id)


func _selected_stage_button() -> Button:
	for button: Button in _stage_buttons:
		if String(button.get_meta("stage_id")) == RunState.selected_stage:
			return button
	return _stage_buttons[0]


func _update_result(mode: String) -> void:
	var won: bool = mode == "won"
	result_heading.text = "大きくなりました！" if won else "時間になりました"
	result_heading.add_theme_color_override("font_color", TEAL if won else CORAL)
	result_detail.text = "目標達成。お部屋をひと玉に！" if won else "金の輪と小さな玩具から、もう一度。"
	_result_icon.texture = load(UI_ROOT + ("goal-rosette.svg" if won else "timer-clock.svg"))
	_result_diameter.text = "%.2f m" % RunState.diameter
	_result_count.text = "%d 個" % RunState.collected


func update_values(effect: float, bump: float) -> void:
	if not is_equal_approx(_target_diameter, RunState.diameter) or _target_count != RunState.collected:
		_animate_numbers()
	var seconds: int = ceili(RunState.remaining)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	timer_label.add_theme_color_override("font_color", CORAL if seconds <= 30 else INK)
	_goal_caption.text = "あと %.2f m。金の輪の玩具へ" % maxf(
		0.0, RunState.TARGET_DIAMETER - RunState.diameter
	)
	if bump > 0.0:
		feedback.text = "まだ大きすぎる！ 金の輪の玩具を探そう"
		feedback.add_theme_color_override("font_color", CORAL)
	elif effect > 0.0:
		feedback.text = "巻き込んだ！  次の金の輪へ"
		feedback.add_theme_color_override("font_color", TEAL)
	else:
		feedback.text = "金の輪が、いま巻き込める一番近い玩具"
		feedback.add_theme_color_override("font_color", INK)


func show_pickup(delta_diameter: float) -> void:
	if _mode != "playing":
		return
	var continuous: bool = is_instance_valid(_pickup_label) and _pickup_age <= 0.35
	_pickup_total = _pickup_total + delta_diameter if continuous else delta_diameter
	_pickup_age = 0.0
	if _pickup_tween:
		_pickup_tween.kill()
		_pickup_tween = null
	if not is_instance_valid(_pickup_label):
		_pickup_label = _label("", 31, TEAL)
		_pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pickup_label.add_theme_color_override("font_outline_color", CREAM)
		_pickup_label.add_theme_constant_override("outline_size", 8)
		_place(self, _pickup_label, Rect2(510, 320, 260, 46))
	if not continuous:
		_pickup_label.position.y = 320.0
	_pickup_label.modulate.a = 1.0
	_pickup_label.text = "+%.2f m" % _pickup_total


func _fade_pickup() -> void:
	_pickup_tween = _pickup_label.create_tween().set_parallel(true)
	_pickup_tween.tween_property(_pickup_label, "position:y", 280.0, 0.35)
	_pickup_tween.tween_property(_pickup_label, "modulate:a", 0.0, 0.35)
	_pickup_tween.finished.connect(_clear_pickup)


func _clear_pickup() -> void:
	if _pickup_tween:
		_pickup_tween.kill()
		_pickup_tween = null
	if is_instance_valid(_pickup_label):
		_pickup_label.queue_free()
	_pickup_label = null
	_pickup_total = 0.0
	_pickup_age = 0.0


func show_bump(lost: bool) -> void:
	if _mode != "playing":
		return
	_clear_pickup()
	_pop("−1 個" if lost else "まだ大きすぎる！", CORAL, Vector2(546, 312))
	_flash_color(CORAL, 0.13)


func show_growth() -> void:
	if _mode != "playing":
		return
	_pop("巻き込める玩具が増えた！", TEAL, Vector2(447, 220), 27)
	_flash_color(GOLD, 0.15)


func _reset_numbers() -> void:
	if _numbers:
		_numbers.kill()
	display_diameter = RunState.diameter
	display_count = float(RunState.collected)
	_target_diameter = RunState.diameter
	_target_count = RunState.collected


func _animate_numbers() -> void:
	if _numbers:
		_numbers.kill()
	_target_diameter = RunState.diameter
	_target_count = RunState.collected
	_numbers = create_tween().set_parallel(true)
	_numbers.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_numbers.tween_property(self, "display_diameter", _target_diameter, 0.32)
	_numbers.tween_property(self, "display_count", float(_target_count), 0.25)


func _pop(text: String, color: Color, origin: Vector2, font_size: int = 31) -> void:
	_popup_serial += 1
	var popup: Label = _label(text, font_size, color)
	popup.set_meta("feedback_popup", true)
	popup.add_theme_color_override("font_outline_color", CREAM)
	popup.add_theme_constant_override("outline_size", 8)
	popup.position = origin + Vector2(float(_popup_serial % 3 - 1) * 21.0, 0)
	add_child(popup)
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2.ONE * 0.8
	var tween: Tween = popup.create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 65.0, 0.85)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tween.chain().tween_callback(popup.queue_free)


func _flash_color(color: Color, strength: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash.color = Color(color, strength)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.32)


func _clear_popups() -> void:
	_clear_pickup()
	for child: Node in get_children():
		if child.has_meta("feedback_popup"):
			child.queue_free()
	if _flash_tween:
		_flash_tween.kill()
	_flash.color.a = 0.0


func _animate_button(button: Button, target: float) -> void:
	if _button_tweens.has(button):
		(_button_tweens[button] as Tween).kill()
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	_button_tweens[button] = tween
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * target, 0.14)


func _label(text: String, font_size: int, color: Color = INK) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _at(parent: Node, text: String, bounds: Rect2, font_size: int, color: Color = INK) -> Label:
	var label: Label = _label(text, font_size, color)
	_place(parent, label, bounds)
	return label


func _picture(parent: Node, filename: String, bounds: Rect2) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.texture = load(UI_ROOT + filename)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(parent, picture, bounds)
	return picture


func _place(parent: Node, child: Control, bounds: Rect2) -> void:
	parent.add_child(child)
	child.position = bounds.position
	child.size = bounds.size


func _canvas(parent: Node) -> Control:
	var body: Control = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(body)
	return body


func _screen() -> Control:
	var screen: Control = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	return screen


func _paper(
	parent: Node, bounds: Rect2, color: Color, rotation: float, radius: int
) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _paper_style(color, radius, 9))
	panel.material = _paper_material()
	_place(parent, panel, bounds)
	panel.pivot_offset = bounds.size * 0.5
	panel.rotation_degrees = rotation
	return panel


func _paper_style(color: Color, radius: int, shadow: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = color.lightened(0.08)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 17.0
	style.content_margin_bottom = 17.0
	style.shadow_color = Color("3d30423d")
	style.shadow_size = shadow
	style.shadow_offset = Vector2(4, 6)
	return style


func _paper_material() -> ShaderMaterial:
	if _paper_shader == null:
		_paper_shader = Shader.new()
		_paper_shader.code = """
shader_type canvas_item;
float paper_noise(vec2 p) {
	return fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec4 base = COLOR;
	float fiber = (paper_noise(FRAGCOORD.xy * 0.72) - 0.5) * 0.055;
	float strand = sin(FRAGCOORD.y * 0.31 + paper_noise(FRAGCOORD.xx) * 2.0) * 0.009;
	COLOR = vec4(base.rgb * (1.0 + fiber + strand), base.a);
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _paper_shader
	return material


func _stage_card_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = _paper_style(color, 6, 13 if selected else 5)
	style.border_width_left = 5 if selected else 2
	style.border_width_top = 5 if selected else 2
	style.border_width_right = 5 if selected else 2
	style.border_width_bottom = 5 if selected else 2
	style.border_color = CREAM if selected else color.lightened(0.12)
	style.content_margin_left = 28.0
	return style


func _stage_focus_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(4)
	style.border_color = color
	style.set_expand_margin_all(7.0)
	style.set_corner_radius_all(8)
	return style


func _wash(color: Color) -> ColorRect:
	var wash: ColorRect = ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = color
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	return wash


func _button(text: String, action: Callable, secondary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	if secondary:
		button.theme_type_variation = &"SecondaryButton"
	button.pressed.connect(action)
	button.mouse_entered.connect(_animate_button.bind(button, 1.025))
	button.mouse_exited.connect(_animate_button.bind(button, 1.0))
	button.focus_entered.connect(_animate_button.bind(button, 1.025))
	button.focus_exited.connect(_animate_button.bind(button, 1.0))
	button.button_down.connect(_animate_button.bind(button, 0.975))
	button.button_up.connect(_animate_button.bind(button, 1.025))
	return button


func _exit_tree() -> void:
	_clear_pickup()
	for tween: Tween in [_transition, _numbers, _flash_tween]:
		if tween:
			tween.kill()
	for tween: Tween in _button_tweens.values():
		tween.kill()
	_button_tweens.clear()
