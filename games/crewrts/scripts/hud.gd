extends CanvasLayer
## モデルを表示へ写す。ここに保持する数値はカウント演出の途中値だけ。

signal start_requested
signal map_requested
signal title_requested
signal tutorial_next_requested
signal tutorial_skip_requested

const INK: Color = Color("244b3d")
const MUTED: Color = Color("697761")
const PAPER: Color = Color("fbf5e1")
const ORANGE: Color = Color("bb5639")
const TEAL: Color = Color("367e87")
const GOLD: Color = Color("d3a449")
const PAPER_TEXTURE: Texture2D = preload("res://assets/textures/paper-grain.png")
const ISLAND_MAP: Texture2D = preload("res://assets/textures/island-map.png")
const RED_CREW: Texture2D = preload("res://assets/ui/crew-red.svg")
const BLUE_CREW: Texture2D = preload("res://assets/ui/crew-blue.svg")
const CRYSTAL: Texture2D = preload("res://assets/ui/crystal.svg")
const SUN: Texture2D = preload("res://assets/ui/sun.svg")
const WHISTLE: Texture2D = preload("res://assets/ui/whistle.svg")

var _root: Control
var _title: PanelContainer
var _title_memo: PanelContainer
var _map: Control
var _playing: Control
var _result: PanelContainer
var _pause: PanelContainer
var _tutorial: PanelContainer
var _tutorial_heading: Label
var _tutorial_body: Label
var _tutorial_page: Label
var _tutorial_next: Button
var _start: Button
var _map_depart: Button
var _retry: Button
var _progress: Label
var _timer: Label
var _crew: Label
var _kind: Label
var _context_label: Label
var _following: Label
var _red_count: Label
var _blue_count: Label
var _red_card: PanelContainer
var _blue_card: PanelContainer
var _result_heading: Label
var _result_body: Label
var _result_stamp: Label
var _time_bar: ProgressBar
var _toast: PanelContainer
var _toast_label: Label
var _toast_icon: TextureRect
var _flash: ColorRect
var _curtain: ColorRect
var _gems: Array[TextureRect] = []
var _phase: String = ""
var _targets: Dictionary = {}
var _display_values: Dictionary = {}
var _number_tweens: Dictionary = {}
var _button_tweens: Dictionary = {}
var _screen_tween: Tween
var _toast_tween: Tween
var _flash_tween: Tween
var _last_tutorial_page: int = -2


func setup(font: Font) -> void:
	if is_instance_valid(_root):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Theme.new()
	_root.theme.default_font = font
	add_child(_root)
	var paper: TextureRect = _icon(_root, PAPER_TEXTURE, Vector2(1280, 720))
	paper.position = Vector2.ZERO
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.modulate = Color(1, 1, 1, 0.08)
	paper.z_index = -1
	_build_title()
	_build_map()
	_build_playing()
	_curtain = _overlay(Color(0.06, 0.16, 0.11, 0.42))
	_curtain.visible = false
	_build_result()
	_build_pause()
	_build_tutorial()
	_build_effects()


func refresh(model: Node) -> void:
	var phase: String = str(model.get("phase"))
	var collected: int = int(model.get("collected"))
	var goal: int = int(model.get("goal"))
	var remaining: int = maxi(0, ceili(float(model.get("remaining"))))
	var crew: Array = model.get("crew")
	_count_to("progress", _progress, collected, "", " / %d" % goal)
	_timer.text = "%02d:%02d" % [remaining / 60, remaining % 60]
	_timer.add_theme_color_override("font_color", ORANGE if remaining < 60 else INK)
	_time_bar.max_value = float(model.DAY_SECONDS)
	_time_bar.value = float(model.get("remaining"))
	_refresh_crew(model, crew)
	for index: int in range(_gems.size()):
		_gems[index].modulate = Color.WHITE if index < collected else Color(0.65, 0.64, 0.51, 0.3)
	_result_heading.text = "おかえりなさい！" if phase == "clear" else "今日の探索はここまで"
	_result_stamp.text = "探索達成" if phase == "clear" else "探索終了"
	_result_body.text = "結晶を %d / %d 個 回収\n帰ってきた仲間  %d 人\n\n%s" % [
		collected, goal, crew.size(),
		"みんなの力で、庭の宝物が集まりました。" if phase == "clear"
		else "次はどの結晶から運びましょう？\n仲間と一緒に、もう一度出発。"]
	if _phase != phase:
		_show_phase(phase)
	_refresh_tutorial(int(model.get("tutorial_page")))


