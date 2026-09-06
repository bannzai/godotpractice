extends Control
## UI は RunState を表示し、操作要求だけを通知する。

signal start_requested
signal title_requested

const INK: Color = Color("23464a")
const CREAM: Color = Color("fff8e8")
const TEAL: Color = Color("267d78")
const CORAL: Color = Color("d95640")

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


## 起動時一度だけノードを組み立てる。
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme: Theme = Theme.new()
	ui_theme.default_font = load("res://assets/fonts/MPLUSRounded1c-Medium.ttf")
	ui_theme.default_font_size = 20
	ui_theme.set_color("font_color", "Label", INK)
	theme = ui_theme
	_build_title()
	_build_play()
	_build_result()
	var footer: PanelContainer = _panel(self, Rect2(24, 663, 1232, 39), Color("fff8e8de"))
	var row: HBoxContainer = HBoxContainer.new()
	footer.add_child(row)
	var hint: Label = _label("移動  WASD / 左スティック    視点  Q・E / 右スティック    戻る  Esc / B", 16)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	sound_label = _label("", 16)
	row.add_child(sound_label)


func _build_title() -> void:
	title_panel = _panel(self, Rect2(54, 82, 470, 525), CREAM)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	title_panel.add_child(column)
	column.add_child(_label("小さなものから、大きなよろこび。", 18, TEAL))
	column.add_child(_label("ころころ工房", 54))
	column.add_child(_label("散らかった部屋を、ひと玉に。", 24))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 12
	column.add_child(spacer)
	column.add_child(_label("01   小さなものに触れて巻き込む", 21))
	column.add_child(_label("02   育ったら、大きなものへ", 21))
	column.add_child(_label("03   大きすぎるものには気をつけて", 21))
	column.add_child(_label("ぶつかると反発し、最後のひとつが外れます。", 16))
	column.add_child(_label("制限時間 3分  /  目標直径 %.1f m" % RunState.TARGET_DIAMETER, 21, TEAL))
	start_button = _button("転がしはじめる   →", func() -> void: start_requested.emit())
	column.add_child(start_button)
	column.add_child(_label("Enter・Space / A ボタンでもスタート", 16))
	var badge: PanelContainer = _panel(self, Rect2(905, 92, 305, 84), CREAM)
	var text: Label = _label("今日の舞台\nおもちゃのアトリエ", 22, TEAL)
	badge.add_child(text)
	badge.name = "StageBadge"


func _build_play() -> void:
	play_panel = _panel(self, Rect2(28, 24, 1224, 116), CREAM)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 35)
	play_panel.add_child(row)
	var size_box: VBoxContainer = VBoxContainer.new()
	size_box.custom_minimum_size.x = 210
	row.add_child(size_box)
	size_box.add_child(_label("いまの直径", 16, TEAL))
	diameter_label = _label("", 35)
	size_box.add_child(diameter_label)
	var progress_box: VBoxContainer = VBoxContainer.new()
	progress_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(progress_box)
	progress_box.add_child(_label("目標 %.1f m まで育てよう" % RunState.TARGET_DIAMETER, 20))
	goal_bar = ProgressBar.new()
	goal_bar.min_value = 0
	goal_bar.max_value = RunState.TARGET_DIAMETER
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size = Vector2(300, 18)
	goal_bar.add_theme_stylebox_override("background", _style(Color("e3e4cd"), 8))
	goal_bar.add_theme_stylebox_override("fill", _style(TEAL, 8))
	progress_box.add_child(goal_bar)
	var count_box: VBoxContainer = VBoxContainer.new()
	row.add_child(count_box)
	count_box.add_child(_label("巻き込んだ数", 16, TEAL))
	count_label = _label("", 30)
	count_box.add_child(count_label)
	var time_box: VBoxContainer = VBoxContainer.new()
	time_box.custom_minimum_size.x = 120
	row.add_child(time_box)
	time_box.add_child(_label("残り時間", 16, TEAL))
	timer_label = _label("", 35)
	time_box.add_child(timer_label)
	feedback = _label("", 25)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.position = Vector2(290, 157)
	feedback.size = Vector2(700, 50)
	feedback.add_theme_color_override("font_shadow_color", CREAM)
	feedback.add_theme_constant_override("shadow_offset_x", 2)
	feedback.add_theme_constant_override("shadow_offset_y", 2)
	add_child(feedback)


func _build_result() -> void:
	result_panel = _panel(self, Rect2(368, 152, 544, 432), CREAM)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	result_panel.add_child(column)
	column.add_child(_label("ころころ工房  /  今回の記録", 18, TEAL))
	result_heading = _label("", 42)
	column.add_child(result_heading)
	result_detail = _label("", 23)
	column.add_child(result_detail)
	retry_button = _button("もう一度転がす", func() -> void: start_requested.emit())
	column.add_child(retry_button)
	column.add_child(_button("タイトルへ戻る", func() -> void: title_requested.emit(), true))


func show_mode(mode: String) -> void:
	title_panel.visible = mode == "title"
	get_node("StageBadge").visible = mode == "title"
	play_panel.visible = mode == "playing"
	feedback.visible = mode == "playing"
	result_panel.visible = mode in ["won", "lost"]
	if mode == "title":
		start_button.grab_focus()
	elif mode in ["won", "lost"]:
		result_heading.text = "大きくなりました！" if mode == "won" else "時間になりました"
		result_heading.add_theme_color_override("font_color", TEAL if mode == "won" else CORAL)
		result_detail.text = (
			"到達直径  %.2f m\n巻き込んだ数  %d 個\n%s"
			% [
				RunState.diameter,
				RunState.collected,
				"目標達成。お部屋をひと玉に！" if mode == "won" else "次は小さなものから集めてみよう。"
			]
		)
		retry_button.grab_focus()


func update_values(effect: float, bump: float) -> void:
	diameter_label.text = "%.2f m" % RunState.diameter
	count_label.text = "%d 個" % RunState.collected
	var seconds: int = ceili(RunState.remaining)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	timer_label.add_theme_color_override("font_color", CORAL if seconds <= 30 else INK)
	goal_bar.value = RunState.diameter
	diameter_label.scale = Vector2.ONE * (1.0 + effect * 0.06)
	if bump > 0.0:
		feedback.text = "大きすぎる！ 小さなものを探そう"
	elif effect > 0.0:
		feedback.text = "巻き込んだ！  ぐんぐん成長中"
	else:
		feedback.text = "%.2f m 以下のものを巻き込めます" % (RunState.diameter * RunState.COLLECT_RATIO)
	sound_label.text = "F11 全画面   M 音：%s" % ("切" if AudioServer.is_bus_mute(0) else "入")


func _label(text: String, font_size: int, color: Color = INK) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style(color: Color, radius: int = 20) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


func _panel(parent: Node, bounds: Rect2, color: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = bounds.position
	panel.size = bounds.size
	var style: StyleBoxFlat = _style(color)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _button(text: String, action: Callable, secondary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 56
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_stylebox_override("normal", _style(Color("e8e7d6") if secondary else TEAL, 12))
	button.add_theme_stylebox_override("hover", _style(Color("45968c"), 12))
	button.add_theme_stylebox_override("pressed", _style(Color("195e5a"), 12))
	var focus: StyleBoxFlat = _style(Color.TRANSPARENT, 12)
	focus.set_border_width_all(3)
	focus.border_color = Color("e8ad54")
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", INK if secondary else CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.pressed.connect(action)
	return button
