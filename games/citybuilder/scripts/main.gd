extends Control
## 画面と入力を接続する。都市の状態は City が保持する。

const UI = preload("res://scripts/ui.gd")
const Backdrop = preload("res://scripts/backdrop.gd")
const View = preload("res://scripts/city_view.gd")
const Sim = preload("res://scripts/simulation.gd")
const TOOLS: Array[String] = [
	"road", "residential", "commercial", "industrial", "power", "park", "police", "fire", "empty"
]
const NAMES: Array[String] = ["道路", "住宅", "商業", "工業", "発電所", "公園", "警察", "消防", "撤去"]
const OVERLAYS: Array[String] = ["none", "power", "pollution", "crime", "fire"]
const OVERLAY_NAMES: Array[String] = ["通常", "電力", "公害", "犯罪", "防火"]
const TUTORIAL_TITLES: Array[String] = ["道路沿いを選ぶ", "完成形を確認する", "時間を進める"]
const TUTORIAL_NOTES: Array[String] = [
	"水色の細線は配置できる区画です。\n住宅の製図道具を選び、道路沿いへ記入します。",
	"黄色いカーソルの建物は配置後の予告です。\n赤い輪郭では、右の判定欄に理由が出ます。",
	"区画を記入したら『翌月』で成長を確認します。\n右下の縮尺で、同じ図面の区画と全体を行き来できます。",
]

var screen: Control
var view: Control
var selected_tool: int = 1
var overlay_index: int = 0
var stats: Label
var needs: Label
var warnings: Label
var tool_description: Label
var placement_label: Label
var objective_label: Label
var time_label: Label
var scale_label: Label
var toast: Label
var tax_label: Label
var tax_slider: HSlider
var demand_bars: Array[ProgressBar] = []
var tool_buttons: Array[Button] = []
var toast_tween: Tween
var transition: Tween
var displayed_population: float = 0.0
var dragging: bool = false
var last_cell: Vector2i = Vector2i(-1, -1)
var closing: bool = false
var keyboard_cursor: bool = false
var tax_held: Dictionary = {"tax_down": false, "tax_up": false}
var notice_panel: Panel
var tutorial_panel: Control


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
	tutorial_panel = null
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
	transition.tween_property(screen, "modulate:a", 1.0, 0.24)


func _title() -> void:
	screen.add_child(Backdrop.new())
	UI.panel(screen, Rect2(44, 42, 516, 636), Color("052d55f2"))
	UI.label(screen, "BLUEPRINT // MUNICIPAL 600", Rect2(74, 70, 450, 26), 15, UI.CYAN)
	UI.rule(screen, Vector2(74, 108), Vector2(530, 108), UI.MUTED)
	UI.label(screen, "A-01", Rect2(74, 126, 100, 30), 18, UI.ORANGE)
	UI.label(screen, "青焼き都市計画", Rect2(74, 162, 450, 70), 47)
	UI.label(screen, "こもれび市・基本図面", Rect2(76, 230, 430, 36), 24, UI.CYAN)
	UI.label(
		screen,
		"道路と電力をつなぎ、住宅と仕事を記入する。\n一枚の図面を育て、人口600人の承認印を目指す。",
		Rect2(76, 288, 442, 72),
		19
	)
	UI.label(screen, "開く図面を選択", Rect2(76, 390, 320, 28), 16, UI.MUTED)
	var start: Button = UI.button(screen, "□  新規図面を起こす", Rect2(76, 426, 448, 58), _start)
	start.grab_focus()
	var resume: Button = UI.button(screen, "□  保存図面を再開", Rect2(76, 496, 448, 52), _resume)
	resume.disabled = City.saved_city().is_empty()
	UI.label(
		screen,
		"保存図面がありません — 新規図面を選択" if resume.disabled else "保存済みの縮尺と街の状態を復元できます",
		Rect2(78, 554, 440, 26),
		14,
		UI.MUTED if resume.disabled else UI.CYAN
	)
	UI.button(screen, "作業を終了", Rect2(76, 594, 188, 44), _request_quit)
	UI.label(screen, "選択中の枠を Enter / A で開く", Rect2(282, 602, 242, 28), 14, UI.ORANGE)
	UI.label(screen, "DRAWING No. CB-600  /  REV. 02", Rect2(858, 650, 360, 28), 15, UI.PAPER)
	Sound.track("title")