func set_context(message: String) -> void:
	if is_instance_valid(_context_label) and _context_label.text != message:
		_context_label.text = message


func set_paused(value: bool) -> void:
	_pause.visible = value
	_curtain.visible = value or _result.visible or _tutorial.visible


## イベントごとに演出を再生するため非冪等。ゲーム状態は変更しない。
func notify_event(event: String) -> void:
	match event:
		"delivery":
			_show_toast("結晶を回収！ 新しい仲間が到着", CRYSTAL, INK)
			_screen_flash(Color(1.0, 0.86, 0.4, 0.2))
		"defeat":
			_show_toast("庭の道が開けました", RED_CREW, ORANGE)
		"lost":
			_show_toast("仲間を失った！ 笛で隊列を集めよう", WHISTLE, ORANGE)
			_screen_flash(Color(0.87, 0.25, 0.13, 0.18))
		"whistle":
			_show_toast("笛の届く仲間が集まります", WHISTLE, TEAL)


func _refresh_crew(model: Node, crew: Array) -> void:
	var red: int = 0
	for member: Dictionary in crew:
		if int(member.kind) == 0:
			red += 1
	_count_to("following", _following, int(model.call("following_count")))
	_count_to("red", _red_count, red, "", " 人")
	_count_to("blue", _blue_count, crew.size() - red, "", " 人")
	_crew.text = "人が隊列にいます  /  仲間 %d 人" % crew.size()
	var selected: bool = int(model.get("selected_kind")) == 0
	_kind.text = "朱を投げる  /  Tab・X で切替" if selected else "青を投げる  /  Tab・X で切替"
	_kind.add_theme_color_override("font_color", ORANGE if selected else TEAL)
	_red_card.modulate = Color.WHITE if selected else Color(0.83, 0.83, 0.77)
	_blue_card.modulate = Color(0.83, 0.83, 0.77) if selected else Color.WHITE


