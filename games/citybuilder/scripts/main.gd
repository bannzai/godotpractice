extends Control
## 画面と入力を接続する。都市の状態は City が保持する。

const UI = preload("res://scripts/ui.gd")
const View = preload("res://scripts/city_view.gd")
const Sim = preload("res://scripts/simulation.gd")
const TOOLS: Array[String] = [
	"road", "residential", "commercial", "industrial", "power", "park", "police", "fire", "empty"
]
const NAMES: Array[String] = ["道路", "住宅", "商業", "工業", "発電所", "公園", "警察", "消防", "撤去"]
const OVERLAYS: Array[String] = ["none", "power", "pollution", "crime", "fire"]
const OVERLAY_NAMES: Array[String] = ["通常", "電力", "公害", "犯罪", "防火"]

var screen: Control
var view: Control
var selected_tool: int = 1
var overlay_index: int = 0
var stats: Label
var needs: Label
var warnings: Label
var tool_description: Label
var time_label: Label
var toast: Label
var tax_label: Label
var demand_bars: Array[ProgressBar] = []
var tool_buttons: Array[Button] = []
var toast_tween: Tween
var transition: Tween
var displayed_population: float = 0.0
var dragging: bool = false
var last_cell: Vector2i = Vector2i(-1, -1)
var closing: bool = false
var keyboard_cursor: bool = false


func _ready() -> void:
	print("citybuilder boot")
	get_tree().auto_accept_quit = false
	theme = UI.make_theme()
	City.phase_changed.connect(_render)
	City.changed.connect(_refresh)
	City.notice.connect(_show_notice)
	_render()


func _render() -> void:
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	view = null
	tool_buttons.clear()
	demand_bars.clear()
	match City.phase:
		"title":
			_title()
		"playing":
			_play()
		"result":
			_result()
	if is_instance_valid(transition):
		transition.kill()
	screen.modulate.a = 0.0
	transition = create_tween()
	transition.tween_property(screen, "modulate:a", 1.0, 0.3)


func _title() -> void:
	UI.picture(screen, "branding/keyart.svg", Rect2(0, 0, 1280, 720))
	UI.panel(screen, Rect2(48, 52, 540, 612), Color("203c42ed"))
	UI.label(screen, "小さな区画から、暮らしのある街へ。", Rect2(80, 82, 480, 36), 19, UI.MINT)
	UI.label(screen, "こもれび\n市計画", Rect2(78, 133, 480, 180), 68)
	UI.label(screen, "道路をつなぐ。仕事を生む。\n緑を残して、600人の故郷をつくろう。", Rect2(82, 341, 460, 72), 22)
	var start: Button = UI.button(screen, "新しい街をつくる   →", Rect2(82, 445, 442, 58), _start)
	start.grab_focus()
	var resume: Button = UI.button(screen, "保存した街から再開", Rect2(82, 515, 286, 50), _resume)
	resume.disabled = City.saved_city().is_empty()
	UI.button(screen, "終了", Rect2(380, 515, 144, 50), _request_quit)
	UI.label(
		screen,
		"Enter / A 決定　　方向キー / 十字キー 選択\nF11 全画面　　M 音の切替",
		Rect2(82, 587, 464, 58),
		15,
		UI.MUTED
	)
	UI.label(screen, "こもれび湾  /  都市計画室", Rect2(858, 636, 370, 40), 22, UI.INK)
	Sound.track("title")


func _play() -> void:
	UI.panel(screen, Rect2(0, 0, 1280, 720), Color("e8e6d6"))
	UI.panel(screen, Rect2(16, 16, 1248, 78))
	UI.label(screen, "こもれび市", Rect2(34, 24, 170, 32), 25, UI.MINT)
	UI.label(screen, "都市計画室", Rect2(34, 59, 170, 24), 14, UI.MUTED)
	stats = UI.label(screen, "", Rect2(220, 26, 800, 54), 23)
	UI.button(screen, "保存・戻る", Rect2(1103, 32, 141, 46), _save_and_title)
	view = View.new()
	view.position = Vector2(16, 106)
	view.size = Vector2(932, 494)
	screen.add_child(view)
	view.gui_input.connect(_map_input)
	UI.panel(screen, Rect2(960, 106, 304, 494))
	UI.label(screen, "街の設計", Rect2(980, 118, 264, 38), 25)
	tool_description = UI.label(screen, "", Rect2(980, 163, 264, 50), 18, UI.MINT)
	UI.label(screen, "需要  /  余力がある区画ほど成長", Rect2(980, 217, 268, 26), 14, UI.MUTED)
	for index: int in range(3):
		UI.label(screen, ["住宅", "商業", "工業"][index], Rect2(980, 250 + index * 34, 50, 26), 15)
		var bar := ProgressBar.new()
		bar.position = Vector2(1038, 259 + index * 34)
		bar.size = Vector2(204, 10)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", UI.box(Color("3c5454")))
		bar.add_theme_stylebox_override("fill", UI.box([UI.MINT, UI.CORAL, Color("eccb7c")][index]))
		screen.add_child(bar)
		demand_bars.append(bar)
	needs = UI.label(screen, "", Rect2(980, 357, 265, 54), 16)
	tax_label = UI.label(screen, "", Rect2(980, 421, 266, 26), 16)
	var tax := HSlider.new()
	tax.position = Vector2(980, 459)
	tax.size = Vector2(262, 22)
	tax.min_value = 0
	tax.max_value = 20
	tax.step = 1
	tax.value = City.state.tax
	tax.value_changed.connect(City.set_tax)
	screen.add_child(tax)
	warnings = UI.label(screen, "", Rect2(980, 503, 265, 82), 14, UI.CORAL)
	warnings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_time_controls()
	_toolbar()
	toast = UI.label(screen, "道路に接する区画へ、電力と仕事を。", Rect2(36, 551, 886, 32), 18, UI.INK)
	_refresh()
	Sound.track("city" if City.state.population >= 300 else "town")