func _play() -> void:
	UI.blueprint_surface(screen, Rect2(0, 0, 1280, 720), UI.BLUE)
	UI.panel(screen, Rect2(18, 18, 902, 684), Color("052f59ed"))
	UI.label(screen, "図面 A-01  /  32×32 区画配置図", Rect2(32, 30, 500, 30), 19, UI.CYAN)
	UI.label(screen, "N ↑", Rect2(842, 31, 60, 28), 16, UI.ORANGE)
	view = View.new()
	view.overlay = OVERLAYS[overlay_index]
	view.position = Vector2(30, 72)
	view.size = Vector2(878, 430)
	screen.add_child(view)
	view.focus_cell(Vector2i(12, 16), 1.05)
	view.gui_input.connect(_map_input)
	UI.panel(screen, Rect2(934, 18, 328, 684), Color("052d55f5"))
	UI.label(screen, "CITY LEDGER / 都市台帳", Rect2(950, 34, 296, 28), 17, UI.CYAN)
	UI.rule(screen, Vector2(950, 68), Vector2(1246, 68), UI.MUTED)
	stats = UI.label(screen, "", Rect2(950, 78, 296, 82), 18)
	needs = UI.label(screen, "", Rect2(950, 164, 296, 54), 15, UI.PAPER)
	UI.label(screen, "需要曲線", Rect2(950, 222, 110, 24), 14, UI.MUTED)
	for index: int in range(3):
		UI.label(screen, ["住", "商", "工"][index], Rect2(950, 251 + index * 29, 26, 22), 14)
		var bar := ProgressBar.new()
		bar.position = Vector2(980, 257 + index * 29)
		bar.size = Vector2(262, 8)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", UI.box(Color("082642"), UI.MUTED, 0))
		bar.add_theme_stylebox_override(
			"fill", UI.box([UI.CYAN, Color("83ddff"), UI.ORANGE][index], Color.TRANSPARENT, 0)
		)
		screen.add_child(bar)
		demand_bars.append(bar)
	tool_description = UI.label(screen, "", Rect2(950, 344, 296, 48), 17, UI.CYAN)
	placement_label = UI.label(screen, "", Rect2(950, 397, 296, 64), 15)
	placement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label = UI.label(screen, "", Rect2(950, 468, 296, 57), 15, UI.ORANGE)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warnings = UI.label(screen, "", Rect2(950, 530, 296, 54), 14, UI.ALERT)
	warnings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tax_label = UI.label(screen, "", Rect2(950, 590, 296, 24), 14, UI.PAPER)
	var tax := HSlider.new()
	tax.focus_mode = Control.FOCUS_NONE
	tax_slider = tax
	tax.position = Vector2(950, 616)
	tax.size = Vector2(296, 18)
	tax.min_value = 0
	tax.max_value = 20
	tax.step = 1
	tax.value = City.state.tax
	tax.value_changed.connect(City.set_tax)
	screen.add_child(tax)
	UI.button(screen, "図面を保存して戻る", Rect2(950, 650, 296, 38), _save_and_title)
	_toolbar()
	_time_controls()
	notice_panel = UI.panel(screen, Rect2(44, 82, 850, 44), Color("062d55ee"))
	toast = UI.label(screen, "水色の輪郭の区画へ住宅を記入します。", Rect2(56, 90, 824, 28), 16, UI.PAPER)
	_refresh()
	if City.tutorial_active:
		_tutorial()
	Sound.track("city" if City.state.population >= 300 else "town")