## 表示対象が変わった時だけ Tween を開始し、同一状態の refresh では作り直さない。
func _count_to(key: String, label: Label, target: int, prefix: String = "",
		suffix: String = "") -> void:
	if _targets.has(key) and int(_targets[key]) == target:
		return
	if _number_tweens.has(key) and _number_tweens[key].is_valid():
		_number_tweens[key].kill()
	var previous: float = float(_display_values.get(key, target))
	_targets[key] = target
	if not _display_values.has(key) or _phase != "playing":
		_write_number(float(target), key, label, prefix, suffix)
		return
	var tween: Tween = create_tween()
	_number_tweens[key] = tween
	tween.tween_method(_write_number.bind(key, label, prefix, suffix), previous,
		float(target), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _write_number(value: float, key: String, label: Label, prefix: String,
		suffix: String) -> void:
	_display_values[key] = value
	label.text = prefix + str(roundi(value)) + suffix


func _show_phase(phase: String) -> void:
	_phase = phase
	if is_instance_valid(_screen_tween) and _screen_tween.is_valid():
		_screen_tween.kill()
	_title.visible = phase == "title"
	_title_memo.visible = phase == "title"
	_map.visible = phase == "map"
	_playing.visible = phase == "playing"
	_result.visible = phase == "clear" or phase == "failed"
	_tutorial.visible = phase == "playing" and _last_tutorial_page >= 0
	_curtain.visible = _result.visible or _tutorial.visible
	_toast.visible = false
	var target: Control = _playing
	if phase == "title":
		target = _title
		_start.grab_focus()
	elif phase == "map":
		target = _map
		_map_depart.grab_focus()
	elif _result.visible:
		target = _result
		_retry.grab_focus()
	else:
		_root.get_viewport().gui_release_focus()
	var settled: Vector2 = target.get_meta("settled_position", target.position)
	target.set_meta("settled_position", settled)
	target.position = settled + Vector2(0, 14)
	target.modulate.a = 0.0
	_screen_tween = create_tween().set_parallel(true)
	_screen_tween.tween_property(target, "modulate:a", 1.0, 0.36)
	_screen_tween.tween_property(target, "position", settled, 0.42).set_trans(
		Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh_tutorial(page: int) -> void:
	if page == _last_tutorial_page:
		return
	_last_tutorial_page = page
	_tutorial.visible = _phase == "playing" and page >= 0
	_curtain.visible = _result.visible or _pause.visible or _tutorial.visible
	if page < 0:
		return
	var pages: Array[Dictionary] = [
		{
			"title": "1頁目　隊長を歩かせる",
			"body": "　W A S D　　　　　　Q　E\n　　↑　　　　　　　←　→\n"
				+ "　←　→　で移動　　 見回す\n　　↓\n\nまずは足もとの橙色の照準を、\n"
				+ "近くの結晶へ重ねてみよう。",
		},
		{
			"title": "2頁目　仲間を結晶へ送る",
			"body": "　仲間　 ──投げる──→　◇ 0 / 2\n　Space・A・左クリック\n\n"
				+ "結晶の数字ぶん仲間が集まると、\n自分たちで基地まで運び始める。\n"
				+ "青い仲間は運搬が速い。",
		},
		{
			"title": "3頁目　迷ったら笛",
			"body": "　　)) ♪ ((　　　みんな集合！\n　Shift・B・右クリック\n\n"
				+ "R・Y で隊列をほどく。\nTab・X で投げる仲間を選ぶ。\n"
				+ "右の鉛筆メモが次の一手を教える。",
		},
	]
	_tutorial_heading.text = pages[page].title
	_tutorial_body.text = pages[page].body
	_tutorial_page.text = "%d / 3" % (page + 1)
	_tutorial_next.text = "探索を始める  →" if page == 2 else "次の頁へ  →"
	_tutorial_next.grab_focus()


## トーストは最新の出来事へ切り替え、古い Tween を終了して表示の競合を防ぐ。
func _show_toast(message: String, icon: Texture2D, color: Color) -> void:
	if is_instance_valid(_toast_tween) and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", color)
	_toast_icon.texture = icon
	_toast.visible = true
	_toast.position = Vector2(415, 16)
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.16)
	_toast_tween.tween_property(_toast, "position:y", 30.0, 0.22).set_trans(Tween.TRANS_BACK)
	_toast_tween.chain().tween_interval(2.3)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.chain().tween_callback(_toast.hide)


## 被弾と回収の短いフラッシュはイベント発生ごとに再生する。
func _screen_flash(color: Color) -> void:
	if is_instance_valid(_flash_tween) and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.3)


# 画面構築はノードを追加するため非冪等。setup の生成済みガード内で一度だけ呼ぶ。
func _build_title() -> void:
	_title = _panel(_root, Vector2(70, 58), Vector2(535, 605))
	_title.rotation = -0.012
	var box: VBoxContainer = _column(_title, 30, 12)
	_label(box, "探検ノート　　朝のしおり", 17, MUTED)
	var heading: Label = _label(box, "こもれび\n回収隊", 70)
	heading.add_theme_constant_override("line_spacing", -12)
	_label(box, "小さな仲間と、島の宝物を運ぶ日。", 22, INK)
	var rule: HSeparator = HSeparator.new()
	rule.add_theme_constant_override("separation", 3)
	box.add_child(rule)
	_label(box, "きょうの目的", 17, ORANGE)
	_label(box, "日暮れまでに  結晶を 5 個\n仲間へ合図し、基地へ持ち帰る。", 21, MUTED)
	_spacer(box)
	_start = _button(box, "島の絵地図をひらく  →", ORANGE)
	_start.custom_minimum_size.y = 64
	_start.pressed.connect(func() -> void: map_requested.emit())
	_label(box, "Enter / A でノートをめくる", 14, MUTED).horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER
	_title_memo = _panel(_root, Vector2(735, 455), Vector2(420, 145))
	_title_memo.rotation = 0.025
	var memo_box: VBoxContainer = _column(_title_memo, 18, 5)
	_label(memo_box, "隊長の走り書き", 16, TEAL)
	_label(memo_box, "『ひとりでは運べない。\n　だから、みんなで行く。』", 25, INK)


