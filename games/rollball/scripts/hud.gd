extends Control
## RunState を表示し、操作要求を通知する。表示値だけを補間し進行状態は保持しない。

signal start_requested
signal title_requested

const INK: Color = Color("23464a")
const CREAM: Color = Color("fff8e8")
const TEAL: Color = Color("267d78")
const CORAL: Color = Color("d95640")
const GOLD: Color = Color("e8b35e")
const UI_ROOT: String = "res://assets/ui/"

var title_panel: PanelContainer
var result_panel: PanelContainer
var play_panel: PanelContainer
var diameter_label: Label
var timer_label: Label
var count_label: Label
var goal_bar: ProgressBar
var feedback: Label
var result_heading: Label
var result_detail: Label
var start_button: Button
var retry_button: Button
var sound_label: Label
var display_diameter: float = RunState.INITIAL_DIAMETER
var display_count: float = 0.0

var _mode: String = ""
var _stage_badge: PanelContainer
var _scrim: ColorRect
var _flash: ColorRect
var _result_icon: TextureRect
var _result_diameter: Label
var _result_count: Label
var _goal_caption: Label
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


## 起動時に一度だけノードを組み立てる。
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://assets/ui/atelier-theme.tres")
	_build_title()
	_build_play()
	_build_footer()
	_scrim = _wash(Color("183b3d00"))
	_build_result()
	_flash = _wash(Color("fff5cc00"))


## 表示中の数値を補間するため非冪等。画面更新ごとに一度呼ばれる。
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
	title_panel = _panel(self, Rect2(44, 42, 478, 588))
	var body: Control = _canvas(title_panel)
	_picture(body, "logo-emblem.svg", Rect2(2, 6, 71, 71))
	_at(body, "ころころ工房", Rect2(87, 4, 345, 72), 46)
	_at(body, "小さなものから、大きなよろこび。", Rect2(3, 84, 424, 31), 21, TEAL)
	_picture(body, "title-key-art.svg", Rect2(0, 134, 430, 169))
	_at(body, "散らかったお部屋を、ひと玉に。", Rect2(3, 319, 424, 34), 23)
	_at(body, "小さなものを集めて、大きく育とう。", Rect2(3, 360, 424, 27), 18)
	_at(body, "大きすぎるものに当たると、ひとつ外れます。", Rect2(3, 389, 424, 26), 16)
	_at(
		body, "制限時間 3分    ・    目標 %.1f m" % RunState.TARGET_DIAMETER,
		Rect2(3, 431, 424, 28), 20, TEAL
	)
	start_button = _button("転がしはじめる  →", func() -> void: start_requested.emit())
	_place(body, start_button, Rect2(0, 477, 430, 58))
	_at(body, "Enter・Space / A ボタンでもスタート", Rect2(0, 542, 430, 25), 15)
	_stage_badge = _panel(self, Rect2(958, 43, 278, 76))
	var badge_body: Control = _canvas(_stage_badge)
	_picture(badge_body, "collected-blocks.svg", Rect2(0, 0, 42, 42))
	_at(badge_body, "今日の舞台", Rect2(55, -2, 175, 23), 14, TEAL)
	_at(badge_body, "おもちゃのアトリエ", Rect2(55, 23, 180, 27), 18)


func _build_play() -> void:
	play_panel = _panel(self, Rect2(24, 22, 1232, 101))
	var body: Control = _canvas(play_panel)
	_picture(body, "logo-emblem.svg", Rect2(-5, -3, 67, 67))
	_at(body, "いまの直径", Rect2(77, -3, 174, 22), 15, TEAL)
	diameter_label = _at(body, "0.80 m", Rect2(75, 18, 210, 46), 36)
	_at(body, "目標  %.1f m" % RunState.TARGET_DIAMETER, Rect2(330, -3, 380, 25), 18)
	goal_bar = ProgressBar.new()
	goal_bar.min_value = 0.0
	goal_bar.max_value = RunState.TARGET_DIAMETER
	goal_bar.show_percentage = false
	_place(body, goal_bar, Rect2(330, 30, 362, 13))
	_goal_caption = _at(body, "小さなものから集めよう", Rect2(330, 48, 400, 24), 13, TEAL)
	_picture(body, "collected-blocks.svg", Rect2(770, 17, 35, 35))
	_at(body, "巻き込んだ数", Rect2(822, -3, 175, 23), 15, TEAL)
	count_label = _at(body, "0 個", Rect2(820, 20, 180, 43), 32)
	_picture(body, "timer-clock.svg", Rect2(995, 11, 45, 45))
	_at(body, "残り時間", Rect2(1053, -3, 139, 23), 15, TEAL)
	timer_label = _at(body, "03:00", Rect2(1051, 20, 144, 43), 32)
	feedback = _at(self, "", Rect2(320, 142, 640, 42), 20)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_color_override("font_shadow_color", CREAM)
	feedback.add_theme_constant_override("shadow_offset_x", 1)
	feedback.add_theme_constant_override("shadow_offset_y", 2)
	feedback.add_theme_color_override("font_outline_color", Color("fff8e8d9"))
	feedback.add_theme_constant_override("outline_size", 5)


func _build_footer() -> void:
	var footer: PanelContainer = _panel(self, Rect2(24, 666, 1232, 36))
	var style: StyleBoxFlat = _paper_style(Color("fff8e8ec"), 12)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	footer.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	footer.add_child(row)
	var hint: Label = _label("移動  WASD / 左スティック     視点  Q・E / 右スティック     戻る  Esc / B", 15)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	sound_label = _label("", 15)
	row.add_child(sound_label)