func _toolbar() -> void:
	UI.panel(screen, Rect2(30, 514, 558, 174), Color("062d55f2"))
	UI.label(screen, "製図道具  /  Q・E / LB・RB で選択", Rect2(44, 524, 530, 26), 14, UI.MUTED)
	for index: int in range(TOOLS.size()):
		var button: Button = UI.button(
			screen,
			"%s  %d" % [NAMES[index], Sim.COSTS[TOOLS[index]]],
			Rect2(44 + index % 3 * 177, 556 + index / 3 * 42, 166, 36),
			_select_tool.bind(index)
		)
		button.add_theme_font_size_override("font_size", 15)
		tool_buttons.append(button)


func _time_controls() -> void:
	UI.panel(screen, Rect2(600, 514, 308, 174), Color("062d55f2"))
	UI.label(screen, "縮尺・時間", Rect2(614, 524, 130, 26), 14, UI.MUTED)
	time_label = UI.label(screen, "", Rect2(740, 524, 154, 26), 14, UI.CYAN)
	for index: int in range(3):
		UI.button(
			screen,
			["Ⅱ", "1倍", "3倍"][index],
			Rect2(614 + index * 66, 556, 58, 34),
			_set_speed.bind([0, 1, 3][index])
		)
	UI.button(screen, "翌月 N / X", Rect2(614, 600, 130, 34), _advance_month)
	UI.button(screen, "問題表示 O / Y", Rect2(752, 600, 142, 34), _cycle_overlay)
	UI.button(screen, "－", Rect2(614, 644, 48, 32), _zoom_by.bind(-0.12))
	UI.button(screen, "＋", Rect2(670, 644, 48, 32), _zoom_by.bind(0.12))
	UI.button(screen, "図面全体", Rect2(726, 644, 104, 32), _center_map)
	scale_label = UI.label(screen, "", Rect2(836, 647, 58, 26), 13, UI.ORANGE)


func _tutorial() -> void:
	tutorial_panel = Control.new()
	tutorial_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(tutorial_panel)
	var note: Panel = UI.panel(tutorial_panel, Rect2(52, 142, 444, 260), Color("073965f8"))
	note.add_theme_stylebox_override("panel", UI.box(Color("073965f8"), UI.ORANGE, 1, 2))
	UI.label(
		tutorial_panel,
		"HAND NOTE 0%d  /  %s" % [City.tutorial_step + 1, TUTORIAL_TITLES[City.tutorial_step]],
		Rect2(78, 166, 390, 30),
		16,
		UI.ORANGE
	)
	UI.rule(tutorial_panel, Vector2(78, 204), Vector2(468, 204), UI.ORANGE)
	var note_text: Label = UI.label(
		tutorial_panel,
		TUTORIAL_NOTES[City.tutorial_step],
		Rect2(78, 220, 390, 76),
		17,
		UI.PAPER
	)
	note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var next_label: String = (
		"図面を使い始める  Enter / A" if City.tutorial_step == 2 else "次の注記  Enter / A"
	)
	var next: Button = UI.button(
		tutorial_panel, next_label, Rect2(78, 314, 254, 48), _advance_tutorial
	)
	UI.button(tutorial_panel, "スキップ  Esc / B", Rect2(340, 314, 128, 48), _skip_tutorial)
	next.grab_focus()
	var target: Vector2 = [Vector2(310, 582), Vector2(520, 310), Vector2(680, 616)][
		City.tutorial_step
	]
	var arrow := Line2D.new()
	arrow.points = PackedVector2Array([Vector2(472, 390), Vector2(520, 430), target])
	arrow.default_color = UI.ORANGE
	arrow.width = 3.0
	arrow.antialiased = true
	tutorial_panel.add_child(arrow)
	var ring := Polygon2D.new()
	ring.polygon = PackedVector2Array(
		[
			target + Vector2(0, -10),
			target + Vector2(16, 0),
			target + Vector2(0, 10),
			target + Vector2(-16, 0),
		]
	)
	ring.color = Color(UI.ORANGE, 0.55)
	tutorial_panel.add_child(ring)