func _build_map() -> void:
	_map = Control.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_map)
	var art: TextureRect = _icon(_map, ISLAND_MAP, Vector2(1280, 720))
	art.position = Vector2.ZERO
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var heading_note: PanelContainer = _panel(_map, Vector2(38, 28), Vector2(310, 92))
	heading_note.rotation = -0.018
	var heading_box: VBoxContainer = _column(heading_note, 13, 1)
	_label(heading_box, "島の絵地図", 32, INK)
	_label(heading_box, "行き先を選ぶ", 15, MUTED)
	var garden: Button = _map_marker(_map, Vector2(250, 480), "陽だまりの庭\n選べます", ORANGE, false)
	garden.pressed.connect(func() -> void: _map_depart.grab_focus())
	var marsh: Button = _map_marker(_map, Vector2(875, 205), "しずく沼\n霧が深くて進めない", TEAL, true)
	marsh.tooltip_text = "調査道具が足りません"
	var hill: Button = _map_marker(_map, Vector2(370, 175), "あかね丘\n橋がまだ架かっていない", ORANGE, true)
	hill.tooltip_text = "橋を直すまで選べません"
	var preview: PanelContainer = _panel(_map, Vector2(855, 405), Vector2(375, 260))
	preview.rotation = 0.012
	var preview_box: VBoxContainer = _column(preview, 20, 6)
	_label(preview_box, "○ 陽だまりの庭", 25, ORANGE)
	_label(preview_box, "結晶 5 個　／　仲間 30 人\n朝の庭で運搬と戦闘を学ぶ。", 17, INK)
	_label(preview_box, "ここへ行くと短い操作ノートが開きます。", 14, MUTED)
	_map_depart = _button(preview_box, "この庭を調査する  →", ORANGE)
	_map_depart.pressed.connect(func() -> void: start_requested.emit())
	_map_depart.focus_neighbor_left = garden.get_path()
	garden.focus_neighbor_right = _map_depart.get_path()
	var back: Button = _button(preview_box, "表紙へ戻る", TEAL)
	back.pressed.connect(func() -> void: title_requested.emit())
	_map.visible = false


func _build_playing() -> void:
	_playing = Control.new()
	_playing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_playing)
	_build_progress()
	_build_timer()
	_build_team()
	var guide: PanelContainer = _panel(_playing, Vector2(940, 505), Vector2(305, 148))
	guide.rotation = -0.013
	var guide_box: VBoxContainer = _column(guide, 15, 4)
	_label(guide_box, "鉛筆メモ　次の一手", 17, TEAL)
	_context_label = _label(guide_box, "橙の照準を結晶へ重ねる。", 16, INK)
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(guide_box, "Esc / Start でノートを閉じて休憩", 12, MUTED)


func _build_progress() -> void:
	var panel: PanelContainer = _panel(_playing, Vector2(28, 24), Vector2(304, 123))
	var box: VBoxContainer = _column(panel, 0, 0)
	_label(box, "今日の目標  /  結晶を拠点へ", 13, MUTED)
	var row: HBoxContainer = _row(box, 12)
	_icon(row, CRYSTAL, Vector2(47, 47))
	_progress = _label(row, "", 35, INK)
	var gems: HBoxContainer = _row(box, 6)
	_label(gems, "回収記録", 11, MUTED)
	for index: int in range(5):
		_gems.append(_icon(gems, CRYSTAL, Vector2(23, 23)))