func _time_controls() -> void:
	UI.panel(screen, Rect2(28, 117, 616, 44), Color("f4f0dfed"))
	for index: int in range(3):
		UI.button(
			screen,
			["Ⅱ", "1倍", "3倍"][index],
			Rect2(36 + index * 58, 123, 52, 32),
			_set_speed.bind([0, 1, 3][index])
		)
	time_label = UI.label(screen, "", Rect2(221, 125, 164, 30), 14, UI.INK)
	UI.button(screen, "翌月 N", Rect2(377, 123, 94, 32), City.next_month)
	UI.button(screen, "問題表示 O", Rect2(479, 123, 147, 32), _cycle_overlay)


func _toolbar() -> void:
	for index: int in range(TOOLS.size()):
		var button: Button = UI.button(
			screen,
			"%s\n%d" % [NAMES[index], Sim.COSTS[TOOLS[index]]],
			Rect2(16 + index * 105, 614, 97, 64),
			_select_tool.bind(index)
		)
		button.add_theme_font_size_override("font_size", 17)
		tool_buttons.append(button)
	UI.button(screen, "－", Rect2(972, 616, 54, 56), _zoom_by.bind(-0.15))
	UI.button(screen, "＋", Rect2(1034, 616, 54, 56), _zoom_by.bind(0.15))
	UI.button(screen, "街の中央", Rect2(1096, 616, 168, 56), _center_map)
	UI.label(
		screen,
		"ドラッグ 建設  /  右ドラッグ 移動  /  ホイール 拡大　　矢印 カーソル・Enter/A 建設　Q/E・LB/RB 道具　Space/Start 時間　O/Y 問題",
		Rect2(18, 690, 1240, 22),
		12,
		UI.INK
	)


func _result() -> void:
	UI.picture(screen, "branding/keyart.svg", Rect2(0, 0, 1280, 720))
	UI.panel(screen, Rect2(240, 93, 800, 534), Color("203c42f5"))
	var won: bool = City.state.outcome == "clear"
	UI.label(screen, "こもれび市  /  最終報告", Rect2(294, 128, 690, 36), 22, UI.MINT)
	UI.label(screen, "暮らしが、街になった。" if won else "街の灯を、もう一度。", Rect2(294, 200, 700, 70), 39)
	UI.label(
		screen,
		"人口600人を達成しました" if won else "資金不足が3か月続き、運営を終了しました",
		Rect2(294, 286, 698, 44),
		22,
		UI.CORAL
	)
	UI.label(
		screen,
		(
			"到達人口  %d人    /    経過  %dか月\n雇用  %d人分    /    最終資金  %d"
			% [City.state.population, City.state.month, City.state.jobs, City.state.money]
		),
		Rect2(294, 356, 692, 90),
		24
	)
	UI.label(screen, "道路・電力・雇用のバランスを、次の街でも。", Rect2(294, 456, 692, 32), 18, UI.MUTED)
	var button: Button = UI.button(screen, "タイトルへ戻る", Rect2(294, 531, 692, 56), _return_title)
	button.grab_focus()
	Sound.track("result")


func _refresh() -> void:
	if City.phase != "playing" or not is_instance_valid(view):
		return
	view.set_city(City.state, City.analysis)
	stats.text = (
		"資金  %s    人口  %d / 600    雇用  %d    %d月"
		% [City.state.money, int(displayed_population), City.state.jobs, City.state.month]
	)
	tool_description.text = (
		"%s  /  費用 %d\n%s"
		% [
			NAMES[selected_tool],
			Sim.COSTS[TOOLS[selected_tool]],
			"区画は道路と電力で成長" if selected_tool in [1, 2, 3] else "クリック・決定で配置"
		]
	)
	var demands: Dictionary = City.analysis.get("demand", City.state.demand)
	for index: int in range(3):
		demand_bars[index].value = float(demands.get(["r", "c", "i"][index], 0))
	needs.text = (
		"電力  %d / %d\n収入 %+d   維持費 −%d"
		% [
			City.analysis.get("power_used", 0),
			City.analysis.get("capacity", 0),
			City.state.income,
			City.state.expenses
		]
	)
	tax_label.text = "税率  %d%%  /  高税率で成長鈍化" % City.state.tax
	warnings.text = "\n".join(City.analysis.get("warnings", []))
	if warnings.text.is_empty():
		warnings.text = "街は順調です。住宅と雇用を増やしましょう。"
	time_label.text = (
		"%s / %s" % ["停止" if City.speed == 0 else "%d倍" % City.speed, OVERLAY_NAMES[overlay_index]]
	)
	for index: int in range(tool_buttons.size()):
		tool_buttons[index].modulate = UI.MINT if index == selected_tool else Color.WHITE
	Sound.track("city" if City.state.population >= 300 else "town")


