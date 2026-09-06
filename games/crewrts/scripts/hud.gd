extends CanvasLayer
## ゲーム状態を保持せず、モデルを日本語の操作案内と進捗へ写す。

signal start_requested
signal title_requested

const INK: Color = Color("263f37")
const MUTED: Color = Color("65776c")
const PAPER: Color = Color(0.97, 0.96, 0.90, 0.95)
const ORANGE: Color = Color("c95c35")
const TEAL: Color = Color("237e80")

var _root: Control
var _title: PanelContainer
var _playing: Control
var _result: PanelContainer
var _pause: PanelContainer
var _start: Button
var _retry: Button
var _progress: Label
var _timer: Label
var _crew: Label
var _kind: Label
var _result_heading: Label
var _result_body: Label
var _phase: String = ""


func setup(font: Font) -> void:
	if is_instance_valid(_root):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme: Theme = Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", INK)
	_root.theme = ui_theme
	add_child(_root)
	_build_title()
	_build_playing()
	_build_result()
	_build_pause()


func refresh(model: Node) -> void:
	var phase: String = str(model.get("phase"))
	var collected: int = int(model.get("collected"))
	var goal: int = int(model.get("goal"))
	var remaining: int = maxi(0, ceili(float(model.get("remaining"))))
	var crew: Array = model.get("crew")
	var living: int = crew.size()
	_progress.text = "回収した結晶   %d / %d" % [collected, goal]
	_timer.text = "日暮れまで   %02d:%02d" % [remaining / 60, remaining % 60]
	_timer.add_theme_color_override("font_color", ORANGE if remaining < 60 else INK)
	_crew.text = "隊列 %d 人  /  仲間 %d 人" % [int(model.call("following_count")), living]
	var red_selected: bool = int(model.get("selected_kind")) == 0
	_kind.text = "● 朱の仲間  /  攻撃が得意" if red_selected else "● 青の仲間  /  運搬が得意"
	_kind.add_theme_color_override("font_color", ORANGE if red_selected else TEAL)
	_result_heading.text = "おかえりなさい！" if phase == "clear" else "今日の探索はここまで"
	_result_body.text = "結晶を %d / %d 個 回収\n帰ってきた仲間  %d 人\n\n%s" % [
		collected, goal, living,
		"みんなの力で、庭の宝物が集まりました。" if phase == "clear"
		else "仲間を集めて、もう一度出かけましょう。"]
	if _phase == phase:
		return
	_phase = phase
	_title.visible = phase == "title"
	_playing.visible = phase == "playing"
	_result.visible = phase == "clear" or phase == "failed"
	if phase == "title":
		_start.grab_focus()
	elif _result.visible:
		_retry.grab_focus()
	else:
		_root.get_viewport().gui_release_focus()


func set_paused(value: bool) -> void:
	_pause.visible = value


# 画面構築はノードを追加するため非冪等。setup の生成済みガード内から一度だけ呼ぶ。
func _build_title() -> void:
	_title = _panel(_root, Vector2(48, 32), Vector2(480, 656))
	var box: VBoxContainer = _column(_title, 12)
	box.add_theme_constant_override("separation", 10)
	_label(box, "庭の調査記録  /  01", 15, TEAL)
	var heading: Label = _label(box, "こもれび\n回収隊", 56)
	heading.add_theme_constant_override("line_spacing", -10)
	_label(box, "小さな仲間と、大きな冒険。", 20)
	_label(box, "日暮れまでに結晶を 5 個、拠点へ。\n仲間を投げて任せ、笛で呼び戻そう。", 16, MUTED)
	_start = _button(box, "庭へ出発する   →", ORANGE)
	_start.custom_minimum_size.y = 54
	_start.pressed.connect(func() -> void: start_requested.emit())
	_label(box, "移動  WASD / 左スティック\n視点  Q・E / 右スティック"
		+ "\n投げる  左クリック・Space / A\n笛  右クリック・Shift / B", 14, MUTED)
	_label(box, "解散  R / Y    種類切替  Tab / X\n休憩  Esc / Start    全画面  F11    出発  Enter", 13, MUTED)
	var space: Control = Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(space)
	_label(box, "素材: 独自生成 / 書体: M PLUS Rounded 1c (OFL)", 11, MUTED)