func _build_timer() -> void:
	var panel: PanelContainer = _panel(_playing, Vector2(1016, 24), Vector2(236, 110))
	var box: VBoxContainer = _column(panel, 0, 3)
	var row: HBoxContainer = _row(box, 11)
	_icon(row, SUN, Vector2(42, 42))
	var time_box: VBoxContainer = _column(row, 0, 0)
	_label(time_box, "日暮れまで", 12, MUTED)
	_timer = _label(time_box, "", 30)
	_time_bar = ProgressBar.new()
	_time_bar.custom_minimum_size = Vector2(194, 7)
	_time_bar.show_percentage = false
	_time_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_bar.add_theme_stylebox_override("fill", _style(GOLD, 4, 0))
	box.add_child(_time_bar)


func _build_team() -> void:
	var team: PanelContainer = _panel(_playing, Vector2(28, 479), Vector2(398, 159))
	var box: VBoxContainer = _column(team, 0, 2)
	var row: HBoxContainer = _row(box, 8)
	_following = _label(row, "", 28)
	_crew = _label(row, "", 13, MUTED)
	_crew.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cards: HBoxContainer = _row(box, 8)
	_red_card = _crew_card(cards, RED_CREW, ORANGE, "朱 / 攻撃")
	_red_count = _red_card.get_meta("count_label")
	_blue_card = _crew_card(cards, BLUE_CREW, TEAL, "青 / 運搬")
	_blue_count = _blue_card.get_meta("count_label")
	_kind = _label(box, "", 12, ORANGE)


func _crew_card(parent: Node, texture: Texture2D, color: Color, title: String) -> PanelContainer:
	var card: PanelContainer = _panel(parent, Vector2.ZERO, Vector2.ZERO)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = _style(color.lightened(0.82), 12, 5)
	style.border_color = color.lightened(0.45)
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = _row(card, 4)
	_icon(row, texture, Vector2(49, 51))
	var box: VBoxContainer = _column(row, 0, 0)
	_label(box, title, 11, color)
	card.set_meta("count_label", _label(box, "", 19, color))
	return card


func _build_result() -> void:
	_result = _panel(_root, Vector2(380, 105), Vector2(520, 510))
	var box: VBoxContainer = _column(_result, 14, 12)
	_label(box, "探検ノート　／　今日のまとめ", 15, MUTED)
	_result_stamp = _label(box, "", 26, ORANGE)
	_result_heading = _label(box, "", 28)
	_result_body = _label(box, "", 17, MUTED)
	_result_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_retry = _button(box, "もう一度、庭へ    →", INK)
	_retry.pressed.connect(func() -> void: start_requested.emit())
	var back: Button = _button(box, "タイトルへ戻る", TEAL)
	back.pressed.connect(func() -> void: title_requested.emit())
	_retry.focus_neighbor_bottom = back.get_path()
	back.focus_neighbor_top = _retry.get_path()


func _build_pause() -> void:
	_pause = _panel(_root, Vector2(420, 258), Vector2(440, 204))
	var box: VBoxContainer = _column(_pause, 12, 12)
	_label(box, "ひとやすみ", 34).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(box, "庭の時間も、ひと休み。", 16, MUTED).horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER
	_label(box, "Esc / Start で探索を再開", 16, TEAL).horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER
	_pause.visible = false