func _result() -> void:
	screen.add_child(Backdrop.new())
	UI.panel(screen, Rect2(226, 76, 828, 570), Color("052d55f6"))
	var won: bool = City.state.outcome == "clear"
	UI.label(screen, "FINAL DRAWING REVIEW / 最終図面審査", Rect2(266, 112, 720, 34), 18, UI.CYAN)
	UI.rule(screen, Vector2(266, 158), Vector2(1014, 158), UI.MUTED)
	UI.label(
		screen,
		"承認済" if won else "再設計",
		Rect2(266, 186, 250, 74),
		52,
		UI.ORANGE if won else UI.ALERT
	)
	UI.label(
		screen,
		"人口600人の図面が完成しました" if won else "資金不足が3か月続きました",
		Rect2(266, 272, 700, 42),
		24
	)
	UI.label(
		screen,
		"到達人口  %d人\n経過月      %d月\n雇用        %d人分\n最終資金    %d"
		% [City.state.population, City.state.month, City.state.jobs, City.state.money],
		Rect2(266, 336, 360, 150),
		21
	)
	var next_note: Label = UI.label(
		screen,
		"次にできること\n同じ図面へ戻り、\n道路・電力・雇用を再配置できます。",
		Rect2(650, 340, 330, 100),
		17,
		UI.CYAN
	)
	next_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var button: Button = UI.button(
		screen, "タイトル図面へ戻る  Enter / A", Rect2(266, 530, 714, 56), _return_title
	)
	button.grab_focus()
	Sound.track("result")


func _refresh() -> void:
	if City.phase != "playing" or not is_instance_valid(view):
		return
	view.set_city(City.state, City.analysis)
	stats.text = _stats_text()
	var grid_power: Vector2i = _cursor_power()
	needs.text = (
		"電力 全系統 %d / %d\n選択区画の系統 %d / %d　維持費 %d"
		% [
			City.analysis.get("power_used", 0),
			City.analysis.get("capacity", 0),
			grid_power.x,
			grid_power.y,
			City.state.expenses,
		]
	)
	var demands: Dictionary = City.analysis.get("demand", City.state.demand)
	for index: int in range(3):
		demand_bars[index].value = float(demands.get(["r", "c", "i"][index], 0))
	tool_description.text = (
		"選択中：%s  /  費用 %d\n%s"
		% [
			NAMES[selected_tool],
			Sim.COSTS[TOOLS[selected_tool]],
			"成長後の等角線画を予告" if selected_tool not in [0, 8] else "区画の輪郭へ直接記入",
		]
	)
	tax_slider.set_value_no_signal(City.state.tax)
	tax_label.text = "税率 %d%%  /  Z・C / LT・RT" % City.state.tax
	warnings.text = " / ".join(City.analysis.get("warnings", []))
	if warnings.text.is_empty():
		warnings.text = "審査メモ：現在の問題報告はありません"
	objective_label.text = _next_action()
	time_label.text = "%s / %s" % [
		"停止" if City.speed == 0 else "%d倍" % City.speed, OVERLAY_NAMES[overlay_index]
	]
	scale_label.text = "%.2f×" % view.zoom
	for index: int in range(tool_buttons.size()):
		var selected: bool = index == selected_tool
		tool_buttons[index].add_theme_stylebox_override(
			"normal",
			UI.box(
				Color("096a9d") if selected else Color("063663e8"),
				UI.ORANGE if selected else UI.MUTED,
				2,
				2 if selected else 1
			)
		)
		tool_buttons[index].modulate = (
			Color.WHITE if City.state.money >= Sim.COSTS[TOOLS[index]] else Color("768fa0")
		)
	_update_selection()
	Sound.track("city" if City.state.population >= 300 else "town")