# 表示の補間は時間経過を積算するため非冪等。
func _process(delta: float) -> void:
	if City.phase != "playing" or not is_instance_valid(stats):
		return
	displayed_population = move_toward(
		displayed_population, float(City.state.population), delta * 160
	)
	stats.text = (
		"資金  %s    人口  %d / 600    雇用  %d    %d月"
		% [City.state.money, int(displayed_population), City.state.jobs, City.state.month]
	)


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(0.1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(-0.1)
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			last_cell = Vector2i(-1, -1)
			if dragging:
				_paint(event.position)
	if event is InputEventMouseMotion:
		keyboard_cursor = false
		view.cursor = view.screen_to_cell(event.position)
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			view.pan += event.relative
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT and dragging:
			_paint(event.position)
		view.queue_redraw()


func _paint(point: Vector2) -> void:
	var cell: Vector2i = view.screen_to_cell(point)
	if cell == last_cell:
		return
	last_cell = cell
	_place(cell)


func _place(cell: Vector2i) -> void:
	if City.build(cell, TOOLS[selected_tool]):
		view.burst(cell, selected_tool == 8)
		Sound.play("demolish" if selected_tool == 8 else "build")
	else:
		Sound.play("alert")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	if event.is_action_pressed("mute"):
		Sound.set_muted(not Sound.muted)
	if City.phase != "playing":
		return
	if event.is_action_pressed("tool_next"):
		_select_tool((selected_tool + 1) % TOOLS.size())
	if event.is_action_pressed("tool_previous"):
		_select_tool(posmod(selected_tool - 1, TOOLS.size()))
	if event.is_action_pressed("pause_time"):
		_set_speed(1 if City.speed == 0 else 0)
	if event.is_action_pressed("next_month"):
		City.next_month()
	if event.is_action_pressed("overlay"):
		_cycle_overlay()
	if event.is_action_pressed("zoom_in"):
		_zoom_by(0.1)
	if event.is_action_pressed("zoom_out"):
		_zoom_by(-0.1)
	if event.is_action_pressed("ui_cancel"):
		_save_and_title()
	for direction: String in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		if event.is_action_pressed(direction):
			var offset: Vector2i = {
				"ui_left": Vector2i.LEFT,
				"ui_right": Vector2i.RIGHT,
				"ui_up": Vector2i.UP,
				"ui_down": Vector2i.DOWN
			}[direction]
			view.cursor = (view.cursor + offset).clamp(Vector2i.ZERO, Vector2i(31, 31))
			keyboard_cursor = true
			_follow_cursor()
	if event.is_action_pressed("build"):
		_place(view.cursor)
		get_viewport().set_input_as_handled()


func _follow_cursor() -> void:
	var point: Vector2 = view.cell_to_screen(view.cursor)
	view.pan += Vector2(clampf(point.x, 60, 860), clampf(point.y, 84, 426)) - point
	view.queue_redraw()


func _select_tool(index: int) -> void:
	selected_tool = index
	# 道具を選んだあと方向キーがボタンに奪われないよう地図へ戻す。
	get_viewport().gui_release_focus()
	_refresh()
	Sound.play("click")


func _set_speed(value: int) -> void:
	City.speed = value
	get_viewport().gui_release_focus()
	_refresh()


func _cycle_overlay() -> void:
	overlay_index = (overlay_index + 1) % OVERLAYS.size()
	view.overlay = OVERLAYS[overlay_index]
	get_viewport().gui_release_focus()
	_refresh()


func _zoom_by(amount: float) -> void:
	view.zoom = clampf(view.zoom + amount, 0.55, 1.7)
	get_viewport().gui_release_focus()
	view.queue_redraw()


func _center_map() -> void:
	view.pan = Vector2(-45, -185)
	view.zoom = 1.0
	view.queue_redraw()
	get_viewport().gui_release_focus()


func _show_notice(message: String) -> void:
	if City.phase != "playing" or not is_instance_valid(toast):
		return
	if is_instance_valid(toast_tween):
		toast_tween.kill()
	toast.text = message
	toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(2.4)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	if message.contains("収支"):
		Sound.play("month")


func _start() -> void:
	displayed_population = 0.0
	City.start_city()
	get_viewport().gui_release_focus()


func _resume() -> void:
	City.resume_city()
	get_viewport().gui_release_focus()


func _save_and_title() -> void:
	if City.save_city():
		_return_title()


func _return_title() -> void:
	City.set_phase("title")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()


func _request_quit() -> void:
	if closing:
		return
	closing = true
	if City.phase == "playing":
		City.save_city()
	await Sound.shutdown()
	get_tree().quit()