func _build_tutorial() -> void:
	_tutorial = _panel(_root, Vector2(265, 70), Vector2(750, 580))
	_tutorial.rotation = -0.006
	var box: VBoxContainer = _column(_tutorial, 34, 12)
	var header: HBoxContainer = _row(box, 12)
	_tutorial_heading = _label(header, "", 29, INK)
	_tutorial_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_page = _label(header, "", 17, MUTED)
	var rule: HSeparator = HSeparator.new()
	box.add_child(rule)
	_tutorial_body = _label(box, "", 24, INK)
	_tutorial_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tutorial_body.add_theme_constant_override("line_spacing", 8)
	var actions: HBoxContainer = _row(box, 12)
	var skip: Button = _button(actions, "説明を飛ばす", TEAL)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(func() -> void: tutorial_skip_requested.emit())
	_tutorial_next = _button(actions, "次の頁へ  →", ORANGE)
	_tutorial_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_next.pressed.connect(func() -> void: tutorial_next_requested.emit())
	_tutorial.visible = false


func _build_effects() -> void:
	_flash = _overlay(Color.TRANSPARENT)
	_toast = _panel(_root, Vector2(415, 30), Vector2(450, 64))
	_toast.add_theme_stylebox_override("panel", _style(PAPER, 30, 12))
	var row: HBoxContainer = _row(_toast, 10)
	_toast_icon = _icon(row, CRYSTAL, Vector2(38, 38))
	_toast_label = _label(row, "", 16)
	_toast_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_toast.visible = false


# 構築ヘルパーは呼び出しごとに別の表示要素を生成するため非冪等。
func _panel(parent: Node, position: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = position
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _paper_style(12))
	parent.add_child(panel)
	return panel


func _column(parent: Node, inset: int, separation: int = 8) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, inset)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	return column


func _row(parent: Node, separation: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	return row


func _label(parent: Node, text: String, font_size: int, color: Color = INK) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _icon(parent: Node, texture: Texture2D, dimensions: Vector2) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = dimensions
	icon.size = dimensions
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(icon)
	return icon


func _spacer(parent: Node) -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func _overlay(color: Color) -> ColorRect:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = color
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(overlay)
	return overlay


func _button(parent: Node, text: String, color: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 49
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill: Color = Color(0.99, 0.97, 0.88, 0.94)
		if state == "hover":
			fill = color.lightened(0.72)
		elif state == "disabled":
			fill = Color(0.79, 0.78, 0.70, 0.68)
		var style: StyleBoxFlat = _style(fill, 5, 10)
		style.border_color = color
		style.set_border_width_all(2)
		if state == "pressed":
			style.bg_color = color.lightened(0.58)
		if state == "focus":
			style.bg_color = color.lightened(0.78)
			style.border_color = ORANGE
			style.set_border_width_all(4)
			style.expand_margin_left = 3
			style.expand_margin_right = 3
			style.expand_margin_top = 3
			style.expand_margin_bottom = 3
		button.add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, color.darkened(0.18))
	button.add_theme_color_override("font_disabled_color", Color(0.35, 0.38, 0.36, 0.86))
	button.mouse_entered.connect(_button_motion.bind(button, 1.025))
	button.mouse_exited.connect(_button_motion.bind(button, 1.0))
	button.button_down.connect(_button_motion.bind(button, 0.97))
	button.button_up.connect(_button_motion.bind(button, 1.0))
	parent.add_child(button)
	return button


func _map_marker(parent: Node, position: Vector2, text: String, color: Color,
		disabled: bool) -> Button:
	var marker: Button = _button(parent, text, color)
	marker.position = position
	marker.size = Vector2(250, 74)
	marker.custom_minimum_size = marker.size
	marker.disabled = disabled
	marker.mouse_filter = Control.MOUSE_FILTER_STOP
	return marker


func _paper_style(padding: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PAPER_TEXTURE
	style.texture_margin_left = 18.0
	style.texture_margin_right = 18.0
	style.texture_margin_top = 18.0
	style.texture_margin_bottom = 18.0
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


## ホバー・押下の入力ごとに短い拡縮を再生するため非冪等。
func _button_motion(button: Button, amount: float) -> void:
	if _button_tweens.has(button) and _button_tweens[button].is_valid():
		_button_tweens[button].kill()
	button.pivot_offset = button.size / 2.0
	var tween: Tween = create_tween()
	_button_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2.ONE * amount, 0.14).set_trans(Tween.TRANS_CUBIC)


func _style(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