func _build_result() -> void:
	result_panel = _panel(self, Rect2(366, 83, 548, 547))
	var body: Control = _canvas(result_panel)
	_result_icon = _picture(body, "goal-rosette.svg", Rect2(202, 4, 96, 96))
	var eyebrow: Label = _at(body, "ころころ工房  /  今回の記録", Rect2(0, 109, 500, 29), 16, TEAL)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_heading = _at(body, "", Rect2(0, 146, 500, 52), 38)
	result_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail = _at(body, "", Rect2(0, 204, 500, 31), 18)
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats: PanelContainer = _panel(body, Rect2(14, 256, 472, 99))
	stats.add_theme_stylebox_override("panel", _paper_style(Color("eee9d7"), 15))
	var stats_body: Control = _canvas(stats)
	_at(stats_body, "到達直径", Rect2(12, -4, 194, 26), 15, TEAL)
	_result_diameter = _at(stats_body, "", Rect2(12, 23, 194, 47), 33)
	_at(stats_body, "巻き込んだ数", Rect2(238, -4, 183, 26), 15, TEAL)
	_result_count = _at(stats_body, "", Rect2(238, 23, 183, 47), 33)
	retry_button = _button("もう一度転がす", func() -> void: start_requested.emit())
	_place(body, retry_button, Rect2(14, 382, 472, 58))
	var back: Button = _button("タイトルへ戻る", func() -> void: title_requested.emit(), true)
	_place(body, back, Rect2(14, 457, 472, 48))


func show_mode(mode: String) -> void:
	if mode == _mode:
		return
	_mode = mode
	if _transition:
		_transition.kill()
	title_panel.visible = mode == "title"
	_stage_badge.visible = mode == "title"
	play_panel.visible = mode == "playing"
	feedback.visible = mode == "playing"
	result_panel.visible = mode in ["won", "lost"]
	_scrim.visible = result_panel.visible
	_clear_popups()
	var incoming: Control = title_panel
	var origin: Vector2 = Vector2(44, 42)
	if mode == "title":
		start_button.grab_focus()
	elif mode == "playing":
		incoming = play_panel
		origin = Vector2(24, 22)
		_reset_numbers()
	elif mode in ["won", "lost"]:
		incoming = result_panel
		origin = Vector2(366, 83)
		_update_result(mode)
		retry_button.grab_focus()
	incoming.modulate.a = 0.0
	incoming.position = origin + Vector2(0, 14)
	_stage_badge.modulate.a = 0.0 if mode == "title" else 1.0
	_scrim.color.a = 0.0
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(incoming, "modulate:a", 1.0, 0.3)
	_transition.tween_property(incoming, "position", origin, 0.38)
	if mode == "title":
		_transition.tween_property(_stage_badge, "modulate:a", 1.0, 0.4)
	if result_panel.visible:
		_transition.tween_property(_scrim, "color:a", 0.43, 0.3)


func _update_result(mode: String) -> void:
	var won: bool = mode == "won"
	result_heading.text = "大きくなりました！" if won else "時間になりました"
	result_heading.add_theme_color_override("font_color", TEAL if won else CORAL)
	result_detail.text = "目標達成。お部屋をひと玉に！" if won else "次は小さなものから集めてみよう。"
	_result_icon.texture = load(UI_ROOT + ("goal-rosette.svg" if won else "timer-clock.svg"))
	_result_diameter.text = "%.2f m" % RunState.diameter
	_result_count.text = "%d 個" % RunState.collected


func update_values(effect: float, bump: float) -> void:
	if not is_equal_approx(_target_diameter, RunState.diameter) or _target_count != RunState.collected:
		_animate_numbers()
	var seconds: int = ceili(RunState.remaining)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	timer_label.add_theme_color_override("font_color", CORAL if seconds <= 30 else INK)
	_goal_caption.text = "あと %.2f m で目標達成" % maxf(0.0, RunState.TARGET_DIAMETER - RunState.diameter)
	if bump > 0.0:
		feedback.text = "大きすぎる！ 小さなものを探そう"
		feedback.add_theme_color_override("font_color", CORAL)
	elif effect > 0.0:
		feedback.text = "巻き込んだ！  ぐんぐん成長中"
		feedback.add_theme_color_override("font_color", TEAL)
	else:
		feedback.text = "%.2f m 以下のものを巻き込めます" % (RunState.diameter * RunState.COLLECT_RATIO)
		feedback.add_theme_color_override("font_color", INK)
	sound_label.text = "F11 全画面    M 音：%s" % ("切" if AudioServer.is_bus_mute(0) else "入")


## 巻き込みごとの増分を積算するため非冪等。主シーンが取得時に一度呼ぶ。
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
	# 最後の取得からの待機は _process で管理し、連続回収中に Tween を増やさない。
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


## 反発イベントごとの演出なので非冪等。主シーンの衝突クールダウンに従う。
func show_bump(lost: bool) -> void:
	if _mode != "playing":
		return
	_clear_pickup()
	_pop("−1 個" if lost else "大きすぎる！", CORAL, Vector2(576, 312))
	_flash_color(CORAL, 0.13)


## 成長段階を越えるイベントごとの演出なので非冪等。
func show_growth() -> void:
	if _mode != "playing":
		return
	_pop("もっと大きなものを集めよう！", TEAL, Vector2(432, 220), 27)
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
	# 演出ノードに Tween を束縛し、画面切替や終了時の解放で一緒に停止する。
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


func _paper_style(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = theme.get_stylebox("panel", "PanelContainer").duplicate()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.shadow_size = 0
	return style


func _panel(parent: Node, bounds: Rect2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(parent, panel, bounds)
	return panel


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