func _stats_text() -> String:
	return (
		"資金 %d　人口 %d / 600\n雇用 %d　経過 %d月"
		% [City.state.money, int(displayed_population), City.state.jobs, City.state.month]
	)


func _next_action() -> String:
	if City.state.money < 0:
		return "次：建設を止め、税率と維持費を見直します"
	if City.state.population == 0:
		return "次：住宅を道路沿いへ記入し、『翌月』で成長を確認します"
	if City.state.jobs < City.state.population:
		return "次：商業か工業を道路沿いへ増やし、雇用を確保します"
	if City.state.population < 600:
		return "次：問題表示を切り替え、人口600人まで不足を補います"
	return "次：完成した図面の最終報告を確認します"


func _cursor_power() -> Vector2i:
	var capacities: Array = City.analysis.get("component_capacity", [])
	var used: Array = City.analysis.get("component_used", [])
	var nearby: Array[Vector2i] = [
		view.cursor,
		view.cursor + Vector2i.LEFT,
		view.cursor + Vector2i.RIGHT,
		view.cursor + Vector2i.UP,
		view.cursor + Vector2i.DOWN,
	]
	for cell: Vector2i in nearby:
		if cell.x < 0 or cell.y < 0 or cell.x >= Sim.SIZE or cell.y >= Sim.SIZE:
			continue
		var index: int = cell.y * Sim.SIZE + cell.x
		if index < capacities.size() and int(capacities[index]) > 0:
			return Vector2i(int(used[index]), int(capacities[index]))
	return Vector2i.ZERO


func _update_selection() -> void:
	if City.phase != "playing" or not is_instance_valid(view):
		return
	var reason: String = Sim.placement_reason(City.state, view.cursor, TOOLS[selected_tool])
	var allowed: bool = reason.is_empty()
	view.set_selection(TOOLS[selected_tool], view.cursor, allowed, reason)
	if not is_instance_valid(placement_label):
		return
	placement_label.text = (
		"配置可：クリック / Enter / A で図面へ記入"
		if allowed
		else "配置不可：" + reason
	)
	placement_label.add_theme_color_override("font_color", UI.CYAN if allowed else UI.ALERT)


# 表示の補間は時間経過を積算するため非冪等。
func _process(delta: float) -> void:
	if City.phase != "playing" or not is_instance_valid(stats):
		return
	displayed_population = move_toward(displayed_population, float(City.state.population), delta * 160)
	if is_instance_valid(notice_panel) and is_instance_valid(toast):
		notice_panel.modulate.a = toast.modulate.a
	stats.text = _stats_text()


func _map_input(event: InputEvent) -> void:
	if City.tutorial_active:
		return
	if event is InputEventMouseButton:
		view.cursor = view.screen_to_cell(event.position)
		_update_selection()
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
		_update_selection()
		view.queue_redraw()


# チュートリアルのボタンがパッド B を GUI 操作として消費する前に扱う。
func _input(event: InputEvent) -> void:
	if City.phase != "playing" or not City.tutorial_active:
		return
	var pad_cancel: bool = (
		event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed
	)
	if event.is_action_pressed("ui_cancel") or pad_cancel:
		_skip_tutorial()
		get_viewport().set_input_as_handled()


func _paint(point: Vector2) -> void:
	var cell: Vector2i = view.screen_to_cell(point)
	if cell == last_cell:
		return
	var current: Vector2i = last_cell
	var distance: Vector2i = (cell - current).abs()
	var moved: Vector2i = Vector2i.ZERO
	if last_cell == Vector2i(-1, -1):
		_place(cell)
	else:
		# 移動イベントが飛んでも、道路を上下左右で接続する通過セルを埋める。
		while current != cell:
			var cross_x: int = (2 * moved.x + 1) * distance.y
			var cross_y: int = (2 * moved.y + 1) * distance.x
			if current.x != cell.x and (current.y == cell.y or cross_x <= cross_y):
				current.x += signi(cell.x - current.x)
				moved.x += 1
			else:
				current.y += signi(cell.y - current.y)
				moved.y += 1
			_place(current)
	last_cell = cell