# 画面構築はノード追加を伴うため一度だけ呼ぶ。
func _build_playing() -> void:
	_playing = Control.new()
	_playing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_playing)
	var top: PanelContainer = _panel(_playing, Vector2(28, 24), Vector2(1224, 76))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	top.add_child(row)
	_label(row, "こもれび回収隊", 23)
	_progress = _label(row, "", 22, TEAL)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer = _label(row, "", 20)
	var guide: PanelContainer = _panel(_playing, Vector2(956, 124), Vector2(296, 142))
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var guide_box: VBoxContainer = _column(guide, 0)
	_label(guide_box, "庭の歩き方", 17, TEAL)
	_label(guide_box, "結晶へ照準 → 必要な人数を投げる\n青の仲間は運搬が速い\n笛で仕事中の仲間も集合", 14, MUTED)
	var team: PanelContainer = _panel(_playing, Vector2(28, 548), Vector2(344, 96))
	team.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var team_box: VBoxContainer = _column(team, 0)
	_crew = _label(team_box, "", 19)
	_kind = _label(team_box, "", 17, ORANGE)
	var footer: PanelContainer = _panel(_playing, Vector2(28, 658), Vector2(1224, 42))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var help: Label = _label(footer,
		"移動 WASD / 左スティック     視点 Q E / 右スティック     投げる 左クリック / A"
		+ "     笛 右クリック / B     解散 R / Y     切替 Tab / X     休憩 Esc / Start", 13)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# 画面構築はノード追加を伴うため一度だけ呼ぶ。
func _build_result() -> void:
	_result = _panel(_root, Vector2(390, 136), Vector2(500, 448))
	var box: VBoxContainer = _column(_result, 24)
	box.add_theme_constant_override("separation", 20)
	_label(box, "庭の調査記録  /  探索結果", 16, TEAL)
	_result_heading = _label(box, "", 30)
	_result_body = _label(box, "", 17, MUTED)
	_result_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_retry = _button(box, "もう一度、庭へ", ORANGE)
	_retry.pressed.connect(func() -> void: start_requested.emit())
	var back: Button = _button(box, "タイトルへ戻る", TEAL)
	back.pressed.connect(func() -> void: title_requested.emit())
	_retry.focus_neighbor_bottom = back.get_path()
	back.focus_neighbor_top = _retry.get_path()


# 画面構築はノード追加を伴うため一度だけ呼ぶ。
func _build_pause() -> void:
	_pause = _panel(_root, Vector2(440, 288), Vector2(400, 144))
	var box: VBoxContainer = _column(_pause, 12)
	_label(box, "ひとやすみ", 32).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(box, "Esc / Start で探索を再開", 17, MUTED).horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER
	_pause.visible = false


# 以下の構築ヘルパーは呼び出しごとに別の表示要素を生成するため非冪等。
func _panel(parent: Node, position: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = position
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _style(PAPER, 20, 18))
	parent.add_child(panel)
	return panel


func _column(parent: Node, inset: int) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, inset)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	return column


func _label(parent: Node, text: String, font_size: int, color: Color = INK) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, color: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var fill: Color = color.lightened(0.12) if state == "hover" else color
		var style: StyleBoxFlat = _style(fill, 12, 10)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = INK
			style.set_border_width_all(3)
			style.expand_margin_left = 4
			style.expand_margin_right = 4
			style.expand_margin_top = 4
			style.expand_margin_bottom = 4
		button.add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("fffaf0"))
	parent.add_child(button)
	return button


func _style(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