func _place(cell: Vector2i) -> void:
	view.cursor = cell
	if City.build(cell, TOOLS[selected_tool]):
		view.burst(cell, selected_tool == 8)
		Sound.play("demolish" if selected_tool == 8 else "build")
	else:
		Sound.play("alert")
	_update_selection()


func _unhandled_input(event: InputEvent) -> void:
	for action: String in tax_held:
		if event.is_action_released(action):
			tax_held[action] = false
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	if event.is_action_pressed("mute"):
		Sound.set_muted(not Sound.muted)
	if City.phase != "playing":
		return
	if City.tutorial_active:
		if event.is_action_pressed("build") or event.is_action_pressed("ui_accept"):
			_advance_tutorial()
		elif event.is_action_pressed("ui_cancel"):
			_skip_tutorial()
		return
	if event.is_action_pressed("tool_next"):
		_select_tool((selected_tool + 1) % TOOLS.size())
	if event.is_action_pressed("tool_previous"):
		_select_tool(posmod(selected_tool - 1, TOOLS.size()))
	if event.is_action_pressed("pause_time"):
		_set_speed(1 if City.speed == 0 else 0)
	if event.is_action_pressed("tax_down"):
		_adjust_tax("tax_down", -1)
	if event.is_action_pressed("tax_up"):
		_adjust_tax("tax_up", 1)
	if event.is_action_pressed("speed_cycle"):
		_set_speed({0: 1, 1: 3, 3: 0}[City.speed])
	if event.is_action_pressed("next_month"):
		_advance_month()
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
				"ui_down": Vector2i.DOWN,
			}[direction]
			view.cursor = (view.cursor + offset).clamp(Vector2i.ZERO, Vector2i(31, 31))
			keyboard_cursor = true
			_follow_cursor()
			_update_selection()
	if event.is_action_pressed("build"):
		_place(view.cursor)
		get_viewport().set_input_as_handled()


func _adjust_tax(action: String, amount: int) -> void:
	if tax_held[action]:
		return
	tax_held[action] = true
	City.set_tax(clampi(int(City.state.tax) + amount, 0, 20))


func _follow_cursor() -> void:
	var point: Vector2 = view.cell_to_screen(view.cursor)
	var target := Vector2(
		clampf(point.x, 70.0, view.size.x - 70.0), clampf(point.y, 60.0, view.size.y - 60.0)
	)
	view.pan += target - point
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


func _advance_month() -> void:
	get_viewport().gui_release_focus()
	City.advance_now()
	_refresh()


func _cycle_overlay() -> void:
	overlay_index = (overlay_index + 1) % OVERLAYS.size()
	view.overlay = OVERLAYS[overlay_index]
	get_viewport().gui_release_focus()
	_refresh()


func _zoom_by(amount: float) -> void:
	view.zoom = clampf(view.zoom + amount, 0.48, 1.7)
	get_viewport().gui_release_focus()
	view.queue_redraw()
	_refresh()


func _center_map() -> void:
	view.show_overview()
	view.queue_redraw()
	get_viewport().gui_release_focus()
	_refresh()


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


func _advance_tutorial() -> void:
	City.advance_tutorial()
	_render()
	Sound.play("click")


func _skip_tutorial() -> void:
	City.finish_tutorial()
	_render()
	Sound.play("click")


func _start() -> void:
	displayed_population = 0.0
	City.start_city()
	get_viewport().gui_release_focus()


func _resume() -> void:
	if not City.resume_city():
		return
	displayed_population = float(City.state.population)
	_refresh()
	if City.phase == "playing":
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
